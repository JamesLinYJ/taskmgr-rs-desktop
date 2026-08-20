// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 跨平台桌面控件集合
//
//   文件:       flutter_app/lib/ui/desktop_controls.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter focus/menu/gestures；two_dimensional_scrollables 0.5.3
// --------------------------------------------------------------------------

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import 'desktop_theme.dart';

class DesktopButton extends StatefulWidget {
  const DesktopButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width,
    this.isDefault = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final double? width;
  final bool isDefault;

  @override
  State<DesktopButton> createState() => _DesktopButtonState();
}

class _DesktopButtonState extends State<DesktopButton> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: stripMnemonic(widget.label),
      child: FocusableActionDetector(
        enabled: enabled,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTapUp: enabled
              ? (_) {
                  setState(() => _pressed = false);
                  widget.onPressed?.call();
                }
              : null,
          child: Container(
            width: widget.width,
            height: DesktopTheme.buttonHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: !enabled
                  ? DesktopTheme.surfaceMuted
                  : widget.isDefault
                  ? (_pressed
                        ? DesktopTheme.accentPressed
                        : DesktopTheme.accent)
                  : _pressed
                  ? DesktopTheme.selection
                  : _hovered
                  ? DesktopTheme.hover
                  : DesktopTheme.surface,
              border: Border.all(
                color: _focused
                    ? DesktopTheme.focusRing
                    : widget.isDefault
                    ? DesktopTheme.accent
                    : DesktopTheme.borderStrong,
              ),
              borderRadius: BorderRadius.circular(DesktopTheme.radiusMedium),
              boxShadow: enabled && !_pressed
                  ? const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x140f172a),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: DesktopMnemonicText(
              widget.label,
              style: TextStyle(
                color: !enabled
                    ? DesktopTheme.disabledText
                    : widget.isDefault
                    ? Colors.white
                    : DesktopTheme.text,
                fontWeight: widget.isDefault
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DesktopGroupBox extends StatelessWidget {
  const DesktopGroupBox({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          top: 6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: DesktopTheme.surface,
              border: Border.all(color: DesktopTheme.border),
              borderRadius: BorderRadius.circular(DesktopTheme.radiusMedium),
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(6, 14, 6, 6), child: child),
        Positioned(
          left: 8,
          top: 0,
          child: ColoredBox(
            color: DesktopTheme.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                label,
                style: const TextStyle(
                  color: DesktopTheme.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DesktopCheckbox extends StatelessWidget {
  const DesktopCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    void toggle() => onChanged?.call(!value);
    return Semantics(
      checked: value,
      enabled: enabled,
      label: stripMnemonic(label),
      child: FocusableActionDetector(
        enabled: enabled,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              toggle();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? toggle : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: !enabled
                        ? DesktopTheme.surfaceMuted
                        : value
                        ? DesktopTheme.accent
                        : DesktopTheme.surface,
                    border: Border.all(
                      color: value
                          ? DesktopTheme.accent
                          : DesktopTheme.borderStrong,
                    ),
                    borderRadius: BorderRadius.circular(
                      DesktopTheme.radiusSmall,
                    ),
                  ),
                  child: value
                      ? CustomPaint(
                          painter: _DesktopCheckPainter(
                            enabled ? Colors.white : DesktopTheme.disabledText,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: DesktopMnemonicText(
                    label,
                    style: TextStyle(
                      color: enabled
                          ? DesktopTheme.text
                          : DesktopTheme.disabledText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DesktopTextField extends StatelessWidget {
  const DesktopTextField({
    super.key,
    required this.controller,
    this.lines = 1,
    this.autofocus = false,
    this.keyboardType,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final int lines;
  final bool autofocus;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      minLines: lines,
      maxLines: lines,
      decoration: const InputDecoration(
        filled: true,
        fillColor: DesktopTheme.surface,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesktopTheme.radiusMedium),
          ),
          borderSide: BorderSide(color: DesktopTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesktopTheme.radiusMedium),
          ),
          borderSide: BorderSide(color: DesktopTheme.accent, width: 1.5),
        ),
      ),
    );
  }
}

class _DesktopCheckPainter extends CustomPainter {
  const _DesktopCheckPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(2.5, size.height * 0.52)
      ..lineTo(5.0, size.height - 3.0)
      ..lineTo(size.width - 2.0, 2.5);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DesktopCheckPainter oldDelegate) =>
      oldDelegate.color != color;
}

class DesktopTab<T> {
  const DesktopTab(this.value, this.label);

  final T value;
  final String label;
}

class DesktopTabs<T> extends StatelessWidget {
  const DesktopTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<DesktopTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: DesktopTheme.background,
        border: Border(bottom: BorderSide(color: DesktopTheme.border)),
      ),
      child: SizedBox(
        height: DesktopTheme.tabHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: tabs
              .map((tab) {
                final active = tab.value == selected;
                return Expanded(
                  child: Semantics(
                    selected: active,
                    button: true,
                    child: GestureDetector(
                      onTap: () => onSelected(tab.value),
                      child: Container(
                        height: DesktopTheme.tabHeight - 3,
                        margin: EdgeInsets.only(
                          left: tab == tabs.first ? 6 : 2,
                          bottom: 3,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? DesktopTheme.surface
                              : Colors.transparent,
                          border: Border.all(
                            color: active
                                ? DesktopTheme.border
                                : Colors.transparent,
                          ),
                          borderRadius: BorderRadius.circular(
                            DesktopTheme.radiusMedium,
                          ),
                          boxShadow: active
                              ? const <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x100f172a),
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          tab.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: active
                                ? DesktopTheme.text
                                : DesktopTheme.mutedText,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class DesktopMenuEntry {
  const DesktopMenuEntry({
    required this.label,
    this.onPressed,
    this.enabled = true,
    this.checked = false,
    this.radio = false,
    this.children = const <DesktopMenuEntry>[],
    this.separator = false,
  });

  const DesktopMenuEntry.separator()
    : label = '',
      onPressed = null,
      enabled = false,
      checked = false,
      radio = false,
      children = const <DesktopMenuEntry>[],
      separator = true;

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool checked;
  final bool radio;
  final List<DesktopMenuEntry> children;
  final bool separator;
}

class DesktopMenuRoot {
  const DesktopMenuRoot(this.label, this.entries);

  final String label;
  final List<DesktopMenuEntry> entries;
}

class DesktopMenuBar extends StatelessWidget {
  const DesktopMenuBar({super.key, required this.menus});

  final List<DesktopMenuRoot> menus;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: DesktopTheme.surface,
        border: Border(bottom: BorderSide(color: DesktopTheme.divider)),
      ),
      child: SizedBox(
        height: DesktopTheme.menuHeight,
        child: Row(
          children: menus
              .map((menu) => _DesktopRootMenu(menu: menu))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _DesktopRootMenu extends StatelessWidget {
  const _DesktopRootMenu({required this.menu});

  final DesktopMenuRoot menu;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: const MenuStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.all(4)),
        backgroundColor: WidgetStatePropertyAll(DesktopTheme.surface),
        elevation: WidgetStatePropertyAll(10),
        shadowColor: WidgetStatePropertyAll(Color(0x330f172a)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(DesktopTheme.radiusMedium),
            ),
            side: BorderSide(color: DesktopTheme.border),
          ),
        ),
      ),
      menuChildren: menu.entries.map(_buildMenuEntry).toList(growable: false),
      builder: (context, controller, child) => GestureDetector(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: DesktopMnemonicText(menu.label),
        ),
      ),
    );
  }

  Widget _buildMenuEntry(DesktopMenuEntry entry) {
    if (entry.separator) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: Divider(height: 2, thickness: 1, color: DesktopTheme.divider),
      );
    }
    final leading = SizedBox(
      width: 13,
      child: entry.checked
          ? Text(entry.radio ? '●' : '✓', textAlign: TextAlign.center)
          : null,
    );
    if (entry.children.isNotEmpty) {
      return SubmenuButton(
        menuChildren: entry.children
            .map(_buildMenuEntry)
            .toList(growable: false),
        style: _menuButtonStyle(entry.enabled),
        leadingIcon: leading,
        child: DesktopMnemonicText(entry.label),
      );
    }
    return MenuItemButton(
      onPressed: entry.enabled ? entry.onPressed : null,
      style: _menuButtonStyle(entry.enabled),
      leadingIcon: leading,
      child: DesktopMnemonicText(entry.label),
    );
  }

  ButtonStyle _menuButtonStyle(bool enabled) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(180, 26)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 6),
      ),
      foregroundColor: WidgetStatePropertyAll(
        enabled ? DesktopTheme.text : DesktopTheme.disabledText,
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: DesktopTheme.fontSize),
      ),
      overlayColor: const WidgetStatePropertyAll(DesktopTheme.hover),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DesktopTheme.radiusSmall),
          ),
        ),
      ),
    );
  }
}

class DesktopStatusBar extends StatelessWidget {
  const DesktopStatusBar({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: DesktopTheme.surface,
        border: Border(top: BorderSide(color: DesktopTheme.divider)),
      ),
      child: SizedBox(
        height: DesktopTheme.statusHeight,
        child: Row(
          children: items
              .map((item) {
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: DesktopTheme.divider),
                      ),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(item, overflow: TextOverflow.ellipsis),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class DesktopColumn<T> {
  const DesktopColumn({
    required this.label,
    required this.width,
    required this.value,
    this.numeric = false,
    this.compare,
    this.leading,
  });

  final String label;
  final double width;
  final String Function(T row) value;
  final bool numeric;
  final int Function(T left, T right)? compare;
  final Widget? Function(T row)? leading;
}

class DesktopDataTable<T> extends StatefulWidget {
  const DesktopDataTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.identity,
    this.onSelectionChanged,
    this.onSelectionsChanged,
    this.onDoubleTap,
    this.contextMenuBuilder,
    this.onColumnWidthChanged,
    this.multiSelect = false,
    this.initiallySelectedIdentity,
    this.initiallySelectedIdentities = const <Object>[],
    this.backgroundContextMenuBuilder,
  });

  final List<DesktopColumn<T>> columns;
  final List<T> rows;
  final Object Function(T row) identity;
  final ValueChanged<T?>? onSelectionChanged;
  final ValueChanged<List<T>>? onSelectionsChanged;
  final ValueChanged<T>? onDoubleTap;
  final List<DesktopMenuEntry> Function(T row)? contextMenuBuilder;
  final void Function(int columnIndex, double width)? onColumnWidthChanged;
  final bool multiSelect;
  final Object? initiallySelectedIdentity;
  final List<Object> initiallySelectedIdentities;
  final List<DesktopMenuEntry> Function()? backgroundContextMenuBuilder;

  @override
  State<DesktopDataTable<T>> createState() => _DesktopDataTableState<T>();
}

class _DesktopDataTableState<T> extends State<DesktopDataTable<T>> {
  late List<double> _widths;
  late List<T> _rows;
  final ScrollController _verticalController = ScrollController();
  final Set<Object> _selectedIdentities = <Object>{};
  Object? _cursorIdentity;
  Object? _anchorIdentity;
  Object? _pendingInitialIdentity;
  int _selectionVersion = 0;
  int? _sortColumn;
  bool _ascending = true;

  @override
  void initState() {
    super.initState();
    _widths = widget.columns.map((column) => column.width).toList();
    _rows = List<T>.of(widget.rows);
    final available = _rows.map(widget.identity).toSet();
    _selectedIdentities.addAll(
      widget.initiallySelectedIdentities.where(available.contains),
    );
    if (_selectedIdentities.isNotEmpty) {
      _cursorIdentity = _selectedIdentities.last;
      _anchorIdentity = _cursorIdentity;
    }
    _pendingInitialIdentity = widget.initiallySelectedIdentity;
    _tryInitialSelection();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DesktopDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incomingWidths = widget.columns
        .map((column) => column.width)
        .toList(growable: false);
    if (oldWidget.columns.length != widget.columns.length ||
        !_sameWidths(_widths, incomingWidths)) {
      _widths = incomingWidths;
    }
    _rows = List<T>.of(widget.rows);
    _applySort();
    final rowsChanged = !identical(oldWidget.rows, widget.rows);
    final newInitialRequest =
        widget.initiallySelectedIdentity != null &&
        widget.initiallySelectedIdentity != oldWidget.initiallySelectedIdentity;
    if (newInitialRequest) {
      _pendingInitialIdentity = widget.initiallySelectedIdentity;
    }
    final available = _rows.map(widget.identity).toSet();
    final previousSelectionCount = _selectedIdentities.length;
    _selectedIdentities.removeWhere(
      (identity) => !available.contains(identity),
    );
    var changed = previousSelectionCount != _selectedIdentities.length;
    if (!widget.multiSelect && _selectedIdentities.length > 1) {
      final retained = available.contains(_cursorIdentity)
          ? _cursorIdentity
          : _selectedIdentities.first;
      _selectedIdentities
        ..clear()
        ..add(retained!);
      changed = true;
    }
    if (!available.contains(_cursorIdentity)) {
      _cursorIdentity = _selectedIdentities.isEmpty
          ? null
          : _selectedIdentities.first;
    }
    if (!available.contains(_anchorIdentity)) {
      _anchorIdentity = _cursorIdentity;
    }
    final initialSelected = _tryInitialSelection();
    if (!initialSelected &&
        _pendingInitialIdentity != null &&
        rowsChanged &&
        !newInitialRequest) {
      // “转到进程”最多等待下一份快照；找不到时保持未选择，
      // 绝不能仅按 PID 猜测另一个已复用该 PID 的进程。
      _pendingInitialIdentity = null;
    }
    changed |= initialSelected;
    if (changed) {
      final version = ++_selectionVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && version == _selectionVersion) {
          _notifySelection();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: widget.backgroundContextMenuBuilder == null
          ? null
          : (details) => showDesktopContextMenu(
              context,
              details.globalPosition,
              widget.backgroundContextMenuBuilder!(),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesktopTheme.radiusMedium),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: DesktopTheme.surface,
            border: DesktopTheme.panelBorder(),
            borderRadius: BorderRadius.circular(DesktopTheme.radiusMedium),
          ),
          child: Focus(
            autofocus: true,
            onKeyEvent: _handleKey,
            child: TableView.builder(
              verticalDetails: ScrollableDetails.vertical(
                controller: _verticalController,
              ),
              pinnedRowCount: 1,
              rowCount: _rows.length + 1,
              columnCount: widget.columns.length,
              columnBuilder: (index) => TableSpan(
                extent: FixedTableSpanExtent(_widths[index]),
                foregroundDecoration: const TableSpanDecoration(
                  border: TableSpanBorder(
                    trailing: BorderSide(color: DesktopTheme.divider),
                  ),
                ),
              ),
              rowBuilder: (index) => TableSpan(
                extent: FixedTableSpanExtent(
                  index == 0
                      ? DesktopTheme.headerHeight
                      : DesktopTheme.rowHeight,
                ),
                backgroundDecoration: TableSpanDecoration(
                  color: index == 0
                      ? DesktopTheme.surfaceMuted
                      : DesktopTheme.surface,
                  border: const TableSpanBorder(
                    trailing: BorderSide(color: DesktopTheme.divider),
                  ),
                ),
              ),
              cellBuilder: (context, vicinity) {
                if (vicinity.row == 0) {
                  return TableViewCell(child: _buildHeader(vicinity.column));
                }
                final rowIndex = vicinity.row - 1;
                final row = _rows[rowIndex];
                return TableViewCell(
                  child: _buildCell(row, vicinity.column, rowIndex),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int columnIndex) {
    final column = widget.columns[columnIndex];
    final sorted = _sortColumn == columnIndex;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _sortBy(columnIndex),
      child: Container(
        decoration: const BoxDecoration(
          color: DesktopTheme.surfaceMuted,
          border: Border(bottom: BorderSide(color: DesktopTheme.border)),
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisAlignment: column.numeric
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        column.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DesktopTheme.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (sorted) Text(_ascending ? ' ▴' : ' ▾'),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _widths[columnIndex] =
                          (_widths[columnIndex] + details.delta.dx).clamp(
                            24,
                            1000,
                          );
                    });
                  },
                  onHorizontalDragEnd: (_) => widget.onColumnWidthChanged?.call(
                    columnIndex,
                    _widths[columnIndex],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _sameWidths(List<double> left, List<double> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if ((left[index] - right[index]).abs() > 0.01) {
        return false;
      }
    }
    return true;
  }

  Widget _buildCell(T row, int columnIndex, int rowIndex) {
    final selected = _selectedIdentities.contains(widget.identity(row));
    final column = widget.columns[columnIndex];
    return Semantics(
      selected: selected,
      child: Listener(
        onPointerDown: (event) {
          if ((event.buttons & kPrimaryMouseButton) != 0) {
            final keyboard = HardwareKeyboard.instance;
            _selectIndex(
              rowIndex,
              additive: keyboard.isControlPressed || keyboard.isMetaPressed,
              extend: keyboard.isShiftPressed,
            );
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: widget.onDoubleTap == null
              ? null
              : () => widget.onDoubleTap!(row),
          onSecondaryTapDown: widget.contextMenuBuilder == null
              ? null
              : (details) {
                  _selectForContextMenu(row);
                  _showContextMenu(details.globalPosition, row);
                },
          child: ColoredBox(
            color: selected ? DesktopTheme.selection : DesktopTheme.surface,
            child: Align(
              alignment: column.numeric
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildCellContents(column, row, selected),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCellContents(DesktopColumn<T> column, T row, bool selected) {
    final style = TextStyle(
      color: selected ? DesktopTheme.selectionText : DesktopTheme.text,
    );
    final text = Text(
      column.value(row),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    final leading = column.leading?.call(row);
    if (leading == null) {
      return text;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: column.numeric
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(child: SizedBox.square(dimension: 16, child: leading)),
        const SizedBox(width: 2),
        Flexible(child: text),
      ],
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _rows.isEmpty) {
      return KeyEventResult.ignored;
    }
    final current = _cursorIdentity == null
        ? -1
        : _rows.indexWhere((row) => widget.identity(row) == _cursorIdentity);
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _selectIndex(
        (current + 1).clamp(0, _rows.length - 1),
        extend: HardwareKeyboard.instance.isShiftPressed,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _selectIndex(
        (current - 1).clamp(0, _rows.length - 1),
        extend: HardwareKeyboard.instance.isShiftPressed,
      );
      return KeyEventResult.handled;
    }
    if (widget.multiSelect &&
        event.logicalKey == LogicalKeyboardKey.keyA &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      setState(() {
        _pendingInitialIdentity = null;
        _selectedIdentities
          ..clear()
          ..addAll(_rows.map(widget.identity));
        _cursorIdentity = widget.identity(_rows.first);
        _anchorIdentity = _cursorIdentity;
      });
      _selectionVersion += 1;
      _notifySelection();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter && current >= 0) {
      widget.onDoubleTap?.call(_rows[current]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _selectIndex(int index, {bool? additive, bool? extend}) {
    if (index < 0 || index >= _rows.length) {
      return;
    }
    final row = _rows[index];
    if (!widget.multiSelect) {
      _replaceSelection(row);
      return;
    }
    final keyboard = HardwareKeyboard.instance;
    final add =
        additive ?? (keyboard.isControlPressed || keyboard.isMetaPressed);
    final extendRange = extend ?? keyboard.isShiftPressed;
    final identity = widget.identity(row);
    setState(() {
      _pendingInitialIdentity = null;
      if (extendRange && _anchorIdentity != null) {
        final anchor = _rows.indexWhere(
          (candidate) => widget.identity(candidate) == _anchorIdentity,
        );
        if (anchor >= 0) {
          if (!add) {
            _selectedIdentities.clear();
          }
          final start = anchor < index ? anchor : index;
          final end = anchor < index ? index : anchor;
          _selectedIdentities.addAll(
            _rows.sublist(start, end + 1).map(widget.identity),
          );
        }
      } else if (add) {
        if (!_selectedIdentities.add(identity)) {
          _selectedIdentities.remove(identity);
        }
        _anchorIdentity = identity;
      } else {
        _selectedIdentities
          ..clear()
          ..add(identity);
        _anchorIdentity = identity;
      }
      _cursorIdentity = identity;
    });
    _selectionVersion += 1;
    _notifySelection();
    _revealIndex(index);
  }

  void _replaceSelection(T row) {
    final identity = widget.identity(row);
    setState(() {
      _pendingInitialIdentity = null;
      _selectedIdentities
        ..clear()
        ..add(identity);
      _cursorIdentity = identity;
      _anchorIdentity = identity;
    });
    _selectionVersion += 1;
    _notifySelection();
    _revealIndex(
      _rows.indexWhere((candidate) => widget.identity(candidate) == identity),
    );
  }

  bool _tryInitialSelection() {
    final identity = _pendingInitialIdentity;
    if (identity == null) {
      return false;
    }
    final index = _rows.indexWhere(
      (candidate) => widget.identity(candidate) == identity,
    );
    if (index < 0) {
      return false;
    }
    final changed =
        _selectedIdentities.length != 1 ||
        !_selectedIdentities.contains(identity) ||
        _cursorIdentity != identity;
    _selectedIdentities
      ..clear()
      ..add(identity);
    _cursorIdentity = identity;
    _anchorIdentity = identity;
    _pendingInitialIdentity = null;
    _revealIndex(index);
    return changed;
  }

  void _revealIndex(int index) {
    if (index < 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_verticalController.hasClients) {
        return;
      }
      final position = _verticalController.position;
      final rowTop = index * DesktopTheme.rowHeight;
      final rowBottom = rowTop + DesktopTheme.rowHeight;
      final visibleTop = position.pixels;
      final visibleBottom = visibleTop + position.viewportDimension;
      double? target;
      if (rowTop < visibleTop) {
        target = rowTop;
      } else if (rowBottom > visibleBottom) {
        target = rowBottom - position.viewportDimension;
      }
      if (target != null) {
        position.jumpTo(target.clamp(0, position.maxScrollExtent));
      }
    });
  }

  void _selectForContextMenu(T row) {
    final identity = widget.identity(row);
    if (widget.multiSelect && _selectedIdentities.contains(identity)) {
      _cursorIdentity = identity;
      return;
    }
    _replaceSelection(row);
  }

  void _notifySelection() {
    final selected = _rows
        .where((row) => _selectedIdentities.contains(widget.identity(row)))
        .toList(growable: false);
    T? primary;
    for (final row in selected) {
      if (widget.identity(row) == _cursorIdentity) {
        primary = row;
        break;
      }
    }
    primary ??= selected.isEmpty ? null : selected.first;
    widget.onSelectionChanged?.call(primary);
    widget.onSelectionsChanged?.call(selected);
  }

  void _sortBy(int columnIndex) {
    setState(() {
      if (_sortColumn == columnIndex) {
        _ascending = !_ascending;
      } else {
        _sortColumn = columnIndex;
        _ascending = true;
      }
      _applySort();
    });
  }

  void _applySort() {
    final index = _sortColumn;
    if (index == null || index >= widget.columns.length) {
      return;
    }
    final column = widget.columns[index];
    _rows.sort((left, right) {
      final result =
          column.compare?.call(left, right) ??
          column
              .value(left)
              .toLowerCase()
              .compareTo(column.value(right).toLowerCase());
      return _ascending ? result : -result;
    });
  }

  Future<void> _showContextMenu(Offset position, T row) async {
    final entries =
        widget.contextMenuBuilder?.call(row) ?? const <DesktopMenuEntry>[];
    if (mounted) {
      await showDesktopContextMenu(context, position, entries);
    }
  }
}

Future<void> showDesktopContextMenu(
  BuildContext context,
  Offset position,
  List<DesktopMenuEntry> entries,
) async {
  if (entries.isEmpty) {
    return;
  }
  await showMenu<void>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx,
      position.dy,
    ),
    color: DesktopTheme.surface,
    elevation: 10,
    shadowColor: const Color(0x330f172a),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(DesktopTheme.radiusMedium),
      ),
      side: BorderSide(color: DesktopTheme.border),
    ),
    items: entries
        .map<PopupMenuEntry<void>>((entry) {
          if (entry.separator) {
            return const PopupMenuDivider(height: 5);
          }
          return PopupMenuItem<void>(
            enabled: entry.enabled,
            height: 28,
            onTap: entry.onPressed,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 13,
                  child: entry.checked
                      ? Text(
                          entry.radio ? '●' : '✓',
                          textAlign: TextAlign.center,
                        )
                      : null,
                ),
                const SizedBox(width: 4),
                DesktopMnemonicText(entry.label),
              ],
            ),
          );
        })
        .toList(growable: false),
  );
}

class DesktopMnemonicText extends StatelessWidget {
  const DesktopMnemonicText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final marker = text.indexOf('&');
    if (marker < 0 || marker == text.length - 1) {
      return Text(text.replaceAll('&&', '&'), style: style);
    }
    final before = text.substring(0, marker);
    final mnemonic = text.substring(marker + 1, marker + 2);
    final after = text.substring(marker + 2);
    return Text.rich(
      TextSpan(
        style: style,
        children: <InlineSpan>[
          TextSpan(text: before),
          TextSpan(
            text: mnemonic,
            style: const TextStyle(decoration: TextDecoration.underline),
          ),
          TextSpan(text: after),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

String stripMnemonic(String value) => value.replaceAll('&', '');

String unavailable(String? value, String fallback) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? fallback : normalized;
}
