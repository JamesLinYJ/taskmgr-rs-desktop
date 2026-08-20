// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 固定容量历史序列
//
//   文件:       crates/taskmgr-core/src/history.rs
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Rust 标准库 VecDeque；项目固定容量历史序列约定
// --------------------------------------------------------------------------

//! 为 CPU、内存、GPU 和网络图表提供 O(1) 推进的 ring buffer。

use std::collections::VecDeque;

#[derive(Clone, Debug)]
pub struct HistoryBuffer {
    values: VecDeque<f64>,
    capacity: usize,
}

impl HistoryBuffer {
    pub fn new(capacity: usize) -> Self {
        Self {
            values: VecDeque::with_capacity(capacity),
            capacity,
        }
    }

    pub fn push(&mut self, value: f64) {
        if self.capacity == 0 || !value.is_finite() {
            return;
        }
        if self.values.len() == self.capacity {
            self.values.pop_front();
        }
        self.values.push_back(value);
    }

    pub fn clear(&mut self) {
        self.values.clear();
    }

    pub fn snapshot(&self) -> Vec<f64> {
        self.values.iter().copied().collect()
    }

    pub fn len(&self) -> usize {
        self.values.len()
    }

    pub fn is_empty(&self) -> bool {
        self.values.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::HistoryBuffer;

    #[test]
    fn preserves_chronological_order_at_capacity() {
        let mut history = HistoryBuffer::new(3);
        for value in [1.0, 2.0, 3.0, 4.0] {
            history.push(value);
        }
        assert_eq!(history.snapshot(), vec![2.0, 3.0, 4.0]);
    }

    #[test]
    fn rejects_non_finite_values() {
        let mut history = HistoryBuffer::new(2);
        history.push(f64::NAN);
        history.push(f64::INFINITY);
        assert!(history.is_empty());
    }
}
