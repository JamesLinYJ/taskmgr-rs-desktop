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

//! 使用 Tool Help 建立一次一致的进程父子视图，再通过进程句柄读取动态指标。
//!
//! 跨采样缓存只以 `PID + FILETIME 创建时间` 为键。所有破坏性动作重新打开句柄并验证
//! 创建时间；结束进程树会先打开和验证整组目标，再按叶子优先顺序执行。

use std::collections::{HashMap, HashSet, VecDeque};
use std::mem::size_of;
use std::process::Command;
use std::ptr::{null, null_mut};
use std::time::Instant;

use taskmgr_core::{
    ActionRequest, ActionResult, BackendError, ProcessIdentity, ProcessPriority, ProcessRow,
    ProcessesData, SnapshotData,
};
use windows_sys::Win32::Foundation::{
    ERROR_INSUFFICIENT_BUFFER, ERROR_NO_MORE_FILES, FILETIME, GetLastError, HANDLE,
};
use windows_sys::Win32::Security::{
    GetTokenInformation, LookupAccountSidW, SID_NAME_USE, TOKEN_QUERY, TOKEN_USER, TokenUser,
};
use windows_sys::Win32::System::Diagnostics::ToolHelp::{
    CreateToolhelp32Snapshot, PROCESSENTRY32W, Process32FirstW, Process32NextW, TH32CS_SNAPPROCESS,
};
use windows_sys::Win32::System::ProcessStatus::{
    K32GetProcessMemoryInfo, PROCESS_MEMORY_COUNTERS, PROCESS_MEMORY_COUNTERS_EX,
};
use windows_sys::Win32::System::RemoteDesktop::ProcessIdToSessionId;
use windows_sys::Win32::System::Threading::{
    ABOVE_NORMAL_PRIORITY_CLASS, BELOW_NORMAL_PRIORITY_CLASS, GetActiveProcessorCount,
    GetPriorityClass, GetProcessAffinityMask, GetProcessHandleCount, GetProcessTimes,
    HIGH_PRIORITY_CLASS, IDLE_PRIORITY_CLASS, NORMAL_PRIORITY_CLASS, OpenProcess, OpenProcessToken,
    PROCESS_QUERY_INFORMATION, PROCESS_QUERY_LIMITED_INFORMATION, PROCESS_SET_INFORMATION,
    PROCESS_TERMINATE, PROCESS_VM_READ, QueryFullProcessImageNameW, REALTIME_PRIORITY_CLASS,
    SetPriorityClass, SetProcessAffinityMask, TerminateProcess,
};

use crate::applications::query_identity_from_handle;
use crate::native::{
    OwnedHandle, error_from_code, filetime_to_u64, last_error, wide_slice_to_string,
};

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

pub(crate) struct ProcessSampler {
    previous: HashMap<ProcessIdentity, PreviousProcessSample>,
    previous_at: Option<Instant>,
}

impl ProcessSampler {
    pub(crate) fn new() -> Self {
        Self {
            previous: HashMap::new(),
            previous_at: None,
        }
    }

    pub(crate) fn sample(&mut self) -> Result<SnapshotData, BackendError> {
        let descriptors = enumerate_processes()?;
        let now = Instant::now();
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
        let mut rows = Vec::with_capacity(descriptors.len());
        for descriptor in descriptors {
            let Some(sampled) = sample_process(&descriptor) else {
                // A PID without a readable creation time cannot safely participate in later
                // actions, so it is not represented by a fabricated PID-only identity.
                continue;
            };
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
            row.cpu_percent = cpu_percent;
            row.memory_delta_kib = memory_delta_kib;
            row.page_faults_delta = page_faults_delta;
            next.insert(
                row.identity.clone(),
                PreviousProcessSample {
                    cpu_100ns: sampled.cpu_100ns,
                    memory_kib: sampled.memory_kib,
                    page_faults: sampled.page_faults,
                },
            );
            rows.push(row);
        }
        rows.sort_by(|left, right| {
            left.image_name
                .to_lowercase()
                .cmp(&right.image_name.to_lowercase())
                .then_with(|| left.identity.pid.cmp(&right.identity.pid))
        });
        self.previous = next;
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
}

fn sample_process(descriptor: &ProcessDescriptor) -> Option<SampledProcess> {
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
        let limited_handle = unsafe { OwnedHandle::from_raw(raw_limited) }?;
        return sample_process_with_handle(descriptor, &limited_handle, false);
    };
    sample_process_with_handle(descriptor, handle, true)
}

fn sample_process_with_handle(
    descriptor: &ProcessDescriptor,
    handle: &OwnedHandle,
    can_read_memory: bool,
) -> Option<SampledProcess> {
    let identity = query_identity_from_handle(descriptor.pid, handle.as_raw()).ok()?;
    let cpu = query_cpu_time(handle.as_raw()).ok();
    let memory = can_read_memory
        .then(|| query_memory(handle.as_raw()))
        .flatten();
    let memory_kib = memory.map(|value| value.WorkingSetSize as u64 / 1024);
    let page_faults = memory.map(|value| u64::from(value.PageFaultCount));
    let mut handle_count = 0u32;
    let handle_count = (unsafe { GetProcessHandleCount(handle.as_raw(), &mut handle_count) } != 0)
        .then_some(u64::from(handle_count));
    let priority_class = unsafe { GetPriorityClass(handle.as_raw()) };
    let base_priority = if priority_class == 0 {
        Some(descriptor.base_priority.to_string())
    } else {
        Some(priority_name(priority_class).to_string())
    };
    let mut session_id = 0u32;
    let session_id = (unsafe { ProcessIdToSessionId(descriptor.pid, &mut session_id) } != 0)
        .then_some(session_id);
    let affinity = query_affinity(handle.as_raw());
    Some(SampledProcess {
        row: ProcessRow {
            identity,
            parent_pid: (descriptor.parent_pid != 0).then_some(descriptor.parent_pid),
            image_name: descriptor.image_name.clone(),
            executable_path: query_executable_path(handle.as_raw()),
            user_name: query_user_name(handle.as_raw()),
            session_id,
            cpu_percent: None,
            cpu_time_millis: cpu.map(|(_, milliseconds)| milliseconds),
            memory_kib,
            memory_delta_kib: None,
            page_faults,
            page_faults_delta: None,
            virtual_memory_kib: memory.map(|value| value.PrivateUsage as u64 / 1024),
            paged_pool_kib: memory.map(|value| value.QuotaPagedPoolUsage as u64 / 1024),
            non_paged_pool_kib: memory.map(|value| value.QuotaNonPagedPoolUsage as u64 / 1024),
            base_priority,
            handle_count,
            thread_count: Some(u64::from(descriptor.thread_count)),
            file_descriptor_count: None,
            nice: None,
            cgroup: None,
            affinity,
            row_error: None,
        },
        cpu_100ns: cpu.map(|(raw, _)| raw),
        memory_kib,
        page_faults,
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
        if entry.th32ProcessID != 0 {
            processes.push(ProcessDescriptor {
                pid: entry.th32ProcessID,
                parent_pid: entry.th32ParentProcessID,
                image_name: wide_slice_to_string(&entry.szExeFile),
                thread_count: entry.cntThreads,
                base_priority: entry.pcPriClassBase,
            });
        }
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

fn query_user_name(process: HANDLE) -> Option<String> {
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
    let mut name_length = 0u32;
    let mut domain_length = 0u32;
    let mut use_type: SID_NAME_USE = 0;
    // SAFETY: documented size probe; SID remains valid in `storage` throughout both calls.
    unsafe {
        let _ = LookupAccountSidW(
            null(),
            token_user.User.Sid,
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
            token_user.User.Sid,
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
    let name = String::from_utf16_lossy(&name[..name_length as usize]);
    let domain = String::from_utf16_lossy(&domain[..domain_length as usize]);
    Some(if domain.is_empty() {
        name
    } else {
        format!("{domain}\\{name}")
    })
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
    if &actual != identity {
        return Err(BackendError::internal(
            "validate Windows process identity",
            "the selected PID was reused by another process",
        ));
    }
    Ok(handle)
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

    let descriptors = enumerate_processes()?;
    let mut children: HashMap<u32, Vec<u32>> = HashMap::new();
    for descriptor in &descriptors {
        children
            .entry(descriptor.parent_pid)
            .or_default()
            .push(descriptor.pid);
    }
    let mut targets = Vec::new();
    let mut queue = VecDeque::from([(identity.pid, 0usize)]);
    let mut seen = HashSet::new();
    while let Some((pid, depth)) = queue.pop_front() {
        if !seen.insert(pid) {
            continue;
        }
        targets.push((pid, depth));
        if let Some(descendants) = children.get(&pid) {
            queue.extend(descendants.iter().copied().map(|child| (child, depth + 1)));
        }
    }
    let mut opened = Vec::with_capacity(targets.len());
    for (pid, depth) in targets {
        let expected = if pid == identity.pid {
            identity.clone()
        } else {
            let raw = unsafe { OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid) };
            let probe = unsafe { OwnedHandle::from_raw(raw) }
                .ok_or_else(|| last_error("OpenProcess descendant identity"))?;
            query_identity_from_handle(pid, probe.as_raw())?
        };
        opened.push((depth, pid, open_verified(&expected, PROCESS_TERMINATE)?));
    }
    opened.sort_by_key(|(depth, _, _)| std::cmp::Reverse(*depth));
    for (_, pid, handle) in opened {
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
    use super::signed_delta;

    #[test]
    fn signed_delta_preserves_counter_direction() {
        assert_eq!(signed_delta(150, 100), 50);
        assert_eq!(signed_delta(80, 100), -20);
    }
}
