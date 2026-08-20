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

use std::collections::{BTreeSet, HashMap};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant};

use crossbeam_channel::{Receiver, Sender, TrySendError, bounded, select};
use thiserror::Error;

use crate::{
    ActionRequest, ActionResult, ActionStatus, BackendError, BackendEvent, BackendOptions, PageId,
    PlatformProvider, PrivilegeResult, PrivilegeState, SnapshotData, SnapshotMeta,
};

const EVENT_CAPACITY: usize = 16;

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
            return Err(RuntimeError::WorkerPanicked);
        }
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
    sample_pages(
        &mut *provider,
        PageId::ALL,
        &mut generations,
        &mut last_good,
        &event_tx,
        &event_drop_rx,
    );

    let mut last_periodic = Instant::now();
    loop {
        let timeout = options
            .update_speed
            .interval_millis()
            .map(|interval| Duration::from_millis(interval).saturating_sub(last_periodic.elapsed()))
            .unwrap_or(Duration::MAX);

        select! {
            recv(operation_rx) -> operation => {
                match operation {
                    Ok(Operation::Action(request, result_tx)) => {
                        let _ = result_tx.send(provider.execute_action(request));
                    }
                    Ok(Operation::OpenPrivilege(result_tx)) => {
                        let result = provider.open_privileged_session();
                        publish_latest(
                            &event_tx,
                            &event_drop_rx,
                            BackendEvent::PrivilegeChanged(result.clone()),
                        );
                        let _ = result_tx.send(result);
                    }
                    Err(_) => break,
                }
            }
            recv(wake_rx) -> wake => {
                if wake.is_err() {
                    break;
                }
                let (requested_pages, replacement_options, shutdown) = {
                    let Ok(mut request) = pending.lock() else {
                        break;
                    };
                    let pages = std::mem::take(&mut request.pages);
                    let replacement_options = request.options.take();
                    (pages, replacement_options, request.shutdown)
                };
                if shutdown {
                    break;
                }
                if let Some(replacement) = replacement_options {
                    options = replacement;
                }
                if !requested_pages.is_empty() {
                    sample_pages(
                        &mut *provider,
                        requested_pages,
                        &mut generations,
                        &mut last_good,
                        &event_tx,
                        &event_drop_rx,
                    );
                    last_periodic = Instant::now();
                }
            }
            default(timeout) => {
                let pages = if options.active_page == PageId::Performance {
                    vec![PageId::Performance]
                } else {
                    vec![options.active_page, PageId::Performance]
                };
                sample_pages(
                    &mut *provider,
                    pages,
                    &mut generations,
                    &mut last_good,
                    &event_tx,
                    &event_drop_rx,
                );
                last_periodic = Instant::now();
            }
        }
    }
}

fn sample_pages(
    provider: &mut dyn PlatformProvider,
    pages: impl IntoIterator<Item = PageId>,
    generations: &mut HashMap<PageId, u64>,
    last_good: &mut HashMap<PageId, SnapshotData>,
    event_tx: &Sender<BackendEvent>,
    event_drop_rx: &Receiver<BackendEvent>,
) {
    for page in pages {
        let generation = generations.entry(page).or_default();
        *generation = generation.saturating_add(1);
        match provider.sample(page) {
            Ok(candidate) if candidate.page() == page => {
                last_good.insert(page, candidate.clone());
                publish_latest(
                    event_tx,
                    event_drop_rx,
                    candidate.into_event(SnapshotMeta::fresh(*generation)),
                );
            }
            Ok(candidate) => {
                publish_error(
                    page,
                    *generation,
                    BackendError::internal(
                        "sample_page",
                        format!(
                            "platform provider returned {:?} data for {page:?}",
                            candidate.page()
                        ),
                    ),
                    last_good,
                    event_tx,
                    event_drop_rx,
                );
            }
            Err(error) => {
                publish_error(page, *generation, error, last_good, event_tx, event_drop_rx)
            }
        }
    }
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
    use std::sync::{Arc, Mutex};
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
}
