// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Flutter Rust Bridge 动态库入口
//
//   文件:       crates/taskmgr-bridge/src/lib.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1；FRB 2.12.0
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   flutter_rust_bridge 2.12；Dart native FFI；项目 FRB 协议 v1
// --------------------------------------------------------------------------

//! 只公开经过 FRB 代码生成的稳定 API；平台实现和 worker 均隐藏在动态库内部。

pub mod api;
mod frb_generated;
