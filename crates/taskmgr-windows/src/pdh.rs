// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows CPU PDH 动态指标
//
//   文件:       crates/taskmgr-windows/src/pdh.rs
//
//   日期:       2026年08月22日
//   环境:       Windows x64/ARM64 API；Rust 1.97.1；x86_64-pc-windows-gnu 交叉检查
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   PdhAddEnglishCounterW；Processor Information；System performance counters
// --------------------------------------------------------------------------

//! 持久化拥有 CPU 频率与系统速率计数器，并保留 PDH 所要求的双样本基线。
//!
//! 英文计数器 API 与系统显示语言无关。单个可选计数器不可用时只让对应字段保持
//! `None`，不会让整个 CPU 页失效。

use std::collections::HashMap;
use std::mem::{size_of, zeroed};
use std::ptr::{null, null_mut};
use std::slice;

use taskmgr_core::BackendError;
use windows_sys::Win32::Foundation::ERROR_SUCCESS;
use windows_sys::Win32::System::Performance::{
    PDH_CSTATUS_NEW_DATA, PDH_CSTATUS_NO_COUNTER, PDH_CSTATUS_NO_OBJECT, PDH_CSTATUS_VALID_DATA,
    PDH_FMT_COUNTERVALUE, PDH_FMT_COUNTERVALUE_ITEM_W, PDH_FMT_DOUBLE, PDH_FMT_LARGE, PDH_HCOUNTER,
    PDH_HQUERY, PDH_INVALID_PATH, PDH_MORE_DATA, PdhAddEnglishCounterW, PdhCloseQuery,
    PdhCollectQueryData, PdhGetFormattedCounterArrayW, PdhGetFormattedCounterValue, PdhOpenQueryW,
};

const FREQUENCY_COUNTER_PATH: &str = r"\Processor Information(*)\Processor Frequency";
const PERFORMANCE_COUNTER_PATH: &str = r"\Processor Information(*)\% Processor Performance";
const CONTEXT_SWITCH_COUNTER_PATH: &str = r"\System\Context Switches/sec";
const SYSTEM_CALL_COUNTER_PATH: &str = r"\System\System Calls/sec";
const PROCESSOR_QUEUE_COUNTER_PATH: &str = r"\System\Processor Queue Length";
const MAX_PDH_ARRAY_BYTES: u32 = 64 * 1024 * 1024;

#[derive(Clone, Copy, Debug, Default)]
pub(crate) struct CpuPdhSnapshot {
    pub(crate) average_frequency_mhz: Option<f64>,
    pub(crate) minimum_frequency_mhz: Option<f64>,
    pub(crate) maximum_frequency_mhz: Option<f64>,
    pub(crate) processor_queue_length: Option<u64>,
    pub(crate) context_switches_per_second: Option<u64>,
    pub(crate) system_calls_per_second: Option<u64>,
}

pub(crate) struct CpuPdhSampler {
    // PDH handles are opaque process-local values. Keeping their bit patterns as integers makes
    // the provider movable to its single owner thread without claiming pointer pointee ownership.
    query: usize,
    frequency: usize,
    performance: usize,
    context_switches: Option<usize>,
    system_calls: Option<usize>,
    processor_queue: Option<usize>,
    expected_processor_count: usize,
    baseline_ready: bool,
}

impl CpuPdhSampler {
    pub(crate) fn new(expected_processor_count: usize) -> Result<Self, BackendError> {
        if expected_processor_count == 0 {
            return Err(invalid_data("initialize CPU PDH with zero processors"));
        }
        let mut query = null_mut();
        // SAFETY: output receives one query handle, owned by the returned sampler on success.
        let status = unsafe { PdhOpenQueryW(null(), 0, &mut query) };
        if status != ERROR_SUCCESS {
            return Err(pdh_error("PdhOpenQueryW for CPU metrics", status));
        }
        let mut sampler = Self {
            query: query as usize,
            frequency: 0,
            performance: 0,
            context_switches: None,
            system_calls: None,
            processor_queue: None,
            expected_processor_count,
            baseline_ready: false,
        };
        sampler.frequency = sampler.add_counter(FREQUENCY_COUNTER_PATH)?;
        sampler.performance = sampler.add_counter(PERFORMANCE_COUNTER_PATH)?;
        sampler.context_switches = sampler.add_optional_counter(CONTEXT_SWITCH_COUNTER_PATH)?;
        sampler.system_calls = sampler.add_optional_counter(SYSTEM_CALL_COUNTER_PATH)?;
        sampler.processor_queue = sampler.add_optional_counter(PROCESSOR_QUEUE_COUNTER_PATH)?;
        Ok(sampler)
    }

    pub(crate) fn sample(&mut self) -> Result<Option<CpuPdhSnapshot>, BackendError> {
        // SAFETY: the sampler owns a live query and all counters remain attached to it.
        let status = unsafe { PdhCollectQueryData(self.query as PDH_HQUERY) };
        if status != ERROR_SUCCESS {
            self.baseline_ready = false;
            return Err(pdh_error("PdhCollectQueryData for CPU metrics", status));
        }
        if !self.baseline_ready {
            self.baseline_ready = true;
            return Ok(None);
        }

        let frequencies = self.query_frequencies().ok();
        Ok(Some(CpuPdhSnapshot {
            average_frequency_mhz: frequencies.map(|value| value.0),
            minimum_frequency_mhz: frequencies.map(|value| value.1),
            maximum_frequency_mhz: frequencies.map(|value| value.2),
            processor_queue_length: read_optional_counter(
                self.processor_queue,
                PROCESSOR_QUEUE_COUNTER_PATH,
            ),
            context_switches_per_second: read_optional_counter(
                self.context_switches,
                CONTEXT_SWITCH_COUNTER_PATH,
            ),
            system_calls_per_second: read_optional_counter(
                self.system_calls,
                SYSTEM_CALL_COUNTER_PATH,
            ),
        }))
    }

    fn add_counter(&self, path: &'static str) -> Result<usize, BackendError> {
        let wide_path = to_wide_null(path);
        let mut counter = null_mut();
        // SAFETY: the query is live and the path buffer is null-terminated for the call.
        let status = unsafe {
            PdhAddEnglishCounterW(
                self.query as PDH_HQUERY,
                wide_path.as_ptr(),
                0,
                &mut counter,
            )
        };
        if status != ERROR_SUCCESS {
            return Err(pdh_counter_error("PdhAddEnglishCounterW", path, status));
        }
        Ok(counter as usize)
    }

    fn add_optional_counter(&self, path: &'static str) -> Result<Option<usize>, BackendError> {
        match self.add_counter(path) {
            Ok(counter) => Ok(Some(counter)),
            Err(error) if pdh_counter_is_unavailable(error.code as u32) => Ok(None),
            Err(error) => Err(error),
        }
    }

    fn query_frequencies(&self) -> Result<(f64, f64, f64), BackendError> {
        let nominal = query_counter_array(
            self.frequency as PDH_HCOUNTER,
            FREQUENCY_COUNTER_PATH,
            PDH_FMT_LARGE,
            |value| unsafe { value.Anonymous.largeValue },
        )?;
        let performance = query_counter_array(
            self.performance as PDH_HCOUNTER,
            PERFORMANCE_COUNTER_PATH,
            PDH_FMT_DOUBLE,
            |value| unsafe { value.Anonymous.doubleValue },
        )?;
        summarize_frequencies(&nominal, &performance, self.expected_processor_count)
    }
}

impl Drop for CpuPdhSampler {
    fn drop(&mut self) {
        if self.query != 0 {
            // SAFETY: this sampler uniquely owns the query handle.
            unsafe {
                let _ = PdhCloseQuery(self.query as PDH_HQUERY);
            }
            self.query = 0;
        }
    }
}

fn read_optional_counter(counter: Option<usize>, path: &'static str) -> Option<u64> {
    counter.and_then(|counter| query_single_counter(counter as PDH_HCOUNTER, path).ok())
}

#[derive(Clone, Debug, PartialEq)]
struct PdhArrayValue<T> {
    instance: String,
    value: T,
}

fn query_counter_array<T>(
    counter: PDH_HCOUNTER,
    counter_path: &'static str,
    format: u32,
    extract: impl Fn(&PDH_FMT_COUNTERVALUE) -> T,
) -> Result<Vec<PdhArrayValue<T>>, BackendError> {
    // SAFETY: both calls follow the documented size-probe then fill pattern. The aligned usize
    // storage remains live while all returned name pointers are decoded.
    unsafe {
        let mut byte_count = 0u32;
        let mut item_count = 0u32;
        let status = PdhGetFormattedCounterArrayW(
            counter,
            format,
            &mut byte_count,
            &mut item_count,
            null_mut(),
        );
        if status != PDH_MORE_DATA {
            return Err(pdh_counter_error(
                "PdhGetFormattedCounterArrayW size query",
                counter_path,
                status,
            ));
        }
        if byte_count == 0 || byte_count > MAX_PDH_ARRAY_BYTES {
            return Err(invalid_data("CPU PDH wildcard buffer size"));
        }
        let mut storage = vec![0usize; (byte_count as usize).div_ceil(size_of::<usize>())];
        let status = PdhGetFormattedCounterArrayW(
            counter,
            format,
            &mut byte_count,
            &mut item_count,
            storage.as_mut_ptr().cast(),
        );
        if status != ERROR_SUCCESS {
            return Err(pdh_counter_error(
                "PdhGetFormattedCounterArrayW data query",
                counter_path,
                status,
            ));
        }
        let used_bytes = byte_count as usize;
        if used_bytes > storage.len() * size_of::<usize>()
            || (item_count as usize)
                .checked_mul(size_of::<PDH_FMT_COUNTERVALUE_ITEM_W>())
                .is_none_or(|size| size > used_bytes)
        {
            return Err(invalid_data("CPU PDH wildcard item bounds"));
        }
        let base = storage.as_ptr() as usize;
        let end = base
            .checked_add(used_bytes)
            .ok_or_else(|| invalid_data("CPU PDH wildcard address overflow"))?;
        let items = slice::from_raw_parts(
            storage.as_ptr().cast::<PDH_FMT_COUNTERVALUE_ITEM_W>(),
            item_count as usize,
        );
        let mut values = Vec::with_capacity(items.len());
        for item in items {
            validate_pdh_status(item.FmtValue.CStatus, counter_path)?;
            values.push(PdhArrayValue {
                instance: read_bounded_wide(item.szName, base, end)?,
                value: extract(&item.FmtValue),
            });
        }
        Ok(values)
    }
}

fn query_single_counter(
    counter: PDH_HCOUNTER,
    counter_path: &'static str,
) -> Result<u64, BackendError> {
    // SAFETY: output points to writable storage and the counter remains attached to a live query.
    let mut value = unsafe { zeroed::<PDH_FMT_COUNTERVALUE>() };
    let status =
        unsafe { PdhGetFormattedCounterValue(counter, PDH_FMT_LARGE, null_mut(), &mut value) };
    if status != ERROR_SUCCESS {
        return Err(pdh_counter_error(
            "PdhGetFormattedCounterValue",
            counter_path,
            status,
        ));
    }
    validate_pdh_status(value.CStatus, counter_path)?;
    // SAFETY: PDH_FMT_LARGE selects the largeValue union member.
    let value = unsafe { value.Anonymous.largeValue };
    u64::try_from(value).map_err(|_| invalid_data("CPU PDH negative counter value"))
}

fn summarize_frequencies(
    nominal_values: &[PdhArrayValue<i64>],
    performance_values: &[PdhArrayValue<f64>],
    expected_count: usize,
) -> Result<(f64, f64, f64), BackendError> {
    let mut nominal = HashMap::with_capacity(expected_count);
    for item in nominal_values {
        let Some(instance) = parse_processor_instance(&item.instance)? else {
            continue;
        };
        if item.value <= 0 || nominal.insert(instance, item.value).is_some() {
            return Err(invalid_data("CPU PDH nominal frequency instance"));
        }
    }
    let mut performance = HashMap::with_capacity(expected_count);
    for item in performance_values {
        let Some(instance) = parse_processor_instance(&item.instance)? else {
            continue;
        };
        if !item.value.is_finite()
            || item.value < 0.0
            || performance.insert(instance, item.value).is_some()
        {
            return Err(invalid_data("CPU PDH performance instance"));
        }
    }
    if nominal.len() != expected_count || performance.len() != expected_count {
        return Err(invalid_data("CPU PDH processor instance completeness"));
    }

    let mut frequencies = Vec::with_capacity(expected_count);
    for (instance, nominal_mhz) in nominal {
        let performance_percent = performance
            .get(&instance)
            .copied()
            .ok_or_else(|| invalid_data("CPU PDH frequency instance mismatch"))?;
        frequencies.push(effective_frequency_mhz(nominal_mhz, performance_percent)?);
    }
    let minimum = frequencies.iter().copied().reduce(f64::min);
    let maximum = frequencies.iter().copied().reduce(f64::max);
    let (Some(minimum), Some(maximum)) = (minimum, maximum) else {
        return Err(invalid_data("CPU PDH empty frequency values"));
    };
    let average = frequencies.iter().sum::<f64>() / frequencies.len() as f64;
    Ok((average, minimum, maximum))
}

fn effective_frequency_mhz(
    nominal_mhz: i64,
    performance_percent: f64,
) -> Result<f64, BackendError> {
    let frequency = nominal_mhz as f64 * performance_percent / 100.0;
    if !frequency.is_finite() || frequency < 0.0 {
        return Err(invalid_data("CPU PDH effective frequency"));
    }
    Ok(frequency)
}

#[derive(Clone, Copy, Debug, Hash, Eq, PartialEq)]
struct PdhProcessorInstance {
    numa_node: u32,
    numa_index: u32,
}

fn parse_processor_instance(value: &str) -> Result<Option<PdhProcessorInstance>, BackendError> {
    if value.eq_ignore_ascii_case("_Total") {
        return Ok(None);
    }
    let mut fields = value.split(',');
    let numa_node = fields
        .next()
        .and_then(|value| value.parse::<u32>().ok())
        .ok_or_else(|| invalid_data("CPU PDH NUMA node instance"))?;
    let numa_index = fields
        .next()
        .ok_or_else(|| invalid_data("CPU PDH NUMA index instance"))?;
    if fields.next().is_some() {
        return Err(invalid_data("CPU PDH processor instance field count"));
    }
    if numa_index.eq_ignore_ascii_case("_Total") {
        return Ok(None);
    }
    let numa_index = numa_index
        .parse::<u32>()
        .map_err(|_| invalid_data("CPU PDH NUMA index instance"))?;
    Ok(Some(PdhProcessorInstance {
        numa_node,
        numa_index,
    }))
}

unsafe fn read_bounded_wide(
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
        return Err(invalid_data("CPU PDH instance name pointer"));
    }
    let max_units = (end - address) / size_of::<u16>();
    // SAFETY: the pointer was validated to remain inside the live PDH output allocation.
    let units = unsafe { slice::from_raw_parts(pointer, max_units) };
    let length = units
        .iter()
        .position(|unit| *unit == 0)
        .ok_or_else(|| invalid_data("CPU PDH instance name terminator"))?;
    String::from_utf16(&units[..length]).map_err(|_| invalid_data("CPU PDH instance name encoding"))
}

fn validate_pdh_status(status: u32, counter_path: &'static str) -> Result<(), BackendError> {
    if matches!(status, PDH_CSTATUS_VALID_DATA | PDH_CSTATUS_NEW_DATA) {
        Ok(())
    } else {
        Err(pdh_counter_error(
            "CPU PDH formatted counter status",
            counter_path,
            status,
        ))
    }
}

fn pdh_counter_is_unavailable(status: u32) -> bool {
    matches!(
        status,
        PDH_CSTATUS_NO_OBJECT | PDH_CSTATUS_NO_COUNTER | PDH_INVALID_PATH
    )
}

fn pdh_error(context: impl Into<String>, status: u32) -> BackendError {
    BackendError {
        domain: "pdh".to_string(),
        code: i64::from(status),
        context: context.into(),
        message: format!("PDH status 0x{status:08X}"),
    }
}

fn pdh_counter_error(context: &str, path: &str, status: u32) -> BackendError {
    pdh_error(format!("{context}: {path}"), status)
}

fn invalid_data(context: impl Into<String>) -> BackendError {
    BackendError::internal(
        context,
        "Windows returned inconsistent CPU performance data",
    )
}

fn to_wide_null(value: &str) -> Vec<u16> {
    value.encode_utf16().chain([0]).collect()
}

#[cfg(test)]
mod tests {
    use super::{
        PdhArrayValue, PdhProcessorInstance, effective_frequency_mhz, parse_processor_instance,
        summarize_frequencies,
    };

    #[test]
    fn processor_instances_exclude_aggregate_rows() {
        assert_eq!(parse_processor_instance("_Total").unwrap(), None);
        assert_eq!(parse_processor_instance("0,_Total").unwrap(), None);
        assert_eq!(
            parse_processor_instance("1,7").unwrap(),
            Some(PdhProcessorInstance {
                numa_node: 1,
                numa_index: 7,
            })
        );
    }

    #[test]
    fn effective_frequency_allows_boost_above_nominal() {
        assert_eq!(effective_frequency_mhz(2400, 125.0).unwrap(), 3000.0);
    }

    #[test]
    fn frequency_summary_pairs_instances_independent_of_order() {
        let nominal = [
            PdhArrayValue {
                instance: "0,0".to_string(),
                value: 2400,
            },
            PdhArrayValue {
                instance: "0,1".to_string(),
                value: 2400,
            },
            PdhArrayValue {
                instance: "_Total".to_string(),
                value: 2400,
            },
        ];
        let performance = [
            PdhArrayValue {
                instance: "0,1".to_string(),
                value: 150.0,
            },
            PdhArrayValue {
                instance: "0,0".to_string(),
                value: 50.0,
            },
            PdhArrayValue {
                instance: "_Total".to_string(),
                value: 100.0,
            },
        ];
        assert_eq!(
            summarize_frequencies(&nominal, &performance, 2).unwrap(),
            (2400.0, 1200.0, 3600.0)
        );
    }
}
