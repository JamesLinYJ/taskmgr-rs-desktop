// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 跨平台设置存储
//
//   文件:       crates/taskmgr-core/src/settings.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   XDG Base Directory Specification；Windows Known Folders；JSON RFC 8259
// --------------------------------------------------------------------------

//! 在 AppData/XDG config 中原子读写版本化 JSON，并保留损坏文件供诊断。

use std::env;
use std::fs::{self, File, OpenOptions};
use std::io::{BufReader, BufWriter, Write};
use std::path::{Path, PathBuf};

use thiserror::Error;

use crate::{BackendError, SettingsLoadResult, UiSettings, unix_time_millis};

#[derive(Debug, Error)]
pub enum SettingsStoreError {
    #[error("no per-user configuration directory is available")]
    MissingConfigDirectory,
    #[error("settings I/O failed at {path}: {source}")]
    Io {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },
    #[error("settings serialization failed: {0}")]
    Serialize(#[from] serde_json::Error),
}

#[derive(Clone, Debug)]
pub struct SettingsStore {
    path: PathBuf,
}

impl SettingsStore {
    pub fn discover() -> Result<Self, SettingsStoreError> {
        let root = if cfg!(windows) {
            env::var_os("APPDATA").map(PathBuf::from)
        } else {
            env::var_os("XDG_CONFIG_HOME")
                .map(PathBuf::from)
                .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".config")))
        }
        .ok_or(SettingsStoreError::MissingConfigDirectory)?;
        Ok(Self::at_path(root.join("taskmgr-rs").join("settings.json")))
    }

    pub fn at_path(path: PathBuf) -> Self {
        Self { path }
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn load(&self) -> Result<SettingsLoadResult, SettingsStoreError> {
        let file = match File::open(&self.path) {
            Ok(file) => file,
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                return Ok(SettingsLoadResult {
                    settings: UiSettings::default(),
                    recovered_corrupt_path: None,
                    warning: None,
                });
            }
            Err(source) => {
                return Err(SettingsStoreError::Io {
                    path: self.path.clone(),
                    source,
                });
            }
        };

        match serde_json::from_reader::<_, UiSettings>(BufReader::new(file)) {
            Ok(settings) => Ok(SettingsLoadResult {
                settings: settings.normalize(),
                recovered_corrupt_path: None,
                warning: None,
            }),
            Err(error) => {
                let recovery_path = self.corrupt_path();
                fs::rename(&self.path, &recovery_path).map_err(|source| {
                    SettingsStoreError::Io {
                        path: self.path.clone(),
                        source,
                    }
                })?;
                Ok(SettingsLoadResult {
                    settings: UiSettings::default(),
                    recovered_corrupt_path: Some(recovery_path.to_string_lossy().into_owned()),
                    warning: Some(BackendError {
                        domain: "settings".to_string(),
                        code: 1,
                        context: "load_settings".to_string(),
                        message: format!("invalid settings were preserved: {error}"),
                    }),
                })
            }
        }
    }

    pub fn save(&self, settings: &UiSettings) -> Result<(), SettingsStoreError> {
        let parent = self
            .path
            .parent()
            .ok_or(SettingsStoreError::MissingConfigDirectory)?;
        fs::create_dir_all(parent).map_err(|source| SettingsStoreError::Io {
            path: parent.to_path_buf(),
            source,
        })?;
        let temporary = parent.join(format!(
            ".settings-{}-{}.tmp",
            std::process::id(),
            unix_time_millis()
        ));
        let file = create_private_file(&temporary).map_err(|source| SettingsStoreError::Io {
            path: temporary.clone(),
            source,
        })?;
        let mut writer = BufWriter::new(file);
        serde_json::to_writer_pretty(&mut writer, &settings.clone().normalize())?;
        writer
            .write_all(b"\n")
            .map_err(|source| SettingsStoreError::Io {
                path: temporary.clone(),
                source,
            })?;
        writer.flush().map_err(|source| SettingsStoreError::Io {
            path: temporary.clone(),
            source,
        })?;
        writer
            .get_ref()
            .sync_all()
            .map_err(|source| SettingsStoreError::Io {
                path: temporary.clone(),
                source,
            })?;
        fs::rename(&temporary, &self.path).map_err(|source| SettingsStoreError::Io {
            path: self.path.clone(),
            source,
        })?;
        sync_directory(parent)?;
        Ok(())
    }

    fn corrupt_path(&self) -> PathBuf {
        let parent = self.path.parent().unwrap_or_else(|| Path::new("."));
        parent.join(format!("settings.corrupt-{}.json", unix_time_millis()))
    }
}

fn create_private_file(path: &Path) -> std::io::Result<File> {
    let mut options = OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    options.open(path)
}

fn sync_directory(_path: &Path) -> Result<(), SettingsStoreError> {
    #[cfg(unix)]
    File::open(_path)
        .and_then(|directory| directory.sync_all())
        .map_err(|source| SettingsStoreError::Io {
            path: _path.to_path_buf(),
            source,
        })?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use std::fs;

    use tempfile::tempdir;

    use super::SettingsStore;
    use crate::{ApplicationViewMode, PageId, UiSettings};

    #[test]
    fn round_trips_versioned_settings() {
        let directory = tempdir().expect("temporary directory");
        let store = SettingsStore::at_path(directory.path().join("settings.json"));
        let settings = UiSettings {
            active_page: PageId::Gpu,
            ..UiSettings::default()
        };
        store.save(&settings).expect("save settings");
        assert_eq!(store.load().expect("load settings").settings, settings);
    }

    #[test]
    fn preserves_corrupt_settings_and_returns_an_observable_warning() {
        let directory = tempdir().expect("temporary directory");
        let path = directory.path().join("settings.json");
        fs::write(&path, b"not json").expect("write corrupt settings");
        let loaded = SettingsStore::at_path(path)
            .load()
            .expect("recover settings");
        assert!(loaded.warning.is_some());
        let recovered = loaded
            .recovered_corrupt_path
            .expect("corrupt settings path");
        assert!(std::path::Path::new(&recovered).exists());
    }

    #[test]
    fn older_settings_default_to_the_details_application_view() {
        let directory = tempdir().expect("temporary directory");
        let path = directory.path().join("settings.json");
        let mut value = serde_json::to_value(UiSettings::default()).expect("serialize settings");
        value
            .as_object_mut()
            .expect("settings object")
            .remove("application_view_mode");
        fs::write(&path, serde_json::to_vec(&value).expect("encode settings"))
            .expect("write old settings");

        let loaded = SettingsStore::at_path(path).load().expect("load settings");

        assert_eq!(
            loaded.settings.application_view_mode,
            ApplicationViewMode::Details
        );
    }
}
