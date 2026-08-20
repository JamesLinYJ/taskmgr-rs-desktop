// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 平台采集器契约
//
//   文件:       crates/taskmgr-core/src/platform.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Rust trait 对象安全约定；项目 FRB 协议 v1
// --------------------------------------------------------------------------

//! 限定各平台后端向运行时提交数据和执行危险操作的边界。

use crate::{
    ActionRequest, ActionResult, BackendError, PageId, PlatformCapabilities, PrivilegeResult,
    SnapshotData,
};

pub trait PlatformProvider: Send + 'static {
    fn capabilities(&self) -> PlatformCapabilities;

    fn sample(&mut self, page: PageId) -> Result<SnapshotData, BackendError>;

    fn execute_action(&mut self, request: ActionRequest) -> ActionResult;

    fn open_privileged_session(&mut self) -> PrivilegeResult {
        PrivilegeResult::unavailable("privileged helper is not available on this platform")
    }
}
