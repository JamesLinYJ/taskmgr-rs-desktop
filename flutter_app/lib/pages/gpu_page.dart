// +-------------------------------------------------------------------------
//
//   taskmgr-rs - GPU 页
//
//   文件:       flutter_app/lib/pages/gpu_page.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   原 IDD_GPUPAGE DLU 布局；DRM/sysfs 与 Windows GPU 指标能力
// --------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../src/native_bridge/third_party/taskmgr_core.dart';
import '../ui/desktop_controls.dart';
import '../ui/desktop_graph.dart';
import '../ui/desktop_theme.dart';
import '../ui/formatters.dart';

class GpuPage extends StatefulWidget {
  const GpuPage({super.key, required this.data});

  final GpuData? data;

  @override
  State<GpuPage> createState() => _GpuPageState();
}

class _GpuPageState extends State<GpuPage> {
  int _selected = 0;

  @override
  void didUpdateWidget(GpuPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final length = widget.data?.adapters.length ?? 0;
    if (_selected >= length) {
      _selected = length == 0 ? 0 : length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final adapters = widget.data?.adapters ?? const <GpuAdapter>[];
    if (adapters.isEmpty) {
      return Center(child: Text(l10n.noHardwareGpusFound));
    }
    final adapter = adapters[_selected];
    final engines = adapter.engines.take(4).toList(growable: false);
    final fallback = l10n.notAvailable;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SizedBox(
        height: 540,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox(
                  width: 220,
                  height: 24,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: DesktopTheme.panelBorder(),
                      color: DesktopTheme.surface,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _selected,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        dropdownColor: DesktopTheme.surface,
                        items: List<DropdownMenuItem<int>>.generate(
                          adapters.length,
                          (index) => DropdownMenuItem<int>(
                            value: index,
                            child: Text(
                              adapters[index].name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _selected = value ?? 0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(adapter.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              adapter.detailError?.message ?? l10n.gpuCurrentMetrics,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 198,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                  childAspectRatio: 2.35,
                ),
                itemCount: 4,
                itemBuilder: (context, index) {
                  final engine = index < engines.length ? engines[index] : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              engine?.name ?? fallback,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            percentOrUnavailable(
                              engine?.utilizationPercent,
                              fallback,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: DesktopGraph(
                          primary: engine?.history.toList() ?? const <double>[],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 5),
            Text(l10n.gpuDedicatedMemory),
            const SizedBox(height: 2),
            SizedBox(
              height: 52,
              child: DesktopGraph(primary: adapter.dedicatedHistory.toList()),
            ),
            const SizedBox(height: 5),
            Text(l10n.gpuSharedMemory),
            const SizedBox(height: 2),
            SizedBox(
              height: 52,
              child: DesktopGraph(primary: adapter.sharedHistory.toList()),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _GpuDetails(
                      title: l10n.gpuCurrentMetrics,
                      rows: <(String, String)>[
                        (
                          l10n.gpuUtilization,
                          percentOrUnavailable(
                            adapter.utilizationPercent,
                            fallback,
                          ),
                        ),
                        (
                          l10n.gpuMemory,
                          _memoryPair(
                            adapter.dedicatedUsedBytes,
                            adapter.dedicatedTotalBytes,
                            fallback,
                          ),
                        ),
                        (
                          l10n.gpuDedicatedMemory,
                          _memoryPair(
                            adapter.dedicatedUsedBytes,
                            adapter.dedicatedTotalBytes,
                            fallback,
                          ),
                        ),
                        (
                          l10n.gpuSharedMemory,
                          _memoryPair(
                            adapter.sharedUsedBytes,
                            adapter.sharedTotalBytes,
                            fallback,
                          ),
                        ),
                        (
                          l10n.gpuTemperature,
                          adapter.temperatureCelsius == null
                              ? fallback
                              : '${adapter.temperatureCelsius!.toStringAsFixed(0)} °C',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _GpuDetails(
                      title: l10n.gpuAdapterDetails,
                      rows: <(String, String)>[
                        (
                          l10n.gpuDriverVersion,
                          textOrUnavailable(adapter.driverVersion, fallback),
                        ),
                        (
                          l10n.gpuDriverDate,
                          textOrUnavailable(adapter.driverDate, fallback),
                        ),
                        (
                          l10n.gpuDirectXVersion,
                          textOrUnavailable(adapter.graphicsApi, fallback),
                        ),
                        (
                          l10n.gpuPhysicalLocation,
                          textOrUnavailable(adapter.physicalLocation, fallback),
                        ),
                        (
                          l10n.gpuHardwareReservedMemory,
                          bytesOrUnavailable(
                            adapter.hardwareReservedBytes,
                            fallback,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _memoryPair(BigInt? used, BigInt? total, String fallback) {
    if (used == null && total == null) {
      return fallback;
    }
    return '${bytesOrUnavailable(used, fallback)} / ${bytesOrUnavailable(total, fallback)}';
  }
}

class _GpuDetails extends StatelessWidget {
  const _GpuDetails({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return DesktopGroupBox(
      label: title,
      child: Column(
        children: rows
            .map(
              (row) => Expanded(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(row.$1, overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      child: Text(
                        row.$2,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
