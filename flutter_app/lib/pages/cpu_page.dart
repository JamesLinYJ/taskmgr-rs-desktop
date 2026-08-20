// +-------------------------------------------------------------------------
//
//   taskmgr-rs - CPU 详情页
//
//   文件:       flutter_app/lib/pages/cpu_page.dart
//
//   日期:       2026年08月21日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   原 IDD_CPUPAGE DLU 布局；Linux sysfs/procfs；Windows CPU API
// --------------------------------------------------------------------------

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../src/native_bridge/third_party/taskmgr_core.dart';
import '../ui/desktop_controls.dart';
import '../ui/desktop_graph.dart';
import '../ui/formatters.dart';

class CpuPage extends StatelessWidget {
  const CpuPage({
    super.key,
    required this.data,
    required this.platform,
    this.showKernelTimes = false,
  });

  final CpuData? data;
  final PlatformKind? platform;
  final bool showKernelTimes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = _groups(l10n, data, platform);
    return LayoutBuilder(
      builder: (context, constraints) {
        const contentHeight = 468.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - 15),
            ),
            child: SizedBox(
              height: math.max(
                contentHeight,
                math.max(0, constraints.maxHeight - 15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        l10n.cpuPageTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Tooltip(
                          message: data?.model ?? l10n.notAvailable,
                          child: Text(
                            data?.model ?? l10n.notAvailable,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Text(
                        percentOrUnavailable(
                          data?.utilizationPercent,
                          l10n.notAvailable,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(_status(l10n, data), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 112,
                    child: DesktopGraph(
                      primary: data?.history.toList() ?? const <double>[],
                      secondary: showKernelTimes
                          ? data?.kernelHistory.toList() ?? const <double>[]
                          : const <double>[],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: GridView.builder(
                      key: const ValueKey<String>('cpu-details-grid'),
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                            mainAxisExtent: 148,
                          ),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return _CpuMetricGroup(
                          key: ValueKey<String>('cpu-group-${group.title}'),
                          title: group.title,
                          metrics: group.metrics,
                          fallback: l10n.notAvailable,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _status(AppLocalizations l10n, CpuData? value) {
    if (value == null) {
      return l10n.cpuLoading;
    }
    final hasPerformance =
        value.utilizationPercent != null ||
        value.current.averageFrequencyMhz != null;
    if (!hasPerformance) {
      return l10n.cpuLoadingDetails;
    }
    final hasTopology =
        value.topology.logicalProcessorCount != null ||
        value.topology.physicalCoreCount != null;
    final hasHardware =
        value.model != null ||
        value.hardware.manufacturer != null ||
        value.hardware.architecture != null ||
        value.hardware.caches.isNotEmpty;
    return hasTopology && hasHardware
        ? l10n.cpuCurrentState
        : l10n.cpuPartialDetails;
  }

  List<_MetricGroupData> _groups(
    AppLocalizations l10n,
    CpuData? value,
    PlatformKind? platform,
  ) {
    final current = value?.current;
    final system = value?.system;
    final topology = value?.topology;
    final hardware = value?.hardware;
    return <_MetricGroupData>[
      _MetricGroupData(l10n.cpuCurrentState, <_Metric>[
        _Metric(
          l10n.cpuAverageFrequency,
          _frequency(current?.averageFrequencyMhz),
        ),
        _Metric(l10n.cpuUsage, _percent(value?.utilizationPercent)),
        _Metric(
          l10n.cpuFrequencyRange,
          _frequencyRange(
            current?.minimumFrequencyMhz,
            current?.maximumFrequencyMhz,
          ),
        ),
        _Metric(l10n.cpuUserTime, _percent(current?.userPercent)),
        _Metric(l10n.cpuKernelTime, _percent(current?.kernelPercent)),
        _Metric(l10n.cpuDpcTime, _percent(current?.dpcPercent)),
        _Metric(l10n.cpuInterruptTime, _percent(current?.interruptPercent)),
        _Metric(
          l10n.cpuInterruptsPerSecond,
          _integer(current?.interruptsPerSecond),
        ),
        _Metric(l10n.cpuUptime, _uptime(current?.uptimeSeconds)),
      ]),
      _MetricGroupData(l10n.cpuSystemDiagnostics, <_Metric>[
        _Metric(l10n.processesLabel, _integer(system?.processCount)),
        _Metric(l10n.threads, _integer(system?.threadCount)),
        _Metric(
          platform == PlatformKind.linux ? l10n.openFileHandles : l10n.handles,
          _integer(
            platform == PlatformKind.linux
                ? system?.openFileCount
                : system?.handleCount,
          ),
        ),
        _Metric(
          l10n.cpuProcessorQueueLength,
          _integer(system?.processorQueueLength),
        ),
        _Metric(
          l10n.cpuContextSwitchesPerSecond,
          _integer(system?.contextSwitchesPerSecond),
        ),
        _Metric(
          l10n.cpuSystemCallsPerSecond,
          _integer(system?.systemCallsPerSecond),
        ),
      ]),
      _MetricGroupData(l10n.cpuTopologyFeatures, <_Metric>[
        _Metric(l10n.cpuPackages, _plainInteger(topology?.packageCount)),
        _Metric(l10n.cpuNumaNodes, _plainInteger(topology?.numaNodeCount)),
        _Metric(l10n.cpuGroups, _plainInteger(topology?.processorGroupCount)),
        _Metric(l10n.cpuDies, _plainInteger(topology?.dieCount)),
        _Metric(l10n.cpuModules, _plainInteger(topology?.moduleCount)),
        _Metric(
          l10n.cpuPhysicalCores,
          _plainInteger(topology?.physicalCoreCount),
        ),
        _Metric(
          l10n.cpuLogicalProcessors,
          _plainInteger(topology?.logicalProcessorCount),
        ),
        _Metric(l10n.cpuCoreClasses, _coreClasses(l10n, topology?.coreClasses)),
        _Metric(l10n.cpuSmtCores, _plainInteger(topology?.smtCoreCount)),
        _Metric(
          l10n.cpuThreadsPerCore,
          _integerRange(
            topology?.minimumThreadsPerCore,
            topology?.maximumThreadsPerCore,
          ),
        ),
        _Metric(
          l10n.cpuVirtualization,
          _boolean(l10n, topology?.virtualization),
        ),
        _Metric(
          l10n.cpuSlat,
          _boolean(l10n, topology?.secondLevelAddressTranslation),
        ),
      ]),
      _MetricGroupData(l10n.cpuHardwareCache, <_Metric>[
        _Metric(l10n.cpuManufacturer, hardware?.manufacturer),
        _Metric(l10n.cpuSocket, hardware?.socket),
        _Metric(l10n.cpuProcessorId, hardware?.processorId),
        _Metric(l10n.cpuArchitectureWidth, _architectureAndWidth(hardware)),
        _Metric(l10n.cpuFamilyLevel, _pair(hardware?.family, hardware?.level)),
        _Metric(
          l10n.cpuRevisionStepping,
          _pair(hardware?.revision, hardware?.stepping),
        ),
        _Metric(
          l10n.cpuFirmwareMaxFrequency,
          _frequency(hardware?.firmwareMaxFrequencyMhz),
        ),
        _Metric(
          l10n.cpuIsaFeatures,
          hardware == null || hardware.isaFeatures.isEmpty
              ? null
              : hardware.isaFeatures.join(', '),
        ),
        _Metric(
          l10n.cpuCacheL1Data,
          _caches(hardware?.caches, 1, CpuCacheKind.data),
        ),
        _Metric(
          l10n.cpuCacheL1Instruction,
          _caches(hardware?.caches, 1, CpuCacheKind.instruction),
        ),
        _Metric(l10n.cpuCacheL2, _caches(hardware?.caches, 2)),
        _Metric(l10n.cpuCacheL3, _caches(hardware?.caches, 3)),
      ]),
    ];
  }

  String? _frequency(double? mhz) {
    if (mhz == null || !mhz.isFinite || mhz < 0) {
      return null;
    }
    return mhz >= 1_000
        ? '${(mhz / 1_000).toStringAsFixed(2)} GHz'
        : '${mhz.toStringAsFixed(0)} MHz';
  }

  String? _frequencyRange(double? minimum, double? maximum) {
    final low = _frequency(minimum);
    final high = _frequency(maximum);
    if (low == null || high == null) {
      return low ?? high;
    }
    return low == high ? low : '$low – $high';
  }

  String? _percent(double? value) {
    if (value == null || !value.isFinite) {
      return null;
    }
    return '${value.clamp(0, 100).toStringAsFixed(1)}%';
  }

  String? _integer(BigInt? value) =>
      value == null ? null : integerOrUnavailable(value, '');

  String? _plainInteger(int? value) => value?.toString();

  String? _uptime(BigInt? seconds) {
    if (seconds == null || seconds.isNegative) {
      return null;
    }
    final day = seconds ~/ BigInt.from(86_400);
    final hour = (seconds % BigInt.from(86_400)) ~/ BigInt.from(3_600);
    final minute = (seconds % BigInt.from(3_600)) ~/ BigInt.from(60);
    final second = seconds % BigInt.from(60);
    return '${day.toString()}:${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';
  }

  String? _boolean(AppLocalizations l10n, bool? value) {
    return value == null ? null : (value ? l10n.cpuYes : l10n.cpuNo);
  }

  String? _integerRange(int? minimum, int? maximum) {
    if (minimum == null || maximum == null) {
      return minimum?.toString() ?? maximum?.toString();
    }
    return minimum == maximum ? '$minimum' : '$minimum–$maximum';
  }

  String? _coreClasses(AppLocalizations l10n, List<CpuCoreClass>? classes) {
    if (classes == null || classes.isEmpty) {
      return null;
    }
    return classes
        .map(
          (value) => value.efficiencyClass == null
              ? '${l10n.cpuUniformClass}: ${value.coreCount}'
              : '${value.efficiencyClass}: ${value.coreCount}',
        )
        .join(', ');
  }

  String? _architectureAndWidth(CpuHardwareMetrics? hardware) {
    if (hardware == null) {
      return null;
    }
    final widths = <int>{
      ?hardware.addressWidthBits,
      ?hardware.dataWidthBits,
    }.toList(growable: false);
    final width = widths.isEmpty
        ? null
        : widths.length == 1
        ? '${widths.first}-bit'
        : '${widths.join('/')}-bit';
    return _pair(hardware.architecture, width);
  }

  String? _pair(String? left, String? right) {
    final normalizedLeft = left?.trim();
    final normalizedRight = right?.trim();
    final hasLeft = normalizedLeft != null && normalizedLeft.isNotEmpty;
    final hasRight = normalizedRight != null && normalizedRight.isNotEmpty;
    if (!hasLeft || !hasRight) {
      return hasLeft ? normalizedLeft : (hasRight ? normalizedRight : null);
    }
    return '$normalizedLeft / $normalizedRight';
  }

  String? _caches(List<CpuCache>? caches, int level, [CpuCacheKind? kind]) {
    final matches = caches
        ?.where(
          (cache) =>
              cache.level == level && (kind == null || cache.kind == kind),
        )
        .toList(growable: false);
    if (matches == null || matches.isEmpty) {
      return null;
    }
    return matches
        .map((cache) {
          final size = bytesOrUnavailable(cache.sizeBytes, '');
          return cache.instanceCount > 1
              ? '${cache.instanceCount} × $size'
              : size;
        })
        .join(' + ');
  }
}

class _MetricGroupData {
  const _MetricGroupData(this.title, this.metrics);

  final String title;
  final List<_Metric> metrics;
}

class _Metric {
  const _Metric(this.label, this.value);

  final String label;
  final String? value;
}

class _CpuMetricGroup extends StatelessWidget {
  const _CpuMetricGroup({
    super.key,
    required this.title,
    required this.metrics,
    required this.fallback,
  });

  final String title;
  final List<_Metric> metrics;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final rows = (metrics.length / 2).ceil().clamp(1, 6);
    return DesktopGroupBox(
      label: title,
      child: Column(
        children: List<Widget>.generate(rows, (rowIndex) {
          return Expanded(
            child: Row(
              children: List<Widget>.generate(2, (columnIndex) {
                final index = rowIndex * 2 + columnIndex;
                if (index >= metrics.length) {
                  return const Expanded(child: SizedBox.shrink());
                }
                final metric = metrics[index];
                final value = metric.value ?? fallback;
                return Expanded(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Tooltip(
                          message: metric.label,
                          child: Text(
                            metric.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Tooltip(
                          message: value,
                          child: Text(
                            value,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (columnIndex == 0) const SizedBox(width: 6),
                    ],
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}
