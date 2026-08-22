// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Flutter 应用窗口壳
//
//   文件:       flutter_app/lib/app/task_manager_app.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   原主窗口菜单/标签/状态栏；Flutter desktop 系统标题栏
// --------------------------------------------------------------------------

import 'dart:async';
import 'dart:ui' show AppExitType;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import '../pages/applications_page.dart';
import '../pages/cpu_page.dart';
import '../pages/gpu_page.dart';
import '../pages/network_page.dart';
import '../pages/performance_page.dart';
import '../pages/processes_page.dart';
import '../pages/users_page.dart';
import '../src/native_bridge/api.dart';
import '../src/native_bridge/third_party/taskmgr_core.dart';
import '../ui/desktop_controls.dart';
import '../ui/desktop_dialogs.dart';
import '../ui/desktop_theme.dart';
import '../ui/diagnostic_dialog.dart';
import '../ui/formatters.dart';
import 'app_window_controller.dart';
import 'backend_controller.dart';
import 'backend_state.dart';

class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({
    super.key,
    required this.controller,
    this.windowController = const NoopAppWindowController(),
  });

  final BackendController controller;
  final AppWindowController windowController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: DesktopTheme.data(),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: _TaskManagerWindow(
        controller: controller,
        windowController: windowController,
      ),
    );
  }
}

class _TaskManagerWindow extends StatefulWidget {
  const _TaskManagerWindow({
    required this.controller,
    required this.windowController,
  });

  final BackendController controller;
  final AppWindowController windowController;

  @override
  State<_TaskManagerWindow> createState() => _TaskManagerWindowState();
}

class _TaskManagerWindowState extends State<_TaskManagerWindow> {
  static const _pageOrder = <PageId>[
    PageId.applications,
    PageId.processes,
    PageId.performance,
    PageId.cpu,
    PageId.gpu,
    PageId.network,
    PageId.users,
  ];

  List<ApplicationIdentity> _selectedApplicationIdentities =
      const <ApplicationIdentity>[];
  ProcessIdentity? _requestedProcessSelection;
  int _processSelectionGeneration = 0;
  Availability _trayAvailability = Availability.unsupported;
  bool _trayInitializationStarted = false;
  int? _lastTrayCpuPercent;
  String? _lastTrayTooltip;

  @override
  void dispose() {
    widget.windowController.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BackendState>(
      valueListenable: widget.controller,
      builder: (context, state, child) {
        final l10n = AppLocalizations.of(context);
        final capabilities = state.capabilities;
        if (!_trayInitializationStarted && capabilities != null) {
          _trayInitializationStarted = true;
          unawaited(_initializeTray(l10n, capabilities.tray));
        }
        _scheduleTrayUpdate(l10n, state);
        final visiblePages = _pageOrder
            .where((page) => _isPageVisible(state.capabilities, page))
            .toList(growable: false);
        final pages = visiblePages.isEmpty ? _pageOrder : visiblePages;
        final activePage = pages.contains(state.activePage)
            ? state.activePage
            : pages.first;
        final tinyFootprint =
            activePage == PageId.performance &&
            (state.settings?.tinyFootprint ?? false);
        final selectedApplications = _selectedApplicationsFor(
          state.applications,
        );
        final selectedApplication = selectedApplications.isEmpty
            ? null
            : selectedApplications.first;
        return Scaffold(
          body: SafeArea(
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.f5): () =>
                    widget.controller.refresh(activePage),
                const SingleActivator(LogicalKeyboardKey.escape, shift: true):
                    widget.windowController.minimize,
                const SingleActivator(LogicalKeyboardKey.enter): () {
                  final selected = selectedApplication;
                  if (activePage == PageId.applications &&
                      selected != null &&
                      selected.allowedActions.contains(ActionKind.switchTo)) {
                    _switchSelectedApplication(
                      context,
                      selected,
                      state.settings?.minimizeOnUse ?? false,
                    );
                  }
                },
                const SingleActivator(LogicalKeyboardKey.delete): () {
                  final selected = selectedApplications
                      .where(
                        (row) =>
                            row.allowedActions.contains(ActionKind.endTask),
                      )
                      .toList(growable: false);
                  if (activePage == PageId.applications &&
                      selected.isNotEmpty) {
                    _applicationWindowActions(
                      context,
                      selected,
                      WindowAction.close,
                    );
                  }
                },
                const SingleActivator(
                  LogicalKeyboardKey.tab,
                  control: true,
                ): () =>
                    _moveTab(pages, activePage, 1),
                const SingleActivator(
                  LogicalKeyboardKey.tab,
                  control: true,
                  shift: true,
                ): () =>
                    _moveTab(pages, activePage, -1),
              },
              child: Focus(
                autofocus: true,
                child: Column(
                  children: <Widget>[
                    if (!tinyFootprint)
                      DesktopMenuBar(
                        menus: _menus(
                          context,
                          state,
                          activePage,
                          selectedApplications,
                        ),
                      ),
                    if (!tinyFootprint)
                      DesktopTabs<PageId>(
                        tabs: pages
                            .map(
                              (page) => DesktopTab<PageId>(
                                page,
                                _pageLabel(l10n, page),
                              ),
                            )
                            .toList(growable: false),
                        selected: activePage,
                        onSelected: widget.controller.selectPage,
                      ),
                    Expanded(
                      key: const ValueKey<String>('task-manager-page-content'),
                      child: Container(
                        margin: tinyFootprint
                            ? EdgeInsets.zero
                            : const EdgeInsets.fromLTRB(6, 6, 6, 4),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: DesktopTheme.surface,
                          border: tinyFootprint
                              ? null
                              : Border.all(color: DesktopTheme.border),
                          borderRadius: tinyFootprint
                              ? null
                              : BorderRadius.circular(
                                  DesktopTheme.radiusMedium,
                                ),
                        ),
                        child: Column(
                          children: <Widget>[
                            if (!tinyFootprint)
                              if (_notice(state, activePage) case final notice?)
                                _SnapshotNotice(text: notice),
                            Expanded(
                              child: _animatedPage(context, state, activePage),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!tinyFootprint)
                      DesktopStatusBar(items: _statusItems(l10n, state)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<DesktopMenuRoot> _menus(
    BuildContext context,
    BackendState state,
    PageId page,
    List<ApplicationRow> selectedApplications,
  ) {
    final l10n = AppLocalizations.of(context);
    final settings = state.settings;
    final roots = <DesktopMenuRoot>[
      DesktopMenuRoot(l10n.file, <DesktopMenuEntry>[
        DesktopMenuEntry(
          label: l10n.newTaskMenu,
          enabled: _supportsAction(
            state.capabilities,
            PageId.applications,
            ActionKind.runTask,
          ),
          onPressed: () => _runTask(context),
        ),
        const DesktopMenuEntry.separator(),
        DesktopMenuEntry(
          label: l10n.exitTaskManager,
          onPressed: _exitTaskManager,
        ),
      ]),
      DesktopMenuRoot(l10n.options, <DesktopMenuEntry>[
        DesktopMenuEntry(
          label: l10n.alwaysOnTop,
          checked: settings?.alwaysOnTop ?? false,
          onPressed: () =>
              _setAlwaysOnTop(context, !(settings?.alwaysOnTop ?? false)),
        ),
        DesktopMenuEntry(
          label: l10n.minimizeOnUse,
          checked: settings?.minimizeOnUse ?? false,
          onPressed: () => widget.controller.setUiPreferences(
            minimizeOnUse: !(settings?.minimizeOnUse ?? false),
          ),
        ),
        if (page == PageId.applications ||
            page == PageId.processes ||
            page == PageId.performance)
          DesktopMenuEntry(
            label: l10n.confirmations,
            checked: settings?.confirmations ?? true,
            onPressed: () => widget.controller.setUiPreferences(
              confirmations: !(settings?.confirmations ?? true),
            ),
          ),
        DesktopMenuEntry(
          label: l10n.hideWhenMinimized,
          enabled: _trayAvailability == Availability.supported,
          checked:
              _trayAvailability == Availability.supported &&
              (settings?.hideWhenMinimized ?? false),
          onPressed: () => _setHideWhenMinimized(
            context,
            !(settings?.hideWhenMinimized ?? false),
          ),
        ),
      ]),
      DesktopMenuRoot(l10n.view, <DesktopMenuEntry>[
        DesktopMenuEntry(
          label: l10n.refreshNow,
          onPressed: () => widget.controller.refresh(page),
        ),
        DesktopMenuEntry(
          label: l10n.updateSpeed,
          children: <DesktopMenuEntry>[
            _speedEntry(l10n.high, UpdateSpeed.high, state.updateSpeed),
            _speedEntry(l10n.normal, UpdateSpeed.normal, state.updateSpeed),
            _speedEntry(l10n.low, UpdateSpeed.low, state.updateSpeed),
            _speedEntry(l10n.paused, UpdateSpeed.paused, state.updateSpeed),
          ],
        ),
        if (page == PageId.applications) ...<DesktopMenuEntry>[
          const DesktopMenuEntry.separator(),
          _applicationViewEntry(
            l10n.largeIcons,
            ApplicationViewMode.largeIcons,
            settings?.applicationViewMode ?? ApplicationViewMode.details,
          ),
          _applicationViewEntry(
            l10n.smallIcons,
            ApplicationViewMode.smallIcons,
            settings?.applicationViewMode ?? ApplicationViewMode.details,
          ),
          _applicationViewEntry(
            l10n.details,
            ApplicationViewMode.details,
            settings?.applicationViewMode ?? ApplicationViewMode.details,
          ),
        ],
        if (page == PageId.performance) ...<DesktopMenuEntry>[
          const DesktopMenuEntry.separator(),
          DesktopMenuEntry(
            label: l10n.cpuHistory,
            children: <DesktopMenuEntry>[
              DesktopMenuEntry(
                label: l10n.oneGraphAllCpus,
                checked: !(settings?.oneGraphPerCpu ?? false),
                radio: true,
                onPressed: () =>
                    widget.controller.setUiPreferences(oneGraphPerCpu: false),
              ),
              DesktopMenuEntry(
                label: l10n.oneGraphPerCpu,
                checked: settings?.oneGraphPerCpu ?? false,
                radio: true,
                onPressed: () =>
                    widget.controller.setUiPreferences(oneGraphPerCpu: true),
              ),
            ],
          ),
          DesktopMenuEntry(
            label: l10n.showKernelTimes,
            checked: settings?.showKernelTimes ?? false,
            onPressed: () => widget.controller.setUiPreferences(
              showKernelTimes: !(settings?.showKernelTimes ?? false),
            ),
          ),
        ],
        if (page == PageId.cpu) ...<DesktopMenuEntry>[
          const DesktopMenuEntry.separator(),
          DesktopMenuEntry(
            label: l10n.showKernelTimes,
            checked: settings?.showKernelTimes ?? false,
            onPressed: () => widget.controller.setUiPreferences(
              showKernelTimes: !(settings?.showKernelTimes ?? false),
            ),
          ),
        ],
        if (page == PageId.processes) ...<DesktopMenuEntry>[
          const DesktopMenuEntry.separator(),
          DesktopMenuEntry(
            label: l10n.selectColumnsMenu,
            enabled: state.settings != null,
            onPressed: () => _selectProcessColumns(context, state),
          ),
        ],
      ]),
    ];
    if (page == PageId.applications) {
      final allApplications =
          state.applications?.rows ?? const <ApplicationRow>[];
      final selectionOrAll = selectedApplications.isEmpty
          ? allApplications
          : selectedApplications;
      final minimizable = selectionOrAll
          .where((row) => row.allowedActions.contains(ActionKind.minimize))
          .toList(growable: false);
      final maximizable = selectionOrAll
          .where((row) => row.allowedActions.contains(ActionKind.maximize))
          .toList(growable: false);
      final foregroundable = selectedApplications
          .where((row) => row.allowedActions.contains(ActionKind.bringToFront))
          .toList(growable: false);
      final canTileHorizontally =
          selectionOrAll.isNotEmpty &&
          _supportsAction(
            state.capabilities,
            PageId.applications,
            ActionKind.tileHorizontally,
          );
      final canTileVertically =
          selectionOrAll.isNotEmpty &&
          _supportsAction(
            state.capabilities,
            PageId.applications,
            ActionKind.tileVertically,
          );
      final canCascade =
          selectionOrAll.isNotEmpty &&
          _supportsAction(
            state.capabilities,
            PageId.applications,
            ActionKind.cascade,
          );
      roots.add(
        DesktopMenuRoot(l10n.windows, <DesktopMenuEntry>[
          DesktopMenuEntry(
            label: l10n.tileHorizontally,
            enabled: canTileHorizontally,
            onPressed: () => _arrangeApplicationWindows(
              context,
              selectionOrAll,
              WindowArrangement.tileHorizontally,
            ),
          ),
          DesktopMenuEntry(
            label: l10n.tileVertically,
            enabled: canTileVertically,
            onPressed: () => _arrangeApplicationWindows(
              context,
              selectionOrAll,
              WindowArrangement.tileVertically,
            ),
          ),
          DesktopMenuEntry(
            label: l10n.minimize,
            enabled: minimizable.isNotEmpty,
            onPressed: () => _applicationWindowActions(
              context,
              minimizable,
              WindowAction.minimize,
            ),
          ),
          DesktopMenuEntry(
            label: l10n.maximize,
            enabled: maximizable.isNotEmpty,
            onPressed: () => _applicationWindowActions(
              context,
              maximizable,
              WindowAction.maximize,
            ),
          ),
          DesktopMenuEntry(
            label: l10n.cascade,
            enabled: canCascade,
            onPressed: () => _arrangeApplicationWindows(
              context,
              selectionOrAll,
              WindowArrangement.cascade,
            ),
          ),
          DesktopMenuEntry(
            label: l10n.bringToFront,
            enabled: foregroundable.isNotEmpty,
            onPressed: () => _applicationWindowActions(
              context,
              foregroundable.reversed.toList(growable: false),
              WindowAction.bringToFront,
            ),
          ),
        ]),
      );
    }
    roots.add(
      DesktopMenuRoot(l10n.help, <DesktopMenuEntry>[
        DesktopMenuEntry(label: l10n.helpTopics, enabled: false),
        DesktopMenuEntry(
          label: l10n.diagnosticLogs,
          onPressed: () => _showDiagnostics(context),
        ),
        const DesktopMenuEntry.separator(),
        DesktopMenuEntry(
          label: l10n.aboutTaskManager,
          onPressed: () => _showAbout(context),
        ),
      ]),
    );
    return roots;
  }

  DesktopMenuEntry _speedEntry(
    String label,
    UpdateSpeed speed,
    UpdateSpeed selected,
  ) {
    return DesktopMenuEntry(
      label: label,
      checked: speed == selected,
      radio: true,
      onPressed: () => widget.controller.setUpdateSpeed(speed),
    );
  }

  DesktopMenuEntry _applicationViewEntry(
    String label,
    ApplicationViewMode mode,
    ApplicationViewMode selected,
  ) {
    return DesktopMenuEntry(
      label: label,
      checked: mode == selected,
      radio: true,
      onPressed: () =>
          widget.controller.setUiPreferences(applicationViewMode: mode),
    );
  }

  Widget _page(BuildContext context, BackendState state, PageId page) {
    final settings = state.settings;
    return switch (page) {
      PageId.applications => ApplicationsPage(
        controller: widget.controller,
        data: state.applications,
        capability: _capabilityFor(state.capabilities, page),
        onRunTask:
            _supportsAction(
              state.capabilities,
              PageId.applications,
              ActionKind.runTask,
            )
            ? () => _runTask(context)
            : null,
        onSwitchCompleted: settings?.minimizeOnUse == true
            ? widget.windowController.minimize
            : null,
        onGoToProcess: _isPageVisible(state.capabilities, PageId.processes)
            ? _goToProcess
            : null,
        viewMode: settings?.applicationViewMode ?? ApplicationViewMode.details,
        onViewModeChanged: (mode) =>
            widget.controller.setUiPreferences(applicationViewMode: mode),
        onSelectionsChanged: (rows) {
          final identities = rows
              .map((row) => row.identity)
              .toList(growable: false);
          if (!_sameApplicationIdentities(
            _selectedApplicationIdentities,
            identities,
          )) {
            setState(() => _selectedApplicationIdentities = identities);
          }
        },
      ),
      PageId.processes => ProcessesPage(
        key: ValueKey<int>(_processSelectionGeneration),
        controller: widget.controller,
        data: state.processes,
        capability: _capabilityFor(state.capabilities, page),
        confirmations: settings?.confirmations ?? true,
        processColumns: settings?.processColumns ?? const <ColumnLayout>[],
        logicalProcessors:
            state.capabilities?.logicalProcessors ?? const <int>[],
        initialSelection: _requestedProcessSelection,
      ),
      PageId.performance => PerformancePage(
        data: state.performance,
        showKernelTimes: settings?.showKernelTimes ?? false,
        oneGraphPerCpu: settings?.oneGraphPerCpu ?? true,
        platform: state.capabilities?.platform,
        tinyFootprint: settings?.tinyFootprint ?? false,
        onToggleTinyFootprint: () => widget.controller.setUiPreferences(
          tinyFootprint: !(settings?.tinyFootprint ?? false),
        ),
      ),
      PageId.cpu => CpuPage(
        data: state.cpu,
        platform: state.capabilities?.platform,
        showKernelTimes: settings?.showKernelTimes ?? false,
      ),
      PageId.gpu => GpuPage(data: state.gpu),
      PageId.network => NetworkPage(data: state.network),
      PageId.users => UsersPage(
        controller: widget.controller,
        data: state.users,
        confirmations: settings?.confirmations ?? true,
      ),
    };
  }

  Widget _animatedPage(BuildContext context, BackendState state, PageId page) {
    final transitionDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : DesktopTheme.pageTransitionDuration;
    return AnimatedSwitcher(
      duration: transitionDuration,
      reverseDuration: transitionDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: <Widget>[...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.015),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey<PageId>(page),
        child: _PageRenderCache(
          controller: widget.controller,
          page: page,
          localRevision: page == PageId.processes
              ? _processSelectionGeneration
              : 0,
          builder: _page,
        ),
      ),
    );
  }

  List<String> _statusItems(AppLocalizations l10n, BackendState state) {
    final performance = state.performance;
    final processCount =
        performance?.processCount ??
        (state.processes == null
            ? null
            : BigInt.from(state.processes!.rows.length));
    final cpu = performance?.cpuPercent;
    final total = performance?.memoryTotalKib;
    final available = performance?.memoryAvailableKib;
    final used = total != null && available != null
        ? (total >= available ? total - available : BigInt.zero)
        : null;
    return <String>[
      processCount == null
          ? replacePrintf(l10n.formatProcesses, <Object>[l10n.notAvailable])
          : replacePrintf(l10n.formatProcesses, <Object>[processCount]),
      replacePrintf(l10n.formatCpuUsage, <Object>[
        cpu == null ? l10n.notAvailable : cpu.round(),
      ]),
      replacePrintf(l10n.formatMemoryUsage, <Object>[
        used ?? l10n.notAvailable,
        total ?? l10n.notAvailable,
      ]),
    ];
  }

  bool _isPageVisible(PlatformCapabilities? capabilities, PageId page) {
    if (capabilities == null) {
      return true;
    }
    final matches = capabilities.pages.where(
      (capability) => capability.page == page,
    );
    return matches.isNotEmpty &&
        matches.first.availability != Availability.unsupported;
  }

  PageCapability? _capabilityFor(
    PlatformCapabilities? capabilities,
    PageId page,
  ) {
    final matches = capabilities?.pages.where((item) => item.page == page);
    return matches == null || matches.isEmpty ? null : matches.first;
  }

  bool _supportsAction(
    PlatformCapabilities? capabilities,
    PageId page,
    ActionKind action,
  ) {
    return _capabilityFor(capabilities, page)?.actions.contains(action) ??
        false;
  }

  List<ApplicationRow> _selectedApplicationsFor(
    ApplicationsData? applications,
  ) {
    if (_selectedApplicationIdentities.isEmpty) {
      return const <ApplicationRow>[];
    }
    final current = <ApplicationIdentity, ApplicationRow>{
      for (final row in applications?.rows ?? const <ApplicationRow>[])
        row.identity: row,
    };
    return _selectedApplicationIdentities
        .map((identity) => current[identity])
        .whereType<ApplicationRow>()
        .toList(growable: false);
  }

  bool _sameApplicationIdentities(
    List<ApplicationIdentity> left,
    List<ApplicationIdentity> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _runTask(BuildContext context) async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final result = await widget.controller.execute(
        const BridgeActionRequest.showRunDialog(),
      );
      if (context.mounted) {
        await showActionFailure(context, result);
        if (result?.status == ActionStatus.succeeded) {
          await widget.controller.refresh(PageId.applications);
        }
      }
      return;
    }
    final commandLine = await showRunTaskDialog(context);
    if (!context.mounted || commandLine == null) {
      return;
    }
    final result = await widget.controller.execute(
      BridgeActionRequest.runTask(commandLine: commandLine),
    );
    if (context.mounted) {
      await showActionFailure(context, result);
      if (result?.status == ActionStatus.succeeded) {
        await widget.controller.refresh(PageId.applications);
      }
    }
  }

  Future<void> _showAbout(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final result = await widget.controller.execute(
        BridgeActionRequest.showAboutDialog(title: l10n.appTitle),
      );
      if (context.mounted) {
        await showActionFailure(context, result);
      }
      return;
    }
    await showDesktopMessage(
      context,
      title: l10n.aboutTaskManager,
      message: '${l10n.appTitle}\nv0.3.0',
    );
  }

  Future<void> _showDiagnostics(BuildContext context) {
    return showDiagnosticLogsDialog(
      context,
      controller: widget.controller,
      onRestarted: _exitTaskManager,
    );
  }

  Future<void> _setAlwaysOnTop(BuildContext context, bool enabled) async {
    try {
      await widget.windowController.setAlwaysOnTop(enabled);
      await widget.controller.setUiPreferences(alwaysOnTop: enabled);
    } catch (error) {
      if (context.mounted) {
        await showDesktopMessage(
          context,
          title: AppLocalizations.of(context).warningTitle,
          message: error.toString(),
        );
      }
    }
  }

  Future<void> _initializeTray(
    AppLocalizations l10n,
    Availability backendAvailability,
  ) async {
    final settings = widget.controller.value.settings;
    if (backendAvailability == Availability.unsupported) {
      await widget.windowController.setHideWhenMinimized(false);
      if (settings?.hideWhenMinimized == true) {
        await widget.controller.setUiPreferences(hideWhenMinimized: false);
      }
      return;
    }
    final availability = await widget.windowController.initializeTray(
      restoreLabel: stripMnemonic(l10n.restoreTaskManager),
      exitLabel: stripMnemonic(l10n.exitTaskManager),
      alwaysOnTopLabel: stripMnemonic(l10n.alwaysOnTop),
      alwaysOnTop: settings?.alwaysOnTop ?? false,
    );
    if (!mounted) {
      return;
    }
    final canHide = availability == Availability.supported;
    try {
      await widget.windowController.setHideWhenMinimized(
        canHide && (settings?.hideWhenMinimized ?? false),
      );
    } catch (error) {
      widget.controller.reportUiError(error);
    }
    if (!canHide && settings?.hideWhenMinimized == true) {
      await widget.controller.setUiPreferences(hideWhenMinimized: false);
    }
    if (mounted) {
      setState(() => _trayAvailability = availability);
    }
  }

  void _scheduleTrayUpdate(AppLocalizations l10n, BackendState state) {
    if (_trayAvailability == Availability.unsupported) {
      return;
    }
    final cpuPercent = state.performance?.cpuPercent?.round().clamp(0, 100);
    final tooltip = replacePrintf(l10n.formatCpuUsage, <Object>[
      cpuPercent ?? l10n.notAvailable,
    ]);
    if (_lastTrayCpuPercent == cpuPercent && _lastTrayTooltip == tooltip) {
      return;
    }
    _lastTrayCpuPercent = cpuPercent;
    _lastTrayTooltip = tooltip;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_updateTray(cpuPercent, tooltip));
      }
    });
  }

  Future<void> _updateTray(int? cpuPercent, String tooltip) async {
    try {
      await widget.windowController.updateTray(
        cpuPercent: cpuPercent,
        tooltip: tooltip,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await widget.windowController.setHideWhenMinimized(false);
      if (widget.controller.value.settings?.hideWhenMinimized == true) {
        await widget.controller.setUiPreferences(hideWhenMinimized: false);
      }
      widget.controller.reportUiError(error);
      if (mounted) {
        setState(() => _trayAvailability = Availability.unsupported);
      }
    }
  }

  Future<void> _setHideWhenMinimized(BuildContext context, bool enabled) async {
    try {
      await widget.windowController.setHideWhenMinimized(enabled);
      await widget.controller.setUiPreferences(hideWhenMinimized: enabled);
    } catch (error) {
      if (context.mounted) {
        await showDesktopMessage(
          context,
          title: AppLocalizations.of(context).warningTitle,
          message: error.toString(),
        );
      }
    }
  }

  Future<void> _exitTaskManager() async {
    try {
      await widget.controller.close();
    } finally {
      await ServicesBinding.instance.exitApplication(AppExitType.required);
    }
  }

  Future<bool> _applicationWindowAction(
    BuildContext context,
    ApplicationRow row,
    WindowAction action,
  ) async {
    final result = await widget.controller.execute(
      BridgeActionRequest.window(identity: row.identity, operation: action),
    );
    if (context.mounted) {
      await showActionFailure(context, result);
      if (result?.status == ActionStatus.succeeded) {
        await widget.controller.refresh(PageId.applications);
        return true;
      }
    }
    return false;
  }

  Future<void> _applicationWindowActions(
    BuildContext context,
    List<ApplicationRow> rows,
    WindowAction action,
  ) async {
    ActionResult? firstFailure;
    var succeeded = false;
    for (final row in rows) {
      final result = await widget.controller.execute(
        BridgeActionRequest.window(identity: row.identity, operation: action),
      );
      if (result?.status == ActionStatus.succeeded) {
        succeeded = true;
      } else {
        firstFailure ??= result;
      }
    }
    if (!context.mounted) {
      return;
    }
    if (firstFailure != null) {
      await showActionFailure(context, firstFailure);
    }
    if (succeeded) {
      await widget.controller.refresh(PageId.applications);
    }
  }

  Future<void> _arrangeApplicationWindows(
    BuildContext context,
    List<ApplicationRow> rows,
    WindowArrangement arrangement,
  ) async {
    final result = await widget.controller.execute(
      BridgeActionRequest.arrangeWindows(
        identities: rows.map((row) => row.identity).toList(growable: false),
        arrangement: arrangement,
      ),
    );
    if (context.mounted) {
      await showActionFailure(context, result);
      if (result?.status == ActionStatus.succeeded) {
        await widget.controller.refresh(PageId.applications);
      }
    }
  }

  Future<void> _switchSelectedApplication(
    BuildContext context,
    ApplicationRow row,
    bool minimizeOnUse,
  ) async {
    if (await _applicationWindowAction(context, row, WindowAction.switchTo) &&
        minimizeOnUse) {
      await widget.windowController.minimize();
    }
  }

  void _goToProcess(ProcessIdentity identity) {
    final generation = _processSelectionGeneration + 1;
    setState(() {
      _requestedProcessSelection = identity;
      _processSelectionGeneration = generation;
    });
    unawaited(
      widget.controller.selectPage(PageId.processes).whenComplete(() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _processSelectionGeneration != generation) {
            return;
          }
          setState(() => _requestedProcessSelection = null);
        });
      }),
    );
  }

  String? _notice(BackendState state, PageId page) {
    final meta = state.metaFor(page);
    if (meta?.error != null) {
      return meta!.error!.message;
    }
    if (state.errorText != null) {
      return state.errorText;
    }
    return null;
  }

  String _pageLabel(AppLocalizations l10n, PageId page) {
    return switch (page) {
      PageId.applications => l10n.applicationsPageTitle,
      PageId.processes => l10n.processesPageTitle,
      PageId.performance => l10n.performancePageTitle,
      PageId.cpu => l10n.cpuPageTitle,
      PageId.gpu => l10n.gpuPageTitle,
      PageId.network => l10n.networkingPageTitle,
      PageId.users => l10n.usersPageTitle,
    };
  }

  void _moveTab(List<PageId> pages, PageId current, int delta) {
    final index = pages.indexOf(current);
    final next = (index + delta) % pages.length;
    widget.controller.selectPage(pages[next]);
  }

  Future<void> _selectProcessColumns(
    BuildContext context,
    BackendState state,
  ) async {
    final settings = state.settings;
    if (settings == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final supported = _capabilityFor(
      state.capabilities,
      PageId.processes,
    )?.columns;
    final choices =
        <(ColumnId, String)>[
              (ColumnId.imageName, l10n.processColumnImageName),
              (ColumnId.pid, l10n.processColumnPid),
              (ColumnId.userName, l10n.processColumnUserName),
              (ColumnId.sessionId, l10n.processColumnSessionId),
              (ColumnId.cpu, l10n.processColumnCpu),
              (ColumnId.cpuTime, l10n.processColumnCpuTime),
              (ColumnId.memoryUsage, l10n.processColumnMemoryUsage),
              (ColumnId.memoryDelta, l10n.processColumnMemoryUsageDelta),
              (ColumnId.pageFaults, l10n.processColumnPageFaults),
              (ColumnId.pageFaultsDelta, l10n.processColumnPageFaultsDelta),
              (ColumnId.virtualMemory, l10n.processColumnVirtualMemorySize),
              (ColumnId.pagedPool, l10n.processColumnPagedPool),
              (ColumnId.nonPagedPool, l10n.processColumnNonPagedPool),
              (ColumnId.basePriority, l10n.processColumnBasePriority),
              (ColumnId.handleCount, l10n.processColumnHandleCount),
              (ColumnId.threadCount, l10n.processColumnThreadCount),
              (
                ColumnId.fileDescriptorCount,
                l10n.processColumnFileDescriptorCount,
              ),
              (ColumnId.nice, l10n.processColumnNice),
              (ColumnId.cgroup, l10n.processColumnCgroup),
            ]
            .where((choice) {
              return supported == null ||
                  supported.isEmpty ||
                  supported.contains(choice.$1);
            })
            .toList(growable: false);
    final existing = <ColumnId, ColumnLayout>{
      for (final layout in settings.processColumns) layout.column: layout,
    };
    final selected = settings.processColumns.isEmpty
        ? choices.map((choice) => choice.$1).toSet()
        : existing.values
              .where((layout) => layout.visible)
              .map((layout) => layout.column)
              .toSet();
    final result = await showSelectColumnsDialog(
      context,
      columns: choices,
      selected: selected,
    );
    if (!mounted || result == null) {
      return;
    }
    final layouts = choices
        .map(
          (choice) => ColumnLayout(
            column: choice.$1,
            width:
                existing[choice.$1]?.width ?? _defaultProcessWidth(choice.$1),
            visible: result.contains(choice.$1),
          ),
        )
        .toList(growable: false);
    await widget.controller.setUiPreferences(processColumns: layouts);
  }

  double _defaultProcessWidth(ColumnId column) {
    return switch (column) {
      ColumnId.imageName || ColumnId.userName => 107,
      ColumnId.pid => 50,
      ColumnId.cpu => 35,
      ColumnId.cpuTime ||
      ColumnId.memoryUsage ||
      ColumnId.memoryDelta ||
      ColumnId.pageFaults ||
      ColumnId.pageFaultsDelta ||
      ColumnId.virtualMemory ||
      ColumnId.pagedPool ||
      ColumnId.nonPagedPool => 70,
      ColumnId.sessionId ||
      ColumnId.basePriority ||
      ColumnId.handleCount ||
      ColumnId.threadCount => 60,
      ColumnId.fileDescriptorCount => 82,
      ColumnId.nice => 55,
      ColumnId.cgroup => 150,
      _ => 80,
    };
  }
}

class _SnapshotNotice extends StatelessWidget {
  const _SnapshotNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const BoxDecoration(
        color: Color(0xfffff7e6),
        border: Border(
          bottom: BorderSide(color: Color(0xffffd591)),
          left: BorderSide(color: Color(0xfff79009), width: 3),
        ),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xff7a2e0e)),
      ),
    );
  }
}

typedef _CachedPageBuilder = Widget Function(
  BuildContext context,
  BackendState state,
  PageId page,
);

/// Keeps an unchanged active page subtree out of unrelated backend rebuilds.
///
/// The status bar consumes the always-on performance snapshot even while another
/// page is visible. Without this cache, that snapshot rebuilt every row and graph
/// on the active page. Identity comparison is intentional: backend snapshots are
/// immutable and a changed reference is the commit boundary for that page.
class _PageRenderCache extends StatefulWidget {
  const _PageRenderCache({
    required this.controller,
    required this.page,
    required this.localRevision,
    required this.builder,
  });

  final BackendController controller;
  final PageId page;
  final int localRevision;
  final _CachedPageBuilder builder;

  @override
  State<_PageRenderCache> createState() => _PageRenderCacheState();
}

class _PageRenderCacheState extends State<_PageRenderCache> {
  late _PageRenderFingerprint _fingerprint;
  Widget? _cachedChild;

  @override
  void initState() {
    super.initState();
    _fingerprint = _PageRenderFingerprint.capture(
      widget.controller.value,
      widget.page,
      widget.localRevision,
    );
    widget.controller.addListener(_handleBackendUpdate);
  }

  @override
  void didChangeDependencies() {
    _cachedChild = null;
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant _PageRenderCache oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleBackendUpdate);
      widget.controller.addListener(_handleBackendUpdate);
    }
    final next = _PageRenderFingerprint.capture(
      widget.controller.value,
      widget.page,
      widget.localRevision,
    );
    if (!_fingerprint.sameAs(next)) {
      _fingerprint = next;
      _cachedChild = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleBackendUpdate);
    super.dispose();
  }

  void _handleBackendUpdate() {
    final next = _PageRenderFingerprint.capture(
      widget.controller.value,
      widget.page,
      widget.localRevision,
    );
    if (_fingerprint.sameAs(next)) {
      return;
    }
    setState(() {
      _fingerprint = next;
      _cachedChild = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _cachedChild ??= RepaintBoundary(
      child: widget.builder(context, widget.controller.value, widget.page),
    );
  }
}

class _PageRenderFingerprint {
  const _PageRenderFingerprint({
    required this.data,
    required this.meta,
    required this.settings,
    required this.capabilities,
    required this.localRevision,
  });

  factory _PageRenderFingerprint.capture(
    BackendState state,
    PageId page,
    int localRevision,
  ) {
    final data = switch (page) {
      PageId.applications => state.applications,
      PageId.processes => state.processes,
      PageId.performance => state.performance,
      PageId.cpu => state.cpu,
      PageId.gpu => state.gpu,
      PageId.network => state.network,
      PageId.users => state.users,
    };
    return _PageRenderFingerprint(
      data: data,
      meta: state.metaFor(page),
      settings: state.settings,
      capabilities: state.capabilities,
      localRevision: localRevision,
    );
  }

  final Object? data;
  final SnapshotMeta? meta;
  final UiSettings? settings;
  final PlatformCapabilities? capabilities;
  final int localRevision;

  bool sameAs(_PageRenderFingerprint other) {
    return identical(data, other.data) &&
        identical(meta, other.meta) &&
        identical(settings, other.settings) &&
        identical(capabilities, other.capabilities) &&
        localRevision == other.localRevision;
  }
}
