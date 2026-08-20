// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Linux 网络接口采样
//
//   文件:       crates/taskmgr-linux/src/network.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Linux sysfs network class ABI；Documentation/ABI/testing/sysfs-class-net
// --------------------------------------------------------------------------

//! 从 `/sys/class/net` 读取稳定累计计数，并显式处理首次样本和计数器回退。

use std::collections::HashMap;
use std::fs;
use std::path::Path;
use std::time::Instant;

use taskmgr_core::{
    BackendError, HISTORY_CAPACITY, HistoryBuffer, NetworkData, NetworkInterface, SnapshotData,
};

struct Baseline {
    received: u64,
    sent: u64,
    sampled_at: Instant,
    received_history: HistoryBuffer,
    sent_history: HistoryBuffer,
}

pub struct NetworkSampler {
    baselines: HashMap<String, Baseline>,
}

impl NetworkSampler {
    pub fn new() -> Self {
        Self {
            baselines: HashMap::new(),
        }
    }

    pub fn sample(&mut self) -> Result<SnapshotData, BackendError> {
        let root = Path::new("/sys/class/net");
        let entries = fs::read_dir(root)
            .map_err(|error| BackendError::io("enumerate /sys/class/net", &error))?;
        let now = Instant::now();
        let mut interfaces = Vec::new();
        let mut live = std::collections::HashSet::new();

        for entry in entries {
            let entry = match entry {
                Ok(entry) => entry,
                Err(_) => continue,
            };
            let name = entry.file_name().to_string_lossy().into_owned();
            let path = entry.path();
            live.insert(name.clone());
            let received = read_u64(path.join("statistics/rx_bytes"));
            let sent = read_u64(path.join("statistics/tx_bytes"));
            let speed = read_i64(path.join("speed"))
                .filter(|speed| *speed > 0)
                .and_then(|megabits| u64::try_from(megabits).ok())
                .map(|megabits| megabits.saturating_mul(1_000_000));
            let operational =
                fs::read_to_string(path.join("operstate")).is_ok_and(|state| state.trim() == "up");
            let description = fs::read_to_string(path.join("device/uevent"))
                .ok()
                .and_then(|text| {
                    text.lines()
                        .find_map(|line| line.strip_prefix("DRIVER=").map(str::to_string))
                });

            let baseline = self
                .baselines
                .entry(name.clone())
                .or_insert_with(|| Baseline {
                    received: received.unwrap_or(0),
                    sent: sent.unwrap_or(0),
                    sampled_at: now,
                    received_history: HistoryBuffer::new(HISTORY_CAPACITY),
                    sent_history: HistoryBuffer::new(HISTORY_CAPACITY),
                });
            let elapsed = now
                .saturating_duration_since(baseline.sampled_at)
                .as_secs_f64();
            let received_rate = received.and_then(|current| {
                (elapsed > 0.0 && current >= baseline.received)
                    .then_some((current - baseline.received) as f64 / elapsed)
            });
            let sent_rate = sent.and_then(|current| {
                (elapsed > 0.0 && current >= baseline.sent)
                    .then_some((current - baseline.sent) as f64 / elapsed)
            });
            if let Some(value) = received_rate {
                baseline.received_history.push(value);
            }
            if let Some(value) = sent_rate {
                baseline.sent_history.push(value);
            }
            if let Some(value) = received {
                baseline.received = value;
            }
            if let Some(value) = sent {
                baseline.sent = value;
            }
            baseline.sampled_at = now;
            let utilization_percent = speed.and_then(|bits_per_second| {
                (bits_per_second > 0).then(|| {
                    (received_rate.unwrap_or(0.0) + sent_rate.unwrap_or(0.0)) * 8.0 * 100.0
                        / bits_per_second as f64
                })
            });
            let row_error = (received.is_none() || sent.is_none()).then(|| {
                BackendError::unsupported(
                    "network statistics",
                    "one or more interface counters are not readable",
                )
            });
            interfaces.push(NetworkInterface {
                id: name.clone(),
                name,
                description,
                operational,
                link_speed_bits_per_second: speed,
                received_bytes_per_second: received_rate,
                sent_bytes_per_second: sent_rate,
                utilization_percent,
                received_history: baseline.received_history.snapshot(),
                sent_history: baseline.sent_history.snapshot(),
                row_error,
            });
        }
        self.baselines.retain(|name, _| live.contains(name));
        interfaces.sort_by(|left, right| left.name.cmp(&right.name));
        Ok(SnapshotData::Network(NetworkData { interfaces }))
    }
}

impl Default for NetworkSampler {
    fn default() -> Self {
        Self::new()
    }
}

fn read_u64(path: impl AsRef<Path>) -> Option<u64> {
    fs::read_to_string(path).ok()?.trim().parse().ok()
}

fn read_i64(path: impl AsRef<Path>) -> Option<i64> {
    fs::read_to_string(path).ok()?.trim().parse().ok()
}
