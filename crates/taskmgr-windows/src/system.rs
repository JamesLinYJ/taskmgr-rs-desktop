// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows 性能与 CPU 采样
//
//   文件:       crates/taskmgr-windows/src/system.rs
//
//   日期:       2026年08月21日
//   环境:       Windows x64/ARM64 API；Rust 1.97.1；x86_64-pc-windows-gnu 交叉检查
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   NtQuerySystemInformation；K32GetPerformanceInfo；GetLogicalProcessorInformationEx
// --------------------------------------------------------------------------

//! 从系统累计计数器生成性能页与 CPU 页的不可变快照。
//!
//! 两个页面持有彼此独立的 CPU 计数器基线。首次采样或计数器不连续时保留
//! `None` 与上一轮可信历史，不把未知值伪装成零。

use std::mem::size_of;

use taskmgr_core::{
    BackendError, CpuCurrentMetrics, CpuData, CpuHardwareMetrics, CpuSystemMetrics,
    CpuTopologyMetrics, HISTORY_CAPACITY, HistoryBuffer, PerformanceData, SnapshotData,
};
use windows_sys::Win32::System::ProcessStatus::{K32GetPerformanceInfo, PERFORMANCE_INFORMATION};
use windows_sys::Win32::System::SystemInformation::GetTickCount64;

use crate::cpu::{CpuUsageDelta, CpuUsageSampler, query_cpu_frequencies, query_cpu_inventory};
use crate::native::last_error;
use crate::pdh::CpuPdhSampler;

pub(crate) struct SystemSampler {
    performance_cpu: CpuUsageSampler,
    cpu_page_cpu: CpuUsageSampler,
    cpu_page_pdh: Option<CpuPdhSampler>,
    performance_cpu_history: HistoryBuffer,
    performance_kernel_history: HistoryBuffer,
    memory_history: HistoryBuffer,
    logical_cpu_histories: Vec<HistoryBuffer>,
    logical_kernel_histories: Vec<HistoryBuffer>,
    logical_cpu_labels: Vec<String>,
    cpu_page_history: HistoryBuffer,
    cpu_page_kernel_history: HistoryBuffer,
    model: Option<String>,
    topology: CpuTopologyMetrics,
    hardware: CpuHardwareMetrics,
}

impl SystemSampler {
    pub(crate) fn new() -> Self {
        let (model, topology, hardware, logical_cpu_labels) = query_cpu_inventory();
        let logical_processor_count = topology.logical_processor_count.unwrap_or(1).max(1) as usize;
        Self {
            performance_cpu: CpuUsageSampler::default(),
            cpu_page_cpu: CpuUsageSampler::default(),
            cpu_page_pdh: CpuPdhSampler::new(logical_processor_count).ok(),
            performance_cpu_history: HistoryBuffer::new(HISTORY_CAPACITY),
            performance_kernel_history: HistoryBuffer::new(HISTORY_CAPACITY),
            memory_history: HistoryBuffer::new(HISTORY_CAPACITY),
            logical_cpu_histories: Vec::new(),
            logical_kernel_histories: Vec::new(),
            logical_cpu_labels,
            cpu_page_history: HistoryBuffer::new(HISTORY_CAPACITY),
            cpu_page_kernel_history: HistoryBuffer::new(HISTORY_CAPACITY),
            model,
            topology,
            hardware,
        }
    }

    pub(crate) fn sample_performance(&mut self) -> Result<SnapshotData, BackendError> {
        let cpu = self.performance_cpu.sample()?;
        let performance = query_performance_information()?;
        if let Some(delta) = &cpu {
            self.push_performance_cpu(delta);
        }

        let memory_percent = memory_percent(&performance);
        if let Some(value) = memory_percent {
            self.memory_history.push(value);
        }
        let page_size = performance.PageSize as u64;
        let pages_to_kib = |pages: usize| Some((pages as u64).saturating_mul(page_size) / 1_024);

        Ok(SnapshotData::Performance(Box::new(PerformanceData {
            process_count: Some(u64::from(performance.ProcessCount)),
            thread_count: Some(u64::from(performance.ThreadCount)),
            handle_count: Some(u64::from(performance.HandleCount)),
            open_file_count: None,
            memory_total_kib: pages_to_kib(performance.PhysicalTotal),
            memory_available_kib: pages_to_kib(performance.PhysicalAvailable),
            file_cache_kib: pages_to_kib(performance.SystemCache),
            commit_total_kib: pages_to_kib(performance.CommitTotal),
            commit_limit_kib: pages_to_kib(performance.CommitLimit),
            commit_peak_kib: pages_to_kib(performance.CommitPeak),
            kernel_total_kib: pages_to_kib(performance.KernelTotal),
            kernel_paged_kib: pages_to_kib(performance.KernelPaged),
            kernel_non_paged_kib: pages_to_kib(performance.KernelNonpaged),
            swap_used_kib: None,
            slab_kib: None,
            kernel_stack_kib: None,
            page_tables_kib: None,
            cpu_percent: cpu.as_ref().map(|delta| delta.busy_percent),
            memory_percent,
            cpu_history: self.performance_cpu_history.snapshot(),
            kernel_history: self.performance_kernel_history.snapshot(),
            memory_history: self.memory_history.snapshot(),
            logical_cpu_labels: logical_labels_for_count(
                &self.logical_cpu_labels,
                self.logical_cpu_histories.len(),
            ),
            logical_cpu_histories: history_snapshots(&self.logical_cpu_histories),
            logical_kernel_histories: history_snapshots(&self.logical_kernel_histories),
        })))
    }

    pub(crate) fn sample_cpu(&mut self) -> Result<SnapshotData, BackendError> {
        let cpu = self.cpu_page_cpu.sample()?;
        let performance = query_performance_information()?;
        if let Some(delta) = &cpu {
            self.cpu_page_history.push(delta.busy_percent);
            self.cpu_page_kernel_history.push(delta.kernel_percent);
        }
        let logical_count = self.cpu_page_cpu.logical_processor_count();
        let pdh = self
            .cpu_page_pdh
            .as_mut()
            .and_then(|sampler| sampler.sample().ok())
            .flatten();
        let frequency = query_cpu_frequencies(logical_count);
        let mut topology = self.topology.clone();
        if logical_count > 0 {
            topology.logical_processor_count = u32::try_from(logical_count).ok();
        }
        let mut hardware = self.hardware.clone();
        if frequency.firmware_maximum_mhz.is_some() {
            hardware.firmware_max_frequency_mhz = frequency.firmware_maximum_mhz;
        }

        Ok(SnapshotData::Cpu(Box::new(CpuData {
            model: self.model.clone(),
            utilization_percent: cpu.as_ref().map(|delta| delta.busy_percent),
            history: self.cpu_page_history.snapshot(),
            kernel_history: self.cpu_page_kernel_history.snapshot(),
            current: CpuCurrentMetrics {
                average_frequency_mhz: pdh
                    .and_then(|value| value.average_frequency_mhz)
                    .or(frequency.average_current_mhz),
                minimum_frequency_mhz: pdh
                    .and_then(|value| value.minimum_frequency_mhz)
                    .or(frequency.minimum_current_mhz),
                maximum_frequency_mhz: pdh
                    .and_then(|value| value.maximum_frequency_mhz)
                    .or(frequency.maximum_current_mhz),
                user_percent: cpu.as_ref().map(|delta| delta.user_percent),
                kernel_percent: cpu.as_ref().map(|delta| delta.kernel_percent),
                dpc_percent: cpu.as_ref().map(|delta| delta.dpc_percent),
                interrupt_percent: cpu.as_ref().map(|delta| delta.interrupt_percent),
                interrupts_per_second: cpu.as_ref().map(|delta| delta.interrupts_per_second),
                uptime_seconds: Some(unsafe { GetTickCount64() } / 1_000),
            },
            system: CpuSystemMetrics {
                process_count: Some(u64::from(performance.ProcessCount)),
                thread_count: Some(u64::from(performance.ThreadCount)),
                handle_count: Some(u64::from(performance.HandleCount)),
                file_descriptor_count: None,
                open_file_count: None,
                processor_queue_length: pdh.and_then(|value| value.processor_queue_length),
                context_switches_per_second: pdh
                    .and_then(|value| value.context_switches_per_second),
                system_calls_per_second: pdh.and_then(|value| value.system_calls_per_second),
            },
            topology,
            hardware,
        })))
    }

    fn push_performance_cpu(&mut self, delta: &CpuUsageDelta) {
        self.performance_cpu_history.push(delta.busy_percent);
        self.performance_kernel_history.push(delta.kernel_percent);
        if self.logical_cpu_histories.len() != delta.logical_busy_percent.len() {
            self.logical_cpu_histories = new_histories(delta.logical_busy_percent.len());
            self.logical_kernel_histories = new_histories(delta.logical_kernel_percent.len());
        }
        for (history, value) in self
            .logical_cpu_histories
            .iter_mut()
            .zip(&delta.logical_busy_percent)
        {
            history.push(*value);
        }
        for (history, value) in self
            .logical_kernel_histories
            .iter_mut()
            .zip(&delta.logical_kernel_percent)
        {
            history.push(*value);
        }
    }
}

fn logical_labels_for_count(labels: &[String], count: usize) -> Vec<String> {
    if labels.len() == count {
        labels.to_vec()
    } else {
        (0..count).map(|index| format!("CPU{index}")).collect()
    }
}

fn query_performance_information() -> Result<PERFORMANCE_INFORMATION, BackendError> {
    let mut performance = PERFORMANCE_INFORMATION {
        cb: size_of::<PERFORMANCE_INFORMATION>() as u32,
        ..PERFORMANCE_INFORMATION::default()
    };
    // SAFETY: `performance` has the documented size and writable storage for the call.
    if unsafe { K32GetPerformanceInfo(&mut performance, performance.cb) } == 0 {
        return Err(last_error("K32GetPerformanceInfo"));
    }
    Ok(performance)
}

fn memory_percent(performance: &PERFORMANCE_INFORMATION) -> Option<f64> {
    (performance.PhysicalTotal > 0).then(|| {
        performance
            .PhysicalTotal
            .saturating_sub(performance.PhysicalAvailable) as f64
            * 100.0
            / performance.PhysicalTotal as f64
    })
}

fn new_histories(count: usize) -> Vec<HistoryBuffer> {
    (0..count)
        .map(|_| HistoryBuffer::new(HISTORY_CAPACITY))
        .collect()
}

fn history_snapshots(histories: &[HistoryBuffer]) -> Vec<Vec<f64>> {
    histories.iter().map(HistoryBuffer::snapshot).collect()
}

#[cfg(test)]
mod tests {
    use super::memory_percent;
    use windows_sys::Win32::System::ProcessStatus::PERFORMANCE_INFORMATION;

    #[test]
    fn memory_usage_is_derived_from_available_pages() {
        let performance = PERFORMANCE_INFORMATION {
            PhysicalTotal: 200,
            PhysicalAvailable: 50,
            ..PERFORMANCE_INFORMATION::default()
        };
        assert_eq!(memory_percent(&performance), Some(75.0));
    }

    #[test]
    fn missing_physical_total_is_not_reported_as_zero() {
        assert_eq!(memory_percent(&PERFORMANCE_INFORMATION::default()), None);
    }
}
