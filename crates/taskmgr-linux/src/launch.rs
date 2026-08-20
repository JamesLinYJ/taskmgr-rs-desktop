// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Linux 新建任务启动器
//
//   文件:       crates/taskmgr-linux/src/launch.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   execve(2) 参数语义；freedesktop.org xdg-open
// --------------------------------------------------------------------------

//! 启动用户输入的程序，或通过桌面默认处理程序打开目录、文档与 URI。
//!
//! 输入只做参数分词，不进行 shell 展开，也绝不传给 `sh -c`。

use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;
use std::process::Command;

use taskmgr_core::{ActionResult, BackendError};

pub(crate) fn run(command_line: &str) -> ActionResult {
    let arguments = match parse_command_line(command_line) {
        Ok(arguments) => arguments,
        Err(error) => return ActionResult::failed(error),
    };
    let target = &arguments[0];
    let mut command = if should_open_with_desktop(target, arguments.len()) {
        let mut command = Command::new("xdg-open");
        command.arg(target);
        command
    } else {
        let mut command = Command::new(target);
        command.args(&arguments[1..]);
        command
    };

    match command.spawn() {
        Ok(mut child) => {
            // A small reaper prevents completed children from remaining as zombies. The GUI
            // remains responsive and never waits for the launched task to exit.
            let _ = std::thread::Builder::new()
                .name("taskmgr-task-reaper".to_string())
                .spawn(move || {
                    let _ = child.wait();
                });
            ActionResult::succeeded()
        }
        Err(error) => ActionResult::failed(BackendError::io("launch task", &error)),
    }
}

#[derive(Clone, Copy, Eq, PartialEq)]
enum Quote {
    None,
    Single,
    Double,
}

fn parse_command_line(input: &str) -> Result<Vec<String>, BackendError> {
    let mut arguments = Vec::new();
    let mut current = String::new();
    let mut quote = Quote::None;
    let mut escaped = false;
    let mut token_started = false;

    for character in input.chars() {
        if escaped {
            current.push(character);
            escaped = false;
            token_started = true;
            continue;
        }
        match quote {
            Quote::Single => {
                if character == '\'' {
                    quote = Quote::None;
                } else {
                    current.push(character);
                }
            }
            Quote::Double => match character {
                '"' => quote = Quote::None,
                '\\' => escaped = true,
                _ => current.push(character),
            },
            Quote::None => match character {
                '\'' => {
                    quote = Quote::Single;
                    token_started = true;
                }
                '"' => {
                    quote = Quote::Double;
                    token_started = true;
                }
                '\\' => {
                    escaped = true;
                    token_started = true;
                }
                value if value.is_whitespace() => {
                    if token_started {
                        arguments.push(std::mem::take(&mut current));
                        token_started = false;
                    }
                }
                _ => {
                    current.push(character);
                    token_started = true;
                }
            },
        }
    }

    if escaped || quote != Quote::None {
        return Err(command_line_error(
            "the command line contains an unfinished quote or escape",
        ));
    }
    if token_started {
        arguments.push(current);
    }
    if arguments.is_empty() || arguments[0].is_empty() {
        return Err(command_line_error(
            "enter a program, document, folder, or URI",
        ));
    }
    Ok(arguments)
}

fn should_open_with_desktop(target: &str, argument_count: usize) -> bool {
    if argument_count != 1 {
        return false;
    }
    if has_uri_scheme(target) {
        return true;
    }
    let Ok(metadata) = fs::metadata(Path::new(target)) else {
        return false;
    };
    metadata.is_dir() || !metadata.is_file() || metadata.permissions().mode() & 0o111 == 0
}

fn has_uri_scheme(value: &str) -> bool {
    let Some((scheme, _)) = value.split_once(':') else {
        return false;
    };
    !scheme.is_empty()
        && scheme
            .bytes()
            .next()
            .is_some_and(|byte| byte.is_ascii_alphabetic())
        && scheme
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'+' | b'-' | b'.'))
}

fn command_line_error(message: impl Into<String>) -> BackendError {
    BackendError {
        domain: "command_line".to_string(),
        code: 1,
        context: "parse run command".to_string(),
        message: message.into(),
    }
}

#[cfg(test)]
mod tests {
    use std::fs;
    use std::os::unix::fs::PermissionsExt;

    use taskmgr_core::ActionStatus;
    use tempfile::tempdir;

    use super::{has_uri_scheme, parse_command_line, run, should_open_with_desktop};

    #[test]
    fn parses_quoted_and_escaped_arguments_without_a_shell() {
        assert_eq!(
            parse_command_line("program --name 'two words' three\\ words \"\"")
                .expect("valid command line"),
            ["program", "--name", "two words", "three words", ""]
        );
    }

    #[test]
    fn rejects_empty_or_unfinished_command_lines() {
        assert!(parse_command_line("  ").is_err());
        assert!(parse_command_line("program 'unfinished").is_err());
        assert!(parse_command_line("program trailing\\").is_err());
    }

    #[test]
    fn recognizes_standard_uri_schemes() {
        assert!(has_uri_scheme("https://example.com"));
        assert!(has_uri_scheme("mailto:user@example.com"));
        assert!(!has_uri_scheme("./document.txt"));
        assert!(!has_uri_scheme("9invalid:value"));
    }

    #[test]
    fn opens_documents_but_executes_executable_files() {
        let directory = tempdir().expect("temporary directory");
        let document = directory.path().join("document.txt");
        let executable = directory.path().join("program");
        fs::write(&document, "text").expect("write document");
        fs::write(&executable, "#!/bin/true\n").expect("write executable");
        let mut permissions = fs::metadata(&executable)
            .expect("executable metadata")
            .permissions();
        permissions.set_mode(0o755);
        fs::set_permissions(&executable, permissions).expect("set executable mode");

        assert!(should_open_with_desktop(
            document.to_str().expect("UTF-8 path"),
            1
        ));
        assert!(!should_open_with_desktop(
            executable.to_str().expect("UTF-8 path"),
            1
        ));
        assert!(!should_open_with_desktop(
            document.to_str().expect("UTF-8 path"),
            2
        ));
    }

    #[test]
    fn launches_an_executable_without_invoking_a_shell() {
        assert_eq!(run("/bin/true").status, ActionStatus::Succeeded);
    }
}
