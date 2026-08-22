// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 诊断日志会话对话框
//
//   文件:       flutter_app/lib/ui/diagnostic_dialog.dart
//
//   日期:       2026年08月22日
//   环境:       Windows 11 x86_64；Flutter 3.47.1；Dart 3.13
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   vendor taskmgr-rs 诊断会话；Flutter 模态对话框
// --------------------------------------------------------------------------

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart' hide DiagnosticLevel;

import '../app/backend_controller.dart';
import '../app/backend_state.dart';
import '../l10n/app_localizations.dart';
import '../src/native_bridge/api.dart';
import '../src/native_bridge/third_party/taskmgr_core.dart';
import 'desktop_controls.dart';
import 'desktop_dialogs.dart';
import 'desktop_theme.dart';

Future<void> showDiagnosticLogsDialog(
  BuildContext context, {
  required BackendController controller,
  Future<void> Function()? onRestarted,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) =>
        _DiagnosticLogsDialog(controller: controller, onRestarted: onRestarted),
  );
}

class _DiagnosticLogsDialog extends StatefulWidget {
  const _DiagnosticLogsDialog({
    required this.controller,
    required this.onRestarted,
  });

  final BackendController controller;
  final Future<void> Function()? onRestarted;

  @override
  State<_DiagnosticLogsDialog> createState() => _DiagnosticLogsDialogState();
}

class _DiagnosticLogsDialogState extends State<_DiagnosticLogsDialog> {
  late bool _detailed;
  late bool _sensitive;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final status = widget.controller.value.diagnostics;
    _detailed = status?.level != DiagnosticLevel.info;
    _sensitive = status?.sensitive ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<BackendState>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        final status = state.diagnostics;
        return Dialog(
          child: SizedBox(
            width: 620,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.diagnosticLogsTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _statusRow(
                    l10n.diagnosticStatusLabel,
                    status == null
                        ? l10n.diagnosticLoggingUnavailable
                        : status.fileActive
                        ? l10n.diagnosticLoggingActive.replaceFirst(
                            '%s',
                            status.level.name,
                          )
                        : l10n.diagnosticLoggingUnavailable,
                  ),
                  _statusRow(
                    l10n.diagnosticSessionLabel,
                    status?.sessionId.isNotEmpty == true
                        ? status!.sessionId
                        : l10n.notAvailable,
                  ),
                  _statusRow(
                    l10n.diagnosticDirectoryLabel,
                    status?.directory ?? l10n.notAvailable,
                  ),
                  if ((status?.droppedEvents ?? BigInt.zero) > BigInt.zero)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.diagnosticDroppedEvents.replaceFirst(
                          '%s',
                          status!.droppedEvents.toString(),
                        ),
                        style: const TextStyle(color: Color(0xffb42318)),
                      ),
                    ),
                  if (status?.sinkError case final error?)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        error,
                        style: const TextStyle(color: Color(0xffb42318)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  DesktopCheckbox(
                    key: const ValueKey<String>('diagnostics-detailed'),
                    label: l10n.diagnosticDetailedCurrentSession,
                    value: _detailed,
                    onChanged: _busy ? null : _setDetailed,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: DesktopCheckbox(
                      key: const ValueKey<String>('diagnostics-sensitive'),
                      label: l10n.diagnosticIncludeSensitive,
                      value: _sensitive,
                      onChanged: !_detailed || _busy ? null : _setSensitive,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: <Widget>[
                      DesktopButton(
                        label: l10n.diagnosticRestartDetailed,
                        onPressed: _busy ? null : _restartDetailed,
                      ),
                      DesktopButton(
                        label: l10n.diagnosticOpenFolder,
                        onPressed: _busy || status?.directory == null
                            ? null
                            : _openFolder,
                      ),
                      DesktopButton(
                        label: l10n.diagnosticSaveBundle,
                        onPressed:
                            _busy ||
                                status?.fileActive != true ||
                                defaultTargetPlatform != TargetPlatform.windows
                            ? null
                            : () => _saveBundle(status!),
                      ),
                      DesktopButton(
                        label: l10n.close,
                        width: 76,
                        isDefault: true,
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  if (_busy) ...<Widget>[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(color: DesktopTheme.mutedText),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Future<void> _setDetailed(bool detailed) async {
    await _configure(detailed: detailed, sensitive: detailed && _sensitive);
  }

  Future<void> _setSensitive(bool sensitive) async {
    await _configure(detailed: _detailed, sensitive: sensitive);
  }

  Future<void> _configure({
    required bool detailed,
    required bool sensitive,
  }) async {
    setState(() => _busy = true);
    final result = await widget.controller.execute(
      BridgeActionRequest.configureDiagnostics(
        detailed: detailed,
        sensitive: sensitive,
      ),
    );
    if (!mounted) {
      return;
    }
    if (result?.status == ActionStatus.succeeded) {
      setState(() {
        _detailed = detailed;
        _sensitive = detailed && sensitive;
        _busy = false;
      });
    } else {
      setState(() => _busy = false);
      await showActionFailure(context, result);
    }
  }

  Future<void> _openFolder() async {
    await _perform(
      const BridgeActionRequest.openDiagnosticFolder(),
      failureMessage: AppLocalizations.of(context).diagnosticOpenFolderFailed,
    );
  }

  Future<void> _saveBundle(DiagnosticStatus status) async {
    final l10n = AppLocalizations.of(context);
    if (status.exportRequiresPrivacyWarning) {
      final confirmed = await showDesktopConfirm(
        context,
        title: l10n.diagnosticLogsTitle,
        message: l10n.diagnosticSensitiveExportWarning,
      );
      if (!confirmed || !mounted) {
        return;
      }
    }
    final result = await _perform(
      const BridgeActionRequest.saveDiagnosticBundle(),
      failureTitle: l10n.diagnosticExportFailedTitle,
    );
    if (mounted && result?.status == ActionStatus.succeeded) {
      await showDesktopMessage(
        context,
        title: l10n.diagnosticLogsTitle,
        message: l10n.diagnosticExportSucceeded,
      );
    }
  }

  Future<void> _restartDetailed() async {
    final l10n = AppLocalizations.of(context);
    final result = await _perform(
      const BridgeActionRequest.restartWithDetailedDiagnostics(),
      failureMessage: l10n.diagnosticRestartFailed,
    );
    if (result?.status != ActionStatus.succeeded || !mounted) {
      return;
    }
    Navigator.of(context).pop();
    await widget.onRestarted?.call();
  }

  Future<ActionResult?> _perform(
    BridgeActionRequest request, {
    String? failureTitle,
    String? failureMessage,
  }) async {
    setState(() => _busy = true);
    final result = await widget.controller.execute(request);
    if (!mounted) {
      return result;
    }
    setState(() => _busy = false);
    if (result?.status != ActionStatus.succeeded) {
      final l10n = AppLocalizations.of(context);
      await showDesktopMessage(
        context,
        title: failureTitle ?? l10n.warningTitle,
        message: result?.error?.message ?? failureMessage ?? l10n.notAvailable,
      );
    }
    return result;
  }
}
