// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 有界 C 文本解码
//
//   文件:       crates/taskmgr-linux/src/c_text.rs
//
//   日期:       2026年08月21日
//   环境:       Linux x64/ARM64；Rust 1.97.1；C ABI
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   ISO C object representation；POSIX fixed-size character fields
// --------------------------------------------------------------------------

//! 在 Rust 切片边界内解码 C ABI 字符缓冲区。
//! 本模块统一隔离 `c_char` 在不同架构上的符号性差异，且不使用无界指针读取。

use std::ffi::c_char;

#[derive(Clone, Copy)]
pub(crate) struct BoundedCText<'a> {
    buffer: &'a [c_char],
}

impl<'a> BoundedCText<'a> {
    pub(crate) const fn new(buffer: &'a [c_char]) -> Self {
        Self { buffer }
    }

    /// Decode a C string only when its terminator exists inside the supplied buffer.
    pub(crate) fn decode_nul_terminated(self) -> Option<String> {
        let end = self.buffer.iter().position(|value| *value == 0)?;
        let text = self.decode_prefix(end);
        (!text.is_empty()).then_some(text)
    }

    /// Decode a fixed-width C field up to its first NUL, or to the field boundary when full.
    pub(crate) fn decode_nul_padded_field(self) -> String {
        let end = self
            .buffer
            .iter()
            .position(|value| *value == 0)
            .unwrap_or(self.buffer.len());
        self.decode_prefix(end)
    }

    fn decode_prefix(self, end: usize) -> String {
        // `c_char` is exactly one byte but may be `i8` or `u8`. Converting its object
        // representation avoids a target-dependent numeric cast and requires no `unsafe`.
        let bytes = self.buffer[..end]
            .iter()
            .map(|value| value.to_ne_bytes()[0])
            .collect::<Vec<_>>();
        String::from_utf8_lossy(&bytes).trim().to_string()
    }
}

#[cfg(test)]
mod tests {
    use std::ffi::c_char;

    use super::BoundedCText;

    #[test]
    fn terminated_text_is_bounded_trimmed_and_stops_at_the_first_nul() {
        let buffer: [c_char; 16] = [
            32, 32, 78, 86, 73, 68, 73, 65, 32, 71, 80, 85, 32, 32, 0, 88,
        ];
        assert_eq!(
            BoundedCText::new(&buffer).decode_nul_terminated(),
            Some("NVIDIA GPU".to_string())
        );
    }

    #[test]
    fn unterminated_c_string_is_rejected() {
        let buffer: [c_char; 4] = [78, 86, 77, 76];
        assert_eq!(BoundedCText::new(&buffer).decode_nul_terminated(), None);
    }

    #[test]
    fn full_fixed_width_field_is_decoded_without_reading_beyond_its_boundary() {
        let field: [c_char; 4] = [84, 84, 89, 49];
        assert_eq!(BoundedCText::new(&field).decode_nul_padded_field(), "TTY1");
    }

    #[test]
    fn empty_or_padding_only_text_remains_empty() {
        let terminated: [c_char; 3] = [32, 32, 0];
        assert_eq!(BoundedCText::new(&terminated).decode_nul_terminated(), None);
        assert_eq!(BoundedCText::new(&terminated).decode_nul_padded_field(), "");
    }
}
