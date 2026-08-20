# taskmgr-rs

[简体中文](README.zh-CN.md) | English

`taskmgr-rs` is a Windows/Linux desktop task manager with a Flutter interface and a Rust native backend. The shared client preserves the established seven-page structure, menu hierarchy, dense tables, button order, dialogs, shortcuts, and graph semantics while using a restrained modern desktop theme on both platforms.

## Supported targets

- Windows x64 and ARM64
- Linux x64 and ARM64
- No Windows x86 build

The GUI always runs with normal user privileges. Missing data is never represented as zero: unsupported sections are hidden by capability, while unavailable individual values remain explicitly unavailable and stale snapshots retain their last trustworthy values.

## Architecture

- `flutter_app/` — shared desktop UI, eight ARB locales, bundled Noto Sans fonts, golden/widget/integration tests
- `flutter_app/lib/src/native_bridge/` — committed FRB-generated Dart bindings
- `flutter_app/native_builder/` — Cargokit integration that builds and bundles the one native library
- `crates/taskmgr-core/` — immutable snapshots, capability model, safe identities, settings, history, and bounded runtime
- `crates/taskmgr-linux/` — `/proc`, `/sys`, DRM, networking, users, and window-system provider
- `crates/taskmgr-windows/` — Windows API provider
- `crates/taskmgr-bridge/` — the only Rust `cdylib` exposed to Flutter
- `crates/taskmgr-helper/` — narrowly scoped, on-demand privileged helper
- `docs/flutter-migration-plan.md` — implementation specification and completion gates

Windows packages contain `taskmgr_native.dll`; Linux packages contain `libtaskmgr_native.so`. The other Rust crates are linked as `rlib`s and are not deployed as separate dynamic libraries.

The Linux Applications page is Wayland-first: standard `ext-foreign-toplevel-list-v1`, then wlroots, then the KDE Plasma compatibility protocol, with X11/EWMH used only after all Wayland options are unavailable. KDE packages declare the restricted window-management interface in their desktop entry; developers can run `scripts/test-kwin-wayland.sh` for a real KWin enumeration test.

## Pinned toolchain

- Flutter `3.44.7`
- Rust `1.97.1`
- `flutter_rust_bridge` / code generator `2.12.0`
- `tray_manager` `0.5.3`
- Rust `png` `0.18.1`

Install the pinned Rust toolchain, make Flutter 3.44.7 available, then run:

```bash
cargo +1.97.1 check --workspace --all-targets
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter run -d linux
```

The full quality gate also covers the four architecture CI jobs, FRB generation drift, seven-page goldens, eight locales at four desktop scale factors, and bundle audits that enforce one Rust dynamic library per platform.

Cargokit compiles the native library as part of the Flutter desktop build. Generated FRB files are committed; regeneration must leave the working tree unchanged.

## Archived reference

The pre-migration Win32 source is retained locally under `achieved/taskmgr-rs-win32-reference/` as a visual and Windows-behavior reference. That directory is intentionally ignored by the new Git repository and is not part of the new source tree or build graph.

## License

[MIT](LICENSE). Bundled Noto fonts are licensed separately under the SIL Open Font License in `flutter_app/assets/fonts/OFL.txt`.
