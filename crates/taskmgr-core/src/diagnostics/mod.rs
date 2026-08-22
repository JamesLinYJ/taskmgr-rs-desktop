// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 跨平台结构化诊断日志
//
//   文件:       crates/taskmgr-core/src/diagnostics/mod.rs
//
//   日期:       2026年08月22日
//   环境:       Windows 11 x86_64；Rust 1.97.1
//   作者:       OpenAI Codex
//   协助:       —
//   参考标准:   Rust std::sync；JSON Lines；项目有界后台线程约定
// --------------------------------------------------------------------------

//! 进程级、默认脱敏的结构化诊断运行时。
//!
//! 调用线程只构造一条拥有所有数据的记录并尝试写入有界通道。一个长期写入线程负责
//! JSON 序列化、定时落盘、轮转和保留；错误/警告使用独立优先通道。队列拥塞时绝不
//! 阻塞采样线程，而是累加可见的丢弃计数。敏感字段和详细级别只对当前进程会话生效。

mod archive;

use std::cell::Cell;
use std::env;
use std::ffi::OsString;
use std::fs::{self, File, OpenOptions};
use std::io::{self, BufWriter, Read, Write};
use std::panic::Location;
use std::path::{Path, PathBuf};
use std::process;
use std::sync::atomic::{AtomicBool, AtomicU8, AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use crossbeam_channel::{Receiver, Sender, TrySendError, bounded, select_biased, tick};
use serde::Serialize;
use serde_json::{Map, Value, json};

use self::archive::StoredZipWriter;
use crate::{DiagnosticLevel, DiagnosticStatus};

const LOG_SCHEMA_VERSION: u16 = 1;
const BUNDLE_SCHEMA_VERSION: u16 = 1;
const REGULAR_QUEUE_CAPACITY: usize = 4_096;
const PRIORITY_QUEUE_CAPACITY: usize = 128;
const CONTROL_QUEUE_CAPACITY: usize = 8;
const LOG_PART_LIMIT_BYTES: u64 = 10 * 1024 * 1024;
const LOG_ROOT_LIMIT_BYTES: u64 = 200 * 1024 * 1024;
const LOG_SESSION_LIMIT: usize = 10;
const FLUSH_INTERVAL: Duration = Duration::from_secs(1);
const CONTROL_TIMEOUT: Duration = Duration::from_secs(5);

static DIAGNOSTICS: OnceLock<Diagnostics> = OnceLock::new();
static PANIC_HOOK_INSTALLED: OnceLock<()> = OnceLock::new();
static SESSION_SEQUENCE: AtomicU64 = AtomicU64::new(0);

thread_local! {
    static CURRENT_OPERATION_ID: Cell<Option<u64>> = const { Cell::new(None) };
}

struct OperationContextGuard {
    previous: Option<u64>,
}

impl Drop for OperationContextGuard {
    fn drop(&mut self) {
        CURRENT_OPERATION_ID.set(self.previous);
    }
}

#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd)]
#[repr(u8)]
pub enum Level {
    Error = 1,
    Warn = 2,
    Info = 3,
    Debug = 4,
    Trace = 5,
}

impl Level {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Error => "error",
            Self::Warn => "warn",
            Self::Info => "info",
            Self::Debug => "debug",
            Self::Trace => "trace",
        }
    }

    const fn configured(self) -> DiagnosticLevel {
        match self {
            Self::Debug => DiagnosticLevel::Debug,
            Self::Trace => DiagnosticLevel::Trace,
            Self::Error | Self::Warn | Self::Info => DiagnosticLevel::Info,
        }
    }

    const fn from_u8(value: u8) -> Self {
        match value {
            4 => Self::Debug,
            5 => Self::Trace,
            _ => Self::Info,
        }
    }
}

#[derive(Clone, Debug)]
pub enum FieldValue {
    Text(String),
    Unsigned(u64),
    Signed(i64),
    Boolean(bool),
}

#[derive(Clone, Debug)]
pub struct Field {
    name: &'static str,
    value: FieldValue,
    sensitive: bool,
}

impl Field {
    pub fn text(name: &'static str, value: impl Into<String>) -> Self {
        Self {
            name,
            value: FieldValue::Text(value.into()),
            sensitive: false,
        }
    }

    pub fn sensitive_text(name: &'static str, value: impl Into<String>) -> Self {
        Self {
            name,
            value: FieldValue::Text(value.into()),
            sensitive: true,
        }
    }

    pub const fn unsigned(name: &'static str, value: u64) -> Self {
        Self {
            name,
            value: FieldValue::Unsigned(value),
            sensitive: false,
        }
    }

    pub const fn signed(name: &'static str, value: i64) -> Self {
        Self {
            name,
            value: FieldValue::Signed(value),
            sensitive: false,
        }
    }

    pub const fn boolean(name: &'static str, value: bool) -> Self {
        Self {
            name,
            value: FieldValue::Boolean(value),
            sensitive: false,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
struct DiagnosticConfig {
    level: Level,
    sensitive: bool,
    root_override: Option<PathBuf>,
    requested_session: Option<String>,
    parse_warnings: Vec<String>,
}

impl DiagnosticConfig {
    fn from_environment() -> Self {
        Self::parse(env::args_os().skip(1))
    }

    fn parse(arguments: impl IntoIterator<Item = OsString>) -> Self {
        let mut level = Level::Info;
        let mut sensitive = false;
        let mut root_override = None;
        let mut requested_session = None;
        let mut parse_warnings = Vec::new();

        for argument in arguments {
            let value = argument.to_string_lossy();
            match value.as_ref() {
                "--diagnostic" => level = Level::Trace,
                "--diagnostic-sensitive" => {
                    level = Level::Trace;
                    sensitive = true;
                }
                _ if value.starts_with("--diagnostic=") => {
                    match value.trim_start_matches("--diagnostic=") {
                        "debug" => level = Level::Debug,
                        "trace" => level = Level::Trace,
                        _ => parse_warnings.push(
                            "ignored an invalid diagnostic level; expected debug or trace"
                                .to_string(),
                        ),
                    }
                }
                _ if value.starts_with("--diagnostic-dir=") => {
                    let path = PathBuf::from(value.trim_start_matches("--diagnostic-dir="));
                    if path.is_absolute() {
                        root_override = Some(path);
                    } else {
                        parse_warnings
                            .push("ignored a relative diagnostic directory override".to_string());
                    }
                }
                _ if value.starts_with("--diagnostic-session=") => {
                    let candidate = value.trim_start_matches("--diagnostic-session=");
                    if valid_session_id(candidate) {
                        requested_session = Some(candidate.to_string());
                    } else {
                        parse_warnings
                            .push("ignored an invalid diagnostic session identifier".to_string());
                    }
                }
                _ => {}
            }
        }

        Self {
            level,
            sensitive,
            root_override,
            requested_session,
            parse_warnings,
        }
    }
}

#[derive(Serialize)]
struct SourceLocation {
    file: String,
    line: u32,
}

#[derive(Serialize)]
struct LogRecord {
    schema_version: u16,
    timestamp_unix_ms: u64,
    monotonic_ms: u64,
    sequence: u64,
    session_id: String,
    pid: u32,
    thread_name: Option<String>,
    level: &'static str,
    target: &'static str,
    event: &'static str,
    message: &'static str,
    source: SourceLocation,
    operation_id: Option<u64>,
    duration_ms: Option<u64>,
    privacy: &'static str,
    fields: Map<String, Value>,
}

struct SharedState {
    started: Instant,
    sequence: AtomicU64,
    operation_sequence: AtomicU64,
    level: AtomicU8,
    sensitive: AtomicBool,
    sensitive_ever_enabled: AtomicBool,
    dropped_regular: AtomicU64,
    dropped_priority: AtomicU64,
    dropped_total: AtomicU64,
    file_active: AtomicBool,
    shutdown: AtomicBool,
    session_id: String,
    session_directory: Option<PathBuf>,
    sink_error: Mutex<Option<String>>,
}

impl SharedState {
    fn allows(&self, level: Level) -> bool {
        level as u8 <= self.level.load(Ordering::Relaxed)
    }
}

struct Diagnostics {
    shared: Arc<SharedState>,
    regular_sender: Sender<LogRecord>,
    priority_sender: Sender<LogRecord>,
    control_sender: Sender<WriterControl>,
    writer_thread: Mutex<Option<JoinHandle<()>>>,
}

enum WriterControl {
    Flush(Sender<Result<(), String>>),
    Shutdown(Sender<()>),
}

struct FileSink {
    writer: BufWriter<File>,
    root_directory: PathBuf,
    session_directory: PathBuf,
    process_id: u32,
    part: u32,
    bytes_written: u64,
}

pub fn initialize() {
    if DIAGNOSTICS.get().is_some() {
        return;
    }
    let config = DiagnosticConfig::from_environment();
    let warnings = config.parse_warnings.clone();
    let diagnostics = Diagnostics::new(config);
    if DIAGNOSTICS.set(diagnostics).is_err() {
        return;
    }
    install_panic_hook();
    event(
        Level::Info,
        "diagnostics.session_started",
        "diagnostics",
        "diagnostic session started",
        &[
            Field::text("app_version", env!("CARGO_PKG_VERSION")),
            Field::text("target_arch", env::consts::ARCH),
            Field::text("target_os", env::consts::OS),
            Field::text("target_family", env::consts::FAMILY),
            Field::unsigned("pointer_width", u64::from(usize::BITS)),
        ],
    );
    for warning in warnings {
        event(
            Level::Warn,
            "diagnostics.argument_ignored",
            "diagnostics",
            "an invalid diagnostic command-line option was ignored",
            &[Field::sensitive_text("detail", warning)],
        );
    }
    if let Some(error) = status().sink_error {
        event(
            Level::Warn,
            "diagnostics.storage_degraded",
            "diagnostics",
            "file diagnostics are unavailable or degraded",
            &[Field::sensitive_text("detail", error)],
        );
    }
}

impl Diagnostics {
    fn new(config: DiagnosticConfig) -> Self {
        let mut startup_errors = Vec::new();
        let (root_directory, session_directory, session_id) =
            prepare_directories(&config, &mut startup_errors);
        let file_sink = match (&root_directory, &session_directory) {
            (Some(root), Some(session)) => match FileSink::open(root, session, process::id()) {
                Ok(sink) => Some(sink),
                Err(error) => {
                    startup_errors.push(format!("unable to open diagnostic log: {error}"));
                    None
                }
            },
            _ => None,
        };
        let shared = Arc::new(SharedState {
            started: Instant::now(),
            sequence: AtomicU64::new(0),
            operation_sequence: AtomicU64::new(u64::from(process::id()) << 32),
            level: AtomicU8::new(config.level as u8),
            sensitive: AtomicBool::new(config.sensitive),
            sensitive_ever_enabled: AtomicBool::new(config.sensitive),
            dropped_regular: AtomicU64::new(0),
            dropped_priority: AtomicU64::new(0),
            dropped_total: AtomicU64::new(0),
            file_active: AtomicBool::new(file_sink.is_some()),
            shutdown: AtomicBool::new(false),
            session_id,
            session_directory,
            sink_error: Mutex::new(startup_errors.first().cloned()),
        });

        let (regular_sender, regular_receiver) = bounded(REGULAR_QUEUE_CAPACITY);
        let (priority_sender, priority_receiver) = bounded(PRIORITY_QUEUE_CAPACITY);
        let (control_sender, control_receiver) = bounded(CONTROL_QUEUE_CAPACITY);
        let writer_shared = Arc::clone(&shared);
        let writer_thread = thread::Builder::new()
            .name("taskmgr-rs-diagnostics".to_string())
            .spawn(move || {
                writer_loop(
                    writer_shared,
                    file_sink,
                    regular_receiver,
                    priority_receiver,
                    control_receiver,
                );
            });
        let writer_thread = match writer_thread {
            Ok(thread) => Some(thread),
            Err(error) => {
                shared.file_active.store(false, Ordering::Release);
                if let Ok(mut sink_error) = shared.sink_error.lock() {
                    *sink_error = Some(format!("unable to start diagnostic writer: {error}"));
                }
                None
            }
        };

        Self {
            shared,
            regular_sender,
            priority_sender,
            control_sender,
            writer_thread: Mutex::new(writer_thread),
        }
    }

    fn enqueue(&self, record: LogRecord, level: Level) {
        if self.shared.shutdown.load(Ordering::Acquire) {
            return;
        }
        let (sender, dropped) = if level <= Level::Warn {
            (&self.priority_sender, &self.shared.dropped_priority)
        } else {
            (&self.regular_sender, &self.shared.dropped_regular)
        };
        match sender.try_send(record) {
            Ok(()) => {}
            Err(TrySendError::Full(_)) | Err(TrySendError::Disconnected(_)) => {
                dropped.fetch_add(1, Ordering::Relaxed);
                self.shared.dropped_total.fetch_add(1, Ordering::Relaxed);
            }
        }
    }

    fn flush(&self) -> Result<(), String> {
        let (sender, receiver) = bounded(1);
        self.control_sender
            .send_timeout(WriterControl::Flush(sender), CONTROL_TIMEOUT)
            .map_err(|_| "diagnostic writer did not accept a flush request".to_string())?;
        receiver
            .recv_timeout(CONTROL_TIMEOUT)
            .map_err(|_| "diagnostic writer flush timed out".to_string())?
    }

    fn shutdown(&self) {
        if self.shared.shutdown.swap(true, Ordering::AcqRel) {
            return;
        }
        let (sender, receiver) = bounded(1);
        if self
            .control_sender
            .send_timeout(WriterControl::Shutdown(sender), CONTROL_TIMEOUT)
            .is_ok()
        {
            let _ = receiver.recv_timeout(CONTROL_TIMEOUT);
        }
        if let Ok(mut thread) = self.writer_thread.lock()
            && let Some(thread) = thread.take()
        {
            let _ = thread.join();
        }
    }
}

pub fn enabled(level: Level) -> bool {
    DIAGNOSTICS
        .get()
        .is_some_and(|runtime| runtime.shared.allows(level))
}

pub fn next_operation_id() -> u64 {
    DIAGNOSTICS
        .get()
        .map(|runtime| {
            runtime
                .shared
                .operation_sequence
                .fetch_add(1, Ordering::Relaxed)
                .wrapping_add(1)
        })
        .unwrap_or(0)
}

pub fn with_operation_id<T>(operation_id: u64, action: impl FnOnce() -> T) -> T {
    let previous = CURRENT_OPERATION_ID.replace(Some(operation_id));
    let _guard = OperationContextGuard { previous };
    action()
}

#[track_caller]
pub fn event(
    level: Level,
    event_name: &'static str,
    target: &'static str,
    message: &'static str,
    fields: &[Field],
) {
    event_with(level, event_name, target, message, None, None, fields);
}

#[track_caller]
pub fn event_with(
    level: Level,
    event_name: &'static str,
    target: &'static str,
    message: &'static str,
    operation_id: Option<u64>,
    duration_ms: Option<u64>,
    fields: &[Field],
) {
    let Some(runtime) = DIAGNOSTICS.get() else {
        return;
    };
    if !runtime.shared.allows(level) {
        return;
    }
    let location = Location::caller();
    let record = build_record(
        &runtime.shared,
        level,
        event_name,
        target,
        message,
        operation_id.or_else(|| CURRENT_OPERATION_ID.get()),
        duration_ms,
        fields,
        location.file(),
        location.line(),
    );
    runtime.enqueue(record, level);
}

#[allow(clippy::too_many_arguments)]
fn build_record(
    shared: &SharedState,
    level: Level,
    event_name: &'static str,
    target: &'static str,
    message: &'static str,
    operation_id: Option<u64>,
    duration_ms: Option<u64>,
    fields: &[Field],
    source_file: &str,
    source_line: u32,
) -> LogRecord {
    let sensitive = shared.sensitive.load(Ordering::Relaxed);
    let mut serialized_fields = Map::new();
    for field in fields {
        if field.sensitive && !sensitive {
            continue;
        }
        let value = match &field.value {
            FieldValue::Text(value) => Value::String(value.clone()),
            FieldValue::Unsigned(value) => Value::from(*value),
            FieldValue::Signed(value) => Value::from(*value),
            FieldValue::Boolean(value) => Value::from(*value),
        };
        serialized_fields.insert(field.name.to_string(), value);
    }
    let current_thread = thread::current();
    LogRecord {
        schema_version: LOG_SCHEMA_VERSION,
        timestamp_unix_ms: unix_time_millis(),
        monotonic_ms: u64::try_from(shared.started.elapsed().as_millis()).unwrap_or(u64::MAX),
        sequence: 0,
        session_id: shared.session_id.clone(),
        pid: process::id(),
        thread_name: current_thread.name().map(ToOwned::to_owned),
        level: level.as_str(),
        target,
        event: event_name,
        message,
        source: SourceLocation {
            file: normalized_source_path(source_file),
            line: source_line,
        },
        operation_id,
        duration_ms,
        privacy: if sensitive { "sensitive" } else { "redacted" },
        fields: serialized_fields,
    }
}

pub fn status() -> DiagnosticStatus {
    let Some(runtime) = DIAGNOSTICS.get() else {
        return DiagnosticStatus {
            level: DiagnosticLevel::Info,
            sensitive: false,
            session_id: String::new(),
            directory: None,
            file_active: false,
            sink_error: Some("diagnostics have not been initialized".to_string()),
            dropped_events: 0,
            export_requires_privacy_warning: false,
        };
    };
    DiagnosticStatus {
        level: Level::from_u8(runtime.shared.level.load(Ordering::Relaxed)).configured(),
        sensitive: runtime.shared.sensitive.load(Ordering::Relaxed),
        session_id: runtime.shared.session_id.clone(),
        directory: runtime
            .shared
            .session_directory
            .as_ref()
            .map(|path| path.to_string_lossy().into_owned()),
        file_active: runtime.shared.file_active.load(Ordering::Acquire),
        sink_error: runtime
            .shared
            .sink_error
            .lock()
            .ok()
            .and_then(|error| error.clone()),
        dropped_events: runtime.shared.dropped_total.load(Ordering::Relaxed),
        export_requires_privacy_warning: runtime
            .shared
            .sensitive_ever_enabled
            .load(Ordering::Acquire),
    }
}

pub fn configure(detailed: bool, sensitive: bool) -> DiagnosticStatus {
    if let Some(runtime) = DIAGNOSTICS.get() {
        let level = if detailed { Level::Trace } else { Level::Info };
        runtime.shared.level.store(level as u8, Ordering::Release);
        let sensitive = detailed && sensitive;
        runtime.shared.sensitive.store(sensitive, Ordering::Release);
        if sensitive {
            runtime
                .shared
                .sensitive_ever_enabled
                .store(true, Ordering::Release);
        }
        event(
            Level::Info,
            "diagnostics.configuration_changed",
            "diagnostics",
            "diagnostic session configuration changed",
            &[
                Field::boolean("detailed", detailed),
                Field::boolean("sensitive", sensitive),
            ],
        );
    }
    status()
}

pub fn flush() -> Result<(), String> {
    DIAGNOSTICS.get().map_or(Ok(()), Diagnostics::flush)
}

pub fn shutdown() {
    if DIAGNOSTICS.get().is_some() {
        event(
            Level::Info,
            "diagnostics.session_stopped",
            "diagnostics",
            "diagnostic session stopped",
            &[],
        );
    }
    if let Some(runtime) = DIAGNOSTICS.get() {
        runtime.shutdown();
    }
}

pub fn session_directory() -> Option<PathBuf> {
    DIAGNOSTICS
        .get()
        .and_then(|runtime| runtime.shared.session_directory.clone())
}

pub fn default_bundle_name() -> String {
    let session = DIAGNOSTICS.get().map_or_else(
        || "session".to_string(),
        |runtime| runtime.shared.session_id.clone(),
    );
    format!("taskmgr-rs-diagnostics-{session}.zip")
}

pub fn export_requires_privacy_warning() -> bool {
    DIAGNOSTICS.get().is_some_and(|runtime| {
        runtime
            .shared
            .sensitive_ever_enabled
            .load(Ordering::Acquire)
    })
}

pub fn detailed_restart_arguments() -> Vec<OsString> {
    let mut arguments = env::args_os()
        .skip(1)
        .filter(|argument| {
            let value = argument.to_string_lossy();
            value.starts_with("--diagnostic-dir=") || !is_diagnostic_argument(&value)
        })
        .collect::<Vec<_>>();
    arguments.push(OsString::from("--diagnostic=trace"));
    if status().sensitive {
        arguments.push(OsString::from("--diagnostic-sensitive"));
    }
    arguments
}

pub fn export_bundle(destination: &Path) -> Result<(), String> {
    if !destination.is_absolute() {
        return Err("diagnostic export destination must be absolute".to_string());
    }
    if destination.exists() {
        return Err("diagnostic export destination already exists".to_string());
    }
    flush()?;
    let Some(runtime) = DIAGNOSTICS.get() else {
        return Err("diagnostics have not been initialized".to_string());
    };
    let session = runtime
        .shared
        .session_directory
        .as_ref()
        .ok_or_else(|| "diagnostic session directory is unavailable".to_string())?;
    let parts = log_parts(session).map_err(|error| error.to_string())?;
    if parts.is_empty() {
        return Err("diagnostic session contains no log parts".to_string());
    }

    let file = create_private_file(destination).map_err(|error| error.to_string())?;
    let result = (|| -> io::Result<()> {
        let mut archive = StoredZipWriter::new(file);
        let manifest = serde_json::to_vec_pretty(&json!({
            "bundle_schema_version": BUNDLE_SCHEMA_VERSION,
            "log_schema_version": LOG_SCHEMA_VERSION,
            "app_version": env!("CARGO_PKG_VERSION"),
            "session_id": &runtime.shared.session_id,
            "exported_unix_ms": unix_time_millis(),
            "privacy": if export_requires_privacy_warning() { "sensitive" } else { "redacted" },
            "log_parts": parts.iter().map(|part| &part.name).collect::<Vec<_>>(),
        }))?;
        archive.add_bytes("manifest.json", &manifest)?;
        for part in &parts {
            let mut reader = File::open(&part.path)?.take(part.size);
            archive.add_reader(&format!("logs/{}", part.name), &mut reader)?;
        }
        archive.finish()
    })();
    if let Err(error) = result {
        let _ = fs::remove_file(destination);
        return Err(format!("unable to export diagnostic bundle: {error}"));
    }
    event(
        Level::Info,
        "diagnostics.bundle_exported",
        "diagnostics",
        "diagnostic bundle exported",
        &[Field::sensitive_text(
            "destination",
            destination.to_string_lossy(),
        )],
    );
    Ok(())
}

fn writer_loop(
    shared: Arc<SharedState>,
    mut sink: Option<FileSink>,
    regular_receiver: Receiver<LogRecord>,
    priority_receiver: Receiver<LogRecord>,
    control_receiver: Receiver<WriterControl>,
) {
    let ticker = tick(FLUSH_INTERVAL);
    loop {
        select_biased! {
            recv(control_receiver) -> command => match command {
                Ok(WriterControl::Flush(reply)) => {
                    drain_records(&shared, &mut sink, &priority_receiver, &regular_receiver);
                    report_dropped_events(&shared, &mut sink);
                    let _ = reply.send(flush_sink(&shared, &mut sink));
                }
                Ok(WriterControl::Shutdown(reply)) => {
                    drain_records(&shared, &mut sink, &priority_receiver, &regular_receiver);
                    report_dropped_events(&shared, &mut sink);
                    let _ = flush_sink(&shared, &mut sink);
                    let _ = reply.send(());
                    break;
                }
                Err(_) => break,
            },
            recv(priority_receiver) -> record => {
                if let Ok(record) = record {
                    write_record(&shared, &mut sink, record);
                    let _ = flush_sink(&shared, &mut sink);
                }
            },
            recv(regular_receiver) -> record => {
                if let Ok(record) = record {
                    write_record(&shared, &mut sink, record);
                }
            },
            recv(ticker) -> _ => {
                report_dropped_events(&shared, &mut sink);
                let _ = flush_sink(&shared, &mut sink);
            },
        }
    }
    shared.file_active.store(false, Ordering::Release);
}

fn drain_records(
    shared: &SharedState,
    sink: &mut Option<FileSink>,
    priority: &Receiver<LogRecord>,
    regular: &Receiver<LogRecord>,
) {
    for record in priority.try_iter() {
        write_record(shared, sink, record);
    }
    for record in regular.try_iter() {
        write_record(shared, sink, record);
    }
}

fn write_record(shared: &SharedState, sink: &mut Option<FileSink>, mut record: LogRecord) {
    let Some(active_sink) = sink.as_mut() else {
        return;
    };
    record.sequence = shared
        .sequence
        .fetch_add(1, Ordering::Relaxed)
        .wrapping_add(1);
    let mut bytes = match serde_json::to_vec(&record) {
        Ok(bytes) => bytes,
        Err(error) => {
            disable_sink(
                shared,
                sink,
                format!("unable to serialize diagnostic event: {error}"),
            );
            return;
        }
    };
    bytes.push(b'\n');
    if let Err(error) = active_sink.write_line(&bytes) {
        disable_sink(
            shared,
            sink,
            format!("unable to write diagnostic log: {error}"),
        );
    }
}

fn report_dropped_events(shared: &SharedState, sink: &mut Option<FileSink>) {
    let regular = shared.dropped_regular.swap(0, Ordering::AcqRel);
    let priority = shared.dropped_priority.swap(0, Ordering::AcqRel);
    if regular == 0 && priority == 0 {
        return;
    }
    let record = build_record(
        shared,
        Level::Warn,
        "diagnostics.events_dropped",
        "diagnostics",
        "diagnostic events were dropped because bounded queues were full",
        None,
        None,
        &[
            Field::unsigned("regular", regular),
            Field::unsigned("priority", priority),
        ],
        "crates/taskmgr-core/src/diagnostics/mod.rs",
        line!(),
    );
    write_record(shared, sink, record);
}

fn flush_sink(shared: &SharedState, sink: &mut Option<FileSink>) -> Result<(), String> {
    let Some(active_sink) = sink.as_mut() else {
        return shared
            .sink_error
            .lock()
            .ok()
            .and_then(|error| error.clone())
            .map_or(Ok(()), Err);
    };
    if let Err(error) = active_sink.flush_sync() {
        let message = format!("unable to flush diagnostic log: {error}");
        disable_sink(shared, sink, message.clone());
        return Err(message);
    }
    Ok(())
}

fn disable_sink(shared: &SharedState, sink: &mut Option<FileSink>, message: String) {
    *sink = None;
    shared.file_active.store(false, Ordering::Release);
    if let Ok(mut error) = shared.sink_error.lock() {
        *error = Some(message);
    }
}

impl FileSink {
    fn open(root: &Path, session: &Path, process_id: u32) -> io::Result<Self> {
        if session.parent() != Some(root) || !safe_directory(root) || !safe_directory(session) {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "diagnostic session is not a trusted direct child of its root",
            ));
        }
        let part = 0;
        let file = create_private_file(&session.join(part_file_name(process_id, part)))?;
        Ok(Self {
            writer: BufWriter::with_capacity(64 * 1024, file),
            root_directory: root.to_path_buf(),
            session_directory: session.to_path_buf(),
            process_id,
            part,
            bytes_written: 0,
        })
    }

    fn write_line(&mut self, bytes: &[u8]) -> io::Result<()> {
        let incoming = u64::try_from(bytes.len()).map_err(|_| {
            io::Error::new(io::ErrorKind::InvalidData, "diagnostic event is too large")
        })?;
        if incoming > LOG_PART_LIMIT_BYTES {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "one diagnostic event exceeds the log part limit",
            ));
        }
        if self.bytes_written != 0
            && self.bytes_written.saturating_add(incoming) > LOG_PART_LIMIT_BYTES
        {
            self.rotate()?;
        }
        self.writer.write_all(bytes)?;
        self.bytes_written = self.bytes_written.saturating_add(incoming);
        Ok(())
    }

    fn rotate(&mut self) -> io::Result<()> {
        self.flush_sync()?;
        cleanup_retention(&self.root_directory, Some(&self.session_directory))?;
        if directory_tree_size(&self.root_directory)?
            > LOG_ROOT_LIMIT_BYTES.saturating_sub(LOG_PART_LIMIT_BYTES)
        {
            return Err(io::Error::other(
                "diagnostic root cannot reserve another log part within its limit",
            ));
        }
        self.part = self
            .part
            .checked_add(1)
            .ok_or_else(|| io::Error::other("diagnostic log part number overflow"))?;
        let file = create_private_file(
            &self
                .session_directory
                .join(part_file_name(self.process_id, self.part)),
        )?;
        self.writer = BufWriter::with_capacity(64 * 1024, file);
        self.bytes_written = 0;
        Ok(())
    }

    fn flush_sync(&mut self) -> io::Result<()> {
        self.writer.flush()?;
        self.writer.get_ref().sync_data()
    }
}

struct LogPart {
    path: PathBuf,
    name: String,
    size: u64,
}

fn log_parts(session: &Path) -> io::Result<Vec<LogPart>> {
    if !safe_directory(session) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "diagnostic session directory is not trusted",
        ));
    }
    let mut parts = Vec::new();
    for entry in fs::read_dir(session)? {
        let entry = entry?;
        let name = entry.file_name().to_string_lossy().into_owned();
        if !valid_log_part_name(&name) || !safe_regular_file(&entry.path()) {
            continue;
        }
        let size = entry.metadata()?.len();
        parts.push(LogPart {
            path: entry.path(),
            name,
            size,
        });
    }
    parts.sort_by(|left, right| left.name.cmp(&right.name));
    Ok(parts)
}

fn prepare_directories(
    config: &DiagnosticConfig,
    errors: &mut Vec<String>,
) -> (Option<PathBuf>, Option<PathBuf>, String) {
    let mut candidates = Vec::new();
    if let Some(override_path) = &config.root_override {
        candidates.push(override_path.clone());
    }
    #[cfg(windows)]
    if let Some(local) = env::var_os("LOCALAPPDATA") {
        candidates.push(PathBuf::from(local).join("taskmgr-rs").join("logs"));
    }
    #[cfg(not(windows))]
    {
        if let Some(state) = env::var_os("XDG_STATE_HOME") {
            candidates.push(PathBuf::from(state).join("taskmgr-rs").join("logs"));
        } else if let Some(home) = env::var_os("HOME") {
            candidates.push(
                PathBuf::from(home)
                    .join(".local")
                    .join("state")
                    .join("taskmgr-rs")
                    .join("logs"),
            );
        }
    }
    candidates.push(env::temp_dir().join("taskmgr-rs").join("logs"));
    candidates.dedup();

    for root in candidates {
        if !root.is_absolute() {
            continue;
        }
        if let Err(error) = create_private_directory_tree(&root) {
            errors.push(format!(
                "unable to create diagnostic root {}: {error}",
                root.display()
            ));
            continue;
        }
        if !safe_directory(&root) {
            errors.push(format!(
                "diagnostic root is a symbolic link or reparse point: {}",
                root.display()
            ));
            continue;
        }
        if let Err(error) = cleanup_retention(&root, None) {
            errors.push(format!(
                "unable to apply diagnostic retention in {}: {error}",
                root.display()
            ));
        }
        match create_session_directory(&root, config.requested_session.as_deref()) {
            Ok((session, id)) => {
                let _ = cleanup_retention(&root, Some(&session));
                return (Some(root), Some(session), id);
            }
            Err(error) => errors.push(format!(
                "unable to create diagnostic session in {}: {error}",
                root.display()
            )),
        }
    }
    (None, None, generate_session_id())
}

fn create_session_directory(root: &Path, requested: Option<&str>) -> io::Result<(PathBuf, String)> {
    for attempt in 0..16u32 {
        let id = if attempt == 0 {
            requested.map_or_else(generate_session_id, ToOwned::to_owned)
        } else {
            generate_session_id()
        };
        let path = root.join(&id);
        match fs::create_dir(&path) {
            Ok(()) => {
                harden_directory_permissions(&path)?;
                return Ok((path, id));
            }
            Err(error) if error.kind() == io::ErrorKind::AlreadyExists => {}
            Err(error) => return Err(error),
        }
    }
    Err(io::Error::new(
        io::ErrorKind::AlreadyExists,
        "unable to allocate a unique diagnostic session",
    ))
}

fn cleanup_retention(root: &Path, active: Option<&Path>) -> io::Result<()> {
    if !safe_directory(root) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "diagnostic root is not a trusted directory",
        ));
    }
    if active.is_some_and(|path| path.parent() != Some(root)) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "active diagnostic session is not a direct child of its root",
        ));
    }
    let mut sessions = Vec::new();
    for entry in fs::read_dir(root)? {
        let entry = entry?;
        let path = entry.path();
        let name = entry.file_name().to_string_lossy().into_owned();
        if !valid_session_id(&name) || !safe_directory(&path) {
            continue;
        }
        sessions.push((name, directory_tree_size(&path)?, path));
    }
    sessions.sort_by(|left, right| left.0.cmp(&right.0));
    let mut total = sessions.iter().map(|entry| entry.1).sum::<u64>();
    let mut remaining = sessions.len();
    for (_, size, path) in sessions {
        if remaining <= LOG_SESSION_LIMIT && total <= LOG_ROOT_LIMIT_BYTES {
            break;
        }
        if active == Some(path.as_path()) {
            continue;
        }
        if delete_session_safely(&path)? {
            total = total.saturating_sub(size);
            remaining = remaining.saturating_sub(1);
        }
    }
    Ok(())
}

fn delete_session_safely(path: &Path) -> io::Result<bool> {
    if !safe_directory(path) {
        return Ok(false);
    }
    let mut files = Vec::new();
    for entry in fs::read_dir(path)? {
        let entry = entry?;
        let entry_path = entry.path();
        let name = entry.file_name().to_string_lossy().into_owned();
        if !safe_regular_file(&entry_path)
            || !(valid_log_part_name(&name) || name == "manifest.json")
        {
            return Ok(false);
        }
        files.push(entry_path);
    }
    for file in files {
        fs::remove_file(file)?;
    }
    fs::remove_dir(path)?;
    Ok(true)
}

fn directory_tree_size(path: &Path) -> io::Result<u64> {
    let mut total = 0u64;
    for entry in fs::read_dir(path)? {
        let entry = entry?;
        let metadata = fs::symlink_metadata(entry.path())?;
        if metadata.file_type().is_file() && !metadata_is_reparse(&metadata) {
            total = total.saturating_add(metadata.len());
        }
    }
    Ok(total)
}

fn create_private_directory_tree(path: &Path) -> io::Result<()> {
    fs::create_dir_all(path)?;
    harden_directory_permissions(path)
}

fn harden_directory_permissions(path: &Path) -> io::Result<()> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(path, fs::Permissions::from_mode(0o700))?;
    }
    #[cfg(not(unix))]
    let _ = path;
    Ok(())
}

fn create_private_file(path: &Path) -> io::Result<File> {
    let mut options = OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    options.open(path)
}

fn safe_directory(path: &Path) -> bool {
    fs::symlink_metadata(path).is_ok_and(|metadata| {
        metadata.file_type().is_dir()
            && !metadata.file_type().is_symlink()
            && !metadata_is_reparse(&metadata)
    })
}

fn safe_regular_file(path: &Path) -> bool {
    fs::symlink_metadata(path).is_ok_and(|metadata| {
        metadata.file_type().is_file()
            && !metadata.file_type().is_symlink()
            && !metadata_is_reparse(&metadata)
    })
}

#[cfg(windows)]
fn metadata_is_reparse(metadata: &fs::Metadata) -> bool {
    use std::os::windows::fs::MetadataExt;
    const FILE_ATTRIBUTE_REPARSE_POINT: u32 = 0x0000_0400;
    metadata.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0
}

#[cfg(not(windows))]
const fn metadata_is_reparse(_metadata: &fs::Metadata) -> bool {
    false
}

fn part_file_name(process_id: u32, part: u32) -> String {
    format!("events-{process_id:010}-{part:04}.jsonl")
}

fn valid_log_part_name(name: &str) -> bool {
    name.starts_with("events-")
        && name.ends_with(".jsonl")
        && name
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'.'))
}

fn generate_session_id() -> String {
    let sequence = SESSION_SEQUENCE.fetch_add(1, Ordering::Relaxed);
    format!(
        "session-{:013}-{:010}-{sequence:04}",
        unix_time_millis(),
        process::id()
    )
}

fn valid_session_id(value: &str) -> bool {
    value.starts_with("session-")
        && (16..=96).contains(&value.len())
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b'-')
}

fn is_diagnostic_argument(argument: &str) -> bool {
    argument == "--diagnostic"
        || argument == "--diagnostic-sensitive"
        || argument.starts_with("--diagnostic=")
        || argument.starts_with("--diagnostic-dir=")
        || argument.starts_with("--diagnostic-session=")
}

fn normalized_source_path(path: &str) -> String {
    let normalized = path
        .split(['\\', '/'])
        .filter(|component| !component.is_empty())
        .collect::<Vec<_>>()
        .join("/");
    for marker in ["crates/", "flutter_app/"] {
        if let Some(index) = normalized.rfind(marker) {
            return normalized[index..].to_string();
        }
    }
    Path::new(&normalized).file_name().map_or_else(
        || "unknown".to_string(),
        |name| name.to_string_lossy().into_owned(),
    )
}

fn unix_time_millis() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |duration| {
            duration
                .as_secs()
                .saturating_mul(1_000)
                .saturating_add(u64::from(duration.subsec_millis()))
        })
}

fn install_panic_hook() {
    PANIC_HOOK_INSTALLED.get_or_init(|| {
        let previous = std::panic::take_hook();
        std::panic::set_hook(Box::new(move |information| {
            let payload = information
                .payload()
                .downcast_ref::<&str>()
                .copied()
                .or_else(|| {
                    information
                        .payload()
                        .downcast_ref::<String>()
                        .map(String::as_str)
                })
                .unwrap_or("non-string panic payload");
            let mut fields = vec![Field::sensitive_text("panic_payload", payload)];
            if let Some(location) = information.location() {
                fields.push(Field::text(
                    "panic_file",
                    normalized_source_path(location.file()),
                ));
                fields.push(Field::unsigned("panic_line", u64::from(location.line())));
                fields.push(Field::unsigned(
                    "panic_column",
                    u64::from(location.column()),
                ));
            }
            event(
                Level::Error,
                "process.panic",
                "runtime",
                "a Rust thread panicked",
                &fields,
            );
            if thread::current().name() != Some("taskmgr-rs-diagnostics") {
                let _ = flush();
            }
            previous(information);
        }));
    });
}

#[cfg(test)]
mod tests {
    use std::ffi::OsString;
    use std::fs;

    use tempfile::tempdir;

    use super::{
        DiagnosticConfig, LOG_SESSION_LIMIT, Level, cleanup_retention, create_session_directory,
        normalized_source_path,
    };

    #[test]
    fn diagnostic_arguments_are_one_session_configuration() {
        let config = DiagnosticConfig::parse([
            OsString::from("--diagnostic=debug"),
            OsString::from("--diagnostic-sensitive"),
            OsString::from("--diagnostic-dir=relative"),
        ]);
        assert_eq!(config.level, Level::Trace);
        assert!(config.sensitive);
        assert!(config.root_override.is_none());
        assert_eq!(config.parse_warnings.len(), 1);
    }

    #[test]
    fn retention_removes_only_known_direct_session_files() {
        let directory = tempdir().expect("temporary directory");
        for index in 0..(LOG_SESSION_LIMIT + 2) {
            let session = directory
                .path()
                .join(format!("session-1700000000000-0000000001-{index:04}"));
            fs::create_dir(&session).expect("create session");
            fs::write(session.join("events-0000000001-0000.jsonl"), b"{}\n").expect("write log");
        }
        let suspicious = directory
            .path()
            .join("session-1700000000000-0000000001-9999");
        fs::create_dir(&suspicious).expect("create suspicious session");
        fs::write(suspicious.join("user-file.txt"), b"keep").expect("write user file");

        cleanup_retention(directory.path(), None).expect("apply retention");

        assert!(suspicious.join("user-file.txt").exists());
        let safe_count = fs::read_dir(directory.path())
            .expect("read root")
            .filter_map(Result::ok)
            .filter(|entry| {
                entry.file_name().to_string_lossy().starts_with("session-")
                    && !entry.path().join("user-file.txt").exists()
            })
            .count();
        assert!(safe_count <= LOG_SESSION_LIMIT);
    }

    #[test]
    fn session_names_are_exclusive_and_source_paths_are_redacted() {
        let directory = tempdir().expect("temporary directory");
        let requested = "session-1700000000000-0000000001-0000";
        let (_, first) = create_session_directory(directory.path(), Some(requested))
            .expect("create requested session");
        let (_, second) = create_session_directory(directory.path(), Some(requested))
            .expect("create collision-safe session");
        assert_eq!(first, requested);
        assert_ne!(second, requested);
        assert_eq!(
            normalized_source_path(
                r"C:\\checkout\\taskmgr-rs-desktop\\crates\\taskmgr-core\\src\\runtime.rs"
            ),
            "crates/taskmgr-core/src/runtime.rs"
        );
    }
}
