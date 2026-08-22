// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 跨平台桌面对话框
//
//   文件:       flutter_app/lib/ui/desktop_dialogs.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Flutter Dialog、焦点与模态导航 API
// --------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../src/native_bridge/third_party/taskmgr_core.dart';
import 'desktop_controls.dart';

Future<String?> showRunTaskDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => const _RunTaskDialog(),
  );
}

class _RunTaskDialog extends StatefulWidget {
  const _RunTaskDialog();

  @override
  State<_RunTaskDialog> createState() => _RunTaskDialogState();
}

class _RunTaskDialogState extends State<_RunTaskDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      child: SizedBox(
        width: 430,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.runTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(l10n.runPrompt),
              const SizedBox(height: 10),
              DesktopTextField(
                controller: _controller,
                autofocus: true,
                onSubmitted: (_) => _accept(l10n),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  DesktopButton(
                    label: l10n.ok,
                    width: 76,
                    isDefault: true,
                    onPressed: () => _accept(l10n),
                  ),
                  const SizedBox(width: 6),
                  DesktopButton(
                    label: l10n.cancel,
                    width: 76,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _accept(AppLocalizations l10n) async {
    final commandLine = _controller.text.trim();
    if (commandLine.isEmpty) {
      await showDesktopMessage(
        context,
        title: l10n.warningTitle,
        message: l10n.runCommandRequired,
      );
      return;
    }
    if (mounted) {
      Navigator.of(context).pop(commandLine);
    }
  }
}

Future<void> showDesktopMessage(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final l10n = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(message),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: DesktopButton(
                  label: l10n.ok,
                  width: 76,
                  isDefault: true,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<bool> showDesktopConfirm(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final l10n = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 360, maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(message),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      DesktopButton(
                        label: l10n.cpuYes,
                        width: 76,
                        isDefault: true,
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                      ),
                      const SizedBox(width: 6),
                      DesktopButton(
                        label: l10n.cpuNo,
                        width: 76,
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ) ??
      false;
}

Future<Set<ColumnId>?> showSelectColumnsDialog(
  BuildContext context, {
  required List<(ColumnId, String)> columns,
  required Set<ColumnId> selected,
}) async {
  final l10n = AppLocalizations.of(context);
  final working = Set<ColumnId>.from(selected)..add(ColumnId.imageName);
  return showDialog<Set<ColumnId>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => Dialog(
        child: SizedBox(
          width: 430,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.selectColumnsTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 9),
                Text(l10n.selectProcessColumnsDescription),
                const SizedBox(height: 9),
                SizedBox(
                  height: 238,
                  child: DesktopGroupBox(
                    label: l10n.processesPageTitle,
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 0,
                        children: columns
                            .map(
                              (column) => SizedBox(
                                width: 185,
                                child: DesktopCheckbox(
                                  label: column.$2,
                                  value: working.contains(column.$1),
                                  onChanged: column.$1 == ColumnId.imageName
                                      ? null
                                      : (value) => setDialogState(() {
                                          if (value) {
                                            working.add(column.$1);
                                          } else {
                                            working.remove(column.$1);
                                          }
                                        }),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    DesktopButton(
                      label: l10n.ok,
                      width: 76,
                      isDefault: true,
                      onPressed: () =>
                          Navigator.of(dialogContext)
                              .pop(Set<ColumnId>.from(working)),
                    ),
                    const SizedBox(width: 6),
                    DesktopButton(
                      label: l10n.cancel,
                      width: 76,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<Set<int>?> showProcessorAffinityDialog(
  BuildContext context, {
  required List<int> processors,
  required Set<int> selected,
}) async {
  final l10n = AppLocalizations.of(context);
  final available = processors.toSet();
  final working = Set<int>.from(selected.intersection(available));
  final groups = <List<int>>[];
  for (var start = 0; start < processors.length; start += 16) {
    groups.add(
      processors.sublist(start, (start + 16).clamp(0, processors.length)),
    );
  }
  return showDialog<Set<int>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => Dialog(
        child: SizedBox(
          width: 600,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.processorAffinity,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(l10n.processorAffinityDescription),
                const SizedBox(height: 8),
                SizedBox(
                  height: 326,
                  child: DesktopGroupBox(
                    label: l10n.processors,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: groups
                            .map(
                              (group) => SizedBox(
                                width: 88,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: group
                                      .map(
                                        (processor) => DesktopCheckbox(
                                          label: 'CPU $processor',
                                          value: working.contains(processor),
                                          onChanged: (value) => setDialogState(
                                            () => value
                                                ? working.add(processor)
                                                : working.remove(processor),
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    DesktopButton(
                      label: l10n.ok,
                      width: 76,
                      isDefault: true,
                      onPressed: () async {
                        if (working.isEmpty) {
                          await showDesktopMessage(
                            dialogContext,
                            title: l10n.warningTitle,
                            message: l10n.noAffinityMaskMessage,
                          );
                          return;
                        }
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext)
                              .pop(Set<int>.from(working));
                        }
                      },
                    ),
                    const SizedBox(width: 6),
                    DesktopButton(
                      label: l10n.cancel,
                      width: 76,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<int?> showNiceValueDialog(BuildContext context, {required int current}) {
  return showDialog<int>(
    context: context,
    builder: (dialogContext) => _NiceValueDialog(current: current),
  );
}

class _NiceValueDialog extends StatefulWidget {
  const _NiceValueDialog({required this.current});

  final int current;

  @override
  State<_NiceValueDialog> createState() => _NiceValueDialogState();
}

class _NiceValueDialogState extends State<_NiceValueDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.current.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      child: SizedBox(
        width: 390,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.setNiceTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 9),
              Text(l10n.niceValueDescription),
              const SizedBox(height: 9),
              Text(l10n.niceValueLabel),
              const SizedBox(height: 3),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 90,
                  child: DesktopTextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  DesktopButton(
                    label: l10n.ok,
                    width: 76,
                    isDefault: true,
                    onPressed: () => _accept(l10n),
                  ),
                  const SizedBox(width: 6),
                  DesktopButton(
                    label: l10n.cancel,
                    width: 76,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _accept(AppLocalizations l10n) async {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < -20 || value > 19) {
      await showDesktopMessage(
        context,
        title: l10n.warningTitle,
        message: l10n.invalidNiceValue,
      );
      return;
    }
    if (mounted) {
      Navigator.of(context).pop(value);
    }
  }
}

Future<void> showActionFailure(
  BuildContext context,
  ActionResult? result,
) async {
  if (result?.status == ActionStatus.succeeded) {
    return;
  }
  final l10n = AppLocalizations.of(context);
  final message = result?.error?.message ?? l10n.notAvailable;
  await showDesktopMessage(context, title: l10n.warningTitle, message: message);
}
