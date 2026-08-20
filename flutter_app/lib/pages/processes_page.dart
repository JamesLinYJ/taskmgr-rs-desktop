// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 进程页
//
//   文件:       flutter_app/lib/pages/processes_page.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   原 IDD_PROCPAGE 与 16 列 ListView；Linux procfs 语义
// --------------------------------------------------------------------------

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/backend_controller.dart';
import '../l10n/app_localizations.dart';
import '../src/native_bridge/api.dart';
import '../src/native_bridge/third_party/taskmgr_core.dart';
import '../ui/desktop_controls.dart';
import '../ui/desktop_dialogs.dart';
import '../ui/formatters.dart';

class ProcessesPage extends StatefulWidget {
  const ProcessesPage({
    super.key,
    required this.controller,
    required this.data,
    required this.capability,
    required this.confirmations,
    required this.processColumns,
    required this.logicalProcessors,
    this.initialSelection,
  });

  final BackendController controller;
  final ProcessesData? data;
  final PageCapability? capability;
  final bool confirmations;
  final List<ColumnLayout> processColumns;
  final List<int> logicalProcessors;
  final ProcessIdentity? initialSelection;

  @override
  State<ProcessesPage> createState() => _ProcessesPageState();
}

class _ProcessesPageState extends State<ProcessesPage> {
  ProcessIdentity? _selectedIdentity;

  @override
  void initState() {
    super.initState();
    _selectedIdentity = widget.initialSelection;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fallback = l10n.notAvailable;
    final rows = widget.data?.rows ?? const <ProcessRow>[];
    final selected = _selectedFor(rows);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 6, 7),
      child: Column(
        children: <Widget>[
          Expanded(
            child: DesktopDataTable<ProcessRow>(
              columns: _columns(l10n, fallback),
              rows: rows,
              identity: (row) => row.identity,
              initiallySelectedIdentity: widget.initialSelection,
              onSelectionChanged: (row) =>
                  setState(() => _selectedIdentity = row?.identity),
              onColumnWidthChanged: _saveColumnWidth,
              contextMenuBuilder: (row) => <DesktopMenuEntry>[
                DesktopMenuEntry(
                  label: l10n.endProcess,
                  enabled: _supports(ActionKind.endProcess),
                  onPressed: () => _end(row, false),
                ),
                DesktopMenuEntry(
                  label: l10n.endProcessTree,
                  enabled: _supports(ActionKind.endProcessTree),
                  onPressed: () => _end(row, true),
                ),
                if (_supports(ActionKind.setPriority)) ...<DesktopMenuEntry>[
                  DesktopMenuEntry(
                    label: l10n.setPriority,
                    children: <DesktopMenuEntry>[
                      _priorityEntry(
                        l10n.realtime,
                        row,
                        ProcessPriority.realtime,
                      ),
                      _priorityEntry(l10n.high, row, ProcessPriority.high),
                      _priorityEntry(
                        l10n.aboveNormal,
                        row,
                        ProcessPriority.aboveNormal,
                      ),
                      _priorityEntry(l10n.normal, row, ProcessPriority.normal),
                      _priorityEntry(
                        l10n.belowNormal,
                        row,
                        ProcessPriority.belowNormal,
                      ),
                      _priorityEntry(l10n.low, row, ProcessPriority.low),
                    ],
                  ),
                ],
                if (_supports(ActionKind.setNice))
                  DesktopMenuEntry(
                    label: l10n.setNice,
                    onPressed: () => _setNice(row),
                  ),
                const DesktopMenuEntry.separator(),
                DesktopMenuEntry(
                  label: l10n.openFileLocation,
                  enabled:
                      row.executablePath != null &&
                      _supports(ActionKind.openFileLocation),
                  onPressed: () => _openFileLocation(row),
                ),
                DesktopMenuEntry(
                  label: l10n.setAffinity,
                  enabled:
                      _supports(ActionKind.setAffinity) &&
                      row.affinity != null &&
                      widget.logicalProcessors.isNotEmpty,
                  onPressed: () => _setAffinity(row),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerRight,
            child: DesktopButton(
              label: l10n.endProcess,
              width: 98,
              onPressed: selected == null || !_supports(ActionKind.endProcess)
                  ? null
                  : () => _end(selected, false),
            ),
          ),
        ],
      ),
    );
  }

  bool _supports(ActionKind action) {
    final capability = widget.capability;
    return capability == null || capability.actions.contains(action);
  }

  ProcessRow? _selectedFor(List<ProcessRow> rows) {
    final identity = _selectedIdentity;
    if (identity == null) {
      return null;
    }
    for (final row in rows) {
      if (row.identity == identity) {
        return row;
      }
    }
    return null;
  }

  void _saveColumnWidth(int columnIndex, double width) {
    final visible = _visibleColumnIds();
    if (columnIndex < 0 || columnIndex >= visible.length) {
      return;
    }
    final changed = visible[columnIndex];
    final all = _availableColumnIds();
    final current = <ColumnId, ColumnLayout>{
      for (final layout in widget.processColumns) layout.column: layout,
    };
    final layouts = all
        .map(
          (column) => ColumnLayout(
            column: column,
            width: column == changed
                ? width
                : current[column]?.width ?? _defaultWidth(column),
            visible: current.isEmpty
                ? true
                : (current[column]?.visible ?? false),
          ),
        )
        .toList(growable: false);
    unawaited(widget.controller.setUiPreferences(processColumns: layouts));
  }

  List<ColumnId> _availableColumnIds() {
    final supported = widget.capability?.columns;
    final legacy = supported == null || supported.isEmpty;
    return _processColumnOrder
        .where((column) => legacy || supported.contains(column))
        .toList(growable: false);
  }

  List<ColumnId> _visibleColumnIds() {
    final layouts = <ColumnId, ColumnLayout>{
      for (final layout in widget.processColumns) layout.column: layout,
    };
    return _availableColumnIds()
        .where(
          (column) => layouts.isEmpty || (layouts[column]?.visible ?? false),
        )
        .toList(growable: false);
  }

  double _defaultWidth(ColumnId column) {
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

  DesktopMenuEntry _priorityEntry(
    String label,
    ProcessRow row,
    ProcessPriority priority,
  ) {
    return DesktopMenuEntry(
      label: label,
      checked: row.basePriority?.toLowerCase() == _priorityName(priority),
      onPressed: () => _setPriority(row, priority),
    );
  }

  String _priorityName(ProcessPriority priority) {
    return switch (priority) {
      ProcessPriority.low => 'low',
      ProcessPriority.belowNormal => 'below normal',
      ProcessPriority.normal => 'normal',
      ProcessPriority.aboveNormal => 'above normal',
      ProcessPriority.high => 'high',
      ProcessPriority.realtime => 'realtime',
    };
  }

  List<DesktopColumn<ProcessRow>> _columns(
    AppLocalizations l10n,
    String fallback,
  ) {
    final supported = widget.capability?.columns;
    final legacy = supported == null || supported.isEmpty;
    final layouts = <ColumnId, ColumnLayout>{
      for (final layout in widget.processColumns) layout.column: layout,
    };
    bool show(ColumnId id) {
      final available = legacy || supported.contains(id);
      return available && (layouts.isEmpty || (layouts[id]?.visible ?? false));
    }

    double width(ColumnId id, double fallback) =>
        layouts[id]?.width ?? fallback;
    return <DesktopColumn<ProcessRow>>[
      if (show(ColumnId.imageName))
        DesktopColumn(
          label: l10n.processColumnImageName,
          width: width(ColumnId.imageName, 107),
          value: (r) => r.imageName,
        ),
      if (show(ColumnId.pid))
        DesktopColumn(
          label: l10n.processColumnPid,
          width: width(ColumnId.pid, 50),
          numeric: true,
          value: (r) => r.identity.pid.toString(),
          compare: (a, b) => a.identity.pid.compareTo(b.identity.pid),
        ),
      if (show(ColumnId.userName))
        DesktopColumn(
          label: l10n.processColumnUserName,
          width: width(ColumnId.userName, 107),
          value: (r) => textOrUnavailable(r.userName, fallback),
        ),
      if (show(ColumnId.sessionId))
        DesktopColumn(
          label: l10n.processColumnSessionId,
          width: width(ColumnId.sessionId, 60),
          numeric: true,
          value: (r) => r.sessionId?.toString() ?? fallback,
        ),
      if (show(ColumnId.cpu))
        DesktopColumn(
          label: l10n.processColumnCpu,
          width: width(ColumnId.cpu, 35),
          numeric: true,
          value: (r) => percentOrUnavailable(r.cpuPercent, fallback),
        ),
      if (show(ColumnId.cpuTime))
        DesktopColumn(
          label: l10n.processColumnCpuTime,
          width: width(ColumnId.cpuTime, 70),
          numeric: true,
          value: (r) => cpuTimeOrUnavailable(r.cpuTimeMillis, fallback),
        ),
      if (show(ColumnId.memoryUsage))
        DesktopColumn(
          label: l10n.processColumnMemoryUsage,
          width: width(ColumnId.memoryUsage, 70),
          numeric: true,
          value: (r) => kibOrUnavailable(r.memoryKib, fallback),
        ),
      if (show(ColumnId.memoryDelta))
        DesktopColumn(
          label: l10n.processColumnMemoryUsageDelta,
          width: width(ColumnId.memoryDelta, 70),
          numeric: true,
          value: (r) => signedIntegerOrUnavailable(r.memoryDeltaKib, fallback),
        ),
      if (show(ColumnId.pageFaults))
        DesktopColumn(
          label: l10n.processColumnPageFaults,
          width: width(ColumnId.pageFaults, 70),
          numeric: true,
          value: (r) => integerOrUnavailable(r.pageFaults, fallback),
        ),
      if (show(ColumnId.pageFaultsDelta))
        DesktopColumn(
          label: l10n.processColumnPageFaultsDelta,
          width: width(ColumnId.pageFaultsDelta, 70),
          numeric: true,
          value: (r) => signedIntegerOrUnavailable(r.pageFaultsDelta, fallback),
        ),
      if (show(ColumnId.virtualMemory))
        DesktopColumn(
          label: l10n.processColumnVirtualMemorySize,
          width: width(ColumnId.virtualMemory, 70),
          numeric: true,
          value: (r) => kibOrUnavailable(r.virtualMemoryKib, fallback),
        ),
      if (show(ColumnId.pagedPool))
        DesktopColumn(
          label: l10n.processColumnPagedPool,
          width: width(ColumnId.pagedPool, 70),
          numeric: true,
          value: (r) => kibOrUnavailable(r.pagedPoolKib, fallback),
        ),
      if (show(ColumnId.nonPagedPool))
        DesktopColumn(
          label: l10n.processColumnNonPagedPool,
          width: width(ColumnId.nonPagedPool, 70),
          numeric: true,
          value: (r) => kibOrUnavailable(r.nonPagedPoolKib, fallback),
        ),
      if (show(ColumnId.basePriority))
        DesktopColumn(
          label: l10n.processColumnBasePriority,
          width: width(ColumnId.basePriority, 60),
          numeric: true,
          value: (r) => textOrUnavailable(r.basePriority, fallback),
        ),
      if (show(ColumnId.handleCount))
        DesktopColumn(
          label: l10n.processColumnHandleCount,
          width: width(ColumnId.handleCount, 60),
          numeric: true,
          value: (r) => integerOrUnavailable(r.handleCount, fallback),
        ),
      if (show(ColumnId.threadCount))
        DesktopColumn(
          label: l10n.processColumnThreadCount,
          width: width(ColumnId.threadCount, 60),
          numeric: true,
          value: (r) => integerOrUnavailable(r.threadCount, fallback),
        ),
      if (show(ColumnId.fileDescriptorCount))
        DesktopColumn(
          label: l10n.processColumnFileDescriptorCount,
          width: width(ColumnId.fileDescriptorCount, 82),
          numeric: true,
          value: (r) => integerOrUnavailable(r.fileDescriptorCount, fallback),
        ),
      if (show(ColumnId.nice))
        DesktopColumn(
          label: l10n.processColumnNice,
          width: width(ColumnId.nice, 55),
          numeric: true,
          value: (r) => r.nice?.toString() ?? fallback,
        ),
      if (show(ColumnId.cgroup))
        DesktopColumn(
          label: l10n.processColumnCgroup,
          width: width(ColumnId.cgroup, 150),
          value: (r) => textOrUnavailable(r.cgroup, fallback),
        ),
    ];
  }

  static const _processColumnOrder = <ColumnId>[
    ColumnId.imageName,
    ColumnId.pid,
    ColumnId.userName,
    ColumnId.sessionId,
    ColumnId.cpu,
    ColumnId.cpuTime,
    ColumnId.memoryUsage,
    ColumnId.memoryDelta,
    ColumnId.pageFaults,
    ColumnId.pageFaultsDelta,
    ColumnId.virtualMemory,
    ColumnId.pagedPool,
    ColumnId.nonPagedPool,
    ColumnId.basePriority,
    ColumnId.handleCount,
    ColumnId.threadCount,
    ColumnId.fileDescriptorCount,
    ColumnId.nice,
    ColumnId.cgroup,
  ];

  Future<void> _end(ProcessRow row, bool descendants) async {
    final l10n = AppLocalizations.of(context);
    if (widget.confirmations &&
        !await showDesktopConfirm(
          context,
          title: l10n.warningTitle,
          message: descendants
              ? l10n.killProcessTreePrompt
              : l10n.killProcessWarning,
        )) {
      return;
    }
    final result = await widget.controller.execute(
      BridgeActionRequest.endProcess(
        identity: row.identity,
        includeDescendants: descendants,
      ),
    );
    if (mounted) {
      await showActionFailure(context, result);
      if (result?.status == ActionStatus.succeeded) {
        await widget.controller.refresh(PageId.processes);
      }
    }
  }

  Future<void> _setPriority(ProcessRow row, ProcessPriority priority) async {
    final l10n = AppLocalizations.of(context);
    if (widget.confirmations &&
        !await showDesktopConfirm(
          context,
          title: l10n.warningTitle,
          message: l10n.priorityChangeWarning,
        )) {
      return;
    }
    final result = await widget.controller.execute(
      BridgeActionRequest.setPriority(
        identity: row.identity,
        priority: priority,
      ),
    );
    if (mounted) {
      await showActionFailure(context, result);
      if (result?.status == ActionStatus.succeeded) {
        await widget.controller.refresh(PageId.processes);
      }
    }
  }

  Future<void> _setAffinity(ProcessRow row) async {
    final current = row.affinity;
    if (current == null || widget.logicalProcessors.isEmpty) {
      return;
    }
    final selected = await showProcessorAffinityDialog(
      context,
      processors: widget.logicalProcessors,
      selected: current.toSet(),
    );
    if (!mounted || selected == null) {
      return;
    }
    final sorted = selected.toList()..sort();
    final result = await widget.controller.execute(
      BridgeActionRequest.setAffinity(
        identity: row.identity,
        logicalProcessors: Uint32List.fromList(sorted),
      ),
    );
    if (!mounted) {
      return;
    }
    await showActionFailure(context, result);
    if (result?.status == ActionStatus.succeeded) {
      await widget.controller.refresh(PageId.processes);
    }
  }

  Future<void> _setNice(ProcessRow row) async {
    final current = row.nice;
    if (current == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final nice = await showNiceValueDialog(context, current: current);
    if (!mounted || nice == null || nice == current) {
      return;
    }
    if (widget.confirmations &&
        !await showDesktopConfirm(
          context,
          title: l10n.warningTitle,
          message: l10n.niceChangeWarning,
        )) {
      return;
    }
    final result = await widget.controller.execute(
      BridgeActionRequest.setNice(identity: row.identity, nice: nice),
    );
    if (!mounted) {
      return;
    }
    await showActionFailure(context, result);
    if (result?.status == ActionStatus.succeeded) {
      await widget.controller.refresh(PageId.processes);
    }
  }

  Future<void> _openFileLocation(ProcessRow row) async {
    final result = await widget.controller.execute(
      BridgeActionRequest.openFileLocation(identity: row.identity),
    );
    if (mounted) {
      await showActionFailure(context, result);
    }
  }
}
