// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 诊断包 ZIP32 写入器
//
//   文件:       crates/taskmgr-core/src/diagnostics/archive.rs
//
//   日期:       2026年08月22日
//   环境:       Windows 11 x86_64；Rust 1.97.1
//   作者:       OpenAI Codex
//   协助:       —
//   参考标准:   PKWARE ZIP AppNote；Rust std::io
// --------------------------------------------------------------------------

//! 写入只存储、不压缩的标准 ZIP32 诊断包。
//!
//! 条目名必须是相对 UTF-8 路径；文件由调用者以 `create_new` 打开，因此本模块既不
//! 覆盖既有文件，也不解析或跟随归档内路径。

use std::fs::File;
use std::io::{self, Read, Write};

use crc32fast::Hasher;

const LOCAL_FILE_HEADER_SIGNATURE: u32 = 0x0403_4b50;
const DATA_DESCRIPTOR_SIGNATURE: u32 = 0x0807_4b50;
const CENTRAL_DIRECTORY_SIGNATURE: u32 = 0x0201_4b50;
const END_OF_CENTRAL_DIRECTORY_SIGNATURE: u32 = 0x0605_4b50;
const VERSION_NEEDED: u16 = 20;
const VERSION_MADE_BY: u16 = 20;
const FLAG_DATA_DESCRIPTOR: u16 = 1 << 3;
const FLAG_UTF8: u16 = 1 << 11;
const STORED_METHOD: u16 = 0;
const COPY_BUFFER_SIZE: usize = 64 * 1024;

struct CentralEntry {
    name: Vec<u8>,
    crc32: u32,
    size: u32,
    local_header_offset: u32,
}

pub(super) struct StoredZipWriter {
    file: File,
    entries: Vec<CentralEntry>,
    position: u64,
}

impl StoredZipWriter {
    pub(super) const fn new(file: File) -> Self {
        Self {
            file,
            entries: Vec::new(),
            position: 0,
        }
    }

    pub(super) fn add_bytes(&mut self, name: &str, bytes: &[u8]) -> io::Result<()> {
        self.add_reader(name, &mut io::Cursor::new(bytes))
    }

    pub(super) fn add_reader(&mut self, name: &str, reader: &mut impl Read) -> io::Result<()> {
        validate_archive_name(name)?;
        if self.entries.len() == usize::from(u16::MAX) {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "diagnostic archive contains too many entries",
            ));
        }

        let name = name.as_bytes().to_vec();
        let name_length = u16::try_from(name.len()).map_err(|_| {
            io::Error::new(io::ErrorKind::InvalidInput, "ZIP entry name is too long")
        })?;
        let local_header_offset = self.position_u32()?;
        let flags = FLAG_DATA_DESCRIPTOR | FLAG_UTF8;

        self.write_u32(LOCAL_FILE_HEADER_SIGNATURE)?;
        self.write_u16(VERSION_NEEDED)?;
        self.write_u16(flags)?;
        self.write_u16(STORED_METHOD)?;
        self.write_u16(0)?;
        self.write_u16(0)?;
        self.write_u32(0)?;
        self.write_u32(0)?;
        self.write_u32(0)?;
        self.write_u16(name_length)?;
        self.write_u16(0)?;
        self.write_all(&name)?;

        let mut hasher = Hasher::new();
        let mut size = 0u64;
        let mut buffer = [0u8; COPY_BUFFER_SIZE];
        loop {
            let count = reader.read(&mut buffer)?;
            if count == 0 {
                break;
            }
            hasher.update(&buffer[..count]);
            self.write_all(&buffer[..count])?;
            size = size
                .checked_add(count as u64)
                .ok_or_else(zip32_size_error)?;
            if size > u64::from(u32::MAX) {
                return Err(zip32_size_error());
            }
        }

        let size = u32::try_from(size).map_err(|_| zip32_size_error())?;
        let crc32 = hasher.finalize();
        self.write_u32(DATA_DESCRIPTOR_SIGNATURE)?;
        self.write_u32(crc32)?;
        self.write_u32(size)?;
        self.write_u32(size)?;
        self.entries.push(CentralEntry {
            name,
            crc32,
            size,
            local_header_offset,
        });
        Ok(())
    }

    pub(super) fn finish(mut self) -> io::Result<()> {
        let central_offset = self.position_u32()?;
        for index in 0..self.entries.len() {
            let (name, crc32, size, local_header_offset) = {
                let entry = &self.entries[index];
                (
                    entry.name.clone(),
                    entry.crc32,
                    entry.size,
                    entry.local_header_offset,
                )
            };
            let name_length = u16::try_from(name.len()).map_err(|_| {
                io::Error::new(io::ErrorKind::InvalidInput, "ZIP entry name is too long")
            })?;
            self.write_u32(CENTRAL_DIRECTORY_SIGNATURE)?;
            self.write_u16(VERSION_MADE_BY)?;
            self.write_u16(VERSION_NEEDED)?;
            self.write_u16(FLAG_DATA_DESCRIPTOR | FLAG_UTF8)?;
            self.write_u16(STORED_METHOD)?;
            self.write_u16(0)?;
            self.write_u16(0)?;
            self.write_u32(crc32)?;
            self.write_u32(size)?;
            self.write_u32(size)?;
            self.write_u16(name_length)?;
            self.write_u16(0)?;
            self.write_u16(0)?;
            self.write_u16(0)?;
            self.write_u16(0)?;
            self.write_u32(0)?;
            self.write_u32(local_header_offset)?;
            self.write_all(&name)?;
        }

        let central_end = self.position_u32()?;
        let central_size = central_end
            .checked_sub(central_offset)
            .ok_or_else(zip32_size_error)?;
        let entry_count = u16::try_from(self.entries.len()).map_err(|_| {
            io::Error::new(
                io::ErrorKind::InvalidData,
                "diagnostic archive contains too many entries",
            )
        })?;
        self.write_u32(END_OF_CENTRAL_DIRECTORY_SIGNATURE)?;
        self.write_u16(0)?;
        self.write_u16(0)?;
        self.write_u16(entry_count)?;
        self.write_u16(entry_count)?;
        self.write_u32(central_size)?;
        self.write_u32(central_offset)?;
        self.write_u16(0)?;
        self.file.flush()?;
        self.file.sync_all()
    }

    fn position_u32(&self) -> io::Result<u32> {
        u32::try_from(self.position).map_err(|_| zip32_size_error())
    }

    fn write_u16(&mut self, value: u16) -> io::Result<()> {
        self.write_all(&value.to_le_bytes())
    }

    fn write_u32(&mut self, value: u32) -> io::Result<()> {
        self.write_all(&value.to_le_bytes())
    }

    fn write_all(&mut self, bytes: &[u8]) -> io::Result<()> {
        self.file.write_all(bytes)?;
        self.position = self
            .position
            .checked_add(bytes.len() as u64)
            .ok_or_else(zip32_size_error)?;
        Ok(())
    }
}

fn validate_archive_name(name: &str) -> io::Result<()> {
    if name.is_empty()
        || name.starts_with('/')
        || name.starts_with('\\')
        || name.contains('\\')
        || name.split('/').any(|part| part.is_empty() || part == "..")
    {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "ZIP entry name must be a normalized relative path",
        ));
    }
    Ok(())
}

fn zip32_size_error() -> io::Error {
    io::Error::new(
        io::ErrorKind::InvalidData,
        "diagnostic archive exceeds the ZIP32 size limit",
    )
}

#[cfg(test)]
mod tests {
    use std::fs::OpenOptions;

    use tempfile::tempdir;

    use super::StoredZipWriter;

    #[test]
    fn writes_a_stored_zip_and_rejects_parent_paths() {
        let directory = tempdir().expect("temporary directory");
        let path = directory.path().join("bundle.zip");
        let file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&path)
            .expect("create archive");
        let mut archive = StoredZipWriter::new(file);
        archive
            .add_bytes("logs/events.jsonl", b"{}\n")
            .expect("add event log");
        assert!(archive.add_bytes("../escape", b"no").is_err());
        archive.finish().expect("finish archive");
        let bytes = std::fs::read(path).expect("read archive");
        assert_eq!(&bytes[..4], &[0x50, 0x4b, 0x03, 0x04]);
        const ENTRY_NAME: &[u8] = b"logs/events.jsonl";
        assert!(
            bytes
                .windows(ENTRY_NAME.len())
                .any(|window| window == ENTRY_NAME)
        );
    }
}
