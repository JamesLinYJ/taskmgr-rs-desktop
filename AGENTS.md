# AGENTS.md

本文件适用于整个仓库。它规定新一代 `taskmgr-rs` 的产品边界、工程约束和完成标准，供开发者与自动化智能体共同遵守。

## 1. 项目定位

`taskmgr-rs` 是一个以 Flutter 实现桌面界面、以 Rust 实现系统采集与受控操作的 Windows/Linux 任务管理器。

本仓库从 `v0.3.0` 起作为独立的新项目演进：

- 不保留旧 Win32 UI、旧 Cargo 单 crate 布局、旧注册表配置或旧二进制接口的兼容义务。
- 旧实现只能作为界面测量、行为核对和平台采集算法的归档参考，不能成为新代码的运行时依赖。
- 旧实现固定保存在被新 Git 忽略的 `achieved/` 下，不得删除、提交或重新接入正式构建图。
- “独立”指源码、构建、配置和发布生命周期独立，不授权自动修改 Git 远端、历史或仓库所有权。

产品必须同时满足：

- 保留既有任务管理器的信息架构、页面骨架、数据密度和操作习惯，并使用统一、克制的现代桌面视觉呈现。
- Windows 和 Linux 共用一套 Flutter 控件树与交互模型。
- Rust 只提供真实平台数据、能力、结构化错误和安全动作；不得伪造跨平台等价性。
- UI isolate 不执行系统采样或阻塞 I/O。
- 普通 GUI 永不以管理员或 root 身份运行。

## 2. 固定技术基线

- Flutter `3.44.7`，Dart 使用该 Flutter SDK 自带版本。
- Rust `1.97.1`，edition 2024，版本由 `rust-toolchain.toml` 固定。
- `flutter_rust_bridge 2.12.0`，使用 Cargokit 集成；生成代码提交仓库并由 CI 检查漂移。
- 正式目标仅为 Windows/Linux 的 x64、ARM64；不恢复 Windows x86。
- Flutter 是唯一正式 UI；Rust 对 Flutter 只暴露一个 `cdylib`：Windows 为 `taskmgr_native.dll`，Linux 为 `libtaskmgr_native.so`。
- 内部 Rust crate 必须保持 `rlib`，不得形成一组需要随应用部署的 Rust 动态库。
- 依赖版本必须锁定并提交 `Cargo.lock`、`pubspec.lock`。新增依赖需要说明用途、许可证和现有依赖不足之处。

如需改变这些基线，必须先更新架构计划、CI 和发布矩阵，不能在局部实现中暗自偏离。

## 3. 文件头

新建或发生职责级重构的手写源码必须使用该语言的行注释写入以下通用字段；不要在本规则文件中写死任何作者、Agent 或模型名称：

```text
+-------------------------------------------------------------------------

  taskmgr-rs - [模块职责]

  文件:       [仓库相对路径]

  日期:       YYYY年MM月DD日
  环境:       [实测 OS/内核/架构；工具链]
  作者:       [Author Name]
  协助:       [Agent Name]:[Model name]
  参考标准:   [本文件实际依赖的 API、ABI、协议或内部契约]
-------------------------------------------------------------------------
```

- Rust/Dart/C/C++ 使用 `//`，Shell/YAML 辅助脚本使用 `#`；不支持注释的原生格式不添加横幅。
- `作者` 填写实际作者；`协助` 单独记录实际参与的 Agent 与模型，不能覆盖作者。
- 所有姓名与模型名只能来自任务上下文中的明确信息，不能推测。
- 日期和环境只在新建、重命名或职责级重构时更新；普通修复不刷新。
- Linux 文件列出真实标准，例如 `proc(5)`、`sysfs(5)`、Linux kernel UAPI、rtnetlink、DRM sysfs ABI、EWMH 或具体 Wayland 协议，不能只写“Linux 标准”。
- Windows 文件列出实际 Win32、NT、PDH、DXGI、WTS、COM 或项目协议；未使用的标准不得列入。
- 跨平台文件列出 Rust/Flutter API、FRB 契约或项目内部协议。
- Rust 文件在横幅后用 `//!` 说明线程、所有权和不变量；Dart 文件用库级注释说明界面或状态职责。
- 生成代码、lockfile、图片、字体和第三方 vendored 文件不手工添加横幅。

## 4. 仓库结构与依赖方向

正式结构为：

| 路径 | 职责 |
| --- | --- |
| `flutter_app/` | 唯一桌面前端、主题、七页、对话框、菜单、托盘、本地化与 golden 测试 |
| `crates/taskmgr-core/` | 平台无关模型、能力、快照、历史、错误、动作与后台运行时 |
| `crates/taskmgr-windows/` | Windows 采集、身份验证与原生动作 |
| `crates/taskmgr-linux/` | Linux 采集、身份验证与原生动作 |
| `crates/taskmgr-bridge/` | 唯一 FRB 边界与唯一部署用 Rust 动态库 |
| `crates/taskmgr-helper/` | 按需提权、白名单协议和调用者验证 |
| `docs/` | 架构计划、能力矩阵、视觉基线与发布说明 |
| `packaging/` | Windows/Linux 安装包、polkit、桌面入口和发布元数据 |

依赖方向必须保持：

```text
Flutter -> taskmgr-bridge -> taskmgr-core <- taskmgr-windows/taskmgr-linux
                                      ^
                                      └── taskmgr-helper + platform crate
```

- `taskmgr-core` 不依赖 Flutter、FRB、Win32、libc、X11 或 Wayland。
- 平台 crate 不依赖 Flutter，也不能包含界面文案或布局常量。
- `taskmgr-bridge` 只做类型映射、生命周期协调与事件转发，不复制采样业务。
- Flutter 不直接调用 Win32、`/proc`、`/sys` 或 helper 私有协议。
- 不为每个类型机械拆文件；只有独立生命周期、可复用边界或可独立测试的职责才拆分。

## 5. UI 结构与视觉契约

归档界面是信息架构、页面布局和行为语义的参考，不是新项目必须逐像素复制的皮肤。当前 Flutter golden 是现代桌面视觉的验收基准；系统标题栏、窗口边框和平台字体栅格化差异不参与比较。

必须保持：

- Linux 运行时 application ID 固定为中性的 `org.taskmgr_rs.TaskManager`；GTK application ID、desktop 文件名、图标名与 polkit action 必须一致，不得从作者、协助者、GitHub 用户名或仓库所有者派生运行时 ID。
- 主窗口标题在所有平台保持 Windows NT 品牌并随界面语言本地化，简体中文精确为“Windows NT 任务管理器”；默认及最小客户区严格采用归档 `264 × 247 DLU` 的 `396 × 401` 逻辑像素基准，允许用户向上放大并保存尺寸。
- Windows 与支持服务端装饰的 Linux 桌面优先使用系统标题栏和原生外窗圆角；GNOME/未知 Wayland 回退到 30px 紧凑 CSD、8px 顶部圆角和 24px 标题按钮。不得在 Flutter 客户区再画一套标题栏。
- 主窗口客户区尺寸关系、菜单层级、标签页顺序和快捷键。
- 七页名称与顺序：应用程序、进程、性能、CPU、GPU、网络、用户。
- 表格列顺序、初始列宽、紧凑行密度、排序、选择、键盘焦点和滚动行为。
- 所有按钮、复选框、状态栏、对话框和右键菜单的相对位置、顺序、默认焦点与启用规则。
- 图表绿/黄/红曲线的语义、采样方向和历史窗口；背景、网格和抗锯齿由当前桌面主题统一定义。
- 100% 缩放以仓库内当前 golden 为准；125%、150%、200% 下不得溢出或不可操作。

实现规则：

- 使用集中式 `DesktopTheme`、颜色、字体、圆角、阴影和尺寸 token；页面不得散落近似常量。
- 不直接套用 Material 默认外观。可以使用 Flutter 基础能力，但可见控件必须由项目桌面主题明确绘制。
- 现代化保持克制：允许小圆角、轻阴影、柔和分隔和清晰的 hover/focus/pressed 状态；禁止把紧凑桌面工具改成大卡片、移动端导航或低信息密度布局。
- 大表格使用虚拟化 `TableView` 或等价惰性构建，只创建可见单元格。
- 图表使用 `CustomPainter`；数据更新不得触发表格、菜单或整个页面无关区域重建。
- 页面控制器和 `ValueNotifier` 保持轻量；只重建发生变化的区域。
- 所有交互控件提供 `Semantics`、键盘焦点和快捷键，精确外观不能以牺牲可访问性为代价。
- 状态动画只能短促且不改变布局；页面切换使用 140 ms 淡入与轻微位移动画，系统要求减少动态效果时必须禁用；Windows 与 Linux 不得因平台分别重排页面。

结构与视觉基线必须固化为 `docs/ui-baseline/` 中的规格和 Flutter golden；正式实现不能长期读取或编译旧 UI 源码。

## 6. 快照、线程与背压

- 所有系统采样在 Rust 的持久后台线程完成；禁止每个 tick 新建线程。
- 刷新唤醒使用有界 single-flight 语义：同类请求合并，慢采样不能形成无限队列。
- Flutter UI isolate 只接收不可变快照与能力变化事件。
- 每个页面快照包含 `generation`、采样时间、最新可信数据、`stale` 和结构化错误。
- 整页失败时保留上一轮可信快照并标为陈旧；没有历史数据时才显示不可用。
- 单行或单指标失败只影响该值，并保留同一行的其他可信字段。
- 暂停刷新时不忙等；关闭时所有工作线程、事件转发线程和 helper 会话必须有序退出。
- 500 ms 高速刷新下不得阻塞 Flutter UI isolate；大表传输要以实际进程规模做压力测试。

## 7. 能力与错误语义

`PlatformCapabilities` 是 UI 显示和动作启用的唯一依据，必须逐页、逐列、逐指标、逐动作表达能力。

- 整项在平台上无实现时隐藏；某个值当前不可读时显示“不可用”或“权限不足”。
- 不得用 `0`、空字符串、空列表或默认枚举冒充查询成功。
- 不得把陈旧快照标成新数据。
- 错误必须保留来源、错误码/错误域、是否可重试、是否权限相关和用户可理解的错误键。
- Rust 返回原始值、枚举和错误码；单位、数字、日期和文案由 Flutter 按 locale 格式化。
- 重复后台错误应去重或限流；用户触发的动作错误必须即时显示。
- 不用同步 fallback、固定 sleep、无限重试或未经证明的备用 API 链掩盖失败。

## 8. 进程身份与危险动作

所有进程动作必须携带 `ProcessIdentity { pid, start_time }`，并在实际执行前重新验证。

- Linux 使用 `/proc/<pid>/stat` starttime 与 pidfd；Windows 使用 PID 与进程创建时间。
- 结束进程树应先解析、验证并打开所有目标，再开始终止；部分失败必须如实报告。
- 优先级、nice、调度策略、亲和性、窗口和会话动作均使用最小权限。
- 不允许 PID-only fallback，不允许因为 UI 仍选中旧行就跳过身份验证。
- 窗口动作还需重新验证窗口与进程的对应关系；用户会话动作需验证会话连续性。
- UI 必须在发起动作前明确展示目标和影响范围，高影响动作保留确认步骤。

## 9. 平台实现

Linux：

- 进程、CPU、内存优先使用 `/proc`；GPU 清单以 DRM sysfs 为准，驱动正式管理 ABI 仅补充内核未公开的真实指标，Vulkan 设备必须按 `VK_EXT_pci_bus_info` 的 PCI 地址精确关联；网络使用 rtnetlink，必要时以已声明的 sysfs 字段补充。
- 应用程序页优先使用 Wayland，顺序固定为 `ext-foreign-toplevel-list-v1`、wlroots、KDE Plasma 兼容协议；三者均不可用的 GNOME 会话可连接用户显式启用、版本化且只读的 Shell 扩展，其他情况才回退 X11/EWMH。KDE 与 GNOME 适配器都属于受限桌面环境实现，必须清楚标注，不能描述为统一标准。
- 标准 foreign-toplevel 协议永远优先于桌面适配器。合成器只允许枚举时保留列表并禁用切换、最小化等动作；禁止调用 GNOME `Eval`、`unsafe_mode`、私有调试接口或解析桌面命令输出。
- 用户与会话优先使用 systemd-logind 的公开接口；降级来源必须在能力中可见。
- Windows 句柄、优先级类等概念在 Linux 上使用 FD、RSS/cgroup、nice/调度策略等真实语义，不伪造同名数据。

Windows：

- 使用官方 Win32/NT/PDH/DXGI/WTS/IP Helper 等接口实现旧版等价能力。
- 原生资源必须有唯一所有者；HANDLE、COM、图标、DC、菜单等使用 RAII 或清晰的成对释放。
- API 失败后按文档保留 Win32、HRESULT、NTSTATUS 等错误域，不混成无来源整数。
- Windows provider 不能反向依赖或复用旧 Win32 UI 层。

`unsafe` 必须保持最小范围，并说明指针有效期、缓冲区、线程和所有权前提。

## 10. FRB 公共接口

Flutter 只使用以下强类型入口；新增入口需同步更新计划与契约测试：

```text
startBackend(BackendOptions) -> BackendHandle
watchBackend(handle) -> Stream<BackendEvent>
updateOptions(handle, BackendOptions)
requestRefresh(handle, PageId?)
openPrivilegedSession(handle) -> PrivilegeResult
executeAction(handle, ActionRequest) -> ActionResult
loadSettings() -> SettingsLoadResult
saveSettings(UiSettings)
shutdownBackend(handle)
```

- 生成的 Dart/Rust 桥接代码不得手改。
- API 枚举必须有未知值或协议版本处理策略；双方版本不匹配应明确失败。
- handle 负责运行时生命周期，不暴露原始指针、系统句柄或平台对象。
- Stream 关闭、Flutter 重连和应用退出必须有契约测试。

## 11. 提权 helper

- 主 GUI 永远保持普通权限；只有受保护读取或白名单动作才按需启动 helper。
- Windows 使用 UAC 与限制访问的命名管道；Linux 使用 polkit 与限制访问的 Unix socket。
- helper 验证调用者、协议版本、随机 nonce、消息长度和 `ProcessIdentity`。
- helper 只能接受枚举化白名单请求，禁止 shell、任意命令、任意路径写入或通用 RPC。
- helper 随 GUI 连接断开而退出，不常驻，不监听网络。
- Linux 安装包中的 helper 必须由 root 拥有且不可由普通用户修改；便携 tar 包不启用提权能力。
- UAC/polkit 被取消是正常结果，不能崩溃、循环弹窗或丢失当前快照。

## 12. 设置、本地化与资源

- 设置使用带 schema 版本的 JSON：Windows 位于用户 AppData，Linux 位于 XDG config。
- 写入采用同目录临时文件、flush/fsync 和原子 rename；损坏文件先备份再恢复默认值。
- 不读取、迁移或删除旧注册表设置。
- 九种语言（含独立 `zh_HK`）统一使用 Flutter ARB；可见文本不得硬编码在页面或由 Rust 拼接。
- Rust 错误只提供稳定错误键与参数，Flutter 负责本地化。
- 内置 Noto Sans 系列字体并记录许可证；不得依赖目标机器恰好安装字体。
- 现有图标、位图若继续使用，必须迁移到 Flutter asset 并确认来源、尺寸和缩放行为。
- 托盘不可用时禁用“隐藏到托盘”，避免窗口失去恢复入口。

## 13. 测试与质量门槛

Rust 必须覆盖：

- `/proc`、`/sys` 和 Windows 模拟夹具的解析、增量、排序和错误保留。
- PID 复用、计数器回退/重置、权限拒绝和 helper 协议。
- 请求合并、背压、最后可信快照、重连与关闭。

Flutter 必须覆盖：

- 七页、全部菜单和对话框的 widget/golden 测试。
- 100% 基准及 125%、150%、200% 缩放。
- 九种语言无溢出，键盘、焦点、右键菜单与 Semantics 可用。
- 大进程表和 500 ms 刷新时的帧稳定性。

平台矩阵至少覆盖 Windows、GNOME Wayland、KDE Wayland 与一个 X11 桌面（优先 Xfce），并核对默认客户区、系统/CSD 标题栏、本地化、四档缩放，以及协议/托盘/helper 不可用路径。矩阵外桌面环境为尽力支持，但启动与七页主体不得依赖托盘或 foreign-toplevel 协议。ARM64 正式发布前必须在真实或虚拟 ARM64 环境做启动与采样冒烟测试。

根目录的最低本地门槛：

```bash
cargo fmt --all -- --check
cargo check --workspace --all-targets
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace --all-targets
flutter analyze
flutter test
git diff --check
```

发布 CI 还必须执行 FRB 生成漂移检查、release 构建、安装包内容审计和校验和生成。无法运行的检查必须在交付说明中写清原因、替代证据和剩余风险。

## 14. 构建与发布

- Windows x64/ARM64 发布 Inno Setup 安装包与便携 ZIP，包含 Flutter bundle、Rust DLL 和 UAC helper。
- Linux x64/ARM64 发布 DEB、RPM 和 tar.gz；DEB/RPM 可安装 polkit policy 与 root-owned helper，tar.gz 不包含提权能力。
- 无签名密钥时生成明确标记的未签名包；流水线预留 Authenticode、DEB/RPM 签名阶段。
- 安装、升级和卸载不得删除用户配置；包清单中不应出现多余 Rust 动态库或旧 Win32 UI 产物。
- `target/`、`flutter_app/build/`、`dist/`、本机 SDK、IDE 状态和临时日志不得提交。

## 15. 变更工作流

1. 阅读相关契约、调用者、测试和 `docs/flutter-migration-plan.md`。
2. 写明要保持的视觉、身份、线程、错误或资源不变量。
3. 先建立失败可观察的类型和测试，再实现平台调用或界面。
4. 以候选快照构建完成后原子提交，禁止半更新 UI。
5. 运行最小针对性测试，再运行完整质量门槛。
6. 检查 diff、生成代码、依赖和包内容，记录尚未完成的本机验证。

工作树可能包含他人修改。禁止 `git reset --hard`、未经授权的覆盖、历史重写或清理无关文件。只有任务明确要求时才 commit、push、修改 remote 或创建 PR。

## 16. 禁止模式

- 在 Flutter UI isolate 中采样系统状态或执行阻塞 FFI。
- 用 PID 单独标识跨快照对象或执行破坏性操作。
- 查询失败时展示假 `0`、空列表或伪成功。
- 每次刷新重建整页、完整菜单、所有单元格或图表布局。
- 使用无界通道、每 tick 新线程、busy loop 或 sleep 修复竞态。
- 从平台 crate 返回本地化文案或从 Flutter 直接读取平台数据源。
- 让 GUI 以高权限运行，或让 helper 执行任意命令。
- 继续扩展旧 Win32 UI、旧注册表设置或旧单 crate 构建。
- 以“现代化”为由改变页序、菜单层级、数据密度、动作语义或快捷键。
- 以大量 `allow`、宽泛 `unsafe`、忽略返回值或静默 fallback 消除工具信号。

## 17. Definition of Done

一项工作只有在以下条件同时成立时才完成：

- 功能已进入真实 Flutter → FRB → Rust 路径，不是占位实现或只写计划。
- Windows/Linux 差异由能力模型真实表达，无假数据。
- UI 结构、当前桌面外观和行为由基线测试证明；旧 UI 不参与正式构建或运行。
- UI isolate、后台线程、helper、身份验证和错误保留不变量成立。
- 与风险相称的单元、契约、golden、平台和安装测试已通过。
- 文档、本地化、资源、生成代码、锁文件和发布清单同步更新。
- 未验证项被明确记录，不把“可编译”表述为“运行行为已验证”。
