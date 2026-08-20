// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 网络页
//
//   文件:       flutter_app/lib/pages/network_page.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   原 IDD_NETPAGE 布局；rtnetlink 网络接口语义
// --------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../src/native_bridge/third_party/taskmgr_core.dart';
import '../ui/desktop_controls.dart';
import '../ui/desktop_graph.dart';
import '../ui/formatters.dart';

class NetworkPage extends StatefulWidget {
  const NetworkPage({super.key, required this.data});

  final NetworkData? data;

  @override
  State<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends State<NetworkPage> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final interfaces = widget.data?.interfaces ?? const <NetworkInterface>[];
    if (interfaces.isEmpty) {
      return Center(child: Text(l10n.noActiveNetworkAdaptersFound));
    }
    final selected = interfaces.firstWhere(
      (item) => item.id == _selectedId,
      orElse: () => interfaces.first,
    );
    final fallback = l10n.notAvailable;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 154,
            child: DesktopDataTable<NetworkInterface>(
              columns: <DesktopColumn<NetworkInterface>>[
                DesktopColumn(
                  label: l10n.adapter,
                  width: 155,
                  value: (row) => row.name,
                ),
                DesktopColumn(
                  label: l10n.networkUtilization,
                  width: 95,
                  numeric: true,
                  value: (row) =>
                      percentOrUnavailable(row.utilizationPercent, fallback),
                ),
                DesktopColumn(
                  label: l10n.linkSpeed,
                  width: 92,
                  numeric: true,
                  value: (row) => linkSpeedOrUnavailable(
                    row.linkSpeedBitsPerSecond,
                    fallback,
                  ),
                ),
                DesktopColumn(
                  label: l10n.state,
                  width: 80,
                  value: (row) =>
                      row.operational ? l10n.connected : l10n.disconnected,
                ),
                DesktopColumn(
                  label: l10n.bytesSent,
                  width: 100,
                  numeric: true,
                  value: (row) =>
                      rateOrUnavailable(row.sentBytesPerSecond, fallback),
                ),
                DesktopColumn(
                  label: l10n.bytesReceived,
                  width: 100,
                  numeric: true,
                  value: (row) =>
                      rateOrUnavailable(row.receivedBytesPerSecond, fallback),
                ),
              ],
              rows: interfaces,
              identity: (row) => row.id,
              onSelectionChanged: (row) =>
                  setState(() => _selectedId = row?.id),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  selected.description ?? selected.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(percentOrUnavailable(selected.utilizationPercent, fallback)),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: DesktopGraph(
              primary: selected.receivedHistory.toList(),
              secondary: selected.sentHistory.toList(),
              secondaryColor: const Color(0xffffff00),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${l10n.bytesReceived}: ${rateOrUnavailable(selected.receivedBytesPerSecond, fallback)}',
                ),
              ),
              Expanded(
                child: Text(
                  '${l10n.bytesSent}: ${rateOrUnavailable(selected.sentBytesPerSecond, fallback)}',
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
