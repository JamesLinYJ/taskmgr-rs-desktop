// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 跨平台后端核心
//
//   文件:       crates/taskmgr-core/src/lib.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Rust 标准库；Serde 数据模型；项目 FRB 协议 v1
// --------------------------------------------------------------------------

//! 定义 Flutter 与平台采集器共同依赖的稳定模型、运行时和设置存储。
//!
//! 本 crate 不依赖 Flutter、Win32、X11 或 Wayland。平台实现只提交完整候选快照，
//! [`BackendRuntime`] 负责 generation、失败时保留上一份可信数据以及有界刷新合并。

pub mod diagnostics;
mod history;
mod model;
mod platform;
mod runtime;
mod settings;

pub use history::HistoryBuffer;
pub use model::*;
pub use platform::PlatformProvider;
pub use runtime::{BackendRuntime, RuntimeError};
pub use settings::{SettingsStore, SettingsStoreError};
