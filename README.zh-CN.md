# taskmgr-rs

简体中文 | [English](README.md)

`taskmgr-rs` 是一个面向 Windows 与 Linux 的桌面任务管理器：Flutter 负责跨平台界面，Rust 负责原生系统采样与安全操作。两平台共用一套前端，保留原有七页结构、菜单层级、紧凑表格、按钮顺序、对话框、快捷键和图表语义，并采用克制的现代桌面视觉。

## 支持目标

- Windows x64、ARM64
- Linux x64、ARM64
- 不再支持 Windows x86

主界面始终以普通用户权限运行。程序不会把读取失败伪装成 `0`：整项不受支持时由能力模型隐藏，单值不可得时明确显示“不可用/权限不足”，刷新失败则保留最后一份可信快照并标记过期。

## 工程结构

- `flutter_app/`：共用桌面 UI、八种 ARB 语言、内置 Noto Sans 字体及 Flutter 测试
- `flutter_app/lib/src/native_bridge/`：提交到仓库的 FRB Dart 生成代码
- `flutter_app/native_builder/`：Cargokit 构建与打包集成
- `crates/taskmgr-core/`：不可变快照、能力模型、安全身份、设置、历史和有界运行时
- `crates/taskmgr-linux/`：`/proc`、`/sys`、DRM、网络、用户及窗口系统 provider
- `crates/taskmgr-windows/`：Windows API provider
- `crates/taskmgr-bridge/`：Flutter 唯一加载的 Rust `cdylib`
- `crates/taskmgr-helper/`：按需启动、动作白名单化的提权 helper
- `docs/flutter-migration-plan.md`：完整实施规格和完成门槛

Windows 只部署一个 `taskmgr_native.dll`，Linux 只部署一个 `libtaskmgr_native.so`；其他 Rust crate 均静态链接为 `rlib`，不会形成一组需要随程序发布的动态库。

Linux 的应用程序页优先使用 Wayland，顺序为标准 `ext-foreign-toplevel-list-v1`、wlroots、KDE Plasma 兼容协议；三者都不可用时才回退 X11/EWMH。KDE 安装包会通过 desktop entry 声明其受限窗口管理接口，开发机可运行 `scripts/test-kwin-wayland.sh` 做真实 KWin 枚举测试。

## 固定工具链

- Flutter `3.44.7`
- Rust `1.97.1`
- `flutter_rust_bridge` 与 codegen `2.12.0`
- `tray_manager` `0.5.3`

安装固定版本 Rust，并让 Flutter 3.44.7 位于 `PATH` 后运行：

```bash
cargo +1.97.1 check --workspace --all-targets
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter run -d linux
```

完整质量检查还包括四架构 CI、FRB 生成漂移检查、七页 golden、八语言四档缩放测试，以及 Linux/Windows bundle 中唯一 Rust 动态库的内容审计。

Flutter 桌面构建会由 Cargokit 自动编译并携带原生动态库。FRB 生成代码必须提交；重新生成后工作树不应出现漂移。

## 已归档参考代码

迁移前的 Win32 源码保留在本地 `achieved/taskmgr-rs-win32-reference/`，仅用于核对视觉和 Windows 行为。该目录被新 Git 仓库明确忽略，不属于新源码树，也不会进入任何正式构建。

## 许可证

[MIT](LICENSE)。内置 Noto 字体另按 `flutter_app/assets/fonts/OFL.txt` 中的 SIL Open Font License 分发。
