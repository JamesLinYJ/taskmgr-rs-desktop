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
//   参考标准:   proc(5)；proc_pid_stat(5)；pidfd_open(2)；pidfd_send_signal(2)；sched_setaffinity(2)；setpriority(2)
// --------------------------------------------------------------------------

//! 从 `/proc` 和 CPU sysfs 构建进程、性能与 CPU 快照。
//!
//! 危险操作先校验 PID 与 starttime；终止操作使用 pidfd，绝不降级为 PID-only kill。

use std::collections::{HashMap, HashSet};
use std::fs;
use std::io;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::process::Command;
use std::time::Instant;

use taskmgr_core::{
    ActionRequest, ActionResult, BackendError, CpuData, CpuMetricGroup, HISTORY_CAPACITY,
    HistoryBuffer, MetricValue, PerformanceData, ProcessIdentity, ProcessRow, ProcessesData,
    SnapshotData,
};

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
    kernel: u64,
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
        let kernel_percent = self.performance_cpu_baseline.and_then(|baseline| {
            let total = aggregate.total.checked_sub(baseline.total)?;
            if total == 0 {
                return None;
            }
            Some(aggregate.kernel.saturating_sub(baseline.kernel) as f64 * 100.0 / total as f64)
        });
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
            per_cpu.len(),
        );
        for (index, current) in per_cpu.into_iter().enumerate() {
            if let Some(value) = utilization(self.per_cpu_baselines[index], current) {
                self.per_cpu_histories[index].push(value);
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
        let (process_count, thread_count, fd_count) = count_process_totals();

        Ok(SnapshotData::Performance(Box::new(PerformanceData {
            process_count: Some(process_count),
            thread_count: Some(thread_count),
            handle_count: Some(fd_count),
            memory_total_kib: total,
            memory_available_kib: available,
            file_cache_kib: sum_keys(&memory, &["Cached", "SReclaimable"]),
            commit_total_kib: memory.get("Committed_AS").copied(),
            commit_limit_kib: memory.get("CommitLimit").copied(),
            commit_peak_kib: None,
            kernel_total_kib: sum_keys(&memory, &["Slab", "KernelStack", "PageTables"]),
            kernel_paged_kib: None,
            kernel_non_paged_kib: None,
            cpu_percent,
            memory_percent,
            cpu_history: self.cpu_history.snapshot(),
            kernel_history: self.kernel_history.snapshot(),
            memory_history: self.memory_history.snapshot(),
            logical_cpu_histories: self
                .per_cpu_histories
                .iter()
                .map(HistoryBuffer::snapshot)
                .collect(),
        })))
    }

    pub fn sample_cpu(&mut self) -> Result<SnapshotData, BackendError> {
        let cpuinfo = fs::read_to_string("/proc/cpuinfo")
            .map_err(|error| BackendError::io("read /proc/cpuinfo", &error))?;
        let first = cpuinfo.split("\n\n").next().unwrap_or_default();
        let fields = key_value_lines(first);
        let logical = cpuinfo
            .lines()
            .filter(|line| line.starts_with("processor"))
            .count() as u64;
        let cores = fields
            .get("cpu cores")
            .and_then(|value| value.parse::<u64>().ok());
        let siblings = fields
            .get("siblings")
            .and_then(|value| value.parse::<u64>().ok());
        let current =
            read_cpu_times().map_err(|error| BackendError::io("read /proc/stat", &error))?;
        let utilization_percent = utilization(self.performance_cpu_baseline, current);
        let uptime = fs::read_to_string("/proc/uptime")
            .ok()
            .and_then(|text| text.split_whitespace().next()?.parse::<f64>().ok());
        let frequency = fields.get("cpu MHz").cloned();
        let model = fields
            .get("model name")
            .or_else(|| fields.get("Processor"))
            .cloned();
        let flags = fields
            .get("flags")
            .or_else(|| fields.get("Features"))
            .cloned();
        let groups = vec![
            CpuMetricGroup {
                title: "Current State".to_string(),
                metrics: vec![
                    metric(
                        "Average Frequency",
                        frequency.map(|value| format!("{value} MHz")),
                    ),
                    metric("Uptime", uptime.map(format_duration)),
                    metric("Processor Queue", read_load_average()),
                ],
            },
            CpuMetricGroup {
                title: "Topology and Features".to_string(),
                metrics: vec![
                    metric("Physical Cores", cores.map(|value| value.to_string())),
                    metric("Logical Processors", Some(logical.to_string())),
                    metric(
                        "Threads/Core",
                        siblings.zip(cores).and_then(|(siblings, cores)| {
                            (cores > 0).then(|| (siblings / cores).to_string())
                        }),
                    ),
                    metric(
                        "Virtualization",
                        flags.as_ref().map(|flags| {
                            if flags
                                .split_whitespace()
                                .any(|flag| matches!(flag, "vmx" | "svm"))
                            {
                                "Yes"
                            } else {
                                "No"
                            }
                            .to_string()
                        }),
                    ),
                ],
            },
            CpuMetricGroup {
                title: "Hardware and Cache".to_string(),
                metrics: vec![
                    metric("Manufacturer", fields.get("vendor_id").cloned()),
                    metric(
                        "Architecture / Width",
                        Some(format!("{} / {}-bit", std::env::consts::ARCH, usize::BITS)),
                    ),
                    metric("ISA Features", flags.map(|value| summarize_flags(&value))),
                    metric("Firmware Max Frequency", read_max_frequency()),
                ],
            },
        ];
        Ok(SnapshotData::Cpu(CpuData {
            model,
            status: None,
            utilization_percent,
            history: self.cpu_history.snapshot(),
            groups,
        }))
    }

    pub fn execute(&mut self, request: ActionRequest) -> ActionResult {
        match request {
            ActionRequest::EndProcess {
                identity,
                include_descendants,
            } => terminate(identity, include_descendants),
            ActionRequest::SetNice { identity, nice } => set_nice(identity, nice),
            ActionRequest::SetAffinity {
                identity,
                logical_processors,
            } => set_affinity(identity, &logical_processors),
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
    let total = values.iter().copied().sum();
    let idle = values
        .get(3)
        .copied()
        .unwrap_or(0)
        .saturating_add(values.get(4).copied().unwrap_or(0));
    let kernel = values
        .get(2)
        .copied()
        .unwrap_or(0)
        .saturating_add(values.get(5).copied().unwrap_or(0))
        .saturating_add(values.get(6).copied().unwrap_or(0));
    Some(CpuTimes {
        total,
        idle,
        kernel,
    })
}

fn utilization(previous: Option<CpuTimes>, current: CpuTimes) -> Option<f64> {
    let previous = previous?;
    let total = current.total.checked_sub(previous.total)?;
    let idle = current.idle.checked_sub(previous.idle)?;
    (total > 0).then_some(total.saturating_sub(idle) as f64 * 100.0 / total as f64)
}

fn resize_cpu_histories(
    baselines: &mut Vec<Option<CpuTimes>>,
    histories: &mut Vec<HistoryBuffer>,
    length: usize,
) {
    baselines.resize(length, None);
    histories.resize_with(length, || HistoryBuffer::new(HISTORY_CAPACITY));
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

fn count_process_totals() -> (u64, u64, u64) {
    let mut processes = 0_u64;
    let mut threads = 0_u64;
    let mut fds = 0_u64;
    if let Ok(pids) = process_ids() {
        for pid in pids {
            if let Ok(stat) = read_process_stat(pid) {
                processes += 1;
                threads = threads.saturating_add(stat.threads);
                if let Ok(entries) = fs::read_dir(format!("/proc/{pid}/fd")) {
                    fds = fds.saturating_add(entries.filter_map(Result::ok).count() as u64);
                }
            }
        }
    }
    (processes, threads, fds)
}

fn signed_delta(current: u64, previous: u64) -> i64 {
    if current >= previous {
        i64::try_from(current - previous).unwrap_or(i64::MAX)
    } else {
        -i64::try_from(previous - current).unwrap_or(i64::MAX)
    }
}

fn metric(label: &str, value: Option<String>) -> MetricValue {
    MetricValue {
        label: label.to_string(),
        value,
    }
}

fn format_duration(seconds: f64) -> String {
    let seconds = seconds.max(0.0) as u64;
    let days = seconds / 86_400;
    let hours = seconds % 86_400 / 3_600;
    let minutes = seconds % 3_600 / 60;
    let seconds = seconds % 60;
    format!("{days}:{hours:02}:{minutes:02}:{seconds:02}")
}

fn read_load_average() -> Option<String> {
    fs::read_to_string("/proc/loadavg")
        .ok()
        .and_then(|text| text.split_whitespace().next().map(str::to_string))
}

fn read_max_frequency() -> Option<String> {
    fs::read_to_string("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq")
        .ok()
        .and_then(|text| text.trim().parse::<u64>().ok())
        .map(|khz| format!("{:.2} GHz", khz as f64 / 1_000_000.0))
}

fn summarize_flags(flags: &str) -> String {
    const IMPORTANT: [&str; 12] = [
        "sse2", "sse4_1", "sse4_2", "avx", "avx2", "avx512f", "aes", "sha_ni", "vmx", "svm",
        "neon", "sve",
    ];
    let present = flags.split_whitespace().collect::<HashSet<_>>();
    IMPORTANT
        .into_iter()
        .filter(|flag| present.contains(flag))
        .collect::<Vec<_>>()
        .join(", ")
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

fn set_nice(identity: ProcessIdentity, nice: i32) -> ActionResult {
    if !(-20..=19).contains(&nice) {
        return ActionResult::failed(BackendError::internal(
            "setpriority",
            "nice value must be between -20 and 19",
        ));
    }
    if let Err(error) = validate_identity(&identity) {
        return ActionResult::failed(error);
    }
    let result = unsafe { libc::setpriority(libc::PRIO_PROCESS, identity.pid, nice) };
    if result != 0 {
        return ActionResult::failed(BackendError::io("setpriority", &io::Error::last_os_error()));
    }
    match validate_identity(&identity) {
        Ok(_) => ActionResult::succeeded(),
        Err(error) => ActionResult::failed(error),
    }
}

fn set_affinity(identity: ProcessIdentity, processors: &[u32]) -> ActionResult {
    if processors.is_empty() {
        return ActionResult::failed(BackendError::internal(
            "sched_setaffinity",
            "at least one logical processor must remain selected",
        ));
    }
    if let Err(error) = validate_identity(&identity) {
        return ActionResult::failed(error);
    }
    let mut set = unsafe { std::mem::zeroed::<libc::cpu_set_t>() };
    unsafe { libc::CPU_ZERO(&mut set) };
    for &processor in processors {
        let Ok(processor) = usize::try_from(processor) else {
            return ActionResult::failed(BackendError::internal(
                "sched_setaffinity",
                "logical processor index is out of range",
            ));
        };
        if processor >= libc::CPU_SETSIZE as usize {
            return ActionResult::failed(BackendError::unsupported(
                "sched_setaffinity",
                "logical processor index exceeds cpu_set_t capacity",
            ));
        }
        unsafe { libc::CPU_SET(processor, &mut set) };
    }
    let result = unsafe {
        libc::sched_setaffinity(
            identity.pid as libc::pid_t,
            std::mem::size_of::<libc::cpu_set_t>(),
            &set,
        )
    };
    if result != 0 {
        return ActionResult::failed(BackendError::io(
            "sched_setaffinity",
            &io::Error::last_os_error(),
        ));
    }
    match validate_identity(&identity) {
        Ok(_) => ActionResult::succeeded(),
        Err(error) => ActionResult::failed(error),
    }
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
    use super::{parse_cpu_line, parse_cpu_list, parse_process_stat};

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
        assert_eq!(times.kernel, 16);
    }

    #[test]
    fn parses_sparse_cpu_lists_used_by_proc_status_and_sysfs() {
        assert_eq!(parse_cpu_list("0-2,4,7-8\n"), Some(vec![0, 1, 2, 4, 7, 8]));
        assert_eq!(parse_cpu_list("4-2"), None);
        assert_eq!(parse_cpu_list(""), None);
    }
}
