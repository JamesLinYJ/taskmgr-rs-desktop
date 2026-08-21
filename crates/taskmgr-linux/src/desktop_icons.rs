// +-------------------------------------------------------------------------
//
//   taskmgr-rs - XDG 桌面应用图标解析
//
//   文件:       crates/taskmgr-linux/src/desktop_icons.rs
//
//   日期:       2026年08月21日
//   环境:       Fedora Linux 46 x86_64；Linux 7.2.0；Rust 1.97.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Desktop Entry Specification；Icon Theme Specification；PNG ISO/IEC 15948
// --------------------------------------------------------------------------

//! 将 Wayland 的主题图标名或 app_id 映射到 XDG desktop entry，并输出有界 PNG。
//! 解析器只接受普通 PNG 文件，限制输入尺寸与解码内存，并缓存每个图标名的结果。

use std::collections::HashMap;
use std::env;
use std::fs::{self, File};
use std::io::BufReader;
use std::path::{Path, PathBuf};

const SMALL_ICON_EDGE: u32 = 16;
const LARGE_ICON_EDGE: u32 = 32;
const MAX_DESKTOP_FILE_BYTES: u64 = 1024 * 1024;
const MAX_ICON_FILE_BYTES: u64 = 8 * 1024 * 1024;
const MAX_DECODED_ICON_BYTES: usize = 64 * 1024 * 1024;
const MAX_ICON_EDGE: u32 = 4096;
const MAX_DIRECTORY_ENTRIES: usize = 100_000;
const MAX_DIRECTORY_DEPTH: usize = 8;

#[derive(Clone, Default)]
pub(crate) struct ResolvedIcons {
    pub(crate) small: Option<Vec<u8>>,
    pub(crate) large: Option<Vec<u8>>,
}

pub(crate) struct DesktopIconResolver {
    data_roots: Vec<PathBuf>,
    desktop_icons: HashMap<String, String>,
    cache: HashMap<String, ResolvedIcons>,
}

impl DesktopIconResolver {
    pub(crate) fn discover() -> Self {
        Self::from_data_roots(xdg_data_roots())
    }

    fn from_data_roots(data_roots: Vec<PathBuf>) -> Self {
        let mut resolver = Self {
            data_roots,
            desktop_icons: HashMap::new(),
            cache: HashMap::new(),
        };
        resolver.index_desktop_entries();
        resolver
    }

    pub(crate) fn resolve(
        &mut self,
        themed_icon_name: Option<&str>,
        app_id: Option<&str>,
    ) -> ResolvedIcons {
        let icon_name = themed_icon_name
            .and_then(safe_icon_name)
            .map(str::to_string)
            .or_else(|| {
                let key = normalized_desktop_key(app_id?);
                self.desktop_icons.get(&key).cloned()
            })
            .or_else(|| app_id.and_then(safe_icon_name).map(str::to_string));
        let Some(icon_name) = icon_name else {
            return ResolvedIcons::default();
        };
        if let Some(cached) = self.cache.get(&icon_name) {
            return cached.clone();
        }
        let resolved = self
            .find_icon(&icon_name)
            .and_then(|path| decode_png(&path))
            .map(|image| ResolvedIcons {
                small: resize_and_encode(&image, SMALL_ICON_EDGE),
                large: resize_and_encode(&image, LARGE_ICON_EDGE),
            })
            .unwrap_or_default();
        self.cache.insert(icon_name, resolved.clone());
        resolved
    }

    fn index_desktop_entries(&mut self) {
        let mut visited = 0;
        for data_root in self.data_roots.clone() {
            let applications = data_root.join("applications");
            let mut files = Vec::new();
            collect_files(&applications, 0, &mut visited, &mut files, |path| {
                path.extension().is_some_and(|value| value == "desktop")
            });
            for path in files {
                let Ok(metadata) = fs::metadata(&path) else {
                    continue;
                };
                if metadata.len() > MAX_DESKTOP_FILE_BYTES {
                    continue;
                }
                let Ok(text) = fs::read_to_string(&path) else {
                    continue;
                };
                let Some(entry) = parse_desktop_entry(&text) else {
                    continue;
                };
                let Some(relative) = path.strip_prefix(&applications).ok() else {
                    continue;
                };
                let desktop_id = relative
                    .to_string_lossy()
                    .replace(std::path::MAIN_SEPARATOR, "-");
                self.insert_desktop_key(&desktop_id, &entry.icon);
                if let Some(file_stem) = path.file_stem().and_then(|value| value.to_str()) {
                    self.insert_desktop_key(file_stem, &entry.icon);
                }
                if let Some(startup_class) = entry.startup_wm_class {
                    self.insert_desktop_key(&startup_class, &entry.icon);
                }
            }
        }
    }

    fn insert_desktop_key(&mut self, value: &str, icon: &str) {
        let key = normalized_desktop_key(value);
        if !key.is_empty() {
            self.desktop_icons
                .entry(key)
                .or_insert_with(|| icon.to_string());
        }
    }

    fn find_icon(&self, icon_name: &str) -> Option<PathBuf> {
        let direct = Path::new(icon_name);
        if direct.is_absolute() {
            return is_png_file(direct).then(|| direct.to_path_buf());
        }
        let icon_name = safe_icon_name(icon_name)?;
        let file_name = format!("{icon_name}.png");
        const SIZES: [&str; 9] = [
            "32x32", "48x48", "64x64", "24x24", "16x16", "96x96", "128x128", "256x256", "512x512",
        ];
        const CONTEXTS: [&str; 4] = ["apps", "applications", "legacy", "devices"];
        for root in &self.data_roots {
            for size in SIZES {
                for context in CONTEXTS {
                    let candidate = root
                        .join("icons")
                        .join("hicolor")
                        .join(size)
                        .join(context)
                        .join(&file_name);
                    if is_png_file(&candidate) {
                        return Some(candidate);
                    }
                }
            }
            let pixmap = root.join("pixmaps").join(&file_name);
            if is_png_file(&pixmap) {
                return Some(pixmap);
            }
        }

        // Some distributions keep a desktop application's only raster icon in a
        // concrete theme. The bounded search is a final Icon Theme fallback and
        // is cached, so it does not run on each snapshot.
        let mut visited = 0;
        for root in &self.data_roots {
            let mut matches = Vec::new();
            collect_files(&root.join("icons"), 0, &mut visited, &mut matches, |path| {
                path.file_name()
                    .is_some_and(|value| value == file_name.as_str())
            });
            if let Some(path) = matches.into_iter().find(|path| is_png_file(path)) {
                return Some(path);
            }
        }
        None
    }
}

struct DesktopEntry {
    icon: String,
    startup_wm_class: Option<String>,
}

fn parse_desktop_entry(text: &str) -> Option<DesktopEntry> {
    let mut in_desktop_entry = false;
    let mut icon = None;
    let mut startup_wm_class = None;
    for raw_line in text.lines() {
        let line = raw_line.trim();
        if line.starts_with('[') && line.ends_with(']') {
            in_desktop_entry = line == "[Desktop Entry]";
            continue;
        }
        if !in_desktop_entry || line.is_empty() || line.starts_with('#') {
            continue;
        }
        let Some((key, value)) = line.split_once('=') else {
            continue;
        };
        let value = value.trim();
        match key.trim() {
            "Icon" if icon.is_none() && !value.is_empty() => icon = Some(value.to_string()),
            "StartupWMClass" if startup_wm_class.is_none() && !value.is_empty() => {
                startup_wm_class = Some(value.to_string());
            }
            _ => {}
        }
    }
    let icon = icon?;
    if !Path::new(&icon).is_absolute() && safe_icon_name(&icon).is_none() {
        return None;
    }
    Some(DesktopEntry {
        icon,
        startup_wm_class,
    })
}

fn normalized_desktop_key(value: &str) -> String {
    value
        .trim()
        .strip_suffix(".desktop")
        .unwrap_or(value.trim())
        .to_ascii_lowercase()
}

fn safe_icon_name(value: &str) -> Option<&str> {
    let value = value.trim();
    (!value.is_empty()
        && value.len() <= 255
        && value != "."
        && value != ".."
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'.' | b'_' | b'+' | b'-')))
    .then_some(value)
}

fn xdg_data_roots() -> Vec<PathBuf> {
    let mut roots = Vec::new();
    if let Some(data_home) = env::var_os("XDG_DATA_HOME") {
        roots.push(PathBuf::from(data_home));
    } else if let Some(home) = env::var_os("HOME") {
        roots.push(PathBuf::from(home).join(".local/share"));
    }
    let data_dirs = env::var_os("XDG_DATA_DIRS")
        .map(|value| env::split_paths(&value).collect::<Vec<_>>())
        .filter(|paths| !paths.is_empty())
        .unwrap_or_else(|| {
            vec![
                PathBuf::from("/usr/local/share"),
                PathBuf::from("/usr/share"),
            ]
        });
    for path in data_dirs {
        if !roots.contains(&path) {
            roots.push(path);
        }
    }
    roots
}

fn collect_files(
    directory: &Path,
    depth: usize,
    visited: &mut usize,
    output: &mut Vec<PathBuf>,
    matches: impl Copy + Fn(&Path) -> bool,
) {
    if depth > MAX_DIRECTORY_DEPTH || *visited >= MAX_DIRECTORY_ENTRIES {
        return;
    }
    let Ok(entries) = fs::read_dir(directory) else {
        return;
    };
    for entry in entries.filter_map(Result::ok) {
        if *visited >= MAX_DIRECTORY_ENTRIES {
            break;
        }
        *visited += 1;
        let Ok(file_type) = entry.file_type() else {
            continue;
        };
        let path = entry.path();
        if file_type.is_dir() {
            collect_files(&path, depth + 1, visited, output, matches);
        } else if file_type.is_file() && matches(&path) {
            output.push(path);
        }
    }
}

fn is_png_file(path: &Path) -> bool {
    path.extension()
        .and_then(|value| value.to_str())
        .is_some_and(|value| value.eq_ignore_ascii_case("png"))
        && path.is_file()
}

struct RgbaImage {
    width: u32,
    height: u32,
    pixels: Vec<u8>,
}

fn decode_png(path: &Path) -> Option<RgbaImage> {
    let metadata = fs::metadata(path).ok()?;
    if metadata.len() > MAX_ICON_FILE_BYTES {
        return None;
    }
    let mut decoder = png::Decoder::new(BufReader::new(File::open(path).ok()?));
    decoder.set_transformations(png::Transformations::normalize_to_color8());
    let mut reader = decoder.read_info().ok()?;
    let (width, height) = reader.info().size();
    if width == 0 || height == 0 || width > MAX_ICON_EDGE || height > MAX_ICON_EDGE {
        return None;
    }
    let output_size = reader.output_buffer_size()?;
    if output_size > MAX_DECODED_ICON_BYTES {
        return None;
    }
    let mut source = vec![0; output_size];
    let info = reader.next_frame(&mut source).ok()?;
    source.truncate(info.buffer_size());
    let pixel_count = usize::try_from(width)
        .ok()?
        .checked_mul(usize::try_from(height).ok()?)?;
    let mut rgba = Vec::with_capacity(pixel_count.checked_mul(4)?);
    match info.color_type {
        png::ColorType::Rgba => rgba.extend_from_slice(&source),
        png::ColorType::Rgb => {
            for pixel in source.chunks_exact(3) {
                rgba.extend_from_slice(&[pixel[0], pixel[1], pixel[2], 0xff]);
            }
        }
        png::ColorType::GrayscaleAlpha => {
            for pixel in source.chunks_exact(2) {
                rgba.extend_from_slice(&[pixel[0], pixel[0], pixel[0], pixel[1]]);
            }
        }
        png::ColorType::Grayscale => {
            for value in source {
                rgba.extend_from_slice(&[value, value, value, 0xff]);
            }
        }
        png::ColorType::Indexed => return None,
    }
    (rgba.len() == pixel_count * 4).then_some(RgbaImage {
        width,
        height,
        pixels: rgba,
    })
}

fn resize_and_encode(image: &RgbaImage, target_edge: u32) -> Option<Vec<u8>> {
    let source_width = usize::try_from(image.width).ok()?;
    let source_height = usize::try_from(image.height).ok()?;
    let edge = usize::try_from(target_edge).ok()?;
    let (scaled_width, scaled_height) = if image.width >= image.height {
        (
            edge,
            usize::try_from(
                (u64::from(image.height) * u64::from(target_edge) / u64::from(image.width)).max(1),
            )
            .ok()?,
        )
    } else {
        (
            usize::try_from(
                (u64::from(image.width) * u64::from(target_edge) / u64::from(image.height)).max(1),
            )
            .ok()?,
            edge,
        )
    };
    let offset_x = (edge - scaled_width) / 2;
    let offset_y = (edge - scaled_height) / 2;
    let mut output = vec![0; edge.checked_mul(edge)?.checked_mul(4)?];
    for target_y in 0..scaled_height {
        let source_y = target_y * source_height / scaled_height;
        for target_x in 0..scaled_width {
            let source_x = target_x * source_width / scaled_width;
            let source_offset = source_y
                .checked_mul(source_width)?
                .checked_add(source_x)?
                .checked_mul(4)?;
            let target_offset = (target_y + offset_y)
                .checked_mul(edge)?
                .checked_add(target_x + offset_x)?
                .checked_mul(4)?;
            output
                .get_mut(target_offset..target_offset + 4)?
                .copy_from_slice(image.pixels.get(source_offset..source_offset + 4)?);
        }
    }
    encode_rgba_png(target_edge, target_edge, &output)
}

fn encode_rgba_png(width: u32, height: u32, rgba: &[u8]) -> Option<Vec<u8>> {
    let expected = usize::try_from(width)
        .ok()?
        .checked_mul(usize::try_from(height).ok()?)?
        .checked_mul(4)?;
    if rgba.len() != expected {
        return None;
    }
    let mut output = Vec::new();
    {
        let mut encoder = png::Encoder::new(&mut output, width, height);
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);
        let mut writer = encoder.write_header().ok()?;
        writer.write_image_data(rgba).ok()?;
    }
    Some(output)
}

#[cfg(test)]
mod tests {
    use std::fs;

    use tempfile::tempdir;

    use super::{DesktopIconResolver, encode_rgba_png, safe_icon_name};

    #[test]
    fn resolves_desktop_id_and_startup_class_to_bounded_pngs() {
        let directory = tempdir().expect("temporary XDG data root");
        let applications = directory.path().join("applications");
        let pixmaps = directory.path().join("pixmaps");
        fs::create_dir_all(&applications).expect("applications directory");
        fs::create_dir_all(&pixmaps).expect("pixmaps directory");
        fs::write(
            applications.join("org.example.Editor.desktop"),
            "[Desktop Entry]\nIcon=example-editor\nStartupWMClass=ExampleEditor\n",
        )
        .expect("desktop entry");
        let pixels = vec![0x80; 64 * 32 * 4];
        fs::write(
            pixmaps.join("example-editor.png"),
            encode_rgba_png(64, 32, &pixels).expect("encode fixture"),
        )
        .expect("icon fixture");
        let mut resolver = DesktopIconResolver::from_data_roots(vec![directory.path().into()]);

        for app_id in ["org.example.Editor", "ExampleEditor"] {
            let icons = resolver.resolve(None, Some(app_id));
            let small = icons.small.expect("small icon");
            let large = icons.large.expect("large icon");
            assert_eq!(&small[16..24], &[0, 0, 0, 16, 0, 0, 0, 16]);
            assert_eq!(&large[16..24], &[0, 0, 0, 32, 0, 0, 0, 32]);
        }
    }

    #[test]
    fn rejects_path_traversal_as_a_theme_icon_name() {
        assert!(safe_icon_name("../../private").is_none());
        assert!(safe_icon_name("folder/icon").is_none());
        assert_eq!(
            safe_icon_name("org.example_App-1"),
            Some("org.example_App-1")
        );
    }
}
