// +-------------------------------------------------------------------------
//
//   taskmgr-rs - GPU 页
//
//   文件:       flutter_app/lib/pages/gpu_page.dart
//
//   日期:       2026年08月21日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   原 IDD_GPUPAGE DLU 布局；DRM/sysfs 与 Windows WDDM/PDH
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
  static const _engineSlotCount = 4;

  String? _selectedAdapterId;
  final Map<String, List<String?>> _engineSelections =
      <String, List<String?>>{};

  @override
  void initState() {
    super.initState();
    _synchronizeSelections();
  }

  @override
  void didUpdateWidget(GpuPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _synchronizeSelections();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final adapters = widget.data?.adapters ?? const <GpuAdapter>[];
    if (adapters.isEmpty) {
      return Center(child: Text(l10n.noHardwareGpusFound));
    }
    final adapterIndex = adapters.indexWhere(
      (adapter) => adapter.id == _selectedAdapterId,
    );
    final selectedIndex = adapterIndex < 0 ? 0 : adapterIndex;
    final adapter = adapters[selectedIndex];
    final selections =
        _engineSelections[adapter.id] ??
        List<String?>.filled(_engineSlotCount, null);
    final fallback = l10n.notAvailable;
    final dedicatedMemoryLabel = adapter.driverModel == GpuDriverModel.linuxDrm
        ? l10n.gpuDeviceLocalMemory
        : l10n.gpuDedicatedMemory;
    final sharedMemoryLabel = adapter.driverModel == GpuDriverModel.linuxDrm
        ? l10n.gpuSharedSystemMemory
        : l10n.gpuSharedMemory;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SizedBox(
        height: 548,
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
                      borderRadius: BorderRadius.circular(
                        DesktopTheme.radiusSmall,
                      ),
                      color: DesktopTheme.surface,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: adapter.id,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        dropdownColor: DesktopTheme.surface,
                        items: adapters
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value.id,
                                child: Text(
                                  value.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedAdapterId = value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Tooltip(
                    message: adapter.name,
                    child: Text(adapter.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(_status(l10n, adapter), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            SizedBox(
              height: 198,
              child: GridView.builder(
                key: const ValueKey<String>('gpu-engine-grid'),
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                  mainAxisExtent: 96.5,
                ),
                itemCount: _engineSlotCount,
                itemBuilder: (context, slot) {
                  final selectedId = selections[slot];
                  final engine = adapter.engines
                      .where((value) => value.id == selectedId)
                      .firstOrNull;
                  return _EngineSlot(
                    key: ValueKey<String>('gpu-engine-slot-$slot'),
                    slot: slot,
                    engines: adapter.engines,
                    selected: engine,
                    fallback: fallback,
                    labelFor: (value) => _engineLabel(l10n, value),
                    onSelected: adapter.engines.isEmpty
                        ? null
                        : (id) {
                            setState(() {
                              final updated = List<String?>.from(selections);
                              updated[slot] = id;
                              _engineSelections[adapter.id] = updated;
                            });
                          },
                  );
                },
              ),
            ),
            const SizedBox(height: 5),
            Text(dedicatedMemoryLabel),
            const SizedBox(height: 2),
            SizedBox(
              height: 52,
              child: DesktopGraph(
                primary: adapter.dedicatedUsageHistoryPercent,
              ),
            ),
            const SizedBox(height: 5),
            Text(sharedMemoryLabel),
            const SizedBox(height: 2),
            SizedBox(
              height: 52,
              child: DesktopGraph(primary: adapter.sharedUsageHistoryPercent),
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
                        (l10n.gpuMemory, _combinedMemory(adapter, fallback)),
                        (
                          dedicatedMemoryLabel,
                          _memoryPair(
                            adapter.dedicatedUsedBytes,
                            adapter.dedicatedTotalBytes,
                            fallback,
                          ),
                        ),
                        (
                          sharedMemoryLabel,
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
                      rows: _adapterDetails(l10n, adapter, fallback),
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

  void _synchronizeSelections() {
    final adapters = widget.data?.adapters ?? const <GpuAdapter>[];
    final liveAdapters = adapters.map((adapter) => adapter.id).toSet();
    _engineSelections.removeWhere((id, _) => !liveAdapters.contains(id));
    for (final adapter in adapters) {
      final liveEngines = adapter.engines.map((engine) => engine.id).toSet();
      final previous = _engineSelections[adapter.id] ?? const <String?>[];
      final next = List<String?>.generate(
        _engineSlotCount,
        (index) =>
            index < previous.length && liveEngines.contains(previous[index])
            ? previous[index]
            : null,
      );
      final initiallySelected = next.whereType<String>().toSet();
      final candidates = adapter.engines
          .map((engine) => engine.id)
          .where((id) => !initiallySelected.contains(id))
          .iterator;
      for (var index = 0; index < next.length; index++) {
        if (next[index] == null && candidates.moveNext()) {
          next[index] = candidates.current;
        }
      }
      _engineSelections[adapter.id] = next;
    }

    if (adapters.isEmpty) {
      _selectedAdapterId = null;
      return;
    }
    if (!liveAdapters.contains(_selectedAdapterId)) {
      final requested = widget.data?.selectedAdapter?.toInt();
      final index =
          requested != null && requested >= 0 && requested < adapters.length
          ? requested
          : 0;
      _selectedAdapterId = adapters[index].id;
    }
  }

  String _status(AppLocalizations l10n, GpuAdapter adapter) {
    if (adapter.detailError != null) {
      return l10n.gpuPartialDetails;
    }
    if (adapter.engines.isEmpty ||
        adapter.engines.every((engine) => engine.utilizationPercent == null)) {
      return l10n.gpuLoadingPerformance;
    }
    final hasDetails =
        adapter.driverName != null ||
        adapter.driverVersion != null ||
        adapter.graphicsApi != null ||
        adapter.physicalLocation != null ||
        adapter.primaryDeviceNode != null ||
        adapter.renderDeviceNode != null;
    return hasDetails ? l10n.gpuCurrentMetrics : l10n.gpuPartialDetails;
  }

  String _engineLabel(AppLocalizations l10n, GpuEngine engine) {
    final base = switch (engine.kind) {
      GpuEngineKind.overall => l10n.gpuUtilization,
      GpuEngineKind.memory => l10n.gpuEngineMemory,
      GpuEngineKind.threeD => l10n.gpuEngine3D,
      GpuEngineKind.copy => l10n.gpuEngineCopy,
      GpuEngineKind.videoEncode => l10n.gpuEngineVideoEncode,
      GpuEngineKind.videoDecode => l10n.gpuEngineVideoDecode,
      GpuEngineKind.compute => l10n.gpuEngineCompute,
      GpuEngineKind.security => l10n.gpuEngineSecurity,
      GpuEngineKind.other => textOrUnavailable(engine.name, l10n.unknown),
    };
    return engine.ordinal == null ? base : '$base ${engine.ordinal}';
  }

  String _driver(GpuAdapter adapter, String fallback) {
    final name = adapter.driverName?.trim();
    final version = adapter.driverVersion?.trim();
    if (name == null || name.isEmpty) {
      return textOrUnavailable(version, fallback);
    }
    if (version == null || version.isEmpty || version == name) {
      return name;
    }
    return '$name $version';
  }

  List<(String, String)> _adapterDetails(
    AppLocalizations l10n,
    GpuAdapter adapter,
    String fallback,
  ) {
    if (adapter.driverModel == GpuDriverModel.linuxDrm) {
      return <(String, String)>[
        (l10n.gpuKernelDriver, textOrUnavailable(adapter.driverName, fallback)),
        (
          l10n.gpuKernelModuleVersion,
          textOrUnavailable(adapter.driverVersion, fallback),
        ),
        (l10n.gpuGraphicsApi, textOrUnavailable(adapter.graphicsApi, fallback)),
        (
          l10n.gpuDrmPrimaryNode,
          textOrUnavailable(adapter.primaryDeviceNode, fallback),
        ),
        (
          l10n.gpuDrmRenderNode,
          textOrUnavailable(adapter.renderDeviceNode, fallback),
        ),
        (
          l10n.gpuPciAddress,
          textOrUnavailable(adapter.physicalLocation, fallback),
        ),
      ];
    }
    return <(String, String)>[
      (l10n.gpuDriverVersion, _driver(adapter, fallback)),
      (l10n.gpuDriverDate, textOrUnavailable(adapter.driverDate, fallback)),
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
        bytesOrUnavailable(adapter.hardwareReservedBytes, fallback),
      ),
    ];
  }

  String _combinedMemory(GpuAdapter adapter, String fallback) {
    final dedicatedUsed = adapter.dedicatedUsedBytes;
    final dedicatedTotal = adapter.dedicatedTotalBytes;
    final sharedUsed = adapter.sharedUsedBytes;
    final sharedTotal = adapter.sharedTotalBytes;
    if (dedicatedUsed != null && dedicatedTotal != null) {
      if (sharedUsed != null && sharedTotal != null) {
        return _memoryPair(
          dedicatedUsed + sharedUsed,
          dedicatedTotal + sharedTotal,
          fallback,
        );
      }
      return _memoryPair(dedicatedUsed, dedicatedTotal, fallback);
    }
    return _memoryPair(sharedUsed, sharedTotal, fallback);
  }

  String _memoryPair(BigInt? used, BigInt? total, String fallback) {
    if (used == null || total == null) {
      return fallback;
    }
    return '${bytesOrUnavailable(used, fallback)} / ${bytesOrUnavailable(total, fallback)}';
  }
}

class _EngineSlot extends StatelessWidget {
  const _EngineSlot({
    super.key,
    required this.slot,
    required this.engines,
    required this.selected,
    required this.fallback,
    required this.labelFor,
    required this.onSelected,
  });

  final int slot;
  final List<GpuEngine> engines;
  final GpuEngine? selected;
  final String fallback;
  final String Function(GpuEngine) labelFor;
  final ValueChanged<String?>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 22,
          child: Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: ValueKey<String>('gpu-engine-selector-$slot'),
                    isExpanded: true,
                    value: selected?.id,
                    hint: Text(fallback, overflow: TextOverflow.ellipsis),
                    dropdownColor: DesktopTheme.surface,
                    items: engines
                        .map(
                          (engine) => DropdownMenuItem<String>(
                            value: engine.id,
                            child: Text(
                              labelFor(engine),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: onSelected,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                percentOrUnavailable(selected?.utilizationPercent, fallback),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: DesktopGraph(primary: selected?.history ?? const <double>[]),
        ),
      ],
    );
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
                      child: Tooltip(
                        message: row.$1,
                        child: Text(row.$1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    Expanded(
                      child: Tooltip(
                        message: row.$2,
                        child: Text(
                          row.$2,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
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
