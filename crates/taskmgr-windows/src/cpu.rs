// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows 逻辑处理器与 CPU 详情采样
//
//   文件:       crates/taskmgr-windows/src/cpu.rs
//
//   日期:       2026年08月21日
//   环境:       Windows x64/ARM64 API；Rust 1.97.1；x86_64-pc-windows-gnu 交叉检查
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   NtQuerySystemInformation；GetLogicalProcessorInformationEx；CallNtPowerInformation；Windows Registry
// --------------------------------------------------------------------------

//! 采集逐逻辑处理器累计时间和静态拓扑。
//!
//! 两个页面分别持有 `CpuUsageSampler`，因此性能页与 CPU 页不会因同一刷新周期内的
//! 连续查询互相推进基线。所有可变缓冲均只属于后台平台线程。

use std::collections::BTreeMap;
use std::ffi::c_void;
use std::mem::{align_of, offset_of, size_of};
use std::ptr::{null, null_mut};
use std::slice;

use taskmgr_core::{
    BackendError, CpuCache, CpuCacheKind, CpuCoreClass, CpuHardwareMetrics, CpuTopologyMetrics,
};
use windows_sys::Win32::Foundation::{ERROR_INSUFFICIENT_BUFFER, ERROR_SUCCESS};
use windows_sys::Win32::System::Registry::{
    HKEY_LOCAL_MACHINE, REG_DWORD, REG_SZ, RRF_RT_REG_DWORD, RRF_RT_REG_SZ, RegGetValueW,
};
use windows_sys::Win32::System::SystemInformation::{
    CACHE_RELATIONSHIP, CacheData as CACHE_DATA, CacheInstruction as CACHE_INSTRUCTION,
    CacheTrace as CACHE_TRACE, CacheUnified as CACHE_UNIFIED, GROUP_AFFINITY, GROUP_RELATIONSHIP,
    GetLogicalProcessorInformationEx, GetNativeSystemInfo, GetTickCount64, PROCESSOR_RELATIONSHIP,
    RelationAll, RelationCache as RELATION_CACHE, RelationGroup as RELATION_GROUP,
    RelationNumaNode as RELATION_NUMA_NODE, RelationNumaNodeEx as RELATION_NUMA_NODE_EX,
    RelationProcessorCore as RELATION_PROCESSOR_CORE,
    RelationProcessorDie as RELATION_PROCESSOR_DIE,
    RelationProcessorModule as RELATION_PROCESSOR_MODULE,
    RelationProcessorPackage as RELATION_PROCESSOR_PACKAGE, SYSTEM_INFO,
    SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX,
};
use windows_sys::Win32::System::Threading::{
    ALL_PROCESSOR_GROUPS, GetActiveProcessorCount, IsProcessorFeaturePresent,
    PF_SECOND_LEVEL_ADDRESS_TRANSLATION, PF_VIRT_FIRMWARE_ENABLED,
};

const PROCESSOR_PERFORMANCE_INFORMATION_CLASS: i32 = 8;
const STATUS_INFO_LENGTH_MISMATCH: i32 = 0xC000_0004_u32 as i32;
const STATUS_INVALID_BUFFER_SIZE: i32 = 0xC000_0206_u32 as i32;
const PROCESSOR_INFORMATION_LEVEL: i32 = 11;
const PROCESSOR_REGISTRY_PATH: &str = r"HARDWARE\DESCRIPTION\System\CentralProcessor\0";
const RELATIONSHIP_HEADER_SIZE: usize =
    offset_of!(SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX, Anonymous);
const LTP_PC_SMT_FLAG: u8 = 1;
const CACHE_FULLY_ASSOCIATIVE: u8 = u8::MAX;

#[repr(C)]
#[derive(Clone, Copy, Debug, Default)]
struct ProcessorPerformance {
    idle_time: i64,
    kernel_time: i64,
    user_time: i64,
    dpc_time: i64,
    interrupt_time: i64,
    interrupt_count: u32,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default)]
struct ProcessorPowerInformation {
    number: u32,
    max_mhz: u32,
    current_mhz: u32,
    mhz_limit: u32,
    max_idle_state: u32,
    current_idle_state: u32,
}

#[link(name = "ntdll")]
unsafe extern "system" {
    fn NtQuerySystemInformation(
        system_information_class: i32,
        system_information: *mut c_void,
        system_information_length: u32,
        return_length: *mut u32,
    ) -> i32;
}

#[link(name = "powrprof")]
unsafe extern "system" {
    fn CallNtPowerInformation(
        information_level: i32,
        input_buffer: *const c_void,
        input_buffer_length: u32,
        output_buffer: *mut c_void,
        output_buffer_length: u32,
    ) -> i32;
}

#[derive(Clone, Copy, Debug)]
struct ProcessorTimes {
    idle: u64,
    kernel: u64,
    user: u64,
    dpc: u64,
    interrupt: u64,
    interrupt_count: u32,
    total: u64,
}

#[derive(Clone, Debug)]
pub(crate) struct CpuUsageDelta {
    pub(crate) busy_percent: f64,
    pub(crate) user_percent: f64,
    pub(crate) kernel_percent: f64,
    pub(crate) dpc_percent: f64,
    pub(crate) interrupt_percent: f64,
    pub(crate) interrupts_per_second: u64,
    pub(crate) logical_busy_percent: Vec<f64>,
    pub(crate) logical_kernel_percent: Vec<f64>,
}

#[derive(Default)]
pub(crate) struct CpuUsageSampler {
    raw: Vec<ProcessorPerformance>,
    previous: Vec<ProcessorTimes>,
    previous_timestamp_millis: Option<u64>,
}

impl CpuUsageSampler {
    pub(crate) fn sample(&mut self) -> Result<Option<CpuUsageDelta>, BackendError> {
        let expected = unsafe { GetActiveProcessorCount(ALL_PROCESSOR_GROUPS) } as usize;
        query_processor_performance(expected, &mut self.raw)?;
        let current = self
            .raw
            .iter()
            .map(processor_times)
            .collect::<Result<Vec<_>, _>>()?;
        let timestamp = unsafe { GetTickCount64() };
        let delta = self
            .previous_timestamp_millis
            .and_then(|previous| timestamp.checked_sub(previous))
            .and_then(|elapsed| calculate_delta(&self.previous, &current, elapsed));
        self.previous = current;
        self.previous_timestamp_millis = Some(timestamp);
        Ok(delta)
    }

    pub(crate) fn logical_processor_count(&self) -> usize {
        self.raw.len()
    }
}

#[derive(Clone, Copy, Debug, Default)]
pub(crate) struct CpuFrequencySnapshot {
    pub(crate) average_current_mhz: Option<f64>,
    pub(crate) minimum_current_mhz: Option<f64>,
    pub(crate) maximum_current_mhz: Option<f64>,
    pub(crate) firmware_maximum_mhz: Option<f64>,
}

pub(crate) fn query_cpu_frequencies(expected_count: usize) -> CpuFrequencySnapshot {
    let count = expected_count.max(1);
    let mut values = vec![ProcessorPowerInformation::default(); count];
    let Some(byte_length) = values
        .len()
        .checked_mul(size_of::<ProcessorPowerInformation>())
        .and_then(|value| u32::try_from(value).ok())
    else {
        return CpuFrequencySnapshot::default();
    };
    let status = unsafe {
        CallNtPowerInformation(
            PROCESSOR_INFORMATION_LEVEL,
            null(),
            0,
            values.as_mut_ptr().cast(),
            byte_length,
        )
    };
    if status < 0 {
        return CpuFrequencySnapshot::default();
    }
    let current = values
        .iter()
        .map(|value| f64::from(value.current_mhz))
        .filter(|value| *value > 0.0)
        .collect::<Vec<_>>();
    CpuFrequencySnapshot {
        average_current_mhz: (!current.is_empty())
            .then(|| current.iter().sum::<f64>() / current.len() as f64),
        minimum_current_mhz: current.iter().copied().reduce(f64::min),
        maximum_current_mhz: current.iter().copied().reduce(f64::max),
        firmware_maximum_mhz: values
            .iter()
            .map(|value| f64::from(value.max_mhz))
            .filter(|value| *value > 0.0)
            .reduce(f64::max),
    }
}

pub(crate) fn query_cpu_inventory() -> (Option<String>, CpuTopologyMetrics, CpuHardwareMetrics) {
    let topology = query_topology().unwrap_or_else(|_| CpuTopologyMetrics {
        logical_processor_count: nonzero_active_processor_count(),
        ..CpuTopologyMetrics::default()
    });
    let mut system_info = SYSTEM_INFO::default();
    unsafe { GetNativeSystemInfo(&mut system_info) };
    let architecture_code = unsafe { system_info.Anonymous.Anonymous.wProcessorArchitecture };
    let architecture = architecture_name(architecture_code).map(str::to_string);
    let width = architecture_width(architecture_code);
    let model = registry_string("ProcessorNameString")
        .or_else(|| std::env::var("PROCESSOR_IDENTIFIER").ok())
        .filter(|value| !value.trim().is_empty());
    let hardware = CpuHardwareMetrics {
        manufacturer: registry_string("VendorIdentifier"),
        socket: topology.package_count.map(|count| {
            (0..count)
                .map(|value| value.to_string())
                .collect::<Vec<_>>()
                .join(", ")
        }),
        processor_id: registry_string("Identifier"),
        architecture,
        address_width_bits: width,
        data_width_bits: width,
        family: registry_string("Identifier"),
        level: Some(system_info.wProcessorLevel.to_string()),
        revision: Some(format!("0x{:04X}", system_info.wProcessorRevision)),
        stepping: Some((system_info.wProcessorRevision & 0x00ff).to_string()),
        firmware_max_frequency_mhz: registry_dword("~MHz").map(f64::from),
        isa_features: Vec::new(),
        caches: query_caches().unwrap_or_default(),
    };
    (model, topology, hardware)
}

fn query_processor_performance(
    expected_count: usize,
    output: &mut Vec<ProcessorPerformance>,
) -> Result<(), BackendError> {
    let item_size = size_of::<ProcessorPerformance>();
    let mut count = expected_count.max(1);
    loop {
        output.resize(count, ProcessorPerformance::default());
        let byte_length = count
            .checked_mul(item_size)
            .and_then(|value| u32::try_from(value).ok())
            .ok_or_else(|| {
                nt_error(
                    "CPU processor performance buffer size",
                    STATUS_INVALID_BUFFER_SIZE,
                )
            })?;
        let mut returned = 0_u32;
        let status = unsafe {
            NtQuerySystemInformation(
                PROCESSOR_PERFORMANCE_INFORMATION_CLASS,
                output.as_mut_ptr().cast(),
                byte_length,
                &mut returned,
            )
        };
        if status >= 0 {
            if returned != 0 {
                let returned = returned as usize;
                if !returned.is_multiple_of(item_size) || returned > byte_length as usize {
                    return Err(nt_error(
                        "CPU processor performance returned length",
                        STATUS_INVALID_BUFFER_SIZE,
                    ));
                }
                output.truncate(returned / item_size);
            }
            if output.is_empty() {
                return Err(nt_error(
                    "CPU processor performance empty result",
                    STATUS_INFO_LENGTH_MISMATCH,
                ));
            }
            return Ok(());
        }
        if status != STATUS_INFO_LENGTH_MISMATCH || returned as usize <= byte_length as usize {
            return Err(nt_error("NtQuerySystemInformation CPU performance", status));
        }
        count = (returned as usize).div_ceil(item_size);
    }
}

fn processor_times(value: &ProcessorPerformance) -> Result<ProcessorTimes, BackendError> {
    let idle = nonnegative_counter(value.idle_time)?;
    let kernel_total = nonnegative_counter(value.kernel_time)?;
    let user = nonnegative_counter(value.user_time)?;
    let dpc = nonnegative_counter(value.dpc_time)?;
    let interrupt = nonnegative_counter(value.interrupt_time)?;
    let kernel = kernel_total.checked_sub(idle).ok_or_else(|| {
        nt_error(
            "CPU kernel counter is smaller than idle counter",
            STATUS_INVALID_BUFFER_SIZE,
        )
    })?;
    let total = kernel_total
        .checked_add(user)
        .ok_or_else(|| nt_error("CPU total counter overflow", STATUS_INVALID_BUFFER_SIZE))?;
    Ok(ProcessorTimes {
        idle,
        kernel,
        user,
        dpc,
        interrupt,
        interrupt_count: value.interrupt_count,
        total,
    })
}

fn nonnegative_counter(value: i64) -> Result<u64, BackendError> {
    u64::try_from(value).map_err(|_| {
        nt_error(
            "negative CPU performance counter",
            STATUS_INVALID_BUFFER_SIZE,
        )
    })
}

fn calculate_delta(
    previous: &[ProcessorTimes],
    current: &[ProcessorTimes],
    elapsed_millis: u64,
) -> Option<CpuUsageDelta> {
    if elapsed_millis == 0 || previous.len() != current.len() || current.is_empty() {
        return None;
    }
    let mut logical_busy_percent = Vec::with_capacity(current.len());
    let mut logical_kernel_percent = Vec::with_capacity(current.len());
    let mut total_sum = 0_u128;
    let mut idle_sum = 0_u128;
    let mut user_sum = 0_u128;
    let mut kernel_sum = 0_u128;
    let mut dpc_sum = 0_u128;
    let mut interrupt_sum = 0_u128;
    let mut interrupt_count_sum = 0_u128;
    for (previous, current) in previous.iter().zip(current) {
        let total = current.total.checked_sub(previous.total)?;
        let idle = current.idle.checked_sub(previous.idle)?;
        let user = current.user.checked_sub(previous.user)?;
        let kernel = current.kernel.checked_sub(previous.kernel)?;
        let dpc = current.dpc.checked_sub(previous.dpc)?;
        let interrupt = current.interrupt.checked_sub(previous.interrupt)?;
        let interrupt_count = current
            .interrupt_count
            .checked_sub(previous.interrupt_count)?;
        if total == 0
            || idle > total
            || user > total
            || kernel > total
            || dpc > kernel
            || interrupt > kernel
        {
            return None;
        }
        logical_busy_percent.push(percent(total - idle, total));
        logical_kernel_percent.push(percent(kernel, total));
        total_sum = total_sum.checked_add(u128::from(total))?;
        idle_sum = idle_sum.checked_add(u128::from(idle))?;
        user_sum = user_sum.checked_add(u128::from(user))?;
        kernel_sum = kernel_sum.checked_add(u128::from(kernel))?;
        dpc_sum = dpc_sum.checked_add(u128::from(dpc))?;
        interrupt_sum = interrupt_sum.checked_add(u128::from(interrupt))?;
        interrupt_count_sum = interrupt_count_sum.checked_add(u128::from(interrupt_count))?;
    }
    if total_sum == 0 || idle_sum > total_sum {
        return None;
    }
    let interrupts_per_second = interrupt_count_sum
        .checked_mul(1_000)?
        .checked_add(u128::from(elapsed_millis / 2))?
        .checked_div(u128::from(elapsed_millis))?;
    Some(CpuUsageDelta {
        busy_percent: percent_u128(total_sum - idle_sum, total_sum),
        user_percent: percent_u128(user_sum, total_sum),
        kernel_percent: percent_u128(kernel_sum, total_sum),
        dpc_percent: percent_u128(dpc_sum, total_sum),
        interrupt_percent: percent_u128(interrupt_sum, total_sum),
        interrupts_per_second: u64::try_from(interrupts_per_second).ok()?,
        logical_busy_percent,
        logical_kernel_percent,
    })
}

fn percent(value: u64, total: u64) -> f64 {
    (value as f64 * 100.0 / total as f64).clamp(0.0, 100.0)
}

fn percent_u128(value: u128, total: u128) -> f64 {
    (value as f64 * 100.0 / total as f64).clamp(0.0, 100.0)
}

fn query_topology() -> Result<CpuTopologyMetrics, BackendError> {
    let buffer = query_relationship_buffer()?;
    let bytes = buffer.as_bytes();
    let mut offset = 0_usize;
    let mut package_count = 0_u32;
    let mut numa_node_count = 0_u32;
    let mut processor_group_count = None;
    let mut die_count = 0_u32;
    let mut module_count = 0_u32;
    let mut physical_core_count = 0_u32;
    let mut smt_core_count = 0_u32;
    let mut minimum_threads_per_core = None::<u32>;
    let mut maximum_threads_per_core = None::<u32>;
    let mut classes = BTreeMap::<u32, u32>::new();
    while offset < bytes.len() {
        let record = relationship_record(bytes, offset)?;
        match record.Relationship {
            RELATION_PROCESSOR_CORE => {
                ensure_relationship_payload::<PROCESSOR_RELATIONSHIP>(record)?;
                let processor = unsafe { record.Anonymous.Processor };
                let threads = processor_thread_count(record, &processor)?;
                physical_core_count = physical_core_count.saturating_add(1);
                if processor.Flags & LTP_PC_SMT_FLAG != 0 || threads > 1 {
                    smt_core_count = smt_core_count.saturating_add(1);
                }
                minimum_threads_per_core =
                    Some(minimum_threads_per_core.map_or(threads, |value| value.min(threads)));
                maximum_threads_per_core =
                    Some(maximum_threads_per_core.map_or(threads, |value| value.max(threads)));
                *classes
                    .entry(u32::from(processor.EfficiencyClass))
                    .or_default() += 1;
            }
            RELATION_PROCESSOR_PACKAGE => package_count = package_count.saturating_add(1),
            RELATION_PROCESSOR_DIE => die_count = die_count.saturating_add(1),
            RELATION_PROCESSOR_MODULE => module_count = module_count.saturating_add(1),
            RELATION_NUMA_NODE | RELATION_NUMA_NODE_EX => {
                numa_node_count = numa_node_count.saturating_add(1)
            }
            RELATION_GROUP => {
                ensure_relationship_payload::<GROUP_RELATIONSHIP>(record)?;
                let group = unsafe { record.Anonymous.Group };
                processor_group_count = Some(u32::from(group.ActiveGroupCount));
            }
            RELATION_CACHE => {}
            _ => {}
        }
        offset = offset
            .checked_add(record.Size as usize)
            .ok_or_else(|| topology_error("CPU topology record offset overflow"))?;
    }
    let core_classes = if classes.len() <= 1 && physical_core_count > 0 {
        vec![CpuCoreClass {
            efficiency_class: None,
            core_count: physical_core_count,
        }]
    } else {
        classes
            .into_iter()
            .map(|(efficiency_class, core_count)| CpuCoreClass {
                efficiency_class: Some(efficiency_class),
                core_count,
            })
            .collect()
    };
    Ok(CpuTopologyMetrics {
        package_count: (package_count > 0).then_some(package_count),
        numa_node_count: (numa_node_count > 0).then_some(numa_node_count),
        processor_group_count,
        die_count: (die_count > 0).then_some(die_count),
        module_count: (module_count > 0).then_some(module_count),
        physical_core_count: (physical_core_count > 0).then_some(physical_core_count),
        logical_processor_count: nonzero_active_processor_count(),
        core_classes,
        smt_core_count: (physical_core_count > 0).then_some(smt_core_count),
        minimum_threads_per_core,
        maximum_threads_per_core,
        virtualization: Some(unsafe { IsProcessorFeaturePresent(PF_VIRT_FIRMWARE_ENABLED) } != 0),
        second_level_address_translation: Some(
            unsafe { IsProcessorFeaturePresent(PF_SECOND_LEVEL_ADDRESS_TRANSLATION) } != 0,
        ),
    })
}

fn query_caches() -> Result<Vec<CpuCache>, BackendError> {
    let buffer = query_relationship_buffer()?;
    let bytes = buffer.as_bytes();
    let mut offset = 0_usize;
    let mut groups = BTreeMap::<(u8, u8, u64, Option<u32>, Option<u32>), u32>::new();
    while offset < bytes.len() {
        let record = relationship_record(bytes, offset)?;
        if record.Relationship == RELATION_CACHE {
            if (record.Size as usize)
                < RELATIONSHIP_HEADER_SIZE.saturating_add(size_of::<CACHE_RELATIONSHIP>())
            {
                return Err(topology_error("CPU cache relationship is truncated"));
            }
            let cache = unsafe { record.Anonymous.Cache };
            let kind = match cache.Type {
                CACHE_DATA => 0,
                CACHE_INSTRUCTION => 1,
                CACHE_UNIFIED => 2,
                CACHE_TRACE => 3,
                _ => 4,
            };
            let associativity = (cache.Associativity != 0
                && cache.Associativity != CACHE_FULLY_ASSOCIATIVE)
                .then_some(u32::from(cache.Associativity));
            let line_size = (cache.LineSize > 0).then_some(u32::from(cache.LineSize));
            *groups
                .entry((
                    cache.Level,
                    kind,
                    u64::from(cache.CacheSize),
                    associativity,
                    line_size,
                ))
                .or_default() += 1;
        }
        offset = offset
            .checked_add(record.Size as usize)
            .ok_or_else(|| topology_error("CPU cache record offset overflow"))?;
    }
    Ok(groups
        .into_iter()
        .map(
            |((level, kind, size_bytes, associativity, line_size_bytes), instance_count)| {
                CpuCache {
                    level,
                    kind: match kind {
                        0 => CpuCacheKind::Data,
                        1 => CpuCacheKind::Instruction,
                        2 => CpuCacheKind::Unified,
                        3 => CpuCacheKind::Trace,
                        _ => CpuCacheKind::Other,
                    },
                    size_bytes,
                    instance_count,
                    associativity,
                    line_size_bytes,
                }
            },
        )
        .collect())
}

struct RelationshipBuffer {
    storage: Vec<usize>,
    byte_length: usize,
}

impl RelationshipBuffer {
    fn as_bytes(&self) -> &[u8] {
        // SAFETY: `storage` owns at least `byte_length` initialized bytes written by
        // GetLogicalProcessorInformationEx. Its `usize` allocation preserves the
        // alignment required by SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX records.
        unsafe { slice::from_raw_parts(self.storage.as_ptr().cast::<u8>(), self.byte_length) }
    }
}

fn query_relationship_buffer() -> Result<RelationshipBuffer, BackendError> {
    let mut byte_length = 0_u32;
    let first =
        unsafe { GetLogicalProcessorInformationEx(RelationAll, null_mut(), &mut byte_length) };
    if first != 0 || byte_length == 0 {
        return Err(topology_error("CPU topology size query returned no length"));
    }
    let error = unsafe { windows_sys::Win32::Foundation::GetLastError() };
    if error != ERROR_INSUFFICIENT_BUFFER {
        return Err(BackendError {
            domain: "win32".to_string(),
            code: i64::from(error),
            context: "GetLogicalProcessorInformationEx size".to_string(),
            message: format!("Win32 error {error}"),
        });
    }
    let word_size = size_of::<usize>();
    loop {
        let words = (byte_length as usize).div_ceil(word_size);
        let mut storage = vec![0_usize; words];
        let mut returned = byte_length;
        if unsafe {
            GetLogicalProcessorInformationEx(
                RelationAll,
                storage.as_mut_ptr().cast(),
                &mut returned,
            )
        } != 0
        {
            if returned == 0 || returned > byte_length {
                return Err(topology_error("CPU topology returned length is invalid"));
            }
            return Ok(RelationshipBuffer {
                storage,
                byte_length: returned as usize,
            });
        }
        let error = unsafe { windows_sys::Win32::Foundation::GetLastError() };
        if error == ERROR_INSUFFICIENT_BUFFER && returned > byte_length {
            byte_length = returned;
            continue;
        }
        return Err(win32_error("GetLogicalProcessorInformationEx data", error));
    }
}

fn relationship_record(
    bytes: &[u8],
    offset: usize,
) -> Result<&SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX, BackendError> {
    let header_end = offset
        .checked_add(RELATIONSHIP_HEADER_SIZE)
        .ok_or_else(|| topology_error("CPU topology header overflow"))?;
    if header_end > bytes.len() {
        return Err(topology_error("CPU topology record header is truncated"));
    }
    let pointer = unsafe { bytes.as_ptr().add(offset) };
    if !(pointer as usize).is_multiple_of(align_of::<SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX>()) {
        return Err(topology_error("CPU topology record alignment is invalid"));
    }
    let record = unsafe { &*pointer.cast::<SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX>() };
    let size = record.Size as usize;
    if size < RELATIONSHIP_HEADER_SIZE
        || offset.checked_add(size).is_none_or(|end| end > bytes.len())
    {
        return Err(topology_error("CPU topology record size is invalid"));
    }
    Ok(record)
}

fn processor_thread_count(
    record: &SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX,
    processor: &PROCESSOR_RELATIONSHIP,
) -> Result<u32, BackendError> {
    let group_count = usize::from(processor.GroupCount);
    if group_count == 0 {
        return Err(topology_error("CPU core has no group affinity"));
    }
    let masks_offset = RELATIONSHIP_HEADER_SIZE + offset_of!(PROCESSOR_RELATIONSHIP, GroupMask);
    let masks_bytes = group_count
        .checked_mul(size_of::<GROUP_AFFINITY>())
        .and_then(|value| masks_offset.checked_add(value))
        .ok_or_else(|| topology_error("CPU core group-mask bounds overflow"))?;
    if masks_bytes > record.Size as usize {
        return Err(topology_error("CPU core group masks are truncated"));
    }
    let masks = unsafe {
        slice::from_raw_parts(
            (record as *const SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX)
                .cast::<u8>()
                .add(masks_offset)
                .cast::<GROUP_AFFINITY>(),
            group_count,
        )
    };
    Ok(masks.iter().map(|mask| mask.Mask.count_ones()).sum::<u32>())
}

fn ensure_relationship_payload<T>(
    record: &SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX,
) -> Result<(), BackendError> {
    let required = RELATIONSHIP_HEADER_SIZE
        .checked_add(size_of::<T>())
        .ok_or_else(|| topology_error("CPU topology payload size overflow"))?;
    if record.Size as usize >= required {
        Ok(())
    } else {
        Err(topology_error("CPU topology relationship is truncated"))
    }
}

fn nonzero_active_processor_count() -> Option<u32> {
    let count = unsafe { GetActiveProcessorCount(ALL_PROCESSOR_GROUPS) };
    (count > 0).then_some(count)
}

fn registry_string(name: &str) -> Option<String> {
    let path = wide(PROCESSOR_REGISTRY_PATH);
    let name = wide(name);
    let mut byte_length = 0_u32;
    let mut value_type = 0_u32;
    let status = unsafe {
        RegGetValueW(
            HKEY_LOCAL_MACHINE,
            path.as_ptr(),
            name.as_ptr(),
            RRF_RT_REG_SZ,
            &mut value_type,
            null_mut(),
            &mut byte_length,
        )
    };
    if status != ERROR_SUCCESS || value_type != REG_SZ || byte_length < 2 {
        return None;
    }
    let mut buffer = vec![0_u16; (byte_length as usize).div_ceil(size_of::<u16>())];
    let status = unsafe {
        RegGetValueW(
            HKEY_LOCAL_MACHINE,
            path.as_ptr(),
            name.as_ptr(),
            RRF_RT_REG_SZ,
            &mut value_type,
            buffer.as_mut_ptr().cast(),
            &mut byte_length,
        )
    };
    if status != ERROR_SUCCESS || value_type != REG_SZ {
        return None;
    }
    let length = buffer
        .iter()
        .position(|unit| *unit == 0)
        .unwrap_or(buffer.len());
    String::from_utf16(&buffer[..length])
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

fn registry_dword(name: &str) -> Option<u32> {
    let path = wide(PROCESSOR_REGISTRY_PATH);
    let name = wide(name);
    let mut value = 0_u32;
    let mut byte_length = size_of::<u32>() as u32;
    let mut value_type = 0_u32;
    let status = unsafe {
        RegGetValueW(
            HKEY_LOCAL_MACHINE,
            path.as_ptr(),
            name.as_ptr(),
            RRF_RT_REG_DWORD,
            &mut value_type,
            (&mut value as *mut u32).cast(),
            &mut byte_length,
        )
    };
    (status == ERROR_SUCCESS && value_type == REG_DWORD && byte_length == size_of::<u32>() as u32)
        .then_some(value)
}

fn wide(value: &str) -> Vec<u16> {
    value.encode_utf16().chain([0]).collect()
}

fn architecture_name(value: u16) -> Option<&'static str> {
    use windows_sys::Win32::System::SystemInformation::{
        PROCESSOR_ARCHITECTURE_AMD64, PROCESSOR_ARCHITECTURE_ARM, PROCESSOR_ARCHITECTURE_ARM64,
        PROCESSOR_ARCHITECTURE_IA64, PROCESSOR_ARCHITECTURE_INTEL,
    };
    match value {
        PROCESSOR_ARCHITECTURE_INTEL => Some("x86"),
        PROCESSOR_ARCHITECTURE_AMD64 => Some("x86_64"),
        PROCESSOR_ARCHITECTURE_ARM => Some("ARM"),
        PROCESSOR_ARCHITECTURE_ARM64 => Some("ARM64"),
        PROCESSOR_ARCHITECTURE_IA64 => Some("IA-64"),
        _ => None,
    }
}

fn architecture_width(value: u16) -> Option<u16> {
    use windows_sys::Win32::System::SystemInformation::{
        PROCESSOR_ARCHITECTURE_AMD64, PROCESSOR_ARCHITECTURE_ARM64, PROCESSOR_ARCHITECTURE_IA64,
        PROCESSOR_ARCHITECTURE_INTEL,
    };
    match value {
        PROCESSOR_ARCHITECTURE_AMD64
        | PROCESSOR_ARCHITECTURE_ARM64
        | PROCESSOR_ARCHITECTURE_IA64 => Some(64),
        PROCESSOR_ARCHITECTURE_INTEL => Some(32),
        _ => None,
    }
}

fn nt_error(context: &str, status: i32) -> BackendError {
    BackendError {
        domain: "ntstatus".to_string(),
        code: i64::from(status),
        context: context.to_string(),
        message: format!("NTSTATUS 0x{:08X}", status as u32),
    }
}

fn win32_error(context: &str, code: u32) -> BackendError {
    BackendError {
        domain: "win32".to_string(),
        code: i64::from(code),
        context: context.to_string(),
        message: format!("Win32 error {code}"),
    }
}

fn topology_error(context: &str) -> BackendError {
    BackendError {
        domain: "win32".to_string(),
        code: -1,
        context: context.to_string(),
        message: "invalid logical processor topology data".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::{ProcessorTimes, calculate_delta};

    fn times(idle: u64, kernel: u64, user: u64) -> ProcessorTimes {
        ProcessorTimes {
            idle,
            kernel,
            user,
            dpc: 0,
            interrupt: 0,
            interrupt_count: 0,
            total: idle + kernel + user,
        }
    }

    #[test]
    fn logical_processor_delta_keeps_each_processor_separate() {
        let previous = [times(10, 5, 5), times(20, 5, 5)];
        let current = [times(15, 10, 15), times(29, 6, 5)];
        let delta = calculate_delta(&previous, &current, 1_000).expect("valid delta");
        assert_eq!(delta.logical_busy_percent, vec![75.0, 10.0]);
        assert_eq!(delta.logical_kernel_percent, vec![25.0, 10.0]);
    }

    #[test]
    fn counter_regression_is_not_reported_as_zero_usage() {
        assert!(calculate_delta(&[times(10, 5, 5)], &[times(9, 5, 5)], 1_000).is_none());
    }
}
