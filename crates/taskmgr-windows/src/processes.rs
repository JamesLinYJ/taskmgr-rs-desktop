// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows 进程采集与身份安全动作
//
//   文件:       crates/taskmgr-windows/src/processes.rs
//
//   日期:       2026年08月20日
//   环境:       Windows x64/ARM64 API；Rust 1.97.1；x86_64-pc-windows-gnu 交叉检查
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Tool Help；Process Status API；Access Token API；Win32 process/thread API
// --------------------------------------------------------------------------

//! 使用 Tool Help 和 SystemProcessInformation 建立进程父子视图，再通过进程句柄读取动态指标。
//!
//! 跨采样缓存只以 `PID + FILETIME 创建时间` 为键。所有破坏性动作重新打开句柄并验证
//! 创建时间；结束进程树会先打开和验证整组目标，再按叶子优先顺序执行。

use std::collections::{HashMap, HashSet, VecDeque};
use std::ffi::c_void;
use std::mem::{align_of, size_of};
use std::process::Command;
use std::ptr::{null, null_mut};
use std::slice;
use std::time::{Duration, Instant};

use taskmgr_core::{
    ActionRequest, ActionResult, BackendError, ProcessIdentity, ProcessPriority, ProcessRow,
    ProcessesData, SnapshotData,
};
use windows_sys::Win32::Foundation::{
    ERROR_INSUFFICIENT_BUFFER, ERROR_MORE_DATA, ERROR_NO_MORE_FILES, FILETIME, GetLastError, HANDLE,
};
use windows_sys::Win32::Security::{
    GetLengthSid, GetTokenInformation, IsValidSid, LookupAccountSidW, SID_NAME_USE, TOKEN_QUERY,
    TOKEN_USER, TokenUser,
};
use windows_sys::Win32::System::Diagnostics::ToolHelp::{
    CreateToolhelp32Snapshot, PROCESSENTRY32W, Process32FirstW, Process32NextW, TH32CS_SNAPPROCESS,
};
use windows_sys::Win32::System::ProcessStatus::{
    K32GetProcessMemoryInfo, PROCESS_MEMORY_COUNTERS, PROCESS_MEMORY_COUNTERS_EX,
};
use windows_sys::Win32::System::RemoteDesktop::{
    ProcessIdToSessionId, WTS_CURRENT_SERVER_HANDLE, WTS_PROCESS_INFOW, WTSEnumerateProcessesW,
    WTSFreeMemory,
};
use windows_sys::Win32::System::Services::{
    CloseServiceHandle, ENUM_SERVICE_STATUS_PROCESSW, EnumServicesStatusExW, OpenSCManagerW,
    OpenServiceW, QUERY_SERVICE_CONFIGW, QueryServiceConfigW, SC_ENUM_PROCESS_INFO, SC_HANDLE,
    SC_MANAGER_ENUMERATE_SERVICE, SERVICE_QUERY_CONFIG, SERVICE_STATE_ALL, SERVICE_WIN32,
};
use windows_sys::Win32::System::Threading::{
    ABOVE_NORMAL_PRIORITY_CLASS, BELOW_NORMAL_PRIORITY_CLASS, GetActiveProcessorCount,
    GetPriorityClass, GetProcessAffinityMask, GetProcessHandleCount, GetProcessTimes,
    HIGH_PRIORITY_CLASS, IDLE_PRIORITY_CLASS, NORMAL_PRIORITY_CLASS, OpenProcess, OpenProcessToken,
    PROCESS_QUERY_INFORMATION, PROCESS_QUERY_LIMITED_INFORMATION, PROCESS_SET_INFORMATION,
    PROCESS_TERMINATE, PROCESS_VM_READ, QueryFullProcessImageNameW, REALTIME_PRIORITY_CLASS,
    SetPriorityClass, SetProcessAffinityMask, TerminateProcess,
};
use windows_sys::Win32::System::WindowsProgramming::SYSTEM_PROCESS_INFORMATION;

use crate::applications::{process_needs_32_bit_suffix_handle, query_identity_from_handle};
use crate::native::{
    OwnedHandle, error_from_code, filetime_to_u64, last_error, wide_slice_to_string,
};

const SYSTEM_PROCESS_INFORMATION_CLASS: i32 = 5;
const STATUS_INFO_LENGTH_MISMATCH: i32 = 0xC000_0004_u32 as i32;
const STATUS_BUFFER_TOO_SMALL: i32 = 0xC000_0023_u32 as i32;
const MAX_SYSTEM_PROCESS_BUFFER_BYTES: usize = 128 * 1024 * 1024;
const SERVICE_ACCOUNT_REFRESH_INTERVAL: Duration = Duration::from_secs(30);

#[link(name = "ntdll")]
unsafe extern "system" {
    fn NtQuerySystemInformation(
        system_information_class: i32,
        system_information: *mut c_void,
        system_information_length: u32,
        return_length: *mut u32,
    ) -> i32;
}

#[derive(Clone, Copy)]
struct PreviousProcessSample {
    cpu_100ns: Option<u64>,
    memory_kib: Option<u64>,
    page_faults: Option<u64>,
}

#[derive(Clone)]
struct ProcessDescriptor {
    pid: u32,
    parent_pid: u32,
    image_name: String,
    thread_count: u32,
    base_priority: i32,
}

#[derive(Clone)]
struct SystemProcessMetrics {
    pid: u32,
    parent_pid: u32,
    image_name: String,
    start_time: u64,
    cpu_100ns: u64,
    memory_kib: u64,
    page_faults: u64,
    virtual_memory_kib: u64,
    paged_pool_kib: u64,
    non_paged_pool_kib: u64,
    handle_count: u64,
    thread_count: u64,
    session_id: u32,
    base_priority: i32,
}

#[derive(Clone)]
struct ProcessTreeNode {
    identity: ProcessIdentity,
    parent_pid: u32,
}

struct WtsProcessIdentity {
    image_name_lower: String,
    user_name: Option<String>,
    session_id: u32,
}

#[derive(Clone, Default)]
struct ProcessStaticMetadata {
    show_32_bit_suffix: Option<bool>,
    executable_path: Option<String>,
    user_name: Option<String>,
    session_id: Option<u32>,
}

#[derive(Clone)]
struct CachedAccountName {
    name: String,
    last_used: u64,
}

#[derive(Default)]
struct AccountNameCache {
    entries: HashMap<Vec<u8>, CachedAccountName>,
    generation: u64,
}

impl AccountNameCache {
    const MAX_ENTRIES: usize = 256;

    fn begin_refresh(&mut self) {
        self.generation = self.generation.wrapping_add(1);
    }

    fn get(&mut self, sid: &[u8]) -> Option<String> {
        let entry = self.entries.get_mut(sid)?;
        entry.last_used = self.generation;
        Some(entry.name.clone())
    }

    fn insert(&mut self, sid: Vec<u8>, name: String) {
        if !self.entries.contains_key(sid.as_slice())
            && self.entries.len() >= Self::MAX_ENTRIES
            && let Some(oldest) = self
                .entries
                .iter()
                .min_by_key(|(_, entry)| entry.last_used)
                .map(|(sid, _)| sid.clone())
        {
            self.entries.remove(oldest.as_slice());
        }
        self.entries.insert(
            sid,
            CachedAccountName {
                name,
                last_used: self.generation,
            },
        );
    }
}

pub(crate) struct ProcessSampler {
    previous: HashMap<ProcessIdentity, PreviousProcessSample>,
    static_metadata: HashMap<ProcessIdentity, ProcessStaticMetadata>,
    account_names: AccountNameCache,
    service_accounts: HashMap<u32, String>,
    service_accounts_at: Option<Instant>,
    previous_at: Option<Instant>,
}

impl ProcessSampler {
    pub(crate) fn new() -> Self {
        Self {
            previous: HashMap::new(),
            static_metadata: HashMap::new(),
            account_names: AccountNameCache::default(),
            service_accounts: HashMap::new(),
            service_accounts_at: None,
            previous_at: None,
        }
    }

    pub(crate) fn sample(&mut self) -> Result<SnapshotData, BackendError> {
        let system_processes = query_system_process_metrics().unwrap_or_default();
        let mut descriptors = enumerate_processes()?;
        merge_system_process_descriptors(&mut descriptors, &system_processes);
        self.account_names.begin_refresh();
        let wts_identities =
            enumerate_wts_process_identities(&mut self.account_names).unwrap_or_default();
        let now = Instant::now();
        if self.service_accounts_at.is_none_or(|previous| {
            now.saturating_duration_since(previous) >= SERVICE_ACCOUNT_REFRESH_INTERVAL
        }) && let Ok(accounts) = query_service_process_accounts()
        {
            self.service_accounts = accounts;
            self.service_accounts_at = Some(now);
        }
        let elapsed_100ns = self
            .previous_at
            .map(|previous| now.saturating_duration_since(previous).as_secs_f64() * 10_000_000.0)
            .filter(|elapsed| *elapsed > 0.0);
        // SAFETY: GetActiveProcessorCount accepts the documented all-groups sentinel.
        let logical_processors = unsafe {
            GetActiveProcessorCount(windows_sys::Win32::System::Threading::ALL_PROCESSOR_GROUPS)
        }
        .max(1);
        let mut next = HashMap::with_capacity(descriptors.len());
        let mut seen_identities = HashSet::with_capacity(descriptors.len());
        let mut rows = Vec::with_capacity(descriptors.len());
        for descriptor in descriptors {
            let system_metrics = system_processes.get(&descriptor.pid);
            let account_hint = self.service_accounts.get(&descriptor.pid);
            let sources = ProcessSampleSources {
                system_metrics,
                wts_identity: wts_identities.get(&descriptor.pid),
                account_hint: account_hint.map(String::as_str),
                static_metadata: &self.static_metadata,
            };
            let sampled = sample_process(&descriptor, &sources, &mut self.account_names);
            let previous = self.previous.get(&sampled.row.identity).copied();
            let cpu_percent = previous.zip(elapsed_100ns).and_then(|(previous, elapsed)| {
                previous
                    .cpu_100ns
                    .zip(sampled.cpu_100ns)
                    .map(|(previous, current)| {
                        let delta = current.saturating_sub(previous) as f64;
                        (delta * 100.0 / elapsed / f64::from(logical_processors)).clamp(0.0, 100.0)
                    })
            });
            let memory_delta_kib = previous.and_then(|previous| {
                sampled
                    .memory_kib
                    .zip(previous.memory_kib)
                    .map(|(current, previous)| signed_delta(current, previous))
            });
            let page_faults_delta = previous.and_then(|previous| {
                sampled
                    .page_faults
                    .zip(previous.page_faults)
                    .map(|(current, previous)| signed_delta(current, previous))
            });
            let mut row = sampled.row;
            row.cpu_percent = Some(cpu_percent.unwrap_or(0.0));
            row.memory_delta_kib = Some(memory_delta_kib.unwrap_or(0));
            row.page_faults_delta = Some(page_faults_delta.unwrap_or(0));
            if row.identity.start_time != 0 {
                seen_identities.insert(row.identity.clone());
                if let Some(metadata) = sampled.static_metadata {
                    self.static_metadata.insert(row.identity.clone(), metadata);
                }
                next.insert(
                    row.identity.clone(),
                    PreviousProcessSample {
                        cpu_100ns: sampled.cpu_100ns,
                        memory_kib: sampled.memory_kib,
                        page_faults: sampled.page_faults,
                    },
                );
            }
            rows.push(row);
        }
        // The archived process page opens in PID order. This also keeps boot/system processes at
        // the top instead of burying them below alphabetically sorted user applications.
        rows.sort_by_key(|row| row.identity.pid);
        self.previous = next;
        self.static_metadata
            .retain(|identity, _| seen_identities.contains(identity));
        self.previous_at = Some(now);
        Ok(SnapshotData::Processes(ProcessesData { rows }))
    }

    pub(crate) fn execute(&mut self, request: ActionRequest) -> ActionResult {
        let outcome = match request {
            ActionRequest::EndProcess {
                identity,
                include_descendants,
            } => terminate(&identity, include_descendants),
            ActionRequest::SetPriority { identity, priority } => set_priority(&identity, priority),
            ActionRequest::SetAffinity {
                identity,
                logical_processors,
            } => set_affinity(&identity, &logical_processors),
            ActionRequest::OpenFileLocation { identity } => open_file_location(&identity),
            ActionRequest::SetNice { .. } => {
                return ActionResult::unsupported("Windows uses priority classes instead of nice");
            }
            _ => {
                return ActionResult::unsupported(
                    "the requested operation is not a process action",
                );
            }
        };
        match outcome {
            Ok(()) => ActionResult::succeeded(),
            Err(error) => ActionResult::failed(error),
        }
    }
}

struct SampledProcess {
    row: ProcessRow,
    cpu_100ns: Option<u64>,
    memory_kib: Option<u64>,
    page_faults: Option<u64>,
    static_metadata: Option<ProcessStaticMetadata>,
}

struct ProcessSampleSources<'a> {
    system_metrics: Option<&'a SystemProcessMetrics>,
    wts_identity: Option<&'a WtsProcessIdentity>,
    account_hint: Option<&'a str>,
    static_metadata: &'a HashMap<ProcessIdentity, ProcessStaticMetadata>,
}

fn sample_process(
    descriptor: &ProcessDescriptor,
    sources: &ProcessSampleSources<'_>,
    account_names: &mut AccountNameCache,
) -> SampledProcess {
    if descriptor.pid == 0 {
        return fallback_process(descriptor, sources);
    }
    let full_access = PROCESS_QUERY_INFORMATION | PROCESS_VM_READ;
    // SAFETY: OpenProcess receives scalar arguments and returns a fresh owned handle on success.
    let raw_full = unsafe { OpenProcess(full_access, 0, descriptor.pid) };
    // SAFETY: a non-null result is transferred into its unique owner.
    let full_handle = unsafe { OwnedHandle::from_raw(raw_full) };
    let handle = if let Some(handle) = full_handle.as_ref() {
        handle
    } else {
        // SAFETY: same ownership rule as above, using the least access needed for identity/path.
        let raw_limited =
            unsafe { OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, descriptor.pid) };
        // SAFETY: a non-null result is transferred into its unique owner.
        let Some(limited_handle) = (unsafe { OwnedHandle::from_raw(raw_limited) }) else {
            return fallback_process(descriptor, sources);
        };
        return sample_process_with_handle(
            descriptor,
            &limited_handle,
            false,
            sources,
            account_names,
        );
    };
    sample_process_with_handle(descriptor, handle, true, sources, account_names)
}

fn sample_process_with_handle(
    descriptor: &ProcessDescriptor,
    handle: &OwnedHandle,
    can_read_memory: bool,
    sources: &ProcessSampleSources<'_>,
    account_names: &mut AccountNameCache,
) -> SampledProcess {
    let system_metrics = sources.system_metrics;
    let wts_identity = sources.wts_identity;
    let account_hint = sources.account_hint;
    let (identity, mut row_error) =
        match query_identity_from_handle(descriptor.pid, handle.as_raw()) {
            Ok(identity) => (identity, None),
            Err(error) => (
                ProcessIdentity {
                    pid: descriptor.pid,
                    start_time: system_metrics.map_or(0, |metrics| metrics.start_time),
                },
                Some(error),
            ),
        };
    let system_metrics = system_metrics.filter(|metrics| {
        identity.start_time == 0
            || metrics.start_time == 0
            || identity.start_time == metrics.start_time
    });
    let cached_metadata = (identity.start_time != 0)
        .then(|| sources.static_metadata.get(&identity))
        .flatten();
    let handle_cpu = query_cpu_time(handle.as_raw()).ok();
    let cpu_100ns = handle_cpu
        .map(|(raw, _)| raw)
        .or_else(|| system_metrics.map(|metrics| metrics.cpu_100ns));
    let memory = can_read_memory
        .then(|| query_memory(handle.as_raw()))
        .flatten();
    let memory_kib = memory
        .map(|value| value.WorkingSetSize as u64 / 1024)
        .or_else(|| system_metrics.map(|metrics| metrics.memory_kib));
    let page_faults = memory
        .map(|value| u64::from(value.PageFaultCount))
        .or_else(|| system_metrics.map(|metrics| metrics.page_faults));
    let virtual_memory_kib = system_metrics
        .map(|metrics| metrics.virtual_memory_kib)
        .or_else(|| memory.map(|value| value.PrivateUsage as u64 / 1024));
    let paged_pool_kib = memory
        .map(|value| value.QuotaPagedPoolUsage as u64 / 1024)
        .or_else(|| system_metrics.map(|metrics| metrics.paged_pool_kib));
    let non_paged_pool_kib = memory
        .map(|value| value.QuotaNonPagedPoolUsage as u64 / 1024)
        .or_else(|| system_metrics.map(|metrics| metrics.non_paged_pool_kib));
    let mut handle_count = 0u32;
    let handle_count = (unsafe { GetProcessHandleCount(handle.as_raw(), &mut handle_count) } != 0)
        .then_some(u64::from(handle_count))
        .or_else(|| system_metrics.map(|metrics| metrics.handle_count));
    let priority_class = unsafe { GetPriorityClass(handle.as_raw()) };
    let base_priority = if priority_class == 0 {
        Some(descriptor.base_priority.to_string())
    } else {
        Some(priority_name(priority_class).to_string())
    };
    let mut queried_session_id = 0u32;
    let session_id = cached_metadata
        .and_then(|metadata| metadata.session_id)
        .or_else(|| {
            (unsafe { ProcessIdToSessionId(descriptor.pid, &mut queried_session_id) } != 0)
                .then_some(queried_session_id)
        })
        .or_else(|| matching_wts_identity(descriptor, wts_identity).map(|value| value.session_id))
        .or_else(|| system_metrics.map(|metrics| metrics.session_id));
    let resolved_user_name = cached_metadata
        .and_then(|metadata| metadata.user_name.clone())
        .or_else(|| query_user_name(handle.as_raw(), account_names))
        .or_else(|| {
            matching_wts_identity(descriptor, wts_identity)
                .and_then(|value| value.user_name.clone())
        });
    let user_name = resolved_user_name
        .clone()
        .or_else(|| account_hint.map(str::to_string));
    let show_32_bit_suffix = if identity.start_time == 0 {
        None
    } else if let Some(value) = cached_metadata.and_then(|metadata| metadata.show_32_bit_suffix) {
        Some(value)
    } else {
        match process_needs_32_bit_suffix_handle(handle.as_raw()) {
            Ok(value) => Some(value),
            Err(error) => {
                row_error.get_or_insert(error);
                None
            }
        }
    };
    let executable_path = cached_metadata
        .and_then(|metadata| metadata.executable_path.clone())
        .or_else(|| query_executable_path(handle.as_raw()));
    let affinity = query_affinity(handle.as_raw());
    let collected_static_metadata = (identity.start_time != 0).then(|| ProcessStaticMetadata {
        show_32_bit_suffix,
        executable_path: executable_path.clone(),
        user_name: resolved_user_name,
        session_id,
    });
    SampledProcess {
        row: ProcessRow {
            identity,
            parent_pid: (descriptor.parent_pid != 0).then_some(descriptor.parent_pid),
            image_name: descriptor.image_name.clone(),
            show_32_bit_suffix,
            executable_path,
            user_name,
            session_id: Some(session_id.unwrap_or(0)),
            cpu_percent: None,
            cpu_time_millis: Some(cpu_100ns.unwrap_or(0) / 10_000),
            memory_kib: Some(memory_kib.unwrap_or(0)),
            memory_delta_kib: None,
            page_faults: Some(page_faults.unwrap_or(0)),
            page_faults_delta: None,
            virtual_memory_kib: Some(virtual_memory_kib.unwrap_or(0)),
            paged_pool_kib: Some(paged_pool_kib.unwrap_or(0)),
            non_paged_pool_kib: Some(non_paged_pool_kib.unwrap_or(0)),
            base_priority,
            handle_count: Some(handle_count.unwrap_or(0)),
            thread_count: Some(
                system_metrics.map_or(u64::from(descriptor.thread_count), |metrics| {
                    metrics.thread_count
                }),
            ),
            file_descriptor_count: None,
            nice: None,
            cgroup: None,
            affinity,
            row_error,
        },
        cpu_100ns,
        memory_kib,
        page_faults,
        static_metadata: collected_static_metadata,
    }
}

fn fallback_process(
    descriptor: &ProcessDescriptor,
    sources: &ProcessSampleSources<'_>,
) -> SampledProcess {
    let system_metrics = sources.system_metrics;
    let account_hint = sources.account_hint;
    let wts_identity = sources.wts_identity;
    let wts_identity = matching_wts_identity(descriptor, wts_identity);
    let cpu_100ns = system_metrics.map(|metrics| metrics.cpu_100ns);
    let memory_kib = system_metrics.map(|metrics| metrics.memory_kib);
    let page_faults = system_metrics.map(|metrics| metrics.page_faults);
    let identity = ProcessIdentity {
        pid: descriptor.pid,
        start_time: system_metrics.map_or(0, |metrics| metrics.start_time),
    };
    let cached_metadata = (identity.start_time != 0)
        .then(|| sources.static_metadata.get(&identity))
        .flatten();
    let resolved_user_name = cached_metadata
        .and_then(|metadata| metadata.user_name.clone())
        .or_else(|| wts_identity.and_then(|value| value.user_name.clone()));
    let session_id = cached_metadata
        .and_then(|metadata| metadata.session_id)
        .or_else(|| wts_identity.map(|identity| identity.session_id))
        .or_else(|| system_metrics.map(|metrics| metrics.session_id));
    let show_32_bit_suffix = cached_metadata.and_then(|metadata| metadata.show_32_bit_suffix);
    let executable_path = cached_metadata.and_then(|metadata| metadata.executable_path.clone());
    let collected_static_metadata = (identity.start_time != 0).then(|| ProcessStaticMetadata {
        show_32_bit_suffix,
        executable_path: executable_path.clone(),
        user_name: resolved_user_name.clone(),
        session_id,
    });
    SampledProcess {
        row: ProcessRow {
            identity,
            parent_pid: (descriptor.parent_pid != 0).then_some(descriptor.parent_pid),
            image_name: descriptor.image_name.clone(),
            show_32_bit_suffix,
            executable_path,
            user_name: resolved_user_name.or_else(|| account_hint.map(str::to_string)),
            session_id: Some(if descriptor.pid == 0 {
                0
            } else {
                session_id.unwrap_or(0)
            }),
            cpu_percent: None,
            cpu_time_millis: Some(cpu_100ns.unwrap_or(0) / 10_000),
            memory_kib: Some(memory_kib.unwrap_or(0)),
            memory_delta_kib: None,
            page_faults: Some(page_faults.unwrap_or(0)),
            page_faults_delta: None,
            virtual_memory_kib: Some(
                system_metrics.map_or(0, |metrics| metrics.virtual_memory_kib),
            ),
            paged_pool_kib: Some(system_metrics.map_or(0, |metrics| metrics.paged_pool_kib)),
            non_paged_pool_kib: Some(
                system_metrics.map_or(0, |metrics| metrics.non_paged_pool_kib),
            ),
            base_priority: Some(descriptor.base_priority.to_string()),
            handle_count: Some(system_metrics.map_or(0, |metrics| metrics.handle_count)),
            thread_count: Some(
                system_metrics.map_or(u64::from(descriptor.thread_count), |metrics| {
                    metrics.thread_count
                }),
            ),
            file_descriptor_count: None,
            nice: None,
            cgroup: None,
            affinity: None,
            row_error: None,
        },
        cpu_100ns,
        memory_kib,
        page_faults,
        static_metadata: collected_static_metadata,
    }
}

fn matching_wts_identity<'a>(
    descriptor: &ProcessDescriptor,
    identity: Option<&'a WtsProcessIdentity>,
) -> Option<&'a WtsProcessIdentity> {
    identity.filter(|value| {
        value.image_name_lower == descriptor.image_name.to_lowercase() || descriptor.pid == 0
    })
}

fn query_affinity(handle: HANDLE) -> Option<Vec<u32>> {
    let mut process_mask = 0usize;
    let mut system_mask = 0usize;
    // SAFETY: both output pointers reference initialized writable values for the call duration.
    if unsafe { GetProcessAffinityMask(handle, &mut process_mask, &mut system_mask) } == 0 {
        return None;
    }
    Some(
        (0..usize::BITS)
            .filter(|processor| process_mask & (1usize << processor) != 0)
            .collect(),
    )
}

fn query_system_process_metrics() -> Result<HashMap<u32, SystemProcessMetrics>, BackendError> {
    let mut byte_length = 1024 * 1024_usize;
    loop {
        if byte_length > MAX_SYSTEM_PROCESS_BUFFER_BYTES {
            return Err(BackendError::internal(
                "NtQuerySystemInformation process buffer",
                "the required process snapshot exceeded the safety limit",
            ));
        }
        let words = byte_length.div_ceil(size_of::<usize>());
        let mut storage = vec![0_usize; words];
        let writable_bytes = storage
            .len()
            .checked_mul(size_of::<usize>())
            .and_then(|value| u32::try_from(value).ok())
            .ok_or_else(|| {
                BackendError::internal(
                    "NtQuerySystemInformation process buffer",
                    "the process snapshot buffer size overflowed",
                )
            })?;
        let mut returned = 0_u32;
        // SAFETY: `storage` is aligned and contains `writable_bytes` writable bytes. The class is
        // the documented SystemProcessInformation class and `returned` remains writable.
        let status = unsafe {
            NtQuerySystemInformation(
                SYSTEM_PROCESS_INFORMATION_CLASS,
                storage.as_mut_ptr().cast(),
                writable_bytes,
                &mut returned,
            )
        };
        if status >= 0 {
            let live_bytes = if returned == 0 {
                writable_bytes as usize
            } else {
                returned as usize
            };
            if live_bytes == 0 || live_bytes > writable_bytes as usize {
                return Err(BackendError::internal(
                    "NtQuerySystemInformation process result",
                    "Windows returned an invalid process snapshot length",
                ));
            }
            return parse_system_process_metrics(&storage, live_bytes);
        }
        if status != STATUS_INFO_LENGTH_MISMATCH && status != STATUS_BUFFER_TOO_SMALL {
            return Err(ntstatus_error("NtQuerySystemInformation processes", status));
        }
        let requested = returned as usize;
        byte_length = requested
            .max(byte_length.saturating_mul(2))
            .max(size_of::<SYSTEM_PROCESS_INFORMATION>());
    }
}

fn parse_system_process_metrics(
    storage: &[usize],
    live_bytes: usize,
) -> Result<HashMap<u32, SystemProcessMetrics>, BackendError> {
    let base = storage.as_ptr().cast::<u8>();
    let base_address = base as usize;
    let end_address = base_address.checked_add(live_bytes).ok_or_else(|| {
        BackendError::internal(
            "SystemProcessInformation bounds",
            "the process snapshot address range overflowed",
        )
    })?;
    let mut offset = 0_usize;
    let mut processes = HashMap::new();
    loop {
        let record_end = offset
            .checked_add(size_of::<SYSTEM_PROCESS_INFORMATION>())
            .ok_or_else(|| {
                BackendError::internal(
                    "SystemProcessInformation record",
                    "the process record offset overflowed",
                )
            })?;
        if record_end > live_bytes {
            return Err(BackendError::internal(
                "SystemProcessInformation record",
                "the process snapshot ended in a truncated record",
            ));
        }
        // SAFETY: the backing `usize` array provides sufficient alignment and the bounds check
        // above proves that a complete fixed record is present at this linked-list offset.
        let record = unsafe { &*base.add(offset).cast::<SYSTEM_PROCESS_INFORMATION>() };
        let pid_value = record.UniqueProcessId as usize;
        let pid = u32::try_from(pid_value).map_err(|_| {
            BackendError::internal(
                "SystemProcessInformation PID",
                "Windows returned a process identifier wider than 32 bits",
            )
        })?;
        let parent_pid = u32::try_from(record.Reserved2 as usize).unwrap_or(0);
        let mut image_name = process_image_name(record, base_address, end_address)?;
        if pid == 0 && image_name.is_empty() {
            image_name = "[System Process]".to_string();
        }
        let create_time = reserved_i64(&record.Reserved1, 24).max(0) as u64;
        let user_time = reserved_i64(&record.Reserved1, 32).max(0) as u64;
        let kernel_time = reserved_i64(&record.Reserved1, 40).max(0) as u64;
        processes.insert(
            pid,
            SystemProcessMetrics {
                pid,
                parent_pid,
                image_name,
                start_time: create_time,
                cpu_100ns: user_time.saturating_add(kernel_time),
                memory_kib: bytes_to_kib(record.WorkingSetSize),
                page_faults: u64::from(record.Reserved4),
                virtual_memory_kib: bytes_to_kib(record.VirtualSize),
                paged_pool_kib: bytes_to_kib(record.QuotaPagedPoolUsage),
                non_paged_pool_kib: bytes_to_kib(record.QuotaNonPagedPoolUsage),
                handle_count: u64::from(record.HandleCount),
                thread_count: u64::from(record.NumberOfThreads),
                session_id: record.SessionId,
                base_priority: record.BasePriority,
            },
        );
        if record.NextEntryOffset == 0 {
            break;
        }
        let next = record.NextEntryOffset as usize;
        if next < size_of::<SYSTEM_PROCESS_INFORMATION>() {
            return Err(BackendError::internal(
                "SystemProcessInformation link",
                "Windows returned a non-advancing process record offset",
            ));
        }
        offset = offset.checked_add(next).ok_or_else(|| {
            BackendError::internal(
                "SystemProcessInformation link",
                "the linked process record offset overflowed",
            )
        })?;
        if offset >= live_bytes {
            return Err(BackendError::internal(
                "SystemProcessInformation link",
                "the next process record lies outside the returned snapshot",
            ));
        }
    }
    Ok(processes)
}

fn process_image_name(
    record: &SYSTEM_PROCESS_INFORMATION,
    base_address: usize,
    end_address: usize,
) -> Result<String, BackendError> {
    let byte_length = usize::from(record.ImageName.Length);
    if byte_length == 0 {
        return Ok(String::new());
    }
    if !byte_length.is_multiple_of(size_of::<u16>())
        || record.ImageName.Length > record.ImageName.MaximumLength
        || record.ImageName.Buffer.is_null()
    {
        return Err(BackendError::internal(
            "SystemProcessInformation image name",
            "Windows returned an invalid process image string",
        ));
    }
    let address = record.ImageName.Buffer as usize;
    let string_end = address.checked_add(byte_length).ok_or_else(|| {
        BackendError::internal(
            "SystemProcessInformation image name",
            "the process image string address overflowed",
        )
    })?;
    if address < base_address
        || string_end > end_address
        || !address.is_multiple_of(align_of::<u16>())
    {
        return Err(BackendError::internal(
            "SystemProcessInformation image name",
            "the process image string lies outside the returned snapshot",
        ));
    }
    // SAFETY: the range and UTF-16 alignment were checked against the live snapshot allocation.
    let units =
        unsafe { slice::from_raw_parts(record.ImageName.Buffer, byte_length / size_of::<u16>()) };
    Ok(String::from_utf16_lossy(units))
}

fn reserved_i64(bytes: &[u8; 48], offset: usize) -> i64 {
    let mut value = [0_u8; size_of::<i64>()];
    value.copy_from_slice(&bytes[offset..offset + size_of::<i64>()]);
    i64::from_ne_bytes(value)
}

fn bytes_to_kib(value: usize) -> u64 {
    u64::try_from(value).unwrap_or(u64::MAX) / 1_024
}

fn merge_system_process_descriptors(
    descriptors: &mut Vec<ProcessDescriptor>,
    system_processes: &HashMap<u32, SystemProcessMetrics>,
) {
    let mut descriptor_indices = descriptors
        .iter()
        .enumerate()
        .map(|(index, descriptor)| (descriptor.pid, index))
        .collect::<HashMap<_, _>>();
    for metrics in system_processes.values() {
        if let Some(index) = descriptor_indices.get(&metrics.pid).copied() {
            let descriptor = &mut descriptors[index];
            if descriptor.image_name.is_empty() && !metrics.image_name.is_empty() {
                descriptor.image_name.clone_from(&metrics.image_name);
            }
            if descriptor.parent_pid == 0 {
                descriptor.parent_pid = metrics.parent_pid;
            }
            descriptor.thread_count = u32::try_from(metrics.thread_count).unwrap_or(u32::MAX);
            descriptor.base_priority = metrics.base_priority;
            continue;
        }
        descriptor_indices.insert(metrics.pid, descriptors.len());
        descriptors.push(ProcessDescriptor {
            pid: metrics.pid,
            parent_pid: metrics.parent_pid,
            image_name: metrics.image_name.clone(),
            thread_count: u32::try_from(metrics.thread_count).unwrap_or(u32::MAX),
            base_priority: metrics.base_priority,
        });
    }
}

fn query_service_process_accounts() -> Result<HashMap<u32, String>, BackendError> {
    // SAFETY: null machine/database names select the local active service database.
    let raw_manager = unsafe { OpenSCManagerW(null(), null(), SC_MANAGER_ENUMERATE_SERVICE) };
    // SAFETY: a non-null SCM handle is uniquely transferred into the wrapper.
    let manager = unsafe { OwnedServiceHandle::from_raw(raw_manager) }
        .ok_or_else(|| last_error("OpenSCManagerW process accounts"))?;
    let mut accounts = HashMap::<u32, Option<String>>::new();
    let mut resume = 0_u32;
    let mut byte_length = 256 * 1_024_usize;
    loop {
        let words = byte_length.div_ceil(size_of::<usize>());
        let mut storage = vec![0_usize; words];
        let writable =
            u32::try_from(storage.len().saturating_mul(size_of::<usize>())).unwrap_or(u32::MAX);
        let mut needed = 0_u32;
        let mut returned = 0_u32;
        // SAFETY: the manager is live, the aligned byte buffer has the advertised size, and all
        // output counters remain writable for the call.
        let succeeded = unsafe {
            EnumServicesStatusExW(
                manager.as_raw(),
                SC_ENUM_PROCESS_INFO,
                SERVICE_WIN32,
                SERVICE_STATE_ALL,
                storage.as_mut_ptr().cast(),
                writable,
                &mut needed,
                &mut returned,
                &mut resume,
                null(),
            )
        } != 0;
        let service_capacity = storage
            .len()
            .checked_mul(size_of::<usize>())
            .map(|bytes| bytes / size_of::<ENUM_SERVICE_STATUS_PROCESSW>())
            .ok_or_else(|| {
                BackendError::internal(
                    "EnumServicesStatusExW result",
                    "the service enumeration capacity overflowed",
                )
            })?;
        if returned as usize > service_capacity {
            return Err(BackendError::internal(
                "EnumServicesStatusExW result",
                "Windows returned more service records than fit in the supplied buffer",
            ));
        }
        // SAFETY: the count was checked against the aligned buffer capacity, and the API
        // initialized every returned record contiguously at the buffer start.
        let services = unsafe {
            slice::from_raw_parts(
                storage.as_ptr().cast::<ENUM_SERVICE_STATUS_PROCESSW>(),
                returned as usize,
            )
        };
        for service in services {
            let pid = service.ServiceStatusProcess.dwProcessId;
            if pid == 0 || service.lpServiceName.is_null() {
                continue;
            }
            let Some(account) = query_service_account(manager.as_raw(), service.lpServiceName)
            else {
                continue;
            };
            match accounts.entry(pid) {
                std::collections::hash_map::Entry::Vacant(entry) => {
                    entry.insert(Some(account));
                }
                std::collections::hash_map::Entry::Occupied(mut entry) => {
                    if entry.get().as_ref() != Some(&account) {
                        entry.insert(None);
                    }
                }
            }
        }
        if succeeded {
            break;
        }
        // SAFETY: read immediately after the failed enumeration call.
        let code = unsafe { GetLastError() };
        if code != ERROR_MORE_DATA {
            return Err(error_from_code("EnumServicesStatusExW", code));
        }
        byte_length = (needed as usize).max(256 * 1_024);
    }
    Ok(accounts
        .into_iter()
        .filter_map(|(pid, account)| account.map(|account| (pid, account)))
        .collect())
}

fn query_service_account(manager: SC_HANDLE, service_name: *const u16) -> Option<String> {
    // SAFETY: `service_name` belongs to the live enumeration buffer and is null terminated.
    let raw_service = unsafe { OpenServiceW(manager, service_name, SERVICE_QUERY_CONFIG) };
    // SAFETY: a non-null service handle is uniquely transferred into the wrapper.
    let service = unsafe { OwnedServiceHandle::from_raw(raw_service) }?;
    let mut needed = 0_u32;
    // SAFETY: documented size probe with a null output buffer.
    unsafe {
        let _ = QueryServiceConfigW(service.as_raw(), null_mut(), 0, &mut needed);
    }
    if needed < size_of::<QUERY_SERVICE_CONFIGW>() as u32 {
        return None;
    }
    let words = (needed as usize).div_ceil(size_of::<usize>());
    let mut storage = vec![0_usize; words];
    let writable = u32::try_from(storage.len().checked_mul(size_of::<usize>())?).ok()?;
    // SAFETY: aligned storage provides at least the byte count requested by the size probe.
    if unsafe {
        QueryServiceConfigW(
            service.as_raw(),
            storage.as_mut_ptr().cast::<QUERY_SERVICE_CONFIGW>(),
            writable,
            &mut needed,
        )
    } == 0
    {
        return None;
    }
    // SAFETY: a successful call initialized the fixed configuration header at the buffer start.
    let config = unsafe { &*storage.as_ptr().cast::<QUERY_SERVICE_CONFIGW>() };
    let base_address = storage.as_ptr() as usize;
    let end_address = base_address.checked_add(writable as usize)?;
    let raw = bounded_wide_pointer_to_string(config.lpServiceStartName, base_address, end_address)?;
    normalize_service_account(&raw)
}

fn bounded_wide_pointer_to_string(
    pointer: *const u16,
    base_address: usize,
    end_address: usize,
) -> Option<String> {
    let address = pointer as usize;
    if pointer.is_null()
        || address < base_address
        || address >= end_address
        || !address.is_multiple_of(align_of::<u16>())
    {
        return None;
    }
    let maximum_units = (end_address - address) / size_of::<u16>();
    let mut length = 0_usize;
    // SAFETY: every inspected unit remains within the validated live service configuration.
    while length < maximum_units && unsafe { *pointer.add(length) } != 0 {
        length += 1;
    }
    if length == maximum_units {
        return None;
    }
    // SAFETY: the bounded scan proved that all units through the terminator are readable.
    Some(String::from_utf16_lossy(unsafe {
        slice::from_raw_parts(pointer, length)
    }))
}

fn normalize_service_account(value: &str) -> Option<String> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return None;
    }
    let compact = trimmed
        .chars()
        .filter(|character| !character.is_whitespace())
        .collect::<String>()
        .to_ascii_lowercase();
    match compact.as_str() {
        "localsystem" | "ntauthority\\system" => Some("SYSTEM".to_string()),
        "localservice" | "ntauthority\\localservice" => Some("LOCAL SERVICE".to_string()),
        "networkservice" | "ntauthority\\networkservice" => Some("NETWORK SERVICE".to_string()),
        _ => trimmed
            .strip_prefix(".\\")
            .unwrap_or(trimmed)
            .rsplit('\\')
            .next()
            .map(str::trim)
            .filter(|account| !account.is_empty())
            .map(str::to_string),
    }
}

struct OwnedServiceHandle(SC_HANDLE);

impl OwnedServiceHandle {
    /// # Safety
    ///
    /// `raw` must be null or a fresh handle returned by the Service Control Manager APIs.
    unsafe fn from_raw(raw: SC_HANDLE) -> Option<Self> {
        (!raw.is_null()).then_some(Self(raw))
    }

    fn as_raw(&self) -> SC_HANDLE {
        self.0
    }
}

impl Drop for OwnedServiceHandle {
    fn drop(&mut self) {
        // SAFETY: this wrapper uniquely owns a non-null service handle.
        unsafe {
            let _ = CloseServiceHandle(self.0);
        }
    }
}

fn ntstatus_error(context: &str, status: i32) -> BackendError {
    BackendError {
        domain: "ntstatus".to_string(),
        code: i64::from(status),
        context: context.to_string(),
        message: format!("NTSTATUS 0x{:08X}", status as u32),
    }
}

fn enumerate_processes() -> Result<Vec<ProcessDescriptor>, BackendError> {
    // SAFETY: CreateToolhelp32Snapshot receives scalar arguments and returns one owned handle.
    let raw = unsafe { CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0) };
    // SAFETY: ownership of a successful snapshot handle is transferred immediately.
    let snapshot = unsafe { OwnedHandle::from_raw(raw) }
        .ok_or_else(|| last_error("CreateToolhelp32Snapshot processes"))?;
    let mut entry = PROCESSENTRY32W {
        dwSize: size_of::<PROCESSENTRY32W>() as u32,
        ..PROCESSENTRY32W::default()
    };
    // SAFETY: snapshot remains open and entry has the documented size and writable storage.
    if unsafe { Process32FirstW(snapshot.as_raw(), &mut entry) } == 0 {
        return Err(last_error("Process32FirstW"));
    }
    let mut processes = Vec::with_capacity(256);
    loop {
        let mut image_name = wide_slice_to_string(&entry.szExeFile);
        if entry.th32ProcessID == 0 && image_name.is_empty() {
            image_name = "[System Process]".to_string();
        }
        processes.push(ProcessDescriptor {
            pid: entry.th32ProcessID,
            parent_pid: entry.th32ParentProcessID,
            image_name,
            thread_count: entry.cntThreads,
            base_priority: entry.pcPriClassBase,
        });
        // SAFETY: same snapshot and correctly sized output remain valid across iterations.
        if unsafe { Process32NextW(snapshot.as_raw(), &mut entry) } == 0 {
            // SAFETY: read immediately after the failing enumeration call.
            let code = unsafe { GetLastError() };
            if code != ERROR_NO_MORE_FILES {
                return Err(error_from_code("Process32NextW", code));
            }
            break;
        }
    }
    Ok(processes)
}

fn enumerate_wts_process_identities(
    account_names: &mut AccountNameCache,
) -> Option<HashMap<u32, WtsProcessIdentity>> {
    let mut raw = null_mut::<WTS_PROCESS_INFOW>();
    let mut count = 0u32;
    // SAFETY: WTS allocates one array on success; `WtsMemory` below owns and frees it.
    if unsafe { WTSEnumerateProcessesW(WTS_CURRENT_SERVER_HANDLE, 0, 1, &mut raw, &mut count) } == 0
    {
        return None;
    }
    // SAFETY: a successful call with a non-null allocation transfers ownership to the caller.
    let memory = unsafe { WtsMemory::from_raw(raw.cast()) }?;
    // SAFETY: WTS reports the number of initialized `WTS_PROCESS_INFOW` records in the array.
    let processes = unsafe { slice::from_raw_parts(raw, count as usize) };
    let mut identities = HashMap::with_capacity(processes.len());
    for process in processes {
        // SAFETY: each process name is a null-terminated string owned by the live WTS allocation.
        let image_name_lower =
            unsafe { wide_pointer_to_string(process.pProcessName) }.to_lowercase();
        let user_name = if process.ProcessId == 0 {
            Some("SYSTEM".to_string())
        } else {
            query_account_name_from_sid_cached(process.pUserSid, account_names)
        };
        identities.insert(
            process.ProcessId,
            WtsProcessIdentity {
                image_name_lower,
                user_name,
                session_id: process.SessionId,
            },
        );
    }
    drop(memory);
    Some(identities)
}

fn query_cpu_time(handle: HANDLE) -> Result<(u64, u64), BackendError> {
    let mut creation = FILETIME::default();
    let mut exit = FILETIME::default();
    let mut kernel = FILETIME::default();
    let mut user = FILETIME::default();
    // SAFETY: handle remains open and all FILETIME outputs point to valid writable storage.
    if unsafe { GetProcessTimes(handle, &mut creation, &mut exit, &mut kernel, &mut user) } == 0 {
        return Err(last_error("GetProcessTimes process metrics"));
    }
    let raw = filetime_to_u64(kernel).saturating_add(filetime_to_u64(user));
    Ok((raw, raw / 10_000))
}

fn query_memory(handle: HANDLE) -> Option<PROCESS_MEMORY_COUNTERS_EX> {
    let mut counters = PROCESS_MEMORY_COUNTERS_EX {
        cb: size_of::<PROCESS_MEMORY_COUNTERS_EX>() as u32,
        ..PROCESS_MEMORY_COUNTERS_EX::default()
    };
    // SAFETY: output points to a sufficiently large compatible structure for the whole call.
    (unsafe {
        K32GetProcessMemoryInfo(
            handle,
            (&mut counters as *mut PROCESS_MEMORY_COUNTERS_EX).cast::<PROCESS_MEMORY_COUNTERS>(),
            counters.cb,
        )
    } != 0)
        .then_some(counters)
}

fn query_executable_path(handle: HANDLE) -> Option<String> {
    let mut buffer = vec![0u16; 32_768];
    let mut length = buffer.len() as u32;
    // SAFETY: buffer contains `length` writable UTF-16 elements and handle remains open.
    if unsafe { QueryFullProcessImageNameW(handle, 0, buffer.as_mut_ptr(), &mut length) } == 0 {
        return None;
    }
    let length = usize::try_from(length).ok()?.min(buffer.len());
    Some(String::from_utf16_lossy(&buffer[..length]))
}

fn query_user_name(process: HANDLE, account_names: &mut AccountNameCache) -> Option<String> {
    let mut raw_token = null_mut();
    // SAFETY: output receives one token handle, transferred to OwnedHandle on success.
    if unsafe { OpenProcessToken(process, TOKEN_QUERY, &mut raw_token) } == 0 {
        return None;
    }
    // SAFETY: ownership of the successful token handle is transferred immediately.
    let token = unsafe { OwnedHandle::from_raw(raw_token) }?;
    let mut required = 0u32;
    // SAFETY: documented size probe with a null output buffer.
    unsafe {
        let _ = GetTokenInformation(token.as_raw(), TokenUser, null_mut(), 0, &mut required);
    }
    if required == 0 {
        return None;
    }
    let words = (required as usize).div_ceil(size_of::<usize>());
    let mut storage = vec![0usize; words];
    // SAFETY: usize storage provides suitable alignment and at least `required` writable bytes.
    if unsafe {
        GetTokenInformation(
            token.as_raw(),
            TokenUser,
            storage.as_mut_ptr().cast(),
            required,
            &mut required,
        )
    } == 0
    {
        return None;
    }
    // SAFETY: successful TokenUser query initialized a TOKEN_USER at the aligned buffer start.
    let token_user = unsafe { &*(storage.as_ptr().cast::<TOKEN_USER>()) };
    query_account_name_from_sid_cached(token_user.User.Sid, account_names)
}

fn query_account_name_from_sid_cached(
    sid: *mut c_void,
    account_names: &mut AccountNameCache,
) -> Option<String> {
    if sid.is_null() || unsafe { IsValidSid(sid) } == 0 {
        return query_account_name_from_sid(sid);
    }
    // SAFETY: IsValidSid accepted this caller-owned SID, so GetLengthSid and the bounded byte
    // view are valid for the duration of this synchronous cache lookup.
    let length = unsafe { GetLengthSid(sid) } as usize;
    if length == 0 {
        return query_account_name_from_sid(sid);
    }
    // SAFETY: GetLengthSid reported the exact readable byte length for the still-live SID.
    let cache_key = unsafe { slice::from_raw_parts(sid.cast::<u8>(), length) };
    if let Some(name) = account_names.get(cache_key) {
        return Some(name);
    }
    let name = query_account_name_from_sid(sid)?;
    account_names.insert(cache_key.to_vec(), name.clone());
    Some(name)
}

fn query_account_name_from_sid(sid: *mut c_void) -> Option<String> {
    if sid.is_null() {
        return None;
    }
    let mut name_length = 0u32;
    let mut domain_length = 0u32;
    let mut use_type: SID_NAME_USE = 0;
    // SAFETY: documented size probe; SID remains valid in `storage` throughout both calls.
    unsafe {
        let _ = LookupAccountSidW(
            null(),
            sid,
            null_mut(),
            &mut name_length,
            null_mut(),
            &mut domain_length,
            &mut use_type,
        );
    }
    // SAFETY: read immediately after the expected failed size probe.
    if name_length == 0 || unsafe { GetLastError() } != ERROR_INSUFFICIENT_BUFFER {
        return None;
    }
    let mut name = vec![0u16; name_length as usize];
    let mut domain = vec![0u16; domain_length.max(1) as usize];
    // SAFETY: both UTF-16 buffers have the sizes advertised by the size probe.
    if unsafe {
        LookupAccountSidW(
            null(),
            sid,
            name.as_mut_ptr(),
            &mut name_length,
            domain.as_mut_ptr(),
            &mut domain_length,
            &mut use_type,
        )
    } == 0
    {
        return None;
    }
    let name_length = (name_length as usize).min(name.len());
    let name = String::from_utf16_lossy(&name[..name_length]);
    (!name.is_empty()).then_some(name)
}

unsafe fn wide_pointer_to_string(pointer: *const u16) -> String {
    if pointer.is_null() {
        return String::new();
    }
    const MAX_UNITS: usize = 32_768;
    let mut length = 0usize;
    // SAFETY: WTS documents this pointer as a live null-terminated process name. The explicit
    // bound prevents an unbounded scan if external data is malformed.
    while length < MAX_UNITS && unsafe { *pointer.add(length) } != 0 {
        length += 1;
    }
    // SAFETY: the preceding bounded scan proved these UTF-16 units readable before the terminator.
    String::from_utf16_lossy(unsafe { slice::from_raw_parts(pointer, length) })
}

struct WtsMemory(*mut c_void);

impl WtsMemory {
    /// # Safety
    ///
    /// `raw` must be a fresh allocation returned by a WTS API.
    unsafe fn from_raw(raw: *mut c_void) -> Option<Self> {
        (!raw.is_null()).then_some(Self(raw))
    }
}

impl Drop for WtsMemory {
    fn drop(&mut self) {
        // SAFETY: this wrapper uniquely owns the WTS allocation.
        unsafe { WTSFreeMemory(self.0) };
    }
}

fn open_verified(identity: &ProcessIdentity, access: u32) -> Result<OwnedHandle, BackendError> {
    if identity.start_time == 0 {
        return Err(BackendError::internal(
            "validate Windows process identity",
            "a PID-only process identity is not actionable",
        ));
    }
    // SAFETY: OpenProcess receives scalar arguments and returns one owned handle on success.
    let raw = unsafe { OpenProcess(access | PROCESS_QUERY_LIMITED_INFORMATION, 0, identity.pid) };
    // SAFETY: ownership is transferred immediately after a successful call.
    let handle = unsafe { OwnedHandle::from_raw(raw) }
        .ok_or_else(|| last_error("OpenProcess for verified action"))?;
    let actual = query_identity_from_handle(identity.pid, handle.as_raw())?;
    validate_process_identity(identity, &actual)?;
    Ok(handle)
}

fn validate_process_identity(
    expected: &ProcessIdentity,
    actual: &ProcessIdentity,
) -> Result<(), BackendError> {
    if actual != expected {
        return Err(BackendError::internal(
            "validate Windows process identity",
            "the selected PID was reused by another process",
        ));
    }
    Ok(())
}

fn build_process_tree_plan(
    root: &ProcessIdentity,
    snapshot: &[ProcessTreeNode],
) -> Result<Vec<ProcessIdentity>, BackendError> {
    if root.start_time == 0 {
        return Err(BackendError::internal(
            "validate Windows process tree identity",
            "a PID-only root process identity is not actionable",
        ));
    }

    let mut by_pid = HashMap::with_capacity(snapshot.len());
    let mut children: HashMap<u32, Vec<&ProcessTreeNode>> = HashMap::new();
    for node in snapshot {
        if by_pid.insert(node.identity.pid, node).is_some() {
            return Err(BackendError::internal(
                "validate Windows process tree snapshot",
                "the captured process snapshot contains a duplicate PID",
            ));
        }
        children.entry(node.parent_pid).or_default().push(node);
    }

    let captured_root = by_pid.get(&root.pid).ok_or_else(|| {
        BackendError::internal(
            "validate Windows process tree identity",
            "the selected process is absent from the captured system snapshot",
        )
    })?;
    validate_process_identity(root, &captured_root.identity)?;

    let mut targets = Vec::new();
    let mut queue = VecDeque::from([(*captured_root, 0usize)]);
    let mut seen = HashSet::new();
    while let Some((node, depth)) = queue.pop_front() {
        if !seen.insert(node.identity.pid) {
            return Err(BackendError::internal(
                "validate Windows process tree ancestry",
                "the captured process tree contains cyclic ancestry",
            ));
        }
        if node.identity.start_time == 0 {
            return Err(BackendError::internal(
                "validate Windows process tree identity",
                "the captured process tree contains a PID-only identity",
            ));
        }
        targets.push((node.identity.clone(), depth));
        if let Some(descendants) = children.get(&node.identity.pid) {
            for child in descendants {
                if child.identity.start_time < node.identity.start_time {
                    return Err(BackendError::internal(
                        "validate Windows process tree ancestry",
                        "a captured child process predates its current parent",
                    ));
                }
                queue.push_back((child, depth + 1));
            }
        }
    }

    targets.sort_by_key(|(identity, depth)| (std::cmp::Reverse(*depth), identity.pid));
    Ok(targets.into_iter().map(|(identity, _)| identity).collect())
}

fn terminate(identity: &ProcessIdentity, include_descendants: bool) -> Result<(), BackendError> {
    if !include_descendants {
        let handle = open_verified(identity, PROCESS_TERMINATE)?;
        // SAFETY: the handle owns PROCESS_TERMINATE access and identity was just revalidated.
        if unsafe { TerminateProcess(handle.as_raw(), 1) } == 0 {
            return Err(last_error("TerminateProcess"));
        }
        return Ok(());
    }

    // Capture identity and ancestry together. Learning an identity from a numeric PID after this
    // point could adopt a replacement process before the termination handles are opened.
    let system_processes = query_system_process_metrics()?;
    let snapshot = system_processes
        .values()
        .map(|metrics| ProcessTreeNode {
            identity: ProcessIdentity {
                pid: metrics.pid,
                start_time: metrics.start_time,
            },
            parent_pid: metrics.parent_pid,
        })
        .collect::<Vec<_>>();
    let targets = build_process_tree_plan(identity, &snapshot)?;
    let mut opened = Vec::with_capacity(targets.len());
    for expected in targets {
        let pid = expected.pid;
        opened.push((pid, open_verified(&expected, PROCESS_TERMINATE)?));
    }
    for (pid, handle) in opened {
        // SAFETY: every handle was opened and identity-verified before the first termination.
        if unsafe { TerminateProcess(handle.as_raw(), 1) } == 0 {
            return Err(last_error(format!("TerminateProcess PID {pid}")));
        }
    }
    Ok(())
}

fn set_priority(identity: &ProcessIdentity, priority: ProcessPriority) -> Result<(), BackendError> {
    let handle = open_verified(identity, PROCESS_SET_INFORMATION)?;
    let class = match priority {
        ProcessPriority::Low => IDLE_PRIORITY_CLASS,
        ProcessPriority::BelowNormal => BELOW_NORMAL_PRIORITY_CLASS,
        ProcessPriority::Normal => NORMAL_PRIORITY_CLASS,
        ProcessPriority::AboveNormal => ABOVE_NORMAL_PRIORITY_CLASS,
        ProcessPriority::High => HIGH_PRIORITY_CLASS,
        ProcessPriority::Realtime => REALTIME_PRIORITY_CLASS,
    };
    // SAFETY: handle owns PROCESS_SET_INFORMATION and identity was just revalidated.
    if unsafe { SetPriorityClass(handle.as_raw(), class) } == 0 {
        return Err(last_error("SetPriorityClass"));
    }
    Ok(())
}

fn set_affinity(
    identity: &ProcessIdentity,
    logical_processors: &[u32],
) -> Result<(), BackendError> {
    if logical_processors.is_empty() {
        return Err(BackendError::internal(
            "SetProcessAffinityMask",
            "at least one logical processor must remain selected",
        ));
    }
    let mut mask = 0usize;
    for processor in logical_processors {
        let Some(bit) = 1usize.checked_shl(*processor) else {
            return Err(BackendError::unsupported(
                "SetProcessAffinityMask",
                "processor groups above the native affinity-mask width require CPU Sets support",
            ));
        };
        mask |= bit;
    }
    let handle = open_verified(identity, PROCESS_SET_INFORMATION)?;
    // SAFETY: handle owns PROCESS_SET_INFORMATION, mask is non-zero, and identity was revalidated.
    if unsafe { SetProcessAffinityMask(handle.as_raw(), mask) } == 0 {
        return Err(last_error("SetProcessAffinityMask"));
    }
    Ok(())
}

fn open_file_location(identity: &ProcessIdentity) -> Result<(), BackendError> {
    let handle = open_verified(identity, PROCESS_QUERY_LIMITED_INFORMATION)?;
    let executable = query_executable_path(handle.as_raw()).ok_or_else(|| {
        BackendError::internal(
            "QueryFullProcessImageNameW",
            "process executable path is unavailable",
        )
    })?;
    Command::new("explorer.exe")
        .arg(format!("/select,{executable}"))
        .spawn()
        .map_err(|error| BackendError::io("spawn explorer.exe", &error))?;
    Ok(())
}

const fn priority_name(class: u32) -> &'static str {
    match class {
        IDLE_PRIORITY_CLASS => "Low",
        BELOW_NORMAL_PRIORITY_CLASS => "Below normal",
        NORMAL_PRIORITY_CLASS => "Normal",
        ABOVE_NORMAL_PRIORITY_CLASS => "Above normal",
        HIGH_PRIORITY_CLASS => "High",
        REALTIME_PRIORITY_CLASS => "Realtime",
        _ => "Unknown",
    }
}

fn signed_delta(current: u64, previous: u64) -> i64 {
    let difference = i128::from(current) - i128::from(previous);
    difference.clamp(i128::from(i64::MIN), i128::from(i64::MAX)) as i64
}

#[cfg(test)]
mod tests {
    use super::{
        AccountNameCache, ProcessSampler, ProcessTreeNode, build_process_tree_plan, signed_delta,
        validate_process_identity,
    };
    use taskmgr_core::{ProcessIdentity, SnapshotData};

    fn tree_node(pid: u32, parent_pid: u32, start_time: u64) -> ProcessTreeNode {
        ProcessTreeNode {
            identity: ProcessIdentity { pid, start_time },
            parent_pid,
        }
    }

    #[test]
    fn signed_delta_preserves_counter_direction() {
        assert_eq!(signed_delta(150, 100), 50);
        assert_eq!(signed_delta(80, 100), -20);
    }

    #[test]
    fn process_tree_plan_preserves_captured_identities_and_orders_leaves_first() {
        let root = ProcessIdentity {
            pid: 10,
            start_time: 100,
        };
        let snapshot = [
            tree_node(10, 1, 100),
            tree_node(20, 10, 200),
            tree_node(30, 10, 150),
            tree_node(40, 20, 300),
            tree_node(50, 1, 125),
        ];

        let plan = build_process_tree_plan(&root, &snapshot).unwrap();

        assert_eq!(
            plan,
            vec![
                ProcessIdentity {
                    pid: 40,
                    start_time: 300,
                },
                ProcessIdentity {
                    pid: 20,
                    start_time: 200,
                },
                ProcessIdentity {
                    pid: 30,
                    start_time: 150,
                },
                root,
            ]
        );
    }

    #[test]
    fn captured_descendant_identity_rejects_a_replacement_process() {
        let root = ProcessIdentity {
            pid: 10,
            start_time: 100,
        };
        let snapshot = [tree_node(10, 1, 100), tree_node(20, 10, 200)];
        let plan = build_process_tree_plan(&root, &snapshot).unwrap();
        let captured_child = plan.iter().find(|identity| identity.pid == 20).unwrap();
        let replacement = ProcessIdentity {
            pid: 20,
            start_time: 900,
        };

        assert_eq!(captured_child.start_time, 200);
        assert!(validate_process_identity(captured_child, &replacement).is_err());
    }

    #[test]
    fn process_tree_plan_rejects_a_child_that_predates_its_current_parent() {
        let root = ProcessIdentity {
            pid: 10,
            start_time: 500,
        };
        let snapshot = [tree_node(10, 1, 500), tree_node(20, 10, 200)];

        assert!(build_process_tree_plan(&root, &snapshot).is_err());
    }

    #[test]
    fn process_tree_plan_rejects_a_reused_root_pid() {
        let selected = ProcessIdentity {
            pid: 10,
            start_time: 100,
        };
        let snapshot = [tree_node(10, 1, 900), tree_node(20, 10, 950)];

        assert!(build_process_tree_plan(&selected, &snapshot).is_err());
    }

    #[test]
    fn process_snapshot_keeps_the_pid_zero_system_row() {
        let mut sampler = ProcessSampler::new();
        let snapshot = sampler.sample().unwrap();
        let SnapshotData::Processes(data) = snapshot else {
            panic!("process sampler returned another page type");
        };
        let system = data
            .rows
            .iter()
            .find(|row| row.identity.pid == 0)
            .expect("Toolhelp PID 0 must remain visible without an open process handle");
        assert!(!system.image_name.is_empty());
        assert_eq!(system.cpu_percent, Some(0.0));
        assert!(system.cpu_time_millis.is_some());
        assert!(system.memory_kib.is_some());
        assert!(system.handle_count.is_some());
        assert!(system.thread_count.is_some());
        assert!(
            sampler
                .static_metadata
                .keys()
                .all(|identity| identity.start_time != 0
                    && data.rows.iter().any(|row| &row.identity == identity))
        );
    }

    #[test]
    fn account_name_cache_is_bounded_and_retains_recent_entries() {
        let mut cache = AccountNameCache::default();
        for index in 0..AccountNameCache::MAX_ENTRIES {
            cache.insert(index.to_le_bytes().to_vec(), format!("user-{index}"));
        }
        cache.begin_refresh();
        assert_eq!(cache.get(&0usize.to_le_bytes()), Some("user-0".to_string()));
        cache.insert(
            AccountNameCache::MAX_ENTRIES.to_le_bytes().to_vec(),
            "new-user".to_string(),
        );

        assert_eq!(cache.entries.len(), AccountNameCache::MAX_ENTRIES);
        assert_eq!(cache.get(&0usize.to_le_bytes()), Some("user-0".to_string()));
        assert_eq!(
            cache.get(&AccountNameCache::MAX_ENTRIES.to_le_bytes()),
            Some("new-user".to_string())
        );
    }
}
