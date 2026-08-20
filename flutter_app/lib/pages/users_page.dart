// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 用户页
//
//   文件:       flutter_app/lib/pages/users_page.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   原 IDD_USERSPAGE/IDD_MESSAGE DLU 布局；systemd-logind 会话语义
// --------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../app/backend_controller.dart';
import '../l10n/app_localizations.dart';
import '../src/native_bridge/api.dart';
import '../src/native_bridge/third_party/taskmgr_core.dart';
import '../ui/desktop_controls.dart';
import '../ui/desktop_dialogs.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({
    super.key,
    required this.controller,
    required this.data,
    required this.confirmations,
  });

  final BackendController controller;
  final UsersData? data;
  final bool confirmations;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  UserSession? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessions = widget.data?.sessions ?? const <UserSession>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 6, 7),
      child: Column(
        children: <Widget>[
          Expanded(
            child: DesktopDataTable<UserSession>(
              columns: <DesktopColumn<UserSession>>[
                DesktopColumn(
                  label: l10n.user,
                  width: 170,
                  value: (row) => row.userName,
                ),
                DesktopColumn(
                  label: l10n.session,
                  width: 100,
                  value: (row) => row.session ?? l10n.notAvailable,
                ),
                DesktopColumn(
                  label: l10n.clientName,
                  width: 125,
                  value: (row) => row.clientName ?? l10n.notAvailable,
                ),
                DesktopColumn(
                  label: l10n.status,
                  width: 90,
                  value: (row) => _localizedState(l10n, row.state),
                ),
              ],
              rows: sessions,
              identity: (row) => '${row.identity.id}:${row.identity.loginTime}',
              onSelectionChanged: (row) => setState(() => _selected = row),
              contextMenuBuilder: (row) => _contextEntries(l10n, row),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              DesktopButton(
                label: l10n.disconnect,
                width: 86,
                onPressed: _can(ActionKind.disconnectSession)
                    ? () => _sessionAction(_selected!, UserAction.disconnect)
                    : null,
              ),
              const SizedBox(width: 5),
              DesktopButton(
                label: l10n.logoff,
                width: 78,
                onPressed: _can(ActionKind.logoffSession)
                    ? () => _sessionAction(_selected!, UserAction.logoff)
                    : null,
              ),
              const SizedBox(width: 5),
              DesktopButton(
                label: l10n.sendMessage,
                width: 102,
                isDefault: true,
                onPressed: _can(ActionKind.sendMessage)
                    ? () => _sendMessage(_selected!)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<DesktopMenuEntry> _contextEntries(
    AppLocalizations l10n,
    UserSession row,
  ) {
    return <DesktopMenuEntry>[
      DesktopMenuEntry(
        label: l10n.disconnect,
        enabled: row.allowedActions.contains(ActionKind.disconnectSession),
        onPressed: () => _sessionAction(row, UserAction.disconnect),
      ),
      DesktopMenuEntry(
        label: l10n.logoff,
        enabled: row.allowedActions.contains(ActionKind.logoffSession),
        onPressed: () => _sessionAction(row, UserAction.logoff),
      ),
      const DesktopMenuEntry.separator(),
      DesktopMenuEntry(
        label: l10n.sendMessage,
        enabled: row.allowedActions.contains(ActionKind.sendMessage),
        onPressed: () => _sendMessage(row),
      ),
    ];
  }

  bool _can(ActionKind action) =>
      _selected?.allowedActions.contains(action) ?? false;

  Future<void> _sessionAction(UserSession row, UserAction action) async {
    final l10n = AppLocalizations.of(context);
    if (widget.confirmations &&
        !await showDesktopConfirm(
          context,
          title: l10n.warningTitle,
          message: action == UserAction.logoff
              ? l10n.confirmLogoffSelectedUsers
              : l10n.confirmDisconnectSelectedUsers,
        )) {
      return;
    }
    final result = await widget.controller.execute(
      BridgeActionRequest.userSession(
        identity: row.identity,
        operation: action,
      ),
    );
    if (mounted) {
      await showActionFailure(context, result);
      if (result?.status == ActionStatus.succeeded) {
        await widget.controller.refresh(PageId.users);
      }
    }
  }

  Future<void> _sendMessage(UserSession row) async {
    final message = await _showMessageDialog();
    if (!mounted || message == null) {
      return;
    }
    final result = await widget.controller.execute(
      BridgeActionRequest.userSession(
        identity: row.identity,
        operation: UserAction.sendMessage,
        title: message.$1,
        message: message.$2,
      ),
    );
    if (mounted) {
      await showActionFailure(context, result);
    }
  }

  Future<(String, String)?> _showMessageDialog() async {
    return showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => const _MessageDialog(),
    );
  }

  String _localizedState(AppLocalizations l10n, String state) {
    return switch (state.toLowerCase()) {
      'active' => l10n.active,
      'connected' => l10n.connected,
      'disconnected' => l10n.disconnected,
      'connecting' => l10n.connecting,
      'disconnecting' => l10n.disconnecting,
      'idle' => l10n.idle,
      'listening' => l10n.listening,
      'down' => l10n.down,
      _ => state,
    };
  }
}

class _MessageDialog extends StatefulWidget {
  const _MessageDialog();

  @override
  State<_MessageDialog> createState() => _MessageDialogState();
}

class _MessageDialogState extends State<_MessageDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
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
              Text(l10n.messageTitleLabel),
              const SizedBox(height: 3),
              DesktopTextField(controller: _title, lines: 2),
              const SizedBox(height: 8),
              Text(l10n.messageLabel),
              const SizedBox(height: 3),
              DesktopTextField(controller: _body, lines: 3),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  DesktopButton(
                    label: l10n.ok,
                    width: 76,
                    isDefault: true,
                    onPressed: () =>
                        Navigator.of(context).pop((_title.text, _body.text)),
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
}
