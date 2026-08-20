// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Linux 登录会话采样
//
//   文件:       crates/taskmgr-linux/src/users.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   utmpx(5)；getutxent(3)；POSIX.1 session accounting
// --------------------------------------------------------------------------

//! 读取 utmpx 的用户会话。破坏性会话控制由后续 logind/polkit helper 承担。

use taskmgr_core::{SnapshotData, UserSession, UserSessionIdentity, UsersData};

pub fn sample() -> Result<SnapshotData, taskmgr_core::BackendError> {
    let mut sessions = Vec::new();
    unsafe {
        libc::setutxent();
        loop {
            let entry = libc::getutxent();
            if entry.is_null() {
                break;
            }
            let entry = &*entry;
            if entry.ut_type != libc::USER_PROCESS {
                continue;
            }
            let user_name = c_field(&entry.ut_user);
            let line = c_field(&entry.ut_line);
            let host = c_field(&entry.ut_host);
            if user_name.is_empty() {
                continue;
            }
            let login_time = u64::try_from(entry.ut_tv.tv_sec).ok();
            sessions.push(UserSession {
                identity: UserSessionIdentity {
                    id: if line.is_empty() {
                        format!("utmpx-{}", entry.ut_session)
                    } else {
                        line.clone()
                    },
                    login_time,
                },
                user_name,
                session: (!line.is_empty()).then_some(line),
                client_name: (!host.is_empty()).then_some(host),
                state: "Active".to_string(),
                idle_seconds: None,
                allowed_actions: Vec::new(),
                row_error: None,
            });
        }
        libc::endutxent();
    }
    sessions.sort_by(|left, right| left.user_name.cmp(&right.user_name));
    Ok(SnapshotData::Users(UsersData { sessions }))
}

fn c_field<const N: usize>(field: &[libc::c_char; N]) -> String {
    let bytes = field
        .iter()
        .map(|value| value.to_ne_bytes()[0])
        .take_while(|value| *value != 0)
        .collect::<Vec<_>>();
    String::from_utf8_lossy(&bytes).trim().to_string()
}
