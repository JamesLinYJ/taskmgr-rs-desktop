// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Windows 网络接口采样
//
//   文件:       crates/taskmgr-windows/src/network.rs
//
//   日期:       2026年08月20日
//   环境:       Windows x64/ARM64 API；Rust 1.97.1；x86_64-pc-windows-gnu 交叉检查
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   IP Helper GetIfTable2；MIB_IF_ROW2；FreeMibTable
// --------------------------------------------------------------------------

//! 从 IP Helper 的累计字节计数生成每秒速率和有界历史。
//!
//! `GetIfTable2` 分配的表由本模块唯一持有并通过 `FreeMibTable` 释放；首次采样的速率
//! 保持 `None`，计数器回退时也不会制造负速率或零值。

use std::collections::{HashMap, HashSet};
use std::slice;
use std::time::Instant;

use taskmgr_core::{
    BackendError, HISTORY_CAPACITY, HistoryBuffer, NetworkData, NetworkInterface, SnapshotData,
};
use windows_sys::Win32::Foundation::NO_ERROR;
use windows_sys::Win32::NetworkManagement::IpHelper::{
    FreeMibTable, GetIfTable2, IF_TYPE_SOFTWARE_LOOPBACK, MIB_IF_ROW2, MIB_IF_TABLE2,
};
use windows_sys::Win32::NetworkManagement::Ndis::IfOperStatusUp;

use crate::native::{error_from_code, wide_slice_to_string};

struct Baseline {
    received: u64,
    sent: u64,
    sampled_at: Instant,
    received_history: HistoryBuffer,
    sent_history: HistoryBuffer,
}

pub(crate) struct NetworkSampler {
    baselines: HashMap<u64, Baseline>,
}

impl NetworkSampler {
    pub(crate) fn new() -> Self {
        Self {
            baselines: HashMap::new(),
        }
    }

    pub(crate) fn sample(&mut self) -> Result<SnapshotData, BackendError> {
        let table = IfTable::query()?;
        let now = Instant::now();
        let mut interfaces = Vec::with_capacity(table.rows().len());
        let mut live = HashSet::with_capacity(table.rows().len());
        for row in table.rows() {
            if row.Type == IF_TYPE_SOFTWARE_LOOPBACK {
                continue;
            }
            // SAFETY: NET_LUID_LH is returned initialized by GetIfTable2; reading Value is the
            // documented stable identifier representation.
            let luid = unsafe { row.InterfaceLuid.Value };
            live.insert(luid);
            let baseline = self.baselines.entry(luid).or_insert_with(|| Baseline {
                received: row.InOctets,
                sent: row.OutOctets,
                sampled_at: now,
                received_history: HistoryBuffer::new(HISTORY_CAPACITY),
                sent_history: HistoryBuffer::new(HISTORY_CAPACITY),
            });
            let elapsed = now
                .saturating_duration_since(baseline.sampled_at)
                .as_secs_f64();
            let received_rate = (elapsed > 0.0 && row.InOctets >= baseline.received)
                .then_some((row.InOctets - baseline.received) as f64 / elapsed);
            let sent_rate = (elapsed > 0.0 && row.OutOctets >= baseline.sent)
                .then_some((row.OutOctets - baseline.sent) as f64 / elapsed);
            if let Some(value) = received_rate {
                baseline.received_history.push(value);
            }
            if let Some(value) = sent_rate {
                baseline.sent_history.push(value);
            }
            baseline.received = row.InOctets;
            baseline.sent = row.OutOctets;
            baseline.sampled_at = now;

            let link_speed = row.ReceiveLinkSpeed.max(row.TransmitLinkSpeed);
            let utilization_percent = received_rate.zip(sent_rate).and_then(|(received, sent)| {
                (link_speed > 0).then(|| {
                    ((received + sent) * 8.0 * 100.0 / link_speed as f64).clamp(0.0, 100.0)
                })
            });
            let alias = wide_slice_to_string(&row.Alias);
            let description = wide_slice_to_string(&row.Description);
            interfaces.push(NetworkInterface {
                id: format!("{luid:016x}"),
                name: if alias.is_empty() {
                    format!("Interface {}", row.InterfaceIndex)
                } else {
                    alias
                },
                description: (!description.is_empty()).then_some(description),
                operational: row.OperStatus == IfOperStatusUp,
                link_speed_bits_per_second: (link_speed > 0).then_some(link_speed),
                received_bytes_per_second: received_rate,
                sent_bytes_per_second: sent_rate,
                utilization_percent,
                received_history: baseline.received_history.snapshot(),
                sent_history: baseline.sent_history.snapshot(),
                row_error: None,
            });
        }
        self.baselines.retain(|luid, _| live.contains(luid));
        interfaces.sort_by_key(|interface| interface.name.to_lowercase());
        Ok(SnapshotData::Network(NetworkData { interfaces }))
    }
}

struct IfTable(*mut MIB_IF_TABLE2);

impl IfTable {
    fn query() -> Result<Self, BackendError> {
        let mut table = std::ptr::null_mut();
        // SAFETY: output receives one table allocation owned by the caller on NO_ERROR.
        let code = unsafe { GetIfTable2(&mut table) };
        if code != NO_ERROR || table.is_null() {
            return Err(error_from_code("GetIfTable2", code));
        }
        Ok(Self(table))
    }

    fn rows(&self) -> &[MIB_IF_ROW2] {
        // SAFETY: GetIfTable2 allocated a MIB_IF_TABLE2 containing NumEntries contiguous rows;
        // the allocation remains owned by self for the returned borrow.
        unsafe {
            let count = (*self.0).NumEntries as usize;
            slice::from_raw_parts((*self.0).Table.as_ptr(), count)
        }
    }
}

impl Drop for IfTable {
    fn drop(&mut self) {
        // SAFETY: this is the original allocation returned by GetIfTable2 and is freed once.
        unsafe { FreeMibTable(self.0.cast()) };
    }
}
