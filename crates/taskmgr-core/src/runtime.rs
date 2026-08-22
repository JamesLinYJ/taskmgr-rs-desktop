// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 有界采样运行时
//
//   文件:       crates/taskmgr-core/src/runtime.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Rust 标准线程模型；Crossbeam 有界通道语义；项目快照提交约定
// --------------------------------------------------------------------------

//! 运行一个长期后台采样线程，合并重复刷新，并在失败时继续发布上一份可信快照。

use std::collections::{BTreeSet, HashMap, VecDeque};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant};

use crossbeam_channel::{Receiver, Sender, TryRecvError, TrySendError, bounded, select};
use thiserror::Error;

use crate::diagnostics::{self, Field, Level};
use crate::{
    ActionRequest, ActionResult, ActionStatus, BackendError, BackendEvent, BackendOptions, PageId,
    PlatformProvider, PrivilegeResult, PrivilegeState, SnapshotData, SnapshotMeta,
};

const EVENT_CAPACITY: usize = 16;
const REPEATED_ERROR_LOG_INTERVAL: Duration = Duration::from_secs(60);

struct LoggedPageError {
    domain: String,
    code: i64,
    context: String,
    logged_at: Instant,
}

#[derive(Debug, Error)]
pub enum RuntimeError {
    #[error("backend runtime has already stopped")]
    Stopped,
    #[error("backend runtime state lock was poisoned")]
    Poisoned,
    #[error("backend runtime worker panicked")]
    WorkerPanicked,
}

#[derive(Default)]
struct PendingRefresh {
    pages: BTreeSet<PageId>,
    options: Option<BackendOptions>,
    shutdown: bool,
}

enum Operation {
    Action(ActionRequest, Sender<ActionResult>),
    OpenPrivilege(Sender<PrivilegeResult>),
}

pub struct BackendRuntime {
    pending: Arc<Mutex<PendingRefresh>>,
    wake_tx: Sender<()>,
    operation_tx: Sender<Operation>,
    events: Receiver<BackendEvent>,
    worker: Mutex<Option<JoinHandle<()>>>,
}

impl BackendRuntime {
    pub fn start(provider: Box<dyn PlatformProvider>, options: BackendOptions) -> Self {
        diagnostics::event(
            Level::Info,
            "backend.starting",
            "runtime",
            "backend runtime is starting",
            &[
                Field::text("active_page", page_name(options.active_page)),
                Field::text("update_speed", format!("{:?}", options.update_speed)),
            ],
        );
        let pending = Arc::new(Mutex::new(PendingRefresh::default()));
        let (wake_tx, wake_rx) = bounded(1);
        let (operation_tx, operation_rx) = bounded(1);
        let (event_tx, events) = bounded(EVENT_CAPACITY);
        let event_drop_rx = events.clone();
        let worker_pending = Arc::clone(&pending);
        let worker = thread::Builder::new()
            .name("taskmgr-backend".to_string())
            .spawn(move || {
                worker_loop(
                    provider,
                    options,
                    worker_pending,
                    wake_rx,
                    operation_rx,
                    event_tx,
                    event_drop_rx,
                );
            })
            .expect("task manager backend worker creation must succeed");

        Self {
            pending,
            wake_tx,
            operation_tx,
            events,
            worker: Mutex::new(Some(worker)),
        }
    }

    pub fn events(&self) -> Receiver<BackendEvent> {
        self.events.clone()
    }

    pub fn request_refresh(&self, page: Option<PageId>) -> Result<(), RuntimeError> {
        let mut pending = self.pending.lock().map_err(|_| RuntimeError::Poisoned)?;
        if pending.shutdown {
            return Err(RuntimeError::Stopped);
        }
        if let Some(page) = page {
            pending.pages.insert(page);
        } else {
            pending.pages.extend(PageId::ALL);
        }
        drop(pending);
        notify_worker(&self.wake_tx)
    }

    pub fn update_options(&self, options: BackendOptions) -> Result<(), RuntimeError> {
        let mut pending = self.pending.lock().map_err(|_| RuntimeError::Poisoned)?;
        if pending.shutdown {
            return Err(RuntimeError::Stopped);
        }
        pending.options = Some(options);
        drop(pending);
        notify_worker(&self.wake_tx)
    }

    pub fn execute_action(&self, request: ActionRequest) -> ActionResult {
        let (result_tx, result_rx) = bounded(1);
        match self
            .operation_tx
            .try_send(Operation::Action(request, result_tx))
        {
            Ok(()) => result_rx.recv().unwrap_or_else(|_| {
                ActionResult::failed(BackendError::internal(
                    "execute_action",
                    "backend worker stopped before returning an action result",
                ))
            }),
            Err(TrySendError::Full(_)) => ActionResult {
                status: ActionStatus::Busy,
                error: Some(BackendError::internal(
                    "execute_action",
                    "another privileged or destructive operation is still running",
                )),
            },
            Err(TrySendError::Disconnected(_)) => ActionResult::failed(BackendError::internal(
                "execute_action",
                "backend runtime is stopped",
            )),
        }
    }

    pub fn open_privileged_session(&self) -> PrivilegeResult {
        let (result_tx, result_rx) = bounded(1);
        match self
            .operation_tx
            .try_send(Operation::OpenPrivilege(result_tx))
        {
            Ok(()) => result_rx.recv().unwrap_or_else(|_| PrivilegeResult {
                state: PrivilegeState::Failed,
                error: Some(BackendError::internal(
                    "open_privileged_session",
                    "backend worker stopped before returning a privilege result",
                )),
            }),
            Err(TrySendError::Full(_)) => PrivilegeResult {
                state: PrivilegeState::Failed,
                error: Some(BackendError::internal(
                    "open_privileged_session",
                    "another privileged or destructive operation is still running",
                )),
            },
            Err(TrySendError::Disconnected(_)) => PrivilegeResult {
                state: PrivilegeState::Failed,
                error: Some(BackendError::internal(
                    "open_privileged_session",
                    "backend runtime is stopped",
                )),
            },
        }
    }

    pub fn shutdown(&self) -> Result<(), RuntimeError> {
        {
            let mut pending = self.pending.lock().map_err(|_| RuntimeError::Poisoned)?;
            if pending.shutdown {
                return Ok(());
            }
            pending.shutdown = true;
        }
        let _ = self.wake_tx.try_send(());
        let worker = self
            .worker
            .lock()
            .map_err(|_| RuntimeError::Poisoned)?
            .take();
        if worker.is_some_and(|worker| worker.join().is_err()) {
            diagnostics::event(
                Level::Error,
                "backend.shutdown_failed",
                "runtime",
                "backend worker panicked while shutting down",
                &[],
            );
            return Err(RuntimeError::WorkerPanicked);
        }
        diagnostics::event(
            Level::Info,
            "backend.stopped",
            "runtime",
            "backend runtime stopped",
            &[],
        );
        Ok(())
    }
}

impl Drop for BackendRuntime {
    fn drop(&mut self) {
        let _ = self.shutdown();
    }
}

fn notify_worker(wake_tx: &Sender<()>) -> Result<(), RuntimeError> {
    match wake_tx.try_send(()) {
        Ok(()) | Err(TrySendError::Full(())) => Ok(()),
        Err(TrySendError::Disconnected(())) => Err(RuntimeError::Stopped),
    }
}

fn worker_loop(
    mut provider: Box<dyn PlatformProvider>,
    mut options: BackendOptions,
    pending: Arc<Mutex<PendingRefresh>>,
    wake_rx: Receiver<()>,
    operation_rx: Receiver<Operation>,
    event_tx: Sender<BackendEvent>,
    event_drop_rx: Receiver<BackendEvent>,
) {
    let mut generations = HashMap::<PageId, u64>::new();
    let mut last_good = HashMap::<PageId, SnapshotData>::new();
    publish_latest(
        &event_tx,
        &event_drop_rx,
        BackendEvent::Capabilities(provider.capabilities()),
    );
    publish_latest(
        &event_tx,
        &event_drop_rx,
        BackendEvent::Diagnostics(diagnostics::status()),
    );

    // Match the archived task manager's activation-first behavior: make the visible page and
    // status sample available before warming hidden pages. Hidden-page prewarm remains bounded
    // and is interrupted at every page boundary by actions and explicit refreshes.
    let mut scheduled_pages = VecDeque::new();
    enqueue_page(&mut scheduled_pages, options.active_page);
    enqueue_page(&mut scheduled_pages, PageId::Performance);
    let mut prewarm_pages = PageId::ALL
        .into_iter()
        .filter(|page| !scheduled_pages.contains(page))
        .collect::<VecDeque<_>>();

    let mut last_periodic = Instant::now();
    let mut logged_page_errors = HashMap::<PageId, LoggedPageError>::new();
    loop {
        match operation_rx.try_recv() {
            Ok(operation) => {
                handle_operation(&mut *provider, operation, &event_tx, &event_drop_rx);
                continue;
            }
            Err(TryRecvError::Disconnected) => break,
            Err(TryRecvError::Empty) => {}
        }

        match wake_rx.try_recv() {
            Ok(()) => {
                if apply_pending_requests(
                    &pending,
                    &mut options,
                    &mut scheduled_pages,
                    &mut prewarm_pages,
                ) {
                    break;
                }
                last_periodic = Instant::now();
                continue;
            }
            Err(TryRecvError::Disconnected) => break,
            Err(TryRecvError::Empty) => {}
        }

        if let Some(page) = scheduled_pages.pop_front() {
            sample_pages(
                &mut *provider,
                [page],
                &mut generations,
                &mut last_good,
                &mut logged_page_errors,
                &event_tx,
                &event_drop_rx,
            );
            continue;
        }

        if let Some(page) = prewarm_pages.pop_front() {
            sample_pages(
                &mut *provider,
                [page],
                &mut generations,
                &mut last_good,
                &mut logged_page_errors,
                &event_tx,
                &event_drop_rx,
            );
            continue;
        }

        let timeout = options
            .update_speed
            .interval_millis()
            .map(|interval| Duration::from_millis(interval).saturating_sub(last_periodic.elapsed()))
            .unwrap_or(Duration::MAX);

        select! {
            recv(operation_rx) -> operation => {
                match operation {
                    Ok(operation) => handle_operation(
                        &mut *provider,
                        operation,
                        &event_tx,
                        &event_drop_rx,
                    ),
                    Err(_) => break,
                }
            }
            recv(wake_rx) -> wake => {
                if wake.is_err() {
                    break;
                }
                if apply_pending_requests(
                    &pending,
                    &mut options,
                    &mut scheduled_pages,
                    &mut prewarm_pages,
                ) {
                    break;
                }
                last_periodic = Instant::now();
            }
            default(timeout) => {
                enqueue_page(&mut scheduled_pages, options.active_page);
                enqueue_page(&mut scheduled_pages, PageId::Performance);
                last_periodic = Instant::now();
            }
        }
    }
}

fn enqueue_page(pages: &mut VecDeque<PageId>, page: PageId) {
    if !pages.contains(&page) {
        pages.push_back(page);
    }
}

fn promote_page(pages: &mut VecDeque<PageId>, page: PageId) {
    pages.retain(|candidate| *candidate != page);
    pages.push_front(page);
}

fn enqueue_requested_pages(
    scheduled_pages: &mut VecDeque<PageId>,
    prewarm_pages: &mut VecDeque<PageId>,
    requested_pages: &BTreeSet<PageId>,
    active_page: PageId,
) {
    if requested_pages.contains(&active_page) {
        prewarm_pages.retain(|candidate| *candidate != active_page);
        promote_page(scheduled_pages, active_page);
    }
    if requested_pages.contains(&PageId::Performance) {
        prewarm_pages.retain(|candidate| *candidate != PageId::Performance);
        enqueue_page(scheduled_pages, PageId::Performance);
    }
    for page in requested_pages {
        prewarm_pages.retain(|candidate| candidate != page);
        enqueue_page(scheduled_pages, *page);
    }
}

fn apply_pending_requests(
    pending: &Arc<Mutex<PendingRefresh>>,
    options: &mut BackendOptions,
    scheduled_pages: &mut VecDeque<PageId>,
    prewarm_pages: &mut VecDeque<PageId>,
) -> bool {
    let (requested_pages, replacement_options, shutdown) = {
        let Ok(mut request) = pending.lock() else {
            return true;
        };
        let pages = std::mem::take(&mut request.pages);
        let replacement_options = request.options.take();
        (pages, replacement_options, request.shutdown)
    };
    if shutdown {
        return true;
    }

    if let Some(replacement) = replacement_options {
        let activated_page =
            (replacement.active_page != options.active_page).then_some(replacement.active_page);
        *options = replacement;
        if let Some(page) = activated_page {
            prewarm_pages.retain(|candidate| *candidate != page);
            promote_page(scheduled_pages, page);
            prewarm_pages.retain(|candidate| *candidate != PageId::Performance);
            enqueue_page(scheduled_pages, PageId::Performance);
        }
    }
    enqueue_requested_pages(
        scheduled_pages,
        prewarm_pages,
        &requested_pages,
        options.active_page,
    );
    false
}

fn handle_operation(
    provider: &mut dyn PlatformProvider,
    operation: Operation,
    event_tx: &Sender<BackendEvent>,
    event_drop_rx: &Receiver<BackendEvent>,
) {
    match operation {
        Operation::Action(request, result_tx) => {
            let action = action_name(&request);
            let operation_id = diagnostics::next_operation_id();
            let started = Instant::now();
            diagnostics::event_with(
                Level::Info,
                "action.started",
                "runtime",
                "backend action started",
                Some(operation_id),
                None,
                &[Field::text("action", action)],
            );
            let publishes_diagnostics = matches!(
                request,
                ActionRequest::ConfigureDiagnostics { .. }
                    | ActionRequest::OpenDiagnosticFolder
                    | ActionRequest::SaveDiagnosticBundle
                    | ActionRequest::RestartWithDetailedDiagnostics
            );
            let result = diagnostics::with_operation_id(operation_id, || match request {
                ActionRequest::ConfigureDiagnostics {
                    detailed,
                    sensitive,
                } => {
                    diagnostics::configure(detailed, sensitive);
                    ActionResult::succeeded()
                }
                ActionRequest::RecordUiError { message, stack } => {
                    let mut fields = vec![Field::sensitive_text("message", message)];
                    if let Some(stack) = stack {
                        fields.push(Field::sensitive_text("stack", stack));
                    }
                    diagnostics::event(
                        Level::Error,
                        "ui.unhandled_error",
                        "flutter",
                        "Flutter reported an unhandled error",
                        &fields,
                    );
                    ActionResult::succeeded()
                }
                request => provider.execute_action(request),
            });
            let mut fields = vec![
                Field::text("action", action),
                Field::text(
                    "status",
                    format!("{:?}", result.status).to_ascii_lowercase(),
                ),
            ];
            if let Some(error) = &result.error {
                fields.extend([
                    Field::text("error_domain", error.domain.clone()),
                    Field::signed("error_code", error.code),
                    Field::text("error_context", error.context.clone()),
                    Field::sensitive_text("error_message", error.message.clone()),
                ]);
            }
            diagnostics::event_with(
                if result.status == ActionStatus::Succeeded {
                    Level::Info
                } else {
                    Level::Warn
                },
                "action.completed",
                "runtime",
                "backend action completed",
                Some(operation_id),
                Some(elapsed_millis(started)),
                &fields,
            );
            if publishes_diagnostics {
                publish_latest(
                    event_tx,
                    event_drop_rx,
                    BackendEvent::Diagnostics(diagnostics::status()),
                );
            }
            let _ = result_tx.send(result);
        }
        Operation::OpenPrivilege(result_tx) => {
            let result = provider.open_privileged_session();
            publish_latest(
                event_tx,
                event_drop_rx,
                BackendEvent::PrivilegeChanged(result.clone()),
            );
            let _ = result_tx.send(result);
        }
    }
}

fn sample_pages(
    provider: &mut dyn PlatformProvider,
    pages: impl IntoIterator<Item = PageId>,
    generations: &mut HashMap<PageId, u64>,
    last_good: &mut HashMap<PageId, SnapshotData>,
    logged_page_errors: &mut HashMap<PageId, LoggedPageError>,
    event_tx: &Sender<BackendEvent>,
    event_drop_rx: &Receiver<BackendEvent>,
) {
    for page in pages {
        let started = Instant::now();
        let generation = generations.entry(page).or_default();
        *generation = generation.saturating_add(1);
        match provider.sample(page) {
            Ok(candidate) if candidate.page() == page => {
                if logged_page_errors.remove(&page).is_some() {
                    diagnostics::event_with(
                        Level::Info,
                        "sampling.recovered",
                        "runtime",
                        "page sampling recovered after an error",
                        None,
                        Some(elapsed_millis(started)),
                        &[Field::text("page", page_name(page))],
                    );
                } else {
                    diagnostics::event_with(
                        Level::Debug,
                        "sampling.completed",
                        "runtime",
                        "page sampling completed",
                        None,
                        Some(elapsed_millis(started)),
                        &[
                            Field::text("page", page_name(page)),
                            Field::unsigned("generation", *generation),
                        ],
                    );
                }
                last_good.insert(page, candidate.clone());
                publish_latest(
                    event_tx,
                    event_drop_rx,
                    candidate.into_event(SnapshotMeta::fresh(*generation)),
                );
            }
            Ok(candidate) => {
                let error = BackendError::internal(
                    "sample_page",
                    format!(
                        "platform provider returned {:?} data for {page:?}",
                        candidate.page()
                    ),
                );
                record_sampling_error(page, &error, started, logged_page_errors);
                publish_error(page, *generation, error, last_good, event_tx, event_drop_rx);
            }
            Err(error) => {
                record_sampling_error(page, &error, started, logged_page_errors);
                publish_error(page, *generation, error, last_good, event_tx, event_drop_rx)
            }
        }
    }
}

fn record_sampling_error(
    page: PageId,
    error: &BackendError,
    started: Instant,
    logged: &mut HashMap<PageId, LoggedPageError>,
) {
    let now = Instant::now();
    let should_log = logged.get(&page).is_none_or(|previous| {
        previous.domain != error.domain
            || previous.code != error.code
            || previous.context != error.context
            || now.duration_since(previous.logged_at) >= REPEATED_ERROR_LOG_INTERVAL
    });
    if !should_log {
        return;
    }
    logged.insert(
        page,
        LoggedPageError {
            domain: error.domain.clone(),
            code: error.code,
            context: error.context.clone(),
            logged_at: now,
        },
    );
    diagnostics::event_with(
        if error.domain == "capability" {
            Level::Debug
        } else {
            Level::Warn
        },
        "sampling.failed",
        "runtime",
        "page sampling failed; the last trusted snapshot is retained",
        None,
        Some(elapsed_millis(started)),
        &[
            Field::text("page", page_name(page)),
            Field::text("error_domain", error.domain.clone()),
            Field::signed("error_code", error.code),
            Field::text("error_context", error.context.clone()),
            Field::sensitive_text("error_message", error.message.clone()),
        ],
    );
}

const fn page_name(page: PageId) -> &'static str {
    match page {
        PageId::Applications => "applications",
        PageId::Processes => "processes",
        PageId::Performance => "performance",
        PageId::Cpu => "cpu",
        PageId::Gpu => "gpu",
        PageId::Network => "network",
        PageId::Users => "users",
    }
}

const fn action_name(request: &ActionRequest) -> &'static str {
    match request {
        ActionRequest::ShowAboutDialog { .. } => "show_about_dialog",
        ActionRequest::ShowRunDialog => "show_run_dialog",
        ActionRequest::ConfigureDiagnostics { .. } => "configure_diagnostics",
        ActionRequest::OpenDiagnosticFolder => "open_diagnostic_folder",
        ActionRequest::SaveDiagnosticBundle => "save_diagnostic_bundle",
        ActionRequest::RestartWithDetailedDiagnostics => "restart_with_detailed_diagnostics",
        ActionRequest::RecordUiError { .. } => "record_ui_error",
        ActionRequest::RunTask { .. } => "run_task",
        ActionRequest::EndProcess { .. } => "end_process",
        ActionRequest::SetPriority { .. } => "set_priority",
        ActionRequest::SetNice { .. } => "set_nice",
        ActionRequest::SetAffinity { .. } => "set_affinity",
        ActionRequest::OpenFileLocation { .. } => "open_file_location",
        ActionRequest::Window { .. } => "window",
        ActionRequest::ArrangeWindows { .. } => "arrange_windows",
        ActionRequest::UserSession { .. } => "user_session",
    }
}

fn elapsed_millis(started: Instant) -> u64 {
    u64::try_from(started.elapsed().as_millis()).unwrap_or(u64::MAX)
}

fn publish_error(
    page: PageId,
    generation: u64,
    error: BackendError,
    last_good: &HashMap<PageId, SnapshotData>,
    event_tx: &Sender<BackendEvent>,
    event_drop_rx: &Receiver<BackendEvent>,
) {
    let meta = SnapshotMeta::stale_with_error(generation, error);
    let event = match last_good.get(&page).cloned() {
        Some(snapshot) => snapshot.into_event(meta),
        None => BackendEvent::PageUnavailable { page, meta },
    };
    publish_latest(event_tx, event_drop_rx, event);
}

fn publish_latest(
    event_tx: &Sender<BackendEvent>,
    event_drop_rx: &Receiver<BackendEvent>,
    mut event: BackendEvent,
) {
    loop {
        match event_tx.try_send(event) {
            Ok(()) | Err(TrySendError::Disconnected(_)) => return,
            Err(TrySendError::Full(returned)) => {
                event = returned;
                let _ = event_drop_rx.try_recv();
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use std::sync::{Arc, Mutex, mpsc};
    use std::thread;
    use std::time::Duration;

    use crate::{
        ActionRequest, ActionResult, ApplicationsData, Availability, BackendError, BackendEvent,
        BackendOptions, PageCapability, PageId, PlatformCapabilities, PlatformKind,
        ProcessIdentity, SnapshotData,
    };

    use super::BackendRuntime;

    struct TestProvider {
        attempts: Arc<Mutex<u32>>,
    }

    #[derive(Clone, Copy, Debug, Eq, PartialEq)]
    enum WorkerTrace {
        Sample(PageId),
        Action,
    }

    struct SlowTraceProvider {
        trace: Arc<Mutex<Vec<WorkerTrace>>>,
        sampled: mpsc::Sender<PageId>,
        slow_first_sample: bool,
    }

    impl crate::PlatformProvider for TestProvider {
        fn capabilities(&self) -> PlatformCapabilities {
            PlatformCapabilities {
                protocol_version: 1,
                platform: PlatformKind::Linux,
                architecture: crate::Architecture::X86_64,
                pages: PageId::ALL
                    .into_iter()
                    .map(|page| PageCapability {
                        page,
                        availability: Availability::Supported,
                        columns: Vec::new(),
                        actions: Vec::new(),
                        detail: None,
                    })
                    .collect(),
                privileged_details: Availability::Unsupported,
                tray: Availability::Unsupported,
                compositor: None,
                logical_processors: vec![0],
            }
        }

        fn sample(&mut self, page: PageId) -> Result<SnapshotData, BackendError> {
            if page != PageId::Applications {
                return Err(BackendError::unsupported("test", "not implemented"));
            }
            let mut attempts = self.attempts.lock().expect("test lock");
            *attempts += 1;
            if *attempts == 1 {
                Ok(SnapshotData::Applications(ApplicationsData {
                    rows: Vec::new(),
                }))
            } else {
                Err(BackendError::internal("test", "injected failure"))
            }
        }

        fn execute_action(&mut self, _: ActionRequest) -> ActionResult {
            ActionResult::succeeded()
        }
    }

    impl crate::PlatformProvider for SlowTraceProvider {
        fn capabilities(&self) -> PlatformCapabilities {
            PlatformCapabilities {
                protocol_version: 1,
                platform: PlatformKind::Linux,
                architecture: crate::Architecture::X86_64,
                pages: Vec::new(),
                privileged_details: Availability::Unsupported,
                tray: Availability::Unsupported,
                compositor: None,
                logical_processors: vec![0],
            }
        }

        fn sample(&mut self, page: PageId) -> Result<SnapshotData, BackendError> {
            self.trace
                .lock()
                .expect("trace lock")
                .push(WorkerTrace::Sample(page));
            let _ = self.sampled.send(page);
            if self.slow_first_sample {
                self.slow_first_sample = false;
                thread::sleep(Duration::from_millis(80));
            }
            Err(BackendError::unsupported("trace sample", "not implemented"))
        }

        fn execute_action(&mut self, _: ActionRequest) -> ActionResult {
            self.trace
                .lock()
                .expect("trace lock")
                .push(WorkerTrace::Action);
            ActionResult::succeeded()
        }
    }

    #[test]
    fn failed_refresh_republishes_the_last_good_snapshot_as_stale() {
        let attempts = Arc::new(Mutex::new(0));
        let runtime = BackendRuntime::start(
            Box::new(TestProvider {
                attempts: Arc::clone(&attempts),
            }),
            BackendOptions::default(),
        );
        let events = runtime.events();
        let _ = events
            .recv_timeout(Duration::from_secs(1))
            .expect("capabilities");
        let first = loop {
            let event = events
                .recv_timeout(Duration::from_secs(1))
                .expect("initial events");
            if matches!(event, BackendEvent::Applications(_)) {
                break event;
            }
        };
        assert!(matches!(
            first,
            BackendEvent::Applications(ref snapshot) if !snapshot.meta.stale
        ));
        runtime
            .request_refresh(Some(PageId::Applications))
            .expect("refresh request");
        let stale = loop {
            let event = events
                .recv_timeout(Duration::from_secs(1))
                .expect("stale event");
            if matches!(event, BackendEvent::Applications(_)) {
                break event;
            }
        };
        assert!(matches!(
            stale,
            BackendEvent::Applications(ref snapshot)
                if snapshot.meta.stale && snapshot.meta.error.is_some()
        ));
        runtime.shutdown().expect("clean shutdown");
    }

    #[test]
    fn action_channel_returns_results_without_pid_only_fallback() {
        let runtime = BackendRuntime::start(
            Box::new(TestProvider {
                attempts: Arc::new(Mutex::new(0)),
            }),
            BackendOptions::default(),
        );
        let result = runtime.execute_action(ActionRequest::EndProcess {
            identity: ProcessIdentity {
                pid: 10,
                start_time: 20,
            },
            include_descendants: false,
        });
        assert_eq!(result, ActionResult::succeeded());
        runtime.shutdown().expect("clean shutdown");
    }

    #[test]
    fn visible_page_precedes_hidden_prewarm_and_actions_interrupt_between_pages() {
        let trace = Arc::new(Mutex::new(Vec::new()));
        let (sampled_tx, sampled_rx) = mpsc::channel();
        let runtime = BackendRuntime::start(
            Box::new(SlowTraceProvider {
                trace: Arc::clone(&trace),
                sampled: sampled_tx,
                slow_first_sample: true,
            }),
            BackendOptions::default(),
        );
        assert_eq!(
            sampled_rx
                .recv_timeout(Duration::from_secs(1))
                .expect("visible-page sample started"),
            PageId::Applications
        );

        assert_eq!(
            runtime.execute_action(ActionRequest::ShowRunDialog),
            ActionResult::succeeded()
        );

        assert_eq!(
            sampled_rx
                .recv_timeout(Duration::from_secs(1))
                .expect("status sample followed action"),
            PageId::Performance
        );
        let trace = trace.lock().expect("trace lock").clone();
        let action_index = trace
            .iter()
            .position(|event| *event == WorkerTrace::Action)
            .expect("action trace");
        assert_eq!(action_index, 1, "trace was {trace:?}");
        assert_eq!(
            trace
                .iter()
                .filter_map(|event| match event {
                    WorkerTrace::Sample(page) => Some(*page),
                    WorkerTrace::Action => None,
                })
                .take(2)
                .collect::<Vec<_>>(),
            vec![PageId::Applications, PageId::Performance]
        );
        runtime.shutdown().expect("clean shutdown");
    }

    #[test]
    fn activating_a_page_promotes_it_ahead_of_pending_prewarm() {
        let trace = Arc::new(Mutex::new(Vec::new()));
        let (sampled_tx, sampled_rx) = mpsc::channel();
        let runtime = BackendRuntime::start(
            Box::new(SlowTraceProvider {
                trace,
                sampled: sampled_tx,
                slow_first_sample: true,
            }),
            BackendOptions::default(),
        );
        assert_eq!(
            sampled_rx
                .recv_timeout(Duration::from_secs(1))
                .expect("initial visible-page sample"),
            PageId::Applications
        );
        runtime
            .update_options(BackendOptions {
                active_page: PageId::Processes,
                ..BackendOptions::default()
            })
            .expect("activate process page");

        assert_eq!(
            sampled_rx
                .recv_timeout(Duration::from_secs(1))
                .expect("activated-page sample"),
            PageId::Processes
        );
        runtime.shutdown().expect("clean shutdown");
    }
}
