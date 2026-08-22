// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Flutter 不可变后端视图状态
//
//   文件:       flutter_app/lib/app/backend_state.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter ValueListenable；项目 FRB 协议 v1
// --------------------------------------------------------------------------

import '../src/native_bridge/third_party/taskmgr_core.dart';

/// UI 只读取这个不可变值；每类快照独立替换，避免无关页面重建数据。
class BackendState {
  const BackendState({
    this.loading = true,
    this.activePage = PageId.applications,
    this.updateSpeed = UpdateSpeed.normal,
    this.settings,
    this.capabilities,
    this.diagnostics,
    this.applications,
    this.processes,
    this.performance,
    this.cpu,
    this.gpu,
    this.network,
    this.users,
    this.pageMeta = const <PageId, SnapshotMeta>{},
    this.errorText,
  });

  final bool loading;
  final PageId activePage;
  final UpdateSpeed updateSpeed;
  final UiSettings? settings;
  final PlatformCapabilities? capabilities;
  final DiagnosticStatus? diagnostics;
  final ApplicationsData? applications;
  final ProcessesData? processes;
  final PerformanceData? performance;
  final CpuData? cpu;
  final GpuData? gpu;
  final NetworkData? network;
  final UsersData? users;
  final Map<PageId, SnapshotMeta> pageMeta;
  final String? errorText;

  SnapshotMeta? metaFor(PageId page) => pageMeta[page];

  BackendState copyWith({
    bool? loading,
    PageId? activePage,
    UpdateSpeed? updateSpeed,
    UiSettings? settings,
    PlatformCapabilities? capabilities,
    DiagnosticStatus? diagnostics,
    ApplicationsData? applications,
    ProcessesData? processes,
    PerformanceData? performance,
    CpuData? cpu,
    GpuData? gpu,
    NetworkData? network,
    UsersData? users,
    Map<PageId, SnapshotMeta>? pageMeta,
    String? errorText,
  }) {
    return BackendState(
      loading: loading ?? this.loading,
      activePage: activePage ?? this.activePage,
      updateSpeed: updateSpeed ?? this.updateSpeed,
      settings: settings ?? this.settings,
      capabilities: capabilities ?? this.capabilities,
      diagnostics: diagnostics ?? this.diagnostics,
      applications: applications ?? this.applications,
      processes: processes ?? this.processes,
      performance: performance ?? this.performance,
      cpu: cpu ?? this.cpu,
      gpu: gpu ?? this.gpu,
      network: network ?? this.network,
      users: users ?? this.users,
      pageMeta: pageMeta ?? this.pageMeta,
      errorText: errorText ?? this.errorText,
    );
  }

  BackendState withSnapshotMeta(PageId page, SnapshotMeta meta) {
    return copyWith(pageMeta: <PageId, SnapshotMeta>{...pageMeta, page: meta});
  }
}
