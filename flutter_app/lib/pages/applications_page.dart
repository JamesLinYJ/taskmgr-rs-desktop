// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 应用程序页
//
//   文件:       flutter_app/lib/pages/applications_page.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   原 IDD_TASKPAGE DLU 布局；EWMH/Wayland 窗口能力模型
// --------------------------------------------------------------------------

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/backend_controller.dart';
import '../l10n/app_localizations.dart';
import '../src/native_bridge/api.dart';
import '../src/native_bridge/third_party/taskmgr_core.dart';
import '../ui/desktop_controls.dart';
import '../ui/desktop_dialogs.dart';
import '../ui/desktop_theme.dart';

class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({
    super.key,
    required this.controller,
    required this.data,
    required this.capability,
    required this.onRunTask,
    required this.onSwitchCompleted,
    required this.onSelectionsChanged,
    required this.onGoToProcess,
    required this.viewMode,
    required this.onViewModeChanged,
  });

  final BackendController controller;
  final ApplicationsData? data;
  final PageCapability? capability;
  final VoidCallback? onRunTask;
  final Future<void> Function()? onSwitchCompleted;
  final ValueChanged<List<ApplicationRow>> onSelectionsChanged;
  final ValueChanged<ProcessIdentity>? onGoToProcess;
  final ApplicationViewMode viewMode;
  final ValueChanged<ApplicationViewMode> onViewModeChanged;

  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  List<ApplicationIdentity> _selectedIdentities = const <ApplicationIdentity>[];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = widget.data?.rows ?? const <ApplicationRow>[];
    final selected = _selectedFor(rows);
    final primary = selected.isEmpty ? null : selected.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 6, 7),
      child: Column(
        children: <Widget>[
          Expanded(child: _applicationList(l10n, rows)),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              DesktopButton(
                label: l10n.endTask,
                width: 80,
                onPressed: _canAll(selected, ActionKind.endTask)
                    ? () => _windowActions(selected, WindowAction.close)
                    : null,
              ),
              const SizedBox(width: 5),
              DesktopButton(
                label: l10n.switchTo,
                width: 80,
                isDefault: true,
                onPressed:
                    primary?.allowedActions.contains(ActionKind.switchTo) ==
                        true
                    ? () => _windowAction(primary!, WindowAction.switchTo)
                    : null,
              ),
              const SizedBox(width: 5),
              DesktopButton(
                label: l10n.newTaskButton,
                width: 82,
                isDefault: true,
                onPressed: widget.onRunTask,
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _canAll(List<ApplicationRow> selected, ActionKind action) =>
      selected.isNotEmpty &&
      selected.every((row) => row.allowedActions.contains(action));

  Widget _applicationList(AppLocalizations l10n, List<ApplicationRow> rows) {
    void selectionsChanged(List<ApplicationRow> selectedRows) {
      setState(() {
        _selectedIdentities = selectedRows
            .map((row) => row.identity)
            .toList(growable: false);
      });
      widget.onSelectionsChanged(selectedRows);
    }

    if (widget.viewMode != ApplicationViewMode.details) {
      return _ApplicationIconView(
        rows: rows,
        large: widget.viewMode == ApplicationViewMode.largeIcons,
        titleFor: (row) => _title(l10n, row),
        initiallySelectedIdentities: _selectedIdentities,
        iconBuilder: (row, large) => _applicationIcon(row, large: large),
        onSelectionsChanged: selectionsChanged,
        onDoubleTap: (row) => _windowAction(row, WindowAction.switchTo),
        contextMenuBuilder: (row) => _contextMenu(l10n, row, rows),
        backgroundContextMenuBuilder: () => _viewContextMenu(l10n),
      );
    }
    return DesktopDataTable<ApplicationRow>(
      columns: <DesktopColumn<ApplicationRow>>[
        DesktopColumn(
          label: l10n.taskColumnTask,
          width: 250,
          value: (row) => _title(l10n, row),
          leading: (row) => _applicationIcon(row),
        ),
        DesktopColumn(
          label: l10n.taskColumnStatus,
          width: 97,
          value: (row) => _status(l10n, row.status),
        ),
        if (_shows(ColumnId.windowStation))
          DesktopColumn(
            label: l10n.taskColumnWinstation,
            width: 70,
            value: (row) => row.windowStation ?? l10n.notAvailable,
          ),
        if (_shows(ColumnId.desktop))
          DesktopColumn(
            label: l10n.taskColumnDesktop,
            width: 70,
            value: (row) => row.desktop ?? l10n.notAvailable,
          ),
      ],
      rows: rows,
      identity: (row) => row.identity,
      multiSelect: true,
      initiallySelectedIdentities: _selectedIdentities,
      onSelectionsChanged: selectionsChanged,
      onDoubleTap: (row) => _windowAction(row, WindowAction.switchTo),
      contextMenuBuilder: (row) => _contextMenu(l10n, row, rows),
      backgroundContextMenuBuilder: () => _viewContextMenu(l10n),
    );
  }

  List<ApplicationRow> _selectedFor(List<ApplicationRow> rows) {
    final current = <ApplicationIdentity, ApplicationRow>{
      for (final row in rows) row.identity: row,
    };
    return _selectedIdentities
        .map((identity) => current[identity])
        .whereType<ApplicationRow>()
        .toList(growable: false);
  }

  List<DesktopMenuEntry> _contextMenu(
    AppLocalizations l10n,
    ApplicationRow row,
    List<ApplicationRow> rows,
  ) {
    final current = _selectedFor(rows);
    final selected = current.any((item) => item.identity == row.identity)
        ? <ApplicationRow>[
            row,
            ...current.where((item) => item.identity != row.identity),
          ]
        : <ApplicationRow>[row];
    final primary = selected.first;
    final canArrange = selected.length >= 2;
    return <DesktopMenuEntry>[
      DesktopMenuEntry(
        label: l10n.switchTo,
        enabled: primary.allowedActions.contains(ActionKind.switchTo),
        onPressed: () => _windowAction(primary, WindowAction.switchTo),
      ),
      DesktopMenuEntry(
        label: l10n.bringToFront,
        enabled: _canAll(selected, ActionKind.bringToFront),
        onPressed: () => _windowActions(
          selected.reversed.toList(growable: false),
          WindowAction.bringToFront,
        ),
      ),
      const DesktopMenuEntry.separator(),
      DesktopMenuEntry(
        label: l10n.minimize,
        enabled: _canAll(selected, ActionKind.minimize),
        onPressed: () => _windowActions(selected, WindowAction.minimize),
      ),
      DesktopMenuEntry(
        label: l10n.maximize,
        enabled: _canAll(selected, ActionKind.maximize),
        onPressed: () => _windowActions(selected, WindowAction.maximize),
      ),
      DesktopMenuEntry(
        label: l10n.cascade,
        enabled: canArrange && _supports(ActionKind.cascade),
        onPressed: () => _arrange(selected, WindowArrangement.cascade),
      ),
      DesktopMenuEntry(
        label: l10n.tileHorizontally,
        enabled: canArrange && _supports(ActionKind.tileHorizontally),
        onPressed: () => _arrange(selected, WindowArrangement.tileHorizontally),
      ),
      DesktopMenuEntry(
        label: l10n.tileVertically,
        enabled: canArrange && _supports(ActionKind.tileVertically),
        onPressed: () => _arrange(selected, WindowArrangement.tileVertically),
      ),
      const DesktopMenuEntry.separator(),
      DesktopMenuEntry(
        label: l10n.endTask,
        enabled: _canAll(selected, ActionKind.endTask),
        onPressed: () => _windowActions(selected, WindowAction.close),
      ),
      DesktopMenuEntry(
        label: l10n.goToProcess,
        enabled:
            primary.identity.process != null && widget.onGoToProcess != null,
        onPressed: () {
          final process = primary.identity.process;
          if (process != null) {
            widget.onGoToProcess?.call(process);
          }
        },
      ),
    ];
  }

  List<DesktopMenuEntry> _viewContextMenu(AppLocalizations l10n) {
    return <DesktopMenuEntry>[
      DesktopMenuEntry(
        label: l10n.newTaskMenu,
        enabled: widget.onRunTask != null,
        onPressed: widget.onRunTask,
      ),
      const DesktopMenuEntry.separator(),
      _viewModeEntry(l10n.largeIcons, ApplicationViewMode.largeIcons),
      _viewModeEntry(l10n.smallIcons, ApplicationViewMode.smallIcons),
      _viewModeEntry(l10n.details, ApplicationViewMode.details),
    ];
  }

  DesktopMenuEntry _viewModeEntry(String label, ApplicationViewMode mode) {
    return DesktopMenuEntry(
      label: label,
      checked: widget.viewMode == mode,
      radio: true,
      onPressed: () => widget.onViewModeChanged(mode),
    );
  }

  bool _supports(ActionKind action) =>
      widget.capability?.actions.contains(action) ?? false;

  bool _shows(ColumnId column) {
    final columns = widget.capability?.columns;
    return columns == null || columns.isEmpty || columns.contains(column);
  }

  Future<void> _windowAction(ApplicationRow row, WindowAction action) async {
    final result = await widget.controller.execute(
      BridgeActionRequest.window(identity: row.identity, operation: action),
    );
    if (mounted) {
      await showActionFailure(context, result);
      if (result?.status == ActionStatus.succeeded) {
        await widget.controller.refresh(PageId.applications);
        if (action == WindowAction.switchTo) {
          await widget.onSwitchCompleted?.call();
        }
      }
    }
  }

  Future<void> _windowActions(
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
    if (!mounted) {
      return;
    }
    if (firstFailure != null) {
      await showActionFailure(context, firstFailure);
    }
    if (succeeded) {
      await widget.controller.refresh(PageId.applications);
    }
  }

  Future<void> _arrange(
    List<ApplicationRow> rows,
    WindowArrangement arrangement,
  ) async {
    final result = await widget.controller.execute(
      BridgeActionRequest.arrangeWindows(
        identities: rows.map((row) => row.identity).toList(growable: false),
        arrangement: arrangement,
      ),
    );
    if (mounted) {
      await showActionFailure(context, result);
      if (result?.status == ActionStatus.succeeded) {
        await widget.controller.refresh(PageId.applications);
      }
    }
  }

  String _status(AppLocalizations l10n, ApplicationStatus status) {
    return switch (status) {
      ApplicationStatus.running => l10n.running,
      ApplicationStatus.notResponding => l10n.notResponding,
      ApplicationStatus.unknown => l10n.unknown,
    };
  }

  String _title(AppLocalizations l10n, ApplicationRow row) {
    final title = row.title.trim();
    final displayTitle = title.isEmpty ? l10n.untitledWindow : title;
    return row.show32BitSuffix == true
        ? '$displayTitle ${l10n.bitness32Suffix}'
        : displayTitle;
  }

  Widget _applicationIcon(ApplicationRow row, {bool large = false}) {
    final bytes = large ? row.largeIconPng ?? row.iconPng : row.iconPng;
    final edge = large ? 32.0 : 16.0;
    if (bytes == null || bytes.isEmpty) {
      return _defaultApplicationIcon(large: large);
    }
    return Image.memory(
      bytes,
      width: edge,
      height: edge,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, _, _) => _defaultApplicationIcon(large: large),
    );
  }

  Widget _defaultApplicationIcon({bool large = false}) {
    final edge = large ? 32.0 : 16.0;
    return Image.asset(
      'assets/icons/default-process-${large ? 32 : 16}.png',
      width: edge,
      height: edge,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
    );
  }
}

class _ApplicationIconView extends StatefulWidget {
  const _ApplicationIconView({
    required this.rows,
    required this.large,
    required this.titleFor,
    required this.initiallySelectedIdentities,
    required this.iconBuilder,
    required this.onSelectionsChanged,
    required this.onDoubleTap,
    required this.contextMenuBuilder,
    required this.backgroundContextMenuBuilder,
  });

  final List<ApplicationRow> rows;
  final bool large;
  final String Function(ApplicationRow row) titleFor;
  final List<ApplicationIdentity> initiallySelectedIdentities;
  final Widget Function(ApplicationRow row, bool large) iconBuilder;
  final ValueChanged<List<ApplicationRow>> onSelectionsChanged;
  final ValueChanged<ApplicationRow> onDoubleTap;
  final List<DesktopMenuEntry> Function(ApplicationRow row) contextMenuBuilder;
  final List<DesktopMenuEntry> Function() backgroundContextMenuBuilder;

  @override
  State<_ApplicationIconView> createState() => _ApplicationIconViewState();
}

class _ApplicationIconViewState extends State<_ApplicationIconView> {
  final Set<ApplicationIdentity> _selected = <ApplicationIdentity>{};
  ApplicationIdentity? _cursor;
  ApplicationIdentity? _anchor;
  int _crossAxisCount = 1;
  Offset? _itemSecondaryDownPosition;

  @override
  void initState() {
    super.initState();
    final available = widget.rows.map((row) => row.identity).toSet();
    _selected.addAll(
      widget.initiallySelectedIdentities.where(available.contains),
    );
    if (_selected.isNotEmpty) {
      _cursor = _selected.last;
      _anchor = _cursor;
    }
  }

  @override
  void didUpdateWidget(_ApplicationIconView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final available = widget.rows.map((row) => row.identity).toSet();
    final before = _selected.length;
    _selected.removeWhere((identity) => !available.contains(identity));
    if (!available.contains(_cursor)) {
      _cursor = _selected.isEmpty ? null : _selected.first;
    }
    if (!available.contains(_anchor)) {
      _anchor = _cursor;
    }
    if (before != _selected.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _notifySelection();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) {
        if (_consumeItemSecondaryDown(details.globalPosition)) {
          return;
        }
        showDesktopContextMenu(
          context,
          details.globalPosition,
          widget.backgroundContextMenuBuilder(),
        );
      },
      child: DecoratedBox(
        key: const ValueKey<String>('applications-icon-view'),
        decoration: BoxDecoration(
          color: DesktopTheme.surface,
          border: DesktopTheme.panelBorder(),
          borderRadius: BorderRadius.circular(DesktopTheme.radiusMedium),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DesktopTheme.radiusMedium),
          child: Focus(
            autofocus: true,
            onKeyEvent: _handleKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final targetWidth = widget.large ? 86.0 : 180.0;
                final columns = (constraints.maxWidth / targetWidth).floor();
                _crossAxisCount = columns < 1 ? 1 : columns;
                return GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _crossAxisCount,
                    mainAxisExtent: widget.large ? 74 : 28,
                  ),
                  itemCount: widget.rows.length,
                  itemBuilder: (context, index) => _buildItem(index),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index) {
    final row = widget.rows[index];
    final title = widget.titleFor(row);
    final selected = _selected.contains(row.identity);
    final color = selected ? DesktopTheme.selectionText : DesktopTheme.text;
    final contents = widget.large
        ? Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              SizedBox.square(
                dimension: 32,
                child: widget.iconBuilder(row, true),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color),
                ),
              ),
            ],
          )
        : Row(
            children: <Widget>[
              SizedBox.square(
                dimension: 16,
                child: widget.iconBuilder(row, false),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color),
                ),
              ),
            ],
          );
    return Semantics(
      selected: selected,
      label: title,
      child: Listener(
        onPointerDown: (event) {
          if ((event.buttons & kPrimaryMouseButton) != 0) {
            final keyboard = HardwareKeyboard.instance;
            _selectIndex(
              index,
              additive: keyboard.isControlPressed || keyboard.isMetaPressed,
              extend: keyboard.isShiftPressed,
            );
          } else if ((event.buttons & kSecondaryMouseButton) != 0) {
            _itemSecondaryDownPosition = event.position;
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () => widget.onDoubleTap(row),
          onSecondaryTapDown: (details) {
            _selectForContextMenu(index);
            showDesktopContextMenu(
              context,
              details.globalPosition,
              widget.contextMenuBuilder(row),
            );
          },
          child: Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: selected ? DesktopTheme.selection : DesktopTheme.surface,
              borderRadius: BorderRadius.circular(DesktopTheme.radiusSmall),
            ),
            child: Padding(
              padding: widget.large
                  ? const EdgeInsets.fromLTRB(3, 2, 3, 1)
                  : const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: contents,
            ),
          ),
        ),
      ),
    );
  }

  bool _consumeItemSecondaryDown(Offset position) {
    final itemPosition = _itemSecondaryDownPosition;
    _itemSecondaryDownPosition = null;
    return itemPosition != null &&
        (itemPosition - position).distanceSquared < 1;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || widget.rows.isEmpty) {
      return KeyEventResult.ignored;
    }
    final current = _cursor == null
        ? -1
        : widget.rows.indexWhere((row) => row.identity == _cursor);
    int? next;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      next = (current + 1).clamp(0, widget.rows.length - 1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      next = (current - 1).clamp(0, widget.rows.length - 1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      next = (current + _crossAxisCount).clamp(0, widget.rows.length - 1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      next = (current - _crossAxisCount).clamp(0, widget.rows.length - 1);
    }
    if (next != null) {
      _selectIndex(next, extend: HardwareKeyboard.instance.isShiftPressed);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyA &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      setState(() {
        _selected
          ..clear()
          ..addAll(widget.rows.map((row) => row.identity));
        _cursor = widget.rows.first.identity;
        _anchor = _cursor;
      });
      _notifySelection();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter && current >= 0) {
      widget.onDoubleTap(widget.rows[current]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _selectIndex(int index, {bool additive = false, bool extend = false}) {
    if (index < 0 || index >= widget.rows.length) {
      return;
    }
    final identity = widget.rows[index].identity;
    setState(() {
      if (extend && _anchor != null) {
        final anchorIndex = widget.rows.indexWhere(
          (row) => row.identity == _anchor,
        );
        if (anchorIndex >= 0) {
          if (!additive) {
            _selected.clear();
          }
          final start = anchorIndex < index ? anchorIndex : index;
          final end = anchorIndex < index ? index : anchorIndex;
          _selected.addAll(
            widget.rows.sublist(start, end + 1).map((row) => row.identity),
          );
        }
      } else if (additive) {
        if (!_selected.add(identity)) {
          _selected.remove(identity);
        }
        _anchor = identity;
      } else {
        _selected
          ..clear()
          ..add(identity);
        _anchor = identity;
      }
      _cursor = identity;
    });
    _notifySelection();
  }

  void _selectForContextMenu(int index) {
    final identity = widget.rows[index].identity;
    if (_selected.contains(identity)) {
      _cursor = identity;
      return;
    }
    _selectIndex(index);
  }

  void _notifySelection() {
    widget.onSelectionsChanged(
      widget.rows
          .where((row) => _selected.contains(row.identity))
          .toList(growable: false),
    );
  }
}
