// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows GPU 性能计数器采样
//
//   文件:       crates/taskmgr-windows/src/gpu.rs
//
//   日期:       2026年08月20日
//   环境:       Windows x64/ARM64 API；Rust 1.97.1；x86_64-pc-windows-gnu 交叉检查
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Windows PDH；GPU Engine；GPU Adapter Memory；DXGI 1.1
// --------------------------------------------------------------------------

//! 用持久 PDH 查询采集 WDDM GPU engine 与 adapter-memory 实例。
//!
//! 首轮只建立 PDH 基线并返回明确的“等待基线”错误；只有第二轮开始才产生速率值。
//! 实例名缓冲区经过边界验证，适配器身份来自 WDDM LUID 与 physical index。

use std::collections::{BTreeMap, HashMap, HashSet};
use std::mem::size_of;
use std::ptr::{null, null_mut};
use std::slice;

use taskmgr_core::{
    BackendError, GpuAdapter, GpuData, GpuEngine, HISTORY_CAPACITY, HistoryBuffer, SnapshotData,
};
use windows::Win32::Graphics::Dxgi::{
    CreateDXGIFactory1, DXGI_ADAPTER_FLAG_REMOTE, DXGI_ADAPTER_FLAG_SOFTWARE, DXGI_ERROR_NOT_FOUND,
    IDXGIFactory1,
};
use windows_sys::Win32::Foundation::ERROR_SUCCESS;
use windows_sys::Win32::System::Performance::{
    PDH_CSTATUS_INVALID_DATA, PDH_CSTATUS_NEW_DATA, PDH_CSTATUS_VALID_DATA,
    PDH_FMT_COUNTERVALUE_ITEM_W, PDH_FMT_DOUBLE, PDH_FMT_LARGE, PDH_HCOUNTER, PDH_HQUERY,
    PDH_MORE_DATA, PdhAddEnglishCounterW, PdhCloseQuery, PdhCollectQueryData,
    PdhGetFormattedCounterArrayW, PdhOpenQueryW,
};

const ENGINE_PATH: &str = r"\GPU Engine(*)\Utilization Percentage";
const DEDICATED_PATH: &str = r"\GPU Adapter Memory(*)\Dedicated Usage";
const SHARED_PATH: &str = r"\GPU Adapter Memory(*)\Shared Usage";
const MAX_ARRAY_BYTES: u32 = 64 * 1024 * 1024;

#[derive(Clone, Copy, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
struct AdapterId {
    luid_high: u32,
    luid_low: u32,
    physical_index: u32,
}

#[derive(Clone, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
struct EngineId {
    adapter: AdapterId,
    ordinal: u32,
    kind: String,
}

struct AdapterHistory {
    dedicated: HistoryBuffer,
    shared: HistoryBuffer,
    engines: HashMap<(u32, String), HistoryBuffer>,
}

#[derive(Clone)]
struct AdapterInventory {
    name: String,
    dedicated_total: u64,
    shared_total: u64,
}

impl AdapterHistory {
    fn new() -> Self {
        Self {
            dedicated: HistoryBuffer::new(HISTORY_CAPACITY),
            shared: HistoryBuffer::new(HISTORY_CAPACITY),
            engines: HashMap::new(),
        }
    }
}

pub(crate) struct GpuSampler {
    query: Option<PdhQuery>,
    histories: HashMap<AdapterId, AdapterHistory>,
}

impl GpuSampler {
    pub(crate) fn new() -> Self {
        Self {
            query: None,
            histories: HashMap::new(),
        }
    }

    pub(crate) fn sample(&mut self) -> Result<SnapshotData, BackendError> {
        if self.query.is_none() {
            self.query = Some(PdhQuery::open()?);
        }
        let query = self.query.as_mut().expect("PDH query initialized above");
        if let Err(error) = query.collect() {
            self.query = None;
            return Err(error);
        }
        if !query.primed {
            query.primed = true;
            return Err(BackendError {
                domain: "pdh".to_string(),
                code: i64::from(PDH_CSTATUS_INVALID_DATA),
                context: "prime Windows GPU counters".to_string(),
                message: "GPU counters are waiting for a second sample".to_string(),
            });
        }

        let engine = query.read_double(query.engine, query.engine_error.clone())?;
        let dedicated = query.read_large(query.dedicated, query.dedicated_error.clone())?;
        let shared = query.read_large(query.shared, query.shared_error.clone())?;
        let mut builders = BTreeMap::<AdapterId, AdapterBuilder>::new();
        let mut first_detail_error = None;

        for reading in engine.values {
            match parse_engine_instance(&reading.name) {
                Some(id) if reading.value.is_finite() && reading.value >= 0.0 => {
                    *builders
                        .entry(id.adapter)
                        .or_default()
                        .engines
                        .entry(id)
                        .or_default() += reading.value;
                }
                _ => {
                    first_detail_error.get_or_insert_with(|| {
                        invalid_data("parse Windows GPU Engine performance instance")
                    });
                }
            };
        }
        for reading in dedicated.values {
            match parse_memory_instance(&reading.name) {
                Some(id) if reading.value >= 0 => {
                    builders.entry(id).or_default().dedicated = Some(reading.value as u64);
                }
                _ => {
                    first_detail_error.get_or_insert_with(|| {
                        invalid_data("parse Windows dedicated GPU memory instance")
                    });
                }
            };
        }
        for reading in shared.values {
            match parse_memory_instance(&reading.name) {
                Some(id) if reading.value >= 0 => {
                    builders.entry(id).or_default().shared = Some(reading.value as u64);
                }
                _ => {
                    first_detail_error.get_or_insert_with(|| {
                        invalid_data("parse Windows shared GPU memory instance")
                    });
                }
            };
        }
        first_detail_error = first_detail_error
            .or(engine.error)
            .or(dedicated.error)
            .or(shared.error);

        let inventory = match query_dxgi_inventory() {
            Ok(inventory) => inventory,
            Err(error) => {
                first_detail_error.get_or_insert(error);
                HashMap::new()
            }
        };
        for &(luid_high, luid_low) in inventory.keys() {
            builders
                .entry(AdapterId {
                    luid_high,
                    luid_low,
                    physical_index: 0,
                })
                .or_default();
        }

        if builders.is_empty() {
            if let Some(error) = first_detail_error {
                return Err(error);
            }
            self.histories.clear();
            return Ok(SnapshotData::Gpu(GpuData {
                adapters: Vec::new(),
                selected_adapter: None,
            }));
        }

        let live = builders.keys().copied().collect::<HashSet<_>>();
        let mut physical_counts = HashMap::<(u32, u32), usize>::new();
        for id in &live {
            *physical_counts
                .entry((id.luid_high, id.luid_low))
                .or_default() += 1;
        }
        self.histories.retain(|id, _| live.contains(id));
        let mut adapters = Vec::with_capacity(builders.len());
        for (index, (id, builder)) in builders.into_iter().enumerate() {
            let history = self.histories.entry(id).or_insert_with(AdapterHistory::new);
            if let Some(value) = builder.dedicated {
                history.dedicated.push(value as f64);
            }
            if let Some(value) = builder.shared {
                history.shared.push(value as f64);
            }
            let mut engines = Vec::with_capacity(builder.engines.len());
            let mut live_engines = HashSet::with_capacity(builder.engines.len());
            for (engine_id, utilization) in builder.engines {
                let utilization = utilization.clamp(0.0, 100.0);
                let history_key = (engine_id.ordinal, engine_id.kind.clone());
                live_engines.insert(history_key.clone());
                let engine_history = history
                    .engines
                    .entry(history_key)
                    .or_insert_with(|| HistoryBuffer::new(HISTORY_CAPACITY));
                engine_history.push(utilization);
                engines.push(GpuEngine {
                    name: engine_display_name(&engine_id.kind, engine_id.ordinal),
                    utilization_percent: Some(utilization),
                    history: engine_history.snapshot(),
                });
            }
            history
                .engines
                .retain(|engine, _| live_engines.contains(engine));
            engines.sort_by(|left, right| left.name.cmp(&right.name));
            let utilization_percent = engines
                .iter()
                .filter_map(|engine| engine.utilization_percent)
                .reduce(f64::max);
            let stable_id = adapter_id_string(id);
            let inventory = inventory.get(&(id.luid_high, id.luid_low));
            let single_physical =
                physical_counts.get(&(id.luid_high, id.luid_low)).copied() == Some(1);
            adapters.push(GpuAdapter {
                id: stable_id.clone(),
                name: inventory
                    .map(|inventory| inventory.name.clone())
                    .unwrap_or_else(|| format!("GPU {index} ({stable_id})")),
                utilization_percent,
                dedicated_used_bytes: builder.dedicated,
                dedicated_total_bytes: inventory
                    .filter(|_| single_physical)
                    .map(|inventory| inventory.dedicated_total)
                    .filter(|value| *value > 0),
                shared_used_bytes: builder.shared,
                shared_total_bytes: inventory
                    .filter(|_| single_physical)
                    .map(|inventory| inventory.shared_total)
                    .filter(|value| *value > 0),
                temperature_celsius: None,
                driver_version: None,
                driver_date: None,
                graphics_api: Some("DirectX/DXGI + WDDM/PDH".to_string()),
                physical_location: None,
                hardware_reserved_bytes: None,
                engines,
                dedicated_history: history.dedicated.snapshot(),
                shared_history: history.shared.snapshot(),
                detail_error: first_detail_error.clone(),
            });
        }
        Ok(SnapshotData::Gpu(GpuData {
            selected_adapter: (!adapters.is_empty()).then_some(0),
            adapters,
        }))
    }
}

#[derive(Default)]
struct AdapterBuilder {
    engines: BTreeMap<EngineId, f64>,
    dedicated: Option<u64>,
    shared: Option<u64>,
}

struct PdhQuery {
    handle: usize,
    engine: usize,
    engine_error: Option<BackendError>,
    dedicated: usize,
    dedicated_error: Option<BackendError>,
    shared: usize,
    shared_error: Option<BackendError>,
    primed: bool,
    engine_storage: Vec<usize>,
    dedicated_storage: Vec<usize>,
    shared_storage: Vec<usize>,
}

impl PdhQuery {
    fn open() -> Result<Self, BackendError> {
        let mut handle = null_mut();
        // SAFETY: output receives one query handle owned by PdhQuery on success.
        let status = unsafe { PdhOpenQueryW(null(), 0, &mut handle) };
        if status != ERROR_SUCCESS {
            return Err(pdh_error("PdhOpenQueryW for Windows GPU", status));
        }
        let mut query = Self {
            handle: handle as usize,
            engine: 0,
            engine_error: None,
            dedicated: 0,
            dedicated_error: None,
            shared: 0,
            shared_error: None,
            primed: false,
            engine_storage: Vec::new(),
            dedicated_storage: Vec::new(),
            shared_storage: Vec::new(),
        };
        (query.engine, query.engine_error) = query.add_optional(ENGINE_PATH);
        (query.dedicated, query.dedicated_error) = query.add_optional(DEDICATED_PATH);
        (query.shared, query.shared_error) = query.add_optional(SHARED_PATH);
        if query.engine == 0 && query.dedicated == 0 && query.shared == 0 {
            return Err(query
                .engine_error
                .clone()
                .or(query.dedicated_error.clone())
                .or(query.shared_error.clone())
                .unwrap_or_else(|| invalid_data("initialize Windows GPU counters")));
        }
        Ok(query)
    }

    fn add_optional(&self, path: &str) -> (usize, Option<BackendError>) {
        let path = path.encode_utf16().chain([0]).collect::<Vec<_>>();
        let mut counter = null_mut();
        // SAFETY: query is live, path is null-terminated, and output is writable.
        let status = unsafe {
            PdhAddEnglishCounterW(self.handle as PDH_HQUERY, path.as_ptr(), 0, &mut counter)
        };
        if status == ERROR_SUCCESS {
            (counter as usize, None)
        } else {
            (0, Some(pdh_error("PdhAddEnglishCounterW GPU", status)))
        }
    }

    fn collect(&mut self) -> Result<(), BackendError> {
        // SAFETY: query remains live and is only accessed from the backend sampling thread.
        let status = unsafe { PdhCollectQueryData(self.handle as PDH_HQUERY) };
        if status == ERROR_SUCCESS {
            Ok(())
        } else {
            Err(pdh_error("PdhCollectQueryData Windows GPU", status))
        }
    }

    fn read_double(
        &mut self,
        counter: usize,
        source_error: Option<BackendError>,
    ) -> Result<CounterRead<f64>, BackendError> {
        if counter == 0 {
            return Ok(CounterRead {
                values: Vec::new(),
                error: source_error,
            });
        }
        read_array(
            counter as PDH_HCOUNTER,
            PDH_FMT_DOUBLE,
            &mut self.engine_storage,
            |item| {
                // SAFETY: PDH_FMT_DOUBLE selects the initialized doubleValue union field.
                unsafe { item.FmtValue.Anonymous.doubleValue }
            },
        )
    }

    fn read_large(
        &mut self,
        counter: usize,
        source_error: Option<BackendError>,
    ) -> Result<CounterRead<i64>, BackendError> {
        if counter == 0 {
            return Ok(CounterRead {
                values: Vec::new(),
                error: source_error,
            });
        }
        let storage = if counter == self.dedicated {
            &mut self.dedicated_storage
        } else {
            &mut self.shared_storage
        };
        read_array(counter as PDH_HCOUNTER, PDH_FMT_LARGE, storage, |item| {
            // SAFETY: PDH_FMT_LARGE selects the initialized largeValue union field.
            unsafe { item.FmtValue.Anonymous.largeValue }
        })
    }
}

impl Drop for PdhQuery {
    fn drop(&mut self) {
        if self.handle != 0 {
            // SAFETY: self uniquely owns this live PDH query handle.
            let _status = unsafe { PdhCloseQuery(self.handle as PDH_HQUERY) };
            self.handle = 0;
        }
    }
}

struct CounterValue<T> {
    name: String,
    value: T,
}

struct CounterRead<T> {
    values: Vec<CounterValue<T>>,
    error: Option<BackendError>,
}

fn read_array<T>(
    counter: PDH_HCOUNTER,
    format: u32,
    storage: &mut Vec<usize>,
    read_value: impl Fn(&PDH_FMT_COUNTERVALUE_ITEM_W) -> T,
) -> Result<CounterRead<T>, BackendError> {
    let mut byte_count = 0u32;
    let mut item_count = 0u32;
    // SAFETY: documented size probe with null data output.
    let status = unsafe {
        PdhGetFormattedCounterArrayW(
            counter,
            format,
            &mut byte_count,
            &mut item_count,
            null_mut(),
        )
    };
    if status == ERROR_SUCCESS && item_count == 0 {
        return Ok(CounterRead {
            values: Vec::new(),
            error: None,
        });
    }
    if status != PDH_MORE_DATA {
        return Err(pdh_error("PdhGetFormattedCounterArrayW size", status));
    }
    if byte_count == 0 || byte_count > MAX_ARRAY_BYTES {
        return Err(invalid_data("Windows GPU PDH array size"));
    }
    let word_size = size_of::<usize>();
    let words = (byte_count as usize).div_ceil(word_size);
    storage.resize(words, 0);
    // SAFETY: usize storage is suitably aligned and has at least byte_count writable bytes.
    let status = unsafe {
        PdhGetFormattedCounterArrayW(
            counter,
            format,
            &mut byte_count,
            &mut item_count,
            storage.as_mut_ptr().cast(),
        )
    };
    if status != ERROR_SUCCESS {
        return Err(pdh_error("PdhGetFormattedCounterArrayW data", status));
    }
    let used = byte_count as usize;
    let item_bytes = (item_count as usize)
        .checked_mul(size_of::<PDH_FMT_COUNTERVALUE_ITEM_W>())
        .ok_or_else(|| invalid_data("Windows GPU PDH item count"))?;
    if used > storage.len() * word_size || item_bytes > used {
        return Err(invalid_data("Windows GPU PDH item bounds"));
    }
    let base = storage.as_ptr().cast::<u8>() as usize;
    let end = base
        .checked_add(used)
        .ok_or_else(|| invalid_data("Windows GPU PDH buffer bounds"))?;
    // SAFETY: the validated prefix contains item_count aligned PDH items.
    let items = unsafe {
        slice::from_raw_parts(
            storage.as_ptr().cast::<PDH_FMT_COUNTERVALUE_ITEM_W>(),
            item_count as usize,
        )
    };
    let mut values = Vec::with_capacity(items.len());
    let mut first_error = None;
    for item in items {
        let name = match unsafe { bounded_wide_string(item.szName, base, end) } {
            Ok(name) => name,
            Err(error) => {
                first_error.get_or_insert(error);
                continue;
            }
        };
        if !matches!(
            item.FmtValue.CStatus,
            PDH_CSTATUS_VALID_DATA | PDH_CSTATUS_NEW_DATA
        ) {
            first_error.get_or_insert_with(|| {
                pdh_error(
                    "Windows GPU formatted counter status",
                    item.FmtValue.CStatus,
                )
            });
            continue;
        }
        values.push(CounterValue {
            name,
            value: read_value(item),
        });
    }
    Ok(CounterRead {
        values,
        error: first_error,
    })
}

unsafe fn bounded_wide_string(
    pointer: *const u16,
    base: usize,
    end: usize,
) -> Result<String, BackendError> {
    let address = pointer as usize;
    if pointer.is_null()
        || address < base
        || address >= end
        || !address.is_multiple_of(size_of::<u16>())
    {
        return Err(invalid_data("Windows GPU PDH instance pointer"));
    }
    let units = (end - address) / size_of::<u16>();
    // SAFETY: pointer and upper bound were validated against the owned PDH result buffer.
    let value = unsafe { slice::from_raw_parts(pointer, units) };
    let length = value
        .iter()
        .position(|unit| *unit == 0)
        .ok_or_else(|| invalid_data("Windows GPU PDH instance terminator"))?;
    String::from_utf16(&value[..length])
        .map_err(|_| invalid_data("Windows GPU PDH instance encoding"))
}

fn parse_engine_instance(value: &str) -> Option<EngineId> {
    let parts = value.split('_').collect::<Vec<_>>();
    if parts.len() < 11
        || !parts[0].eq_ignore_ascii_case("pid")
        || !parts[2].eq_ignore_ascii_case("luid")
        || !parts[5].eq_ignore_ascii_case("phys")
        || !parts[7].eq_ignore_ascii_case("eng")
        || !parts[9].eq_ignore_ascii_case("engtype")
    {
        return None;
    }
    let kind = parts[10..].join("_");
    (!kind.is_empty()).then_some(EngineId {
        adapter: AdapterId {
            luid_high: parse_hex(parts[3])?,
            luid_low: parse_hex(parts[4])?,
            physical_index: parse_decimal(parts[6])?,
        },
        ordinal: parse_decimal(parts[8])?,
        kind,
    })
}

fn parse_memory_instance(value: &str) -> Option<AdapterId> {
    let parts = value.split('_').collect::<Vec<_>>();
    if parts.len() != 5
        || !parts[0].eq_ignore_ascii_case("luid")
        || !parts[3].eq_ignore_ascii_case("phys")
    {
        return None;
    }
    Some(AdapterId {
        luid_high: parse_hex(parts[1])?,
        luid_low: parse_hex(parts[2])?,
        physical_index: parse_decimal(parts[4])?,
    })
}

fn parse_hex(value: &str) -> Option<u32> {
    let digits = value
        .strip_prefix("0x")
        .or_else(|| value.strip_prefix("0X"))?;
    (!digits.is_empty() && digits.len() <= 8 && digits.bytes().all(|byte| byte.is_ascii_hexdigit()))
        .then(|| u32::from_str_radix(digits, 16).ok())
        .flatten()
}

fn parse_decimal(value: &str) -> Option<u32> {
    (!value.is_empty() && value.bytes().all(|byte| byte.is_ascii_digit()))
        .then(|| value.parse().ok())
        .flatten()
}

fn adapter_id_string(id: AdapterId) -> String {
    format!(
        "luid_{:#x}_{:#x}_phys_{}",
        id.luid_high, id.luid_low, id.physical_index
    )
}

fn query_dxgi_inventory() -> Result<HashMap<(u32, u32), AdapterInventory>, BackendError> {
    // SAFETY: CreateDXGIFactory1 initializes and returns one reference-counted COM interface.
    let factory: IDXGIFactory1 = unsafe { CreateDXGIFactory1() }
        .map_err(|error| hresult_error("CreateDXGIFactory1 GPU inventory", error.code().0))?;
    let mut inventory = HashMap::new();
    let mut index = 0u32;
    loop {
        // SAFETY: factory remains live for enumeration and index is monotonically bounded by DXGI.
        let adapter = match unsafe { factory.EnumAdapters1(index) } {
            Ok(adapter) => adapter,
            Err(error) if error.code() == DXGI_ERROR_NOT_FOUND => break,
            Err(error) => {
                return Err(hresult_error(
                    "IDXGIFactory1::EnumAdapters1 GPU inventory",
                    error.code().0,
                ));
            }
        };
        index = index
            .checked_add(1)
            .ok_or_else(|| invalid_data("DXGI adapter enumeration index"))?;
        // SAFETY: adapter is a live IDXGIAdapter1 and GetDesc1 writes its value result.
        let description = unsafe { adapter.GetDesc1() }.map_err(|error| {
            hresult_error("IDXGIAdapter1::GetDesc1 GPU inventory", error.code().0)
        })?;
        let excluded_flags = (DXGI_ADAPTER_FLAG_SOFTWARE.0 | DXGI_ADAPTER_FLAG_REMOTE.0) as u32;
        if description.Flags & excluded_flags != 0 {
            continue;
        }
        let length = description
            .Description
            .iter()
            .position(|unit| *unit == 0)
            .unwrap_or(description.Description.len());
        let name = String::from_utf16(&description.Description[..length])
            .map_err(|_| invalid_data("DXGI adapter description encoding"))?;
        inventory.insert(
            (
                description.AdapterLuid.HighPart as u32,
                description.AdapterLuid.LowPart,
            ),
            AdapterInventory {
                name,
                dedicated_total: description.DedicatedVideoMemory as u64,
                shared_total: description.SharedSystemMemory as u64,
            },
        );
    }
    Ok(inventory)
}

fn engine_display_name(kind: &str, ordinal: u32) -> String {
    let display = match kind.to_ascii_lowercase().as_str() {
        "3d" => "3D",
        "copy" => "Copy",
        "videoencode" => "Video Encode",
        "videodecode" => "Video Decode",
        "compute" | "computing" => "Compute",
        "security" => "Security",
        _ => kind,
    };
    format!("{display} {ordinal}")
}

fn pdh_error(context: impl Into<String>, status: u32) -> BackendError {
    BackendError {
        domain: "pdh".to_string(),
        code: i64::from(status),
        context: context.into(),
        message: format!("PDH status 0x{status:08x}"),
    }
}

fn hresult_error(context: impl Into<String>, code: i32) -> BackendError {
    BackendError {
        domain: "hresult".to_string(),
        code: i64::from(code),
        context: context.into(),
        message: format!("HRESULT 0x{:08x}", code as u32),
    }
}

fn invalid_data(context: impl Into<String>) -> BackendError {
    BackendError {
        domain: "pdh".to_string(),
        code: -1,
        context: context.into(),
        message: "invalid GPU performance-counter data".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::{AdapterId, parse_engine_instance, parse_memory_instance};

    #[test]
    fn parses_wddm_engine_identity() {
        let value = parse_engine_instance("pid_42_luid_0x0_0x71_phys_2_eng_3_engtype_VideoDecode")
            .expect("valid engine instance");
        assert_eq!(
            value.adapter,
            AdapterId {
                luid_high: 0,
                luid_low: 0x71,
                physical_index: 2,
            }
        );
        assert_eq!(value.ordinal, 3);
        assert_eq!(value.kind, "VideoDecode");
    }

    #[test]
    fn rejects_malformed_memory_identity() {
        assert!(parse_memory_instance("luid_0x0_phys_0").is_none());
        assert!(parse_memory_instance("luid_0x0_0x71_phys_0").is_some());
    }
}
