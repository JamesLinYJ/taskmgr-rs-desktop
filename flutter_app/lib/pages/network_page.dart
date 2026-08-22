// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 网络页
//
//   文件:       flutter_app/lib/pages/network_page.dart
//
//   日期:       2026年08月22日
//   环境:       Windows 11；Flutter 3.47.1；Dart 3.13
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   原 IDD_NETPAGE 布局；GetIfTable2 / MIB_IF_ROW2
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
  final ScrollController _graphController = ScrollController();

  @override
  void dispose() {
    _graphController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final interfaces = widget.data?.interfaces ?? const <NetworkInterface>[];
    if (interfaces.isEmpty) {
      return Center(child: Text(l10n.noActiveNetworkAdaptersFound));
    }
    const fallback = '-';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableHeight = (constraints.maxHeight * 0.23).clamp(
            112.0,
            145.0,
          );
          final graphAreaHeight = constraints.maxHeight - tableHeight - 7;
          final graphsOnPage = interfaces.length.clamp(1, 3);
          final graphHeight = (graphAreaHeight / graphsOnPage).clamp(
            104.0,
            150.0,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Scrollbar(
                  controller: _graphController,
                  thumbVisibility: interfaces.length > graphsOnPage,
                  child: ListView.separated(
                    key: const ValueKey<String>('network-adapter-graphs'),
                    controller: _graphController,
                    padding: EdgeInsets.zero,
                    itemCount: interfaces.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 5),
                    itemBuilder: (context, index) {
                      final interface = interfaces[index];
                      return SizedBox(
                        height: graphHeight,
                        child: DesktopGroupBox(
                          label: interface.name,
                          child: DesktopNetworkGraph(
                            received: interface.receivedHistory,
                            sent: interface.sentHistory,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 7),
              SizedBox(
                height: tableHeight,
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
                      value: (row) => percentOrUnavailable(
                        row.utilizationPercent,
                        fallback,
                      ),
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
                      width: 125,
                      value: (row) => _stateLabel(l10n, row.state),
                    ),
                  ],
                  rows: interfaces,
                  identity: (row) => row.id,
                  initiallySelectedIdentity: _selectedId,
                  onSelectionChanged: (row) {
                    setState(() => _selectedId = row?.id);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _stateLabel(AppLocalizations l10n, NetworkInterfaceState state) =>
      switch (state) {
        NetworkInterfaceState.connected => l10n.connected,
        NetworkInterfaceState.disconnected => l10n.disconnected,
        NetworkInterfaceState.connecting => l10n.connecting,
        NetworkInterfaceState.disconnecting => l10n.disconnecting,
        NetworkInterfaceState.hardwareMissing => l10n.hardwareMissing,
        NetworkInterfaceState.hardwareDisabled => l10n.hardwareDisabled,
        NetworkInterfaceState.hardwareMalfunction => l10n.hardwareMalfunction,
        NetworkInterfaceState.unknown => l10n.unknown,
      };
}
