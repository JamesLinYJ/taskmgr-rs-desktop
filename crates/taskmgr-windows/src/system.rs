// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows 性能与 CPU 采样
//
//   文件:       crates/taskmgr-windows/src/system.rs
//
//   日期:       2026年08月20日
//   环境:       Windows x64/ARM64 API；Rust 1.97.1；x86_64-pc-windows-gnu 交叉检查
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   GetSystemTimes；K32GetPerformanceInfo；GetActiveProcessorCount；GetTickCount64
// --------------------------------------------------------------------------

//! 从系统累计计数器生成性能与 CPU 不可变快照。
//!
//! 百分比只在存在前一轮可信计数器时计算；首次采样保持 `None`，不会伪造为零。

use std::mem::size_of;

use taskmgr_core::{
    BackendError, CpuData, CpuMetricGroup, HISTORY_CAPACITY, HistoryBuffer, MetricValue,
    PerformanceData, SnapshotData,
};
use windows_sys::Win32::Foundation::FILETIME;
use windows_sys::Win32::System::ProcessStatus::{K32GetPerformanceInfo, PERFORMANCE_INFORMATION};
use windows_sys::Win32::System::SystemInformation::GetTickCount64;
use windows_sys::Win32::System::Threading::{
    ALL_PROCESSOR_GROUPS, GetActiveProcessorCount, GetSystemTimes,
};

use crate::native::{filetime_to_u64, last_error};

#[derive(Clone, Copy)]
struct CpuTimes {
    idle: u64,
    kernel: u64,
    user: u64,
}

impl CpuTimes {
    const fn total(self) -> u64 {
        self.kernel.saturating_add(self.user)
    }
}

struct SystemSample {
    performance: PERFORMANCE_INFORMATION,
    cpu_percent: Option<f64>,
    kernel_percent: Option<f64>,
    memory_percent: Option<f64>,
}

pub(crate) struct SystemSampler {
    previous_cpu: Option<CpuTimes>,
    cpu_history: HistoryBuffer,
    kernel_history: HistoryBuffer,
    memory_history: HistoryBuffer,
    model: Option<String>,
}

impl SystemSampler {
    pub(crate) fn new() -> Self {
        Self {
            previous_cpu: None,
            cpu_history: HistoryBuffer::new(HISTORY_CAPACITY),
            kernel_history: HistoryBuffer::new(HISTORY_CAPACITY),
            memory_history: HistoryBuffer::new(HISTORY_CAPACITY),
            model: std::env::var("PROCESSOR_IDENTIFIER")
                .ok()
                .filter(|value| !value.trim().is_empty()),
        }
    }

    pub(crate) fn sample_performance(&mut self) -> Result<SnapshotData, BackendError> {
        let sample = self.collect()?;
        let page_size = sample.performance.PageSize as u64;
        let pages_to_kib = |pages: usize| Some((pages as u64).saturating_mul(page_size) / 1_024);
        Ok(SnapshotData::Performance(Box::new(PerformanceData {
            process_count: Some(u64::from(sample.performance.ProcessCount)),
            thread_count: Some(u64::from(sample.performance.ThreadCount)),
            handle_count: Some(u64::from(sample.performance.HandleCount)),
            memory_total_kib: pages_to_kib(sample.performance.PhysicalTotal),
            memory_available_kib: pages_to_kib(sample.performance.PhysicalAvailable),
            file_cache_kib: pages_to_kib(sample.performance.SystemCache),
            commit_total_kib: pages_to_kib(sample.performance.CommitTotal),
            commit_limit_kib: pages_to_kib(sample.performance.CommitLimit),
            commit_peak_kib: pages_to_kib(sample.performance.CommitPeak),
            kernel_total_kib: pages_to_kib(sample.performance.KernelTotal),
            kernel_paged_kib: pages_to_kib(sample.performance.KernelPaged),
            kernel_non_paged_kib: pages_to_kib(sample.performance.KernelNonpaged),
            cpu_percent: sample.cpu_percent,
            memory_percent: sample.memory_percent,
            cpu_history: self.cpu_history.snapshot(),
            kernel_history: self.kernel_history.snapshot(),
            memory_history: self.memory_history.snapshot(),
            logical_cpu_histories: Vec::new(),
        })))
    }

    pub(crate) fn sample_cpu(&mut self) -> Result<SnapshotData, BackendError> {
        let sample = self.collect()?;
        // SAFETY: the all-groups sentinel is explicitly accepted by GetActiveProcessorCount.
        let logical = unsafe { GetActiveProcessorCount(ALL_PROCESSOR_GROUPS) };
        // SAFETY: GetTickCount64 has no preconditions.
        let uptime_millis = unsafe { GetTickCount64() };
        Ok(SnapshotData::Cpu(CpuData {
            model: self.model.clone(),
            status: Some("Active".to_string()),
            utilization_percent: sample.cpu_percent,
            history: self.cpu_history.snapshot(),
            groups: vec![
                CpuMetricGroup {
                    title: "Current State".to_string(),
                    metrics: vec![
                        metric(
                            "Kernel Time",
                            sample.kernel_percent.map(|value| format!("{value:.1}%")),
                        ),
                        metric("Uptime", Some(format_duration(uptime_millis / 1_000))),
                    ],
                },
                CpuMetricGroup {
                    title: "Topology and Features".to_string(),
                    metrics: vec![
                        metric(
                            "Logical Processors",
                            (logical > 0).then(|| logical.to_string()),
                        ),
                        metric(
                            "Architecture / Width",
                            Some(format!("{} / {}-bit", std::env::consts::ARCH, usize::BITS)),
                        ),
                    ],
                },
                CpuMetricGroup {
                    title: "System Totals".to_string(),
                    metrics: vec![
                        metric(
                            "Processes",
                            Some(sample.performance.ProcessCount.to_string()),
                        ),
                        metric("Threads", Some(sample.performance.ThreadCount.to_string())),
                        metric("Handles", Some(sample.performance.HandleCount.to_string())),
                    ],
                },
            ],
        }))
    }

    fn collect(&mut self) -> Result<SystemSample, BackendError> {
        let current = query_cpu_times()?;
        let (cpu_percent, kernel_percent) = self
            .previous_cpu
            .and_then(|previous| percentages(previous, current))
            .map_or((None, None), |(cpu, kernel)| (Some(cpu), Some(kernel)));
        self.previous_cpu = Some(current);
        if let Some(value) = cpu_percent {
            self.cpu_history.push(value);
        }
        if let Some(value) = kernel_percent {
            self.kernel_history.push(value);
        }

        let mut performance = PERFORMANCE_INFORMATION {
            cb: size_of::<PERFORMANCE_INFORMATION>() as u32,
            ..PERFORMANCE_INFORMATION::default()
        };
        // SAFETY: `performance` has the documented size and writable storage for the call.
        if unsafe { K32GetPerformanceInfo(&mut performance, performance.cb) } == 0 {
            return Err(last_error("K32GetPerformanceInfo"));
        }
        let memory_percent = (performance.PhysicalTotal > 0).then(|| {
            performance
                .PhysicalTotal
                .saturating_sub(performance.PhysicalAvailable) as f64
                * 100.0
                / performance.PhysicalTotal as f64
        });
        if let Some(value) = memory_percent {
            self.memory_history.push(value);
        }
        Ok(SystemSample {
            performance,
            cpu_percent,
            kernel_percent,
            memory_percent,
        })
    }
}

fn query_cpu_times() -> Result<CpuTimes, BackendError> {
    let mut idle = FILETIME::default();
    let mut kernel = FILETIME::default();
    let mut user = FILETIME::default();
    // SAFETY: all outputs are valid writable FILETIME storage.
    if unsafe { GetSystemTimes(&mut idle, &mut kernel, &mut user) } == 0 {
        return Err(last_error("GetSystemTimes"));
    }
    Ok(CpuTimes {
        idle: filetime_to_u64(idle),
        kernel: filetime_to_u64(kernel),
        user: filetime_to_u64(user),
    })
}

fn percentages(previous: CpuTimes, current: CpuTimes) -> Option<(f64, f64)> {
    let total = current.total().saturating_sub(previous.total());
    if total == 0 {
        return None;
    }
    let idle = current.idle.saturating_sub(previous.idle).min(total);
    let kernel = current
        .kernel
        .saturating_sub(previous.kernel)
        .saturating_sub(idle)
        .min(total);
    Some((
        ((total - idle) as f64 * 100.0 / total as f64).clamp(0.0, 100.0),
        (kernel as f64 * 100.0 / total as f64).clamp(0.0, 100.0),
    ))
}

fn metric(label: &str, value: Option<String>) -> MetricValue {
    MetricValue {
        label: label.to_string(),
        value,
    }
}

fn format_duration(seconds: u64) -> String {
    let days = seconds / 86_400;
    let hours = seconds % 86_400 / 3_600;
    let minutes = seconds % 3_600 / 60;
    let seconds = seconds % 60;
    format!("{days}:{hours:02}:{minutes:02}:{seconds:02}")
}

#[cfg(test)]
mod tests {
    use super::{CpuTimes, percentages};

    #[test]
    fn derives_busy_and_kernel_percent_from_cumulative_times() {
        let previous = CpuTimes {
            idle: 100,
            kernel: 200,
            user: 100,
        };
        let current = CpuTimes {
            idle: 140,
            kernel: 260,
            user: 140,
        };
        assert_eq!(percentages(previous, current), Some((60.0, 20.0)));
    }

    #[test]
    fn does_not_invent_a_value_without_elapsed_ticks() {
        let value = CpuTimes {
            idle: 10,
            kernel: 20,
            user: 30,
        };
        assert_eq!(percentages(value, value), None);
    }
}
