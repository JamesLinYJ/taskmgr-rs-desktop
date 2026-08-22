// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Linux procfs 采样与进程操作
//
//   文件:       crates/taskmgr-linux/src/procfs.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   proc(5)；proc_pid_stat(5)；pidfd_open(2)；pidfd_send_signal(2)
// --------------------------------------------------------------------------

//! 从 `/proc` 和 CPU sysfs 构建进程、性能与 CPU 快照。
//!
//! 危险操作先校验 PID 与 starttime；终止操作使用 pidfd，绝不降级为 PID-only kill。
//! `setpriority` 和 `sched_setaffinity` 只接受 PID，无法与 `ProcessIdentity` 原子绑定，因此保持不支持。

use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::fs;
use std::io;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::path::Path;
use std::process::Command;
use std::time::Instant;

use taskmgr_core::{
    ActionRequest, ActionResult, BackendError, CpuCache, CpuCacheKind, CpuCoreClass,
    CpuCurrentMetrics, CpuData, CpuHardwareMetrics, CpuSystemMetrics, CpuTopologyMetrics,
    HISTORY_CAPACITY, HistoryBuffer, PerformanceData, ProcessIdentity, ProcessRow, ProcessesData,
    SnapshotData,
};

pub(crate) const PID_ONLY_SCHEDULING_UNSUPPORTED: &str = "Linux scheduling mutations are unavailable because PID-only syscalls cannot remain bound to ProcessIdentity";

#[derive(Clone, Debug)]
struct ParsedStat {
    pid: u32,
    command: String,
    parent_pid: u32,
    minor_faults: u64,
    major_faults: u64,
    user_ticks: u64,
    system_ticks: u64,
    priority: i64,
    nice: i32,
    threads: u64,
    start_time: u64,
    virtual_bytes: u64,
    resident_pages: i64,
}

#[derive(Clone, Debug)]
struct ProcessBaseline {
    cpu_ticks: u64,
    memory_kib: u64,
    page_faults: u64,
}

#[derive(Clone, Copy, Debug)]
struct CpuTimes {
    total: u64,
    idle: u64,
    user: u64,
    kernel: u64,
    interrupt: u64,
}

#[derive(Clone, Debug)]
struct CpuDetailBaseline {
    times: CpuTimes,
    interrupts: Option<u64>,
    context_switches: Option<u64>,
    sampled_at: Instant,
}

#[derive(Clone, Debug)]
struct CpuTopologySnapshot {
    package_count: Option<u32>,
    numa_node_count: Option<u32>,
    die_count: Option<u32>,
    module_count: Option<u32>,
    physical_core_count: Option<u32>,
    logical_processor_count: Option<u32>,
    core_classes: Vec<CpuCoreClass>,
    smt_core_count: Option<u32>,
    minimum_threads_per_core: Option<u32>,
    maximum_threads_per_core: Option<u32>,
}

pub struct ProcSampler {
    process_baselines: HashMap<ProcessIdentity, ProcessBaseline>,
    total_cpu_baseline: Option<CpuTimes>,
    performance_cpu_baseline: Option<CpuTimes>,
    per_cpu_baselines: Vec<Option<CpuTimes>>,
    cpu_history: HistoryBuffer,
    kernel_history: HistoryBuffer,
    memory_history: HistoryBuffer,
    per_cpu_histories: Vec<HistoryBuffer>,
    per_cpu_kernel_histories: Vec<HistoryBuffer>,
    cpu_detail_baseline: Option<CpuDetailBaseline>,
    cpu_detail_history: HistoryBuffer,
    cpu_detail_kernel_history: HistoryBuffer,
    clock_ticks_per_second: u64,
    page_size: u64,
    last_process_sample: Option<Instant>,
}

impl ProcSampler {
    pub fn new() -> Self {
        let clock_ticks = unsafe { libc::sysconf(libc::_SC_CLK_TCK) };
        let page_size = unsafe { libc::sysconf(libc::_SC_PAGESIZE) };
        Self {
            process_baselines: HashMap::new(),
            total_cpu_baseline: None,
            performance_cpu_baseline: None,
            per_cpu_baselines: Vec::new(),
            cpu_history: HistoryBuffer::new(HISTORY_CAPACITY),
            kernel_history: HistoryBuffer::new(HISTORY_CAPACITY),
            memory_history: HistoryBuffer::new(HISTORY_CAPACITY),
            per_cpu_histories: Vec::new(),
            per_cpu_kernel_histories: Vec::new(),
            cpu_detail_baseline: None,
            cpu_detail_history: HistoryBuffer::new(HISTORY_CAPACITY),
            cpu_detail_kernel_history: HistoryBuffer::new(HISTORY_CAPACITY),
            clock_ticks_per_second: u64::try_from(clock_ticks)
                .ok()
                .filter(|value| *value > 0)
                .unwrap_or(100),
            page_size: u64::try_from(page_size)
                .ok()
                .filter(|value| *value > 0)
                .unwrap_or(4_096),
            last_process_sample: None,
        }
    }

    pub fn sample_processes(&mut self) -> Result<SnapshotData, BackendError> {
        let system_cpu =
            read_cpu_times().map_err(|error| BackendError::io("read /proc/stat", &error))?;
        let total_delta = self
            .total_cpu_baseline
            .map(|baseline| system_cpu.total.saturating_sub(baseline.total))
            .filter(|delta| *delta > 0);
        self.total_cpu_baseline = Some(system_cpu);
        let _elapsed = self.last_process_sample.replace(Instant::now());
        let users = passwd_users();
        let mut next_baselines = HashMap::new();
        let mut rows = Vec::new();

        for pid in process_ids().map_err(|error| BackendError::io("enumerate /proc", &error))? {
            let stat = match read_process_stat(pid) {
                Ok(stat) => stat,
                Err(error)
                    if matches!(
                        error.kind(),
                        io::ErrorKind::NotFound | io::ErrorKind::PermissionDenied
                    ) =>
                {
                    continue;
                }
                Err(error) => {
                    rows.push(inaccessible_process_row(
                        pid,
                        BackendError::io("read process stat", &error),
                    ));
                    continue;
                }
            };
            let identity = ProcessIdentity {
                pid,
                start_time: stat.start_time,
            };
            let status = read_status(pid).unwrap_or_default();
            let memory_kib = status
                .get("VmRSS")
                .and_then(|value| first_u64(value))
                .or_else(|| {
                    u64::try_from(stat.resident_pages)
                        .ok()
                        .map(|pages| pages.saturating_mul(self.page_size) / 1_024)
                });
            let faults = stat.minor_faults.saturating_add(stat.major_faults);
            let cpu_ticks = stat.user_ticks.saturating_add(stat.system_ticks);
            let previous = self.process_baselines.get(&identity);
            let cpu_percent = previous.zip(total_delta).map(|(previous, total_delta)| {
                (cpu_ticks.saturating_sub(previous.cpu_ticks) as f64 * 100.0) / total_delta as f64
            });
            let memory_delta_kib = previous.and_then(|previous| {
                memory_kib.map(|current| signed_delta(current, previous.memory_kib))
            });
            let page_faults_delta =
                previous.map(|previous| signed_delta(faults, previous.page_faults));
            let uid = status.get("Uid").and_then(|value| first_u64(value));
            let file_descriptor_count = fs::read_dir(format!("/proc/{pid}/fd"))
                .ok()
                .map(|entries| entries.filter_map(Result::ok).count() as u64);
            let row_error = if file_descriptor_count.is_none() {
                Some(BackendError::unsupported(
                    "process_fd_count",
                    "file descriptors are hidden by process permissions",
                ))
            } else {
                None
            };
            let executable_path = fs::read_link(format!("/proc/{pid}/exe"))
                .ok()
                .map(|path| path.to_string_lossy().into_owned());
            let session_id = unsafe { libc::getsid(pid as libc::pid_t) };
            let cgroup = fs::read_to_string(format!("/proc/{pid}/cgroup"))
                .ok()
                .and_then(|text| text.lines().next().map(cgroup_path));
            let affinity = status
                .get("Cpus_allowed_list")
                .and_then(|value| parse_cpu_list(value));

            rows.push(ProcessRow {
                identity: identity.clone(),
                parent_pid: Some(stat.parent_pid),
                image_name: stat.command,
                show_32_bit_suffix: None,
                executable_path,
                user_name: uid.and_then(|uid| users.get(&uid).cloned()),
                session_id: u32::try_from(session_id).ok(),
                cpu_percent,
                cpu_time_millis: Some(
                    cpu_ticks.saturating_mul(1_000) / self.clock_ticks_per_second,
                ),
                memory_kib,
                memory_delta_kib,
                page_faults: Some(faults),
                page_faults_delta,
                virtual_memory_kib: Some(stat.virtual_bytes / 1_024),
                paged_pool_kib: None,
                non_paged_pool_kib: None,
                base_priority: Some(stat.priority.to_string()),
                handle_count: None,
                thread_count: Some(stat.threads),
                file_descriptor_count,
                nice: Some(stat.nice),
                cgroup,
                affinity,
                row_error,
            });
            next_baselines.insert(
                identity,
                ProcessBaseline {
                    cpu_ticks,
                    memory_kib: memory_kib.unwrap_or(0),
                    page_faults: faults,
                },
            );
        }
        rows.sort_by_key(|row| row.image_name.to_lowercase());
        self.process_baselines = next_baselines;
        Ok(SnapshotData::Processes(ProcessesData { rows }))
    }

    pub fn sample_performance(&mut self) -> Result<SnapshotData, BackendError> {
        let stat = fs::read_to_string("/proc/stat")
            .map_err(|error| BackendError::io("read /proc/stat", &error))?;
        let mut lines = stat.lines();
        let aggregate = parse_cpu_line(lines.next().unwrap_or_default()).ok_or_else(|| {
            BackendError::internal("parse /proc/stat", "aggregate CPU counters are missing")
        })?;
        let cpu_percent = utilization(self.performance_cpu_baseline, aggregate);
        let kernel_percent =
            percentages(self.performance_cpu_baseline, aggregate).map(|value| value.kernel);
        self.performance_cpu_baseline = Some(aggregate);
        if let Some(value) = cpu_percent {
            self.cpu_history.push(value);
        }
        if let Some(value) = kernel_percent {
            self.kernel_history.push(value);
        }

        let per_cpu = lines
            .take_while(|line| line.starts_with("cpu"))
            .filter_map(parse_cpu_line)
            .collect::<Vec<_>>();
        resize_cpu_histories(
            &mut self.per_cpu_baselines,
            &mut self.per_cpu_histories,
            &mut self.per_cpu_kernel_histories,
            per_cpu.len(),
        );
        for (index, current) in per_cpu.into_iter().enumerate() {
            if let Some(value) = percentages(self.per_cpu_baselines[index], current) {
                self.per_cpu_histories[index].push(value.busy);
                self.per_cpu_kernel_histories[index].push(value.kernel);
            }
            self.per_cpu_baselines[index] = Some(current);
        }

        let memory =
            read_meminfo().map_err(|error| BackendError::io("read /proc/meminfo", &error))?;
        let total = memory.get("MemTotal").copied();
        let available = memory.get("MemAvailable").copied();
        let memory_percent = total.zip(available).and_then(|(total, available)| {
            (total > 0).then_some((total.saturating_sub(available) as f64 * 100.0) / total as f64)
        });
        if let Some(value) = memory_percent {
            self.memory_history.push(value);
        }
        let (process_count, thread_count) = count_process_totals();
        let swap_used_kib = memory
            .get("SwapTotal")
            .copied()
            .zip(memory.get("SwapFree").copied())
            .map(|(total, free)| total.saturating_sub(free));

        Ok(SnapshotData::Performance(Box::new(PerformanceData {
            process_count: Some(process_count),
            thread_count: Some(thread_count),
            handle_count: None,
            open_file_count: read_open_file_count(),
            memory_total_kib: total,
            memory_available_kib: available,
            file_cache_kib: sum_keys(&memory, &["Cached", "SReclaimable"]),
            commit_total_kib: memory.get("Committed_AS").copied(),
            commit_limit_kib: memory.get("CommitLimit").copied(),
            commit_peak_kib: None,
            kernel_total_kib: sum_keys(&memory, &["Slab", "KernelStack", "PageTables"]),
            kernel_paged_kib: None,
            kernel_non_paged_kib: None,
            swap_used_kib,
            slab_kib: memory.get("Slab").copied(),
            kernel_stack_kib: memory.get("KernelStack").copied(),
            page_tables_kib: memory.get("PageTables").copied(),
            cpu_percent,
            memory_percent,
            cpu_history: self.cpu_history.snapshot(),
            kernel_history: self.kernel_history.snapshot(),
            memory_history: self.memory_history.snapshot(),
            logical_cpu_labels: (0..self.per_cpu_histories.len())
                .map(|index| format!("CPU{index}"))
                .collect(),
            logical_cpu_histories: self
                .per_cpu_histories
                .iter()
                .map(HistoryBuffer::snapshot)
                .collect(),
            logical_kernel_histories: self
                .per_cpu_kernel_histories
                .iter()
                .map(HistoryBuffer::snapshot)
                .collect(),
        })))
    }

    pub fn sample_cpu(&mut self) -> Result<SnapshotData, BackendError> {
        let cpuinfo = fs::read_to_string("/proc/cpuinfo")
            .map_err(|error| BackendError::io("read /proc/cpuinfo", &error))?;
        let processors = cpuinfo
            .split("\n\n")
            .map(key_value_lines)
            .filter(|fields| !fields.is_empty())
            .collect::<Vec<_>>();
        let fields = processors.first().cloned().unwrap_or_default();
        let model = unique_cpuinfo_values(&processors, &["model name", "Processor", "cpu"])
            .into_iter()
            .reduce(|mut joined, value| {
                joined.push_str(" | ");
                joined.push_str(&value);
                joined
            });
        let flags = fields
            .get("flags")
            .or_else(|| fields.get("Features"))
            .map(|value| {
                value
                    .split_whitespace()
                    .map(str::to_string)
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default();

        let stat = fs::read_to_string("/proc/stat")
            .map_err(|error| BackendError::io("read /proc/stat for CPU details", &error))?;
        let stat_details = parse_cpu_detail_stat(&stat).ok_or_else(|| {
            BackendError::internal(
                "parse /proc/stat for CPU details",
                "aggregate CPU counters are missing",
            )
        })?;
        let now = Instant::now();
        let delta = self
            .cpu_detail_baseline
            .as_ref()
            .and_then(|baseline| cpu_detail_delta(baseline, &stat_details, now));
        self.cpu_detail_baseline = Some(CpuDetailBaseline {
            times: stat_details.times,
            interrupts: stat_details.interrupts,
            context_switches: stat_details.context_switches,
            sampled_at: now,
        });
        if let Some(delta) = &delta {
            self.cpu_detail_history.push(delta.busy_percent);
            self.cpu_detail_kernel_history.push(delta.kernel_percent);
        }

        let frequencies = read_cpu_frequencies(&processors);
        let topology = read_cpu_topology(processors.len());
        let (process_count, thread_count) = count_process_totals();
        let uptime_seconds = fs::read_to_string("/proc/uptime")
            .ok()
            .and_then(|text| text.split_whitespace().next()?.parse::<f64>().ok())
            .filter(|value| value.is_finite() && *value >= 0.0)
            .map(|value| value as u64);
        let virtualization = (!flags.is_empty()).then(|| {
            flags
                .iter()
                .any(|flag| matches!(flag.as_str(), "vmx" | "svm"))
        });
        let second_level_address_translation = (!flags.is_empty()).then(|| {
            flags
                .iter()
                .any(|flag| matches!(flag.as_str(), "ept" | "npt"))
        });

        Ok(SnapshotData::Cpu(Box::new(CpuData {
            model,
            utilization_percent: delta.as_ref().map(|value| value.busy_percent),
            history: self.cpu_detail_history.snapshot(),
            kernel_history: self.cpu_detail_kernel_history.snapshot(),
            current: CpuCurrentMetrics {
                average_frequency_mhz: frequencies.average_current_mhz,
                minimum_frequency_mhz: frequencies.minimum_current_mhz,
                maximum_frequency_mhz: frequencies.maximum_current_mhz,
                user_percent: delta.as_ref().map(|value| value.user_percent),
                kernel_percent: delta.as_ref().map(|value| value.kernel_percent),
                dpc_percent: None,
                interrupt_percent: delta.as_ref().map(|value| value.interrupt_percent),
                interrupts_per_second: delta.as_ref().and_then(|value| value.interrupts_per_second),
                uptime_seconds,
            },
            system: CpuSystemMetrics {
                process_count: Some(process_count),
                thread_count: Some(thread_count),
                handle_count: None,
                file_descriptor_count: None,
                open_file_count: read_open_file_count(),
                processor_queue_length: stat_details.processor_queue_length,
                context_switches_per_second: delta
                    .as_ref()
                    .and_then(|value| value.context_switches_per_second),
                system_calls_per_second: None,
            },
            topology: CpuTopologyMetrics {
                package_count: topology.package_count,
                numa_node_count: topology.numa_node_count,
                processor_group_count: None,
                die_count: topology.die_count,
                module_count: topology.module_count,
                physical_core_count: topology.physical_core_count,
                logical_processor_count: topology.logical_processor_count,
                core_classes: topology.core_classes,
                smt_core_count: topology.smt_core_count,
                minimum_threads_per_core: topology.minimum_threads_per_core,
                maximum_threads_per_core: topology.maximum_threads_per_core,
                virtualization,
                second_level_address_translation,
            },
            hardware: CpuHardwareMetrics {
                manufacturer: first_cpuinfo_value(
                    &fields,
                    &["vendor_id", "CPU implementer", "Hardware"],
                ),
                socket: topology_package_ids(),
                processor_id: first_cpuinfo_value(&fields, &["processor id", "Serial", "CPU part"]),
                architecture: Some(std::env::consts::ARCH.to_string()),
                address_width_bits: Some(usize::BITS as u16),
                data_width_bits: Some(usize::BITS as u16),
                family: first_cpuinfo_value(&fields, &["cpu family", "CPU architecture"]),
                level: None,
                revision: first_cpuinfo_value(&fields, &["revision", "microcode"]),
                stepping: first_cpuinfo_value(&fields, &["stepping"]),
                firmware_max_frequency_mhz: frequencies.firmware_maximum_mhz,
                isa_features: flags,
                caches: read_cpu_caches(),
            },
        })))
    }

    pub fn execute(&mut self, request: ActionRequest) -> ActionResult {
        match request {
            ActionRequest::EndProcess {
                identity,
                include_descendants,
            } => terminate(identity, include_descendants),
            ActionRequest::SetNice { .. } | ActionRequest::SetAffinity { .. } => {
                ActionResult::unsupported(PID_ONLY_SCHEDULING_UNSUPPORTED)
            }
            ActionRequest::OpenFileLocation { identity } => open_file_location(identity),
            ActionRequest::SetPriority { .. } => ActionResult::unsupported(
                "Linux exposes nice values instead of Windows priority classes",
            ),
            _ => ActionResult::unsupported("the requested operation is not a process operation"),
        }
    }
}

impl Default for ProcSampler {
    fn default() -> Self {
        Self::new()
    }
}

fn process_ids() -> io::Result<Vec<u32>> {
    let mut pids = Vec::new();
    for entry in fs::read_dir("/proc")? {
        let entry = entry?;
        if let Some(pid) = entry
            .file_name()
            .to_str()
            .and_then(|name| name.parse().ok())
        {
            pids.push(pid);
        }
    }
    Ok(pids)
}

fn read_process_stat(pid: u32) -> io::Result<ParsedStat> {
    parse_process_stat(pid, &fs::read_to_string(format!("/proc/{pid}/stat"))?)
}

fn parse_process_stat(pid: u32, text: &str) -> io::Result<ParsedStat> {
    let open = text.find('(').ok_or_else(invalid_stat)?;
    let close = text.rfind(')').ok_or_else(invalid_stat)?;
    if close <= open {
        return Err(invalid_stat());
    }
    let fields = text[close + 1..].split_whitespace().collect::<Vec<_>>();
    let number = |index: usize| -> io::Result<u64> {
        fields
            .get(index)
            .ok_or_else(invalid_stat)?
            .parse()
            .map_err(|_| invalid_stat())
    };
    Ok(ParsedStat {
        pid,
        command: text[open + 1..close].to_string(),
        parent_pid: u32::try_from(number(1)?).map_err(|_| invalid_stat())?,
        minor_faults: number(7)?,
        major_faults: number(9)?,
        user_ticks: number(11)?,
        system_ticks: number(12)?,
        priority: fields
            .get(15)
            .ok_or_else(invalid_stat)?
            .parse()
            .map_err(|_| invalid_stat())?,
        nice: fields
            .get(16)
            .ok_or_else(invalid_stat)?
            .parse()
            .map_err(|_| invalid_stat())?,
        threads: number(17)?,
        start_time: number(19)?,
        virtual_bytes: number(20)?,
        resident_pages: fields
            .get(21)
            .ok_or_else(invalid_stat)?
            .parse()
            .map_err(|_| invalid_stat())?,
    })
}

fn invalid_stat() -> io::Error {
    io::Error::new(
        io::ErrorKind::InvalidData,
        "invalid /proc/<pid>/stat record",
    )
}

fn inaccessible_process_row(pid: u32, error: BackendError) -> ProcessRow {
    ProcessRow {
        identity: ProcessIdentity { pid, start_time: 0 },
        parent_pid: None,
        image_name: format!("[{pid}]"),
        show_32_bit_suffix: None,
        executable_path: None,
        user_name: None,
        session_id: None,
        cpu_percent: None,
        cpu_time_millis: None,
        memory_kib: None,
        memory_delta_kib: None,
        page_faults: None,
        page_faults_delta: None,
        virtual_memory_kib: None,
        paged_pool_kib: None,
        non_paged_pool_kib: None,
        base_priority: None,
        handle_count: None,
        thread_count: None,
        file_descriptor_count: None,
        nice: None,
        cgroup: None,
        affinity: None,
        row_error: Some(error),
    }
}

fn read_status(pid: u32) -> io::Result<HashMap<String, String>> {
    Ok(key_value_lines(&fs::read_to_string(format!(
        "/proc/{pid}/status"
    ))?))
}

fn key_value_lines(text: &str) -> HashMap<String, String> {
    text.lines()
        .filter_map(|line| line.split_once(':'))
        .map(|(key, value)| (key.trim().to_string(), value.trim().to_string()))
        .collect()
}

fn first_u64(value: &str) -> Option<u64> {
    value.split_whitespace().next()?.parse().ok()
}

pub(crate) fn online_logical_processors() -> Vec<u32> {
    fs::read_to_string("/sys/devices/system/cpu/online")
        .ok()
        .and_then(|value| parse_cpu_list(&value))
        .or_else(|| {
            let status = fs::read_to_string("/proc/self/status").ok()?;
            key_value_lines(&status)
                .get("Cpus_allowed_list")
                .and_then(|value| parse_cpu_list(value))
        })
        .unwrap_or_default()
}

fn parse_cpu_list(value: &str) -> Option<Vec<u32>> {
    let mut result = Vec::new();
    for part in value.trim().split(',').filter(|part| !part.is_empty()) {
        let (start, end) = match part.split_once('-') {
            Some((start, end)) => (start.parse::<u32>().ok()?, end.parse::<u32>().ok()?),
            None => {
                let processor = part.parse::<u32>().ok()?;
                (processor, processor)
            }
        };
        if start > end || end.saturating_sub(start) > 65_535 {
            return None;
        }
        result.extend(start..=end);
    }
    (!result.is_empty()).then_some(result)
}

fn passwd_users() -> HashMap<u64, String> {
    fs::read_to_string("/etc/passwd")
        .ok()
        .into_iter()
        .flat_map(|text| text.lines().map(str::to_string).collect::<Vec<_>>())
        .filter_map(|line| {
            let mut fields = line.split(':');
            let name = fields.next()?.to_string();
            let _password = fields.next()?;
            let uid = fields.next()?.parse().ok()?;
            Some((uid, name))
        })
        .collect()
}

fn cgroup_path(line: &str) -> String {
    line.rsplit_once(':')
        .map_or(line, |(_, path)| path)
        .to_string()
}

fn read_cpu_times() -> io::Result<CpuTimes> {
    let stat = fs::read_to_string("/proc/stat")?;
    parse_cpu_line(stat.lines().next().unwrap_or_default()).ok_or_else(invalid_stat)
}

fn parse_cpu_line(line: &str) -> Option<CpuTimes> {
    let mut fields = line.split_whitespace();
    let name = fields.next()?;
    if !name.starts_with("cpu") {
        return None;
    }
    let values = fields
        .take(10)
        .map(str::parse::<u64>)
        .collect::<Result<Vec<_>, _>>()
        .ok()?;
    let guest = values.get(8).copied().unwrap_or(0);
    let guest_nice = values.get(9).copied().unwrap_or(0);
    let user = values
        .first()
        .copied()
        .unwrap_or(0)
        .saturating_sub(guest)
        .saturating_add(
            values
                .get(1)
                .copied()
                .unwrap_or(0)
                .saturating_sub(guest_nice),
        );
    let idle = values
        .get(3)
        .copied()
        .unwrap_or(0)
        .saturating_add(values.get(4).copied().unwrap_or(0));
    let interrupt = values
        .get(5)
        .copied()
        .unwrap_or(0)
        .saturating_add(values.get(6).copied().unwrap_or(0));
    let kernel = values
        .get(2)
        .copied()
        .unwrap_or(0)
        .saturating_add(interrupt);
    let total = user
        .saturating_add(kernel)
        .saturating_add(idle)
        .saturating_add(values.get(7).copied().unwrap_or(0));
    Some(CpuTimes {
        total,
        idle,
        user,
        kernel,
        interrupt,
    })
}

fn utilization(previous: Option<CpuTimes>, current: CpuTimes) -> Option<f64> {
    percentages(previous, current).map(|value| value.busy)
}

#[derive(Clone, Copy, Debug)]
struct CpuPercentages {
    busy: f64,
    user: f64,
    kernel: f64,
    interrupt: f64,
}

fn percentages(previous: Option<CpuTimes>, current: CpuTimes) -> Option<CpuPercentages> {
    let previous = previous?;
    let total = current.total.checked_sub(previous.total)?;
    let idle = current.idle.checked_sub(previous.idle)?;
    let user = current.user.checked_sub(previous.user)?;
    let kernel = current.kernel.checked_sub(previous.kernel)?;
    let interrupt = current.interrupt.checked_sub(previous.interrupt)?;
    if total == 0 || idle > total || user > total || kernel > total || interrupt > total {
        return None;
    }
    let percent = |value: u64| (value as f64 * 100.0 / total as f64).clamp(0.0, 100.0);
    Some(CpuPercentages {
        busy: percent(total - idle),
        user: percent(user),
        kernel: percent(kernel),
        interrupt: percent(interrupt),
    })
}

fn resize_cpu_histories(
    baselines: &mut Vec<Option<CpuTimes>>,
    histories: &mut Vec<HistoryBuffer>,
    kernel_histories: &mut Vec<HistoryBuffer>,
    length: usize,
) {
    if baselines.len() == length {
        return;
    }
    *baselines = vec![None; length];
    *histories = (0..length)
        .map(|_| HistoryBuffer::new(HISTORY_CAPACITY))
        .collect();
    *kernel_histories = (0..length)
        .map(|_| HistoryBuffer::new(HISTORY_CAPACITY))
        .collect();
}

fn read_meminfo() -> io::Result<HashMap<String, u64>> {
    Ok(fs::read_to_string("/proc/meminfo")?
        .lines()
        .filter_map(|line| {
            let (key, value) = line.split_once(':')?;
            Some((key.to_string(), first_u64(value)?))
        })
        .collect())
}

fn sum_keys(values: &HashMap<String, u64>, keys: &[&str]) -> Option<u64> {
    let present = keys
        .iter()
        .filter_map(|key| values.get(*key).copied())
        .collect::<Vec<_>>();
    (!present.is_empty()).then(|| present.into_iter().sum())
}

fn count_process_totals() -> (u64, u64) {
    let mut processes = 0_u64;
    let mut threads = 0_u64;
    if let Ok(pids) = process_ids() {
        for pid in pids {
            if let Ok(stat) = read_process_stat(pid) {
                processes += 1;
                threads = threads.saturating_add(stat.threads);
            }
        }
    }
    (processes, threads)
}

fn read_open_file_count() -> Option<u64> {
    fs::read_to_string("/proc/sys/fs/file-nr")
        .ok()
        .and_then(|value| parse_open_file_count(&value))
}

fn parse_open_file_count(value: &str) -> Option<u64> {
    let mut fields = value.split_whitespace();
    let allocated = fields.next()?.parse::<u64>().ok()?;
    let unused = fields.next()?.parse::<u64>().ok()?;
    Some(allocated.saturating_sub(unused))
}

fn signed_delta(current: u64, previous: u64) -> i64 {
    if current >= previous {
        i64::try_from(current - previous).unwrap_or(i64::MAX)
    } else {
        -i64::try_from(previous - current).unwrap_or(i64::MAX)
    }
}

#[derive(Clone, Copy, Debug)]
struct CpuDetailStat {
    times: CpuTimes,
    interrupts: Option<u64>,
    context_switches: Option<u64>,
    processor_queue_length: Option<u64>,
}

#[derive(Clone, Copy, Debug)]
struct CpuDetailDelta {
    busy_percent: f64,
    user_percent: f64,
    kernel_percent: f64,
    interrupt_percent: f64,
    interrupts_per_second: Option<u64>,
    context_switches_per_second: Option<u64>,
}

#[derive(Clone, Copy, Debug, Default)]
struct CpuFrequencies {
    average_current_mhz: Option<f64>,
    minimum_current_mhz: Option<f64>,
    maximum_current_mhz: Option<f64>,
    firmware_maximum_mhz: Option<f64>,
}

fn parse_cpu_detail_stat(stat: &str) -> Option<CpuDetailStat> {
    let mut lines = stat.lines();
    let times = parse_cpu_line(lines.next()?)?;
    let mut interrupts = None;
    let mut context_switches = None;
    let mut processor_queue_length = None;
    for line in lines {
        let mut fields = line.split_whitespace();
        let Some(name) = fields.next() else {
            continue;
        };
        match name {
            "intr" => interrupts = fields.next().and_then(|value| value.parse().ok()),
            "ctxt" => context_switches = fields.next().and_then(|value| value.parse().ok()),
            "procs_running" => {
                processor_queue_length = fields.next().and_then(|value| value.parse().ok())
            }
            _ => {}
        }
    }
    Some(CpuDetailStat {
        times,
        interrupts,
        context_switches,
        processor_queue_length,
    })
}

fn cpu_detail_delta(
    baseline: &CpuDetailBaseline,
    current: &CpuDetailStat,
    sampled_at: Instant,
) -> Option<CpuDetailDelta> {
    let percentages = percentages(Some(baseline.times), current.times)?;
    let elapsed = sampled_at.checked_duration_since(baseline.sampled_at)?;
    let elapsed_seconds = elapsed.as_secs_f64();
    if elapsed_seconds <= 0.0 {
        return None;
    }
    Some(CpuDetailDelta {
        busy_percent: percentages.busy,
        user_percent: percentages.user,
        kernel_percent: percentages.kernel,
        interrupt_percent: percentages.interrupt,
        interrupts_per_second: counter_rate(
            baseline.interrupts,
            current.interrupts,
            elapsed_seconds,
        ),
        context_switches_per_second: counter_rate(
            baseline.context_switches,
            current.context_switches,
            elapsed_seconds,
        ),
    })
}

fn counter_rate(previous: Option<u64>, current: Option<u64>, seconds: f64) -> Option<u64> {
    let delta = current?.checked_sub(previous?)?;
    let rate = delta as f64 / seconds;
    (rate.is_finite() && rate >= 0.0 && rate <= u64::MAX as f64).then(|| rate.round() as u64)
}

fn unique_cpuinfo_values(processors: &[HashMap<String, String>], keys: &[&str]) -> Vec<String> {
    processors
        .iter()
        .filter_map(|fields| first_cpuinfo_value(fields, keys))
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect()
}

fn first_cpuinfo_value(fields: &HashMap<String, String>, keys: &[&str]) -> Option<String> {
    keys.iter().find_map(|key| {
        fields
            .get(*key)
            .map(|value| value.trim())
            .filter(|value| !value.is_empty())
            .map(str::to_string)
    })
}

fn read_cpu_frequencies(processors: &[HashMap<String, String>]) -> CpuFrequencies {
    let online = online_logical_processors();
    let mut current = online
        .iter()
        .filter_map(|processor| {
            read_f64_file(format!(
                "/sys/devices/system/cpu/cpu{processor}/cpufreq/scaling_cur_freq"
            ))
            .or_else(|| {
                read_f64_file(format!(
                    "/sys/devices/system/cpu/cpu{processor}/cpufreq/cpuinfo_cur_freq"
                ))
            })
            .map(|khz| khz / 1_000.0)
        })
        .filter(|value| value.is_finite() && *value >= 0.0)
        .collect::<Vec<_>>();
    if current.is_empty() {
        current = processors
            .iter()
            .filter_map(|fields| fields.get("cpu MHz"))
            .filter_map(|value| value.parse::<f64>().ok())
            .filter(|value| value.is_finite() && *value >= 0.0)
            .collect();
    }
    let firmware_maximum_mhz = online
        .iter()
        .filter_map(|processor| {
            read_f64_file(format!(
                "/sys/devices/system/cpu/cpu{processor}/cpufreq/cpuinfo_max_freq"
            ))
            .map(|khz| khz / 1_000.0)
        })
        .filter(|value| value.is_finite() && *value >= 0.0)
        .reduce(f64::max);
    let average_current_mhz =
        (!current.is_empty()).then(|| current.iter().sum::<f64>() / current.len() as f64);
    CpuFrequencies {
        average_current_mhz,
        minimum_current_mhz: current.iter().copied().reduce(f64::min),
        maximum_current_mhz: current.iter().copied().reduce(f64::max),
        firmware_maximum_mhz,
    }
}

fn read_cpu_topology(processor_count_hint: usize) -> CpuTopologySnapshot {
    #[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd)]
    struct CoreKey {
        package: i64,
        die: i64,
        core: i64,
    }

    let online = online_logical_processors();
    let logical_processor_count = u32::try_from(if online.is_empty() {
        processor_count_hint
    } else {
        online.len()
    })
    .ok();
    let mut packages = BTreeSet::new();
    let mut dies = BTreeSet::new();
    let mut modules = BTreeSet::new();
    let mut core_threads = BTreeMap::<CoreKey, u32>::new();
    let mut core_classes = BTreeMap::<CoreKey, u32>::new();
    for processor in online {
        let topology = format!("/sys/devices/system/cpu/cpu{processor}/topology");
        let Some(package) = read_i64_file(format!("{topology}/physical_package_id")) else {
            continue;
        };
        let Some(core) = read_i64_file(format!("{topology}/core_id")) else {
            continue;
        };
        let die = read_i64_file(format!("{topology}/die_id")).unwrap_or(-1);
        let key = CoreKey { package, die, core };
        packages.insert(package);
        if die >= 0 {
            dies.insert((package, die));
        }
        if let Some(module) = read_i64_file(format!("{topology}/cluster_id")) {
            modules.insert((package, die, module));
        }
        *core_threads.entry(key).or_default() += 1;
        if let Some(class) = read_u32_file(format!(
            "/sys/devices/system/cpu/cpu{processor}/cpu_capacity"
        ))
        .or_else(|| read_u32_file(format!("{topology}/core_type")))
        {
            core_classes.entry(key).or_insert(class);
        }
    }
    let physical_core_count = u32::try_from(core_threads.len())
        .ok()
        .filter(|value| *value > 0);
    let thread_counts = core_threads.values().copied().collect::<Vec<_>>();
    let smt_core_count = (!thread_counts.is_empty()).then(|| {
        u32::try_from(thread_counts.iter().filter(|count| **count > 1).count()).unwrap_or(u32::MAX)
    });
    let class_counts = if physical_core_count.is_some() {
        if core_classes.is_empty() {
            vec![CpuCoreClass {
                efficiency_class: None,
                core_count: physical_core_count.unwrap_or_default(),
            }]
        } else {
            let mut counts = BTreeMap::<u32, u32>::new();
            for class in core_classes.values() {
                *counts.entry(*class).or_default() += 1;
            }
            counts
                .into_iter()
                .map(|(efficiency_class, core_count)| CpuCoreClass {
                    efficiency_class: Some(efficiency_class),
                    core_count,
                })
                .collect()
        }
    } else {
        Vec::new()
    };
    CpuTopologySnapshot {
        package_count: u32::try_from(packages.len())
            .ok()
            .filter(|value| *value > 0),
        numa_node_count: fs::read_to_string("/sys/devices/system/node/online")
            .ok()
            .and_then(|value| parse_cpu_list(&value))
            .and_then(|nodes| u32::try_from(nodes.len()).ok()),
        die_count: u32::try_from(dies.len()).ok().filter(|value| *value > 0),
        module_count: u32::try_from(modules.len()).ok().filter(|value| *value > 0),
        physical_core_count,
        logical_processor_count,
        core_classes: class_counts,
        smt_core_count,
        minimum_threads_per_core: thread_counts.iter().copied().min(),
        maximum_threads_per_core: thread_counts.iter().copied().max(),
    }
}

fn topology_package_ids() -> Option<String> {
    let packages = online_logical_processors()
        .into_iter()
        .filter_map(|processor| {
            read_i64_file(format!(
                "/sys/devices/system/cpu/cpu{processor}/topology/physical_package_id"
            ))
        })
        .collect::<BTreeSet<_>>();
    (!packages.is_empty()).then(|| {
        packages
            .into_iter()
            .map(|value| value.to_string())
            .collect::<Vec<_>>()
            .join(", ")
    })
}

fn read_cpu_caches() -> Vec<CpuCache> {
    #[derive(Clone, Debug, Eq, Ord, PartialEq, PartialOrd)]
    struct CacheInstance {
        level: u8,
        kind: u8,
        size_bytes: u64,
        shared_cpu_list: String,
        associativity: Option<u32>,
        line_size_bytes: Option<u32>,
    }

    let mut instances = BTreeSet::new();
    for processor in online_logical_processors() {
        let root = format!("/sys/devices/system/cpu/cpu{processor}/cache");
        let Ok(entries) = fs::read_dir(root) else {
            continue;
        };
        for entry in entries.filter_map(Result::ok) {
            let name = entry.file_name();
            if !name.to_string_lossy().starts_with("index") {
                continue;
            }
            let path = entry.path();
            let Some(level) =
                read_u32_file(path.join("level")).and_then(|value| u8::try_from(value).ok())
            else {
                continue;
            };
            let cache_type = fs::read_to_string(path.join("type")).unwrap_or_default();
            let kind = match cache_type.trim() {
                "Data" => 0,
                "Instruction" => 1,
                "Unified" => 2,
                "Trace" => 3,
                _ => 4,
            };
            let Some(size_bytes) = fs::read_to_string(path.join("size"))
                .ok()
                .and_then(|value| parse_cache_size(&value))
            else {
                continue;
            };
            let shared_cpu_list = fs::read_to_string(path.join("shared_cpu_list"))
                .map(|value| value.trim().to_string())
                .unwrap_or_else(|_| processor.to_string());
            let associativity = read_u32_file(path.join("ways_of_associativity"))
                .filter(|value| *value > 0 && *value != u32::MAX);
            let line_size_bytes =
                read_u32_file(path.join("coherency_line_size")).filter(|value| *value > 0);
            instances.insert(CacheInstance {
                level,
                kind,
                size_bytes,
                shared_cpu_list,
                associativity,
                line_size_bytes,
            });
        }
    }
    let mut groups = BTreeMap::<(u8, u8, u64, Option<u32>, Option<u32>), u32>::new();
    for instance in instances {
        *groups
            .entry((
                instance.level,
                instance.kind,
                instance.size_bytes,
                instance.associativity,
                instance.line_size_bytes,
            ))
            .or_default() += 1;
    }
    groups
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
        .collect()
}

fn parse_cache_size(value: &str) -> Option<u64> {
    let value = value.trim();
    let split = value
        .find(|character: char| !character.is_ascii_digit())
        .unwrap_or(value.len());
    let amount = value[..split].parse::<u64>().ok()?;
    let multiplier = match value[split..].trim().to_ascii_uppercase().as_str() {
        "" | "B" => 1,
        "K" | "KB" => 1_024,
        "M" | "MB" => 1_024 * 1_024,
        "G" | "GB" => 1_024 * 1_024 * 1_024,
        _ => return None,
    };
    amount.checked_mul(multiplier)
}

fn read_f64_file(path: impl AsRef<Path>) -> Option<f64> {
    fs::read_to_string(path).ok()?.trim().parse().ok()
}

fn read_i64_file(path: impl AsRef<Path>) -> Option<i64> {
    fs::read_to_string(path).ok()?.trim().parse().ok()
}

fn read_u32_file(path: impl AsRef<Path>) -> Option<u32> {
    fs::read_to_string(path).ok()?.trim().parse().ok()
}

fn validate_identity(identity: &ProcessIdentity) -> Result<ParsedStat, BackendError> {
    let stat = read_process_stat(identity.pid)
        .map_err(|error| BackendError::io("validate process identity", &error))?;
    if stat.start_time != identity.start_time {
        return Err(BackendError {
            domain: "process_identity".to_string(),
            code: 1,
            context: "validate process identity".to_string(),
            message: "the PID now refers to a different process".to_string(),
        });
    }
    Ok(stat)
}

fn terminate(identity: ProcessIdentity, include_descendants: bool) -> ActionResult {
    if let Err(error) = validate_identity(&identity) {
        return ActionResult::failed(error);
    }
    let identities = if include_descendants {
        match descendant_identities(&identity) {
            Ok(identities) => identities,
            Err(error) => return ActionResult::failed(error),
        }
    } else {
        vec![identity]
    };
    let mut targets = Vec::with_capacity(identities.len());
    for identity in identities {
        match open_pidfd(&identity) {
            Ok(fd) => targets.push(fd),
            Err(error) => return ActionResult::failed(error),
        }
    }
    for target in targets.into_iter().rev() {
        let result = unsafe {
            libc::syscall(
                libc::SYS_pidfd_send_signal,
                target.as_raw_fd(),
                libc::SIGKILL,
                std::ptr::null::<libc::siginfo_t>(),
                0_u32,
            )
        };
        if result != 0 {
            return ActionResult::failed(BackendError::io(
                "pidfd_send_signal",
                &io::Error::last_os_error(),
            ));
        }
    }
    ActionResult::succeeded()
}

fn descendant_identities(root: &ProcessIdentity) -> Result<Vec<ProcessIdentity>, BackendError> {
    let mut stats = HashMap::<u32, ParsedStat>::new();
    for pid in process_ids().map_err(|error| BackendError::io("enumerate process tree", &error))? {
        if let Ok(stat) = read_process_stat(pid) {
            stats.insert(pid, stat);
        }
    }
    if stats
        .get(&root.pid)
        .is_none_or(|stat| stat.start_time != root.start_time)
    {
        return Err(BackendError::internal(
            "enumerate process tree",
            "root process identity changed before tree termination",
        ));
    }
    let mut result = vec![root.clone()];
    let mut frontier = vec![root.pid];
    while let Some(parent) = frontier.pop() {
        for stat in stats.values().filter(|stat| stat.parent_pid == parent) {
            if result.iter().any(|identity| identity.pid == stat.pid) {
                continue;
            }
            result.push(ProcessIdentity {
                pid: stat.pid,
                start_time: stat.start_time,
            });
            frontier.push(stat.pid);
        }
    }
    Ok(result)
}

fn open_pidfd(identity: &ProcessIdentity) -> Result<OwnedFd, BackendError> {
    validate_identity(identity)?;
    let descriptor = unsafe { libc::syscall(libc::SYS_pidfd_open, identity.pid, 0_u32) };
    let descriptor = i32::try_from(descriptor)
        .map_err(|_| BackendError::io("pidfd_open", &io::Error::last_os_error()))?;
    if descriptor < 0 {
        return Err(BackendError::io("pidfd_open", &io::Error::last_os_error()));
    }
    let fd = unsafe { OwnedFd::from_raw_fd(descriptor) };
    let current = read_process_stat(identity.pid)
        .map_err(|error| BackendError::io("revalidate pidfd target", &error))?;
    if current.start_time != identity.start_time {
        return Err(BackendError::internal(
            "revalidate pidfd target",
            "process identity changed while opening pidfd",
        ));
    }
    Ok(fd)
}

fn open_file_location(identity: ProcessIdentity) -> ActionResult {
    if let Err(error) = validate_identity(&identity) {
        return ActionResult::failed(error);
    }
    let executable = match fs::read_link(format!("/proc/{}/exe", identity.pid)) {
        Ok(path) => path,
        Err(error) => {
            return ActionResult::failed(BackendError::io("read process executable", &error));
        }
    };
    let Some(parent) = executable.parent() else {
        return ActionResult::failed(BackendError::internal(
            "open file location",
            "process executable has no parent directory",
        ));
    };
    if let Err(error) = validate_identity(&identity) {
        return ActionResult::failed(error);
    }
    match Command::new("xdg-open").arg(parent).spawn() {
        Ok(_) => ActionResult::succeeded(),
        Err(error) => ActionResult::failed(BackendError::io("spawn xdg-open", &error)),
    }
}

#[cfg(test)]
mod tests {
    use taskmgr_core::{
        ActionRequest, ActionStatus, HISTORY_CAPACITY, HistoryBuffer, ProcessIdentity,
    };

    use super::{
        PID_ONLY_SCHEDULING_UNSUPPORTED, ProcSampler, parse_cache_size, parse_cpu_detail_stat,
        parse_cpu_line, parse_cpu_list, parse_open_file_count, parse_process_stat,
        resize_cpu_histories,
    };

    #[test]
    fn pid_only_scheduling_actions_fail_closed_while_termination_stays_routed() {
        let identity = ProcessIdentity {
            pid: u32::MAX,
            start_time: 1,
        };
        let mut sampler = ProcSampler::new();
        let scheduling_actions = [
            ActionRequest::SetNice {
                identity: identity.clone(),
                nice: 0,
            },
            ActionRequest::SetAffinity {
                identity: identity.clone(),
                logical_processors: vec![0],
            },
        ];

        for action in scheduling_actions {
            let result = sampler.execute(action);
            assert_eq!(result.status, ActionStatus::Unsupported);
            let error = result.error.expect("unsupported action has an error");
            assert_eq!(error.domain, "capability");
            assert_eq!(error.context, "execute_action");
            assert_eq!(error.message, PID_ONLY_SCHEDULING_UNSUPPORTED);
        }

        let termination = sampler.execute(ActionRequest::EndProcess {
            identity,
            include_descendants: false,
        });
        assert_eq!(termination.status, ActionStatus::Failed);
        assert_ne!(termination.status, ActionStatus::Unsupported);
        assert_eq!(
            termination
                .error
                .expect("invalid identity must fail")
                .context,
            "validate process identity"
        );
    }

    #[test]
    fn parses_process_names_containing_spaces_and_parentheses() {
        let text = "42 (worker (one)) S 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22";
        let stat = parse_process_stat(42, text).expect("valid stat");
        assert_eq!(stat.command, "worker (one)");
        assert_eq!(stat.parent_pid, 1);
        assert_eq!(stat.start_time, 19);
    }

    #[test]
    fn calculates_aggregate_cpu_fields_without_fabricating_missing_values() {
        let times = parse_cpu_line("cpu  10 2 3 40 5 6 7 0 0 0").expect("cpu line");
        assert_eq!(times.total, 73);
        assert_eq!(times.idle, 45);
        assert_eq!(times.user, 12);
        assert_eq!(times.kernel, 16);
        assert_eq!(times.interrupt, 13);
    }

    #[test]
    fn guest_ticks_are_not_counted_twice() {
        let times = parse_cpu_line("cpu  110 22 30 40 5 6 7 8 10 2").expect("cpu line");
        assert_eq!(times.user, 120);
        assert_eq!(times.kernel, 43);
        assert_eq!(times.idle, 45);
        assert_eq!(times.total, 216);
    }

    #[test]
    fn blank_stat_lines_do_not_discard_valid_diagnostics() {
        let details = parse_cpu_detail_stat(
            "cpu 10 0 5 20 0 2 1 0 0 0\n\nintr 900\nctxt 700\nprocs_running 3\n",
        )
        .expect("valid /proc/stat fixture");
        assert_eq!(details.interrupts, Some(900));
        assert_eq!(details.context_switches, Some(700));
        assert_eq!(details.processor_queue_length, Some(3));
    }

    #[test]
    fn parses_kernel_cache_capacity_units() {
        assert_eq!(parse_cache_size("48K\n"), Some(48 * 1_024));
        assert_eq!(parse_cache_size("32M"), Some(32 * 1_024 * 1_024));
        assert_eq!(parse_cache_size("invalid"), None);
    }

    #[test]
    fn parses_in_use_file_handles_without_counting_unused_capacity() {
        assert_eq!(parse_open_file_count("1200 80 922337\n"), Some(1120));
        assert_eq!(parse_open_file_count("1200 0 922337\n"), Some(1200));
        assert_eq!(parse_open_file_count("invalid"), None);
    }

    #[test]
    fn processor_count_changes_reset_per_cpu_identity_history() {
        let mut baselines = vec![None, None];
        let mut histories = vec![HistoryBuffer::new(HISTORY_CAPACITY); 2];
        let mut kernel_histories = vec![HistoryBuffer::new(HISTORY_CAPACITY); 2];
        histories[0].push(50.0);
        kernel_histories[0].push(20.0);

        resize_cpu_histories(&mut baselines, &mut histories, &mut kernel_histories, 3);

        assert_eq!(baselines.len(), 3);
        assert!(histories.iter().all(HistoryBuffer::is_empty));
        assert!(kernel_histories.iter().all(HistoryBuffer::is_empty));
    }

    #[test]
    fn parses_sparse_cpu_lists_used_by_proc_status_and_sysfs() {
        assert_eq!(parse_cpu_list("0-2,4,7-8\n"), Some(vec![0, 1, 2, 4, 7, 8]));
        assert_eq!(parse_cpu_list("4-2"), None);
        assert_eq!(parse_cpu_list(""), None);
    }
}
