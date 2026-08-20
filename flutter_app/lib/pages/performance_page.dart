// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 性能页
//
//   文件:       flutter_app/lib/pages/performance_page.dart
//
//   日期:       2026年08月21日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   原 IDD_PERFPAGE DLU 布局；GDI/Direct2D 曲线视觉
// --------------------------------------------------------------------------

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../src/native_bridge/third_party/taskmgr_core.dart';
import '../ui/desktop_controls.dart';
import '../ui/desktop_graph.dart';
import '../ui/formatters.dart';

class PerformancePage extends StatelessWidget {
  const PerformancePage({
    super.key,
    required this.data,
    required this.showKernelTimes,
    required this.oneGraphPerCpu,
    required this.platform,
    required this.tinyFootprint,
    required this.onToggleTinyFootprint,
  });

  final PerformanceData? data;
  final bool showKernelTimes;
  final bool oneGraphPerCpu;
  final PlatformKind? platform;
  final bool tinyFootprint;
  final VoidCallback onToggleTinyFootprint;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('performance-page-double-click-target'),
      behavior: HitTestBehavior.opaque,
      onDoubleTap: onToggleTinyFootprint,
      child: tinyFootprint
          ? _TinyPerformanceLayout(
              data: data,
              showKernelTimes: showKernelTimes,
              oneGraphPerCpu: oneGraphPerCpu,
            )
          : _NormalPerformanceLayout(
              data: data,
              showKernelTimes: showKernelTimes,
              oneGraphPerCpu: oneGraphPerCpu,
              platform: platform,
            ),
    );
  }
}

class _TinyPerformanceLayout extends StatelessWidget {
  const _TinyPerformanceLayout({
    required this.data,
    required this.showKernelTimes,
    required this.oneGraphPerCpu,
  });

  final PerformanceData? data;
  final bool showKernelTimes;
  final bool oneGraphPerCpu;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 92,
            child: DesktopGroupBox(
              label: l10n.cpuUsage,
              child: DesktopMeter(
                value: data?.cpuPercent,
                label: l10n.cpuUsage,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: DesktopGroupBox(
              label: l10n.cpuUsageHistory,
              child: _CpuHistory(
                data: data,
                showKernelTimes: showKernelTimes,
                oneGraphPerCpu: oneGraphPerCpu,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NormalPerformanceLayout extends StatelessWidget {
  const _NormalPerformanceLayout({
    required this.data,
    required this.showKernelTimes,
    required this.oneGraphPerCpu,
    required this.platform,
  });

  final PerformanceData? data;
  final bool showKernelTimes;
  final bool oneGraphPerCpu;
  final PlatformKind? platform;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fallback = l10n.notAvailable;
    final isLinux = platform == PlatformKind.linux;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 7),
      child: Column(
        children: <Widget>[
          Expanded(
            flex: 58,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 92,
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: DesktopGroupBox(
                          label: l10n.cpuUsage,
                          child: DesktopMeter(
                            value: data?.cpuPercent,
                            label: l10n.cpuUsage,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: DesktopGroupBox(
                          label: l10n.memUsage,
                          child: DesktopMeter(
                            value: data?.memoryPercent,
                            label: l10n.memUsage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: DesktopGroupBox(
                          label: l10n.cpuUsageHistory,
                          child: _CpuHistory(
                            data: data,
                            showKernelTimes: showKernelTimes,
                            oneGraphPerCpu: oneGraphPerCpu,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: DesktopGroupBox(
                          label: l10n.memoryUsageHistory,
                          child: DesktopGraph(
                            primary:
                                data?.memoryHistory.toList() ??
                                const <double>[],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            flex: 42,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _MetricGroup(
                          label: l10n.totals,
                          rows: <(String, String)>[
                            (
                              isLinux ? l10n.openFileHandles : l10n.handles,
                              integerOrUnavailable(
                                isLinux
                                    ? data?.openFileCount
                                    : data?.handleCount,
                                fallback,
                              ),
                            ),
                            (
                              l10n.threads,
                              integerOrUnavailable(data?.threadCount, fallback),
                            ),
                            (
                              l10n.processesLabel,
                              integerOrUnavailable(
                                data?.processCount,
                                fallback,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricGroup(
                          label: l10n.physicalMemoryK,
                          rows: <(String, String)>[
                            (
                              l10n.total,
                              integerOrUnavailable(
                                data?.memoryTotalKib,
                                fallback,
                              ),
                            ),
                            (
                              l10n.available,
                              integerOrUnavailable(
                                data?.memoryAvailableKib,
                                fallback,
                              ),
                            ),
                            (
                              l10n.fileCache,
                              integerOrUnavailable(
                                data?.fileCacheKib,
                                fallback,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _MetricGroup(
                          label: isLinux
                              ? l10n.virtualMemoryK
                              : l10n.commitChargeK,
                          rows: isLinux
                              ? <(String, String)>[
                                  (
                                    l10n.committed,
                                    integerOrUnavailable(
                                      data?.commitTotalKib,
                                      fallback,
                                    ),
                                  ),
                                  (
                                    l10n.commitLimit,
                                    integerOrUnavailable(
                                      data?.commitLimitKib,
                                      fallback,
                                    ),
                                  ),
                                  (
                                    l10n.swapUsed,
                                    integerOrUnavailable(
                                      data?.swapUsedKib,
                                      fallback,
                                    ),
                                  ),
                                ]
                              : <(String, String)>[
                                  (
                                    l10n.total,
                                    integerOrUnavailable(
                                      data?.commitTotalKib,
                                      fallback,
                                    ),
                                  ),
                                  (
                                    l10n.limit,
                                    integerOrUnavailable(
                                      data?.commitLimitKib,
                                      fallback,
                                    ),
                                  ),
                                  (
                                    l10n.peak,
                                    integerOrUnavailable(
                                      data?.commitPeakKib,
                                      fallback,
                                    ),
                                  ),
                                ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricGroup(
                          label: l10n.kernelMemoryK,
                          rows: isLinux
                              ? <(String, String)>[
                                  (
                                    l10n.slab,
                                    integerOrUnavailable(
                                      data?.slabKib,
                                      fallback,
                                    ),
                                  ),
                                  (
                                    l10n.kernelStack,
                                    integerOrUnavailable(
                                      data?.kernelStackKib,
                                      fallback,
                                    ),
                                  ),
                                  (
                                    l10n.pageTables,
                                    integerOrUnavailable(
                                      data?.pageTablesKib,
                                      fallback,
                                    ),
                                  ),
                                ]
                              : <(String, String)>[
                                  (
                                    l10n.total,
                                    integerOrUnavailable(
                                      data?.kernelTotalKib,
                                      fallback,
                                    ),
                                  ),
                                  (
                                    l10n.paged,
                                    integerOrUnavailable(
                                      data?.kernelPagedKib,
                                      fallback,
                                    ),
                                  ),
                                  (
                                    l10n.nonpaged,
                                    integerOrUnavailable(
                                      data?.kernelNonPagedKib,
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
        ],
      ),
    );
  }
}

class _CpuHistory extends StatelessWidget {
  const _CpuHistory({
    required this.data,
    required this.showKernelTimes,
    required this.oneGraphPerCpu,
  });

  final PerformanceData? data;
  final bool showKernelTimes;
  final bool oneGraphPerCpu;

  @override
  Widget build(BuildContext context) {
    final value = data;
    if (oneGraphPerCpu && (value?.logicalCpuHistories.isNotEmpty ?? false)) {
      return _LogicalCpuGraphs(
        histories: value!.logicalCpuHistories,
        kernelHistories: value.logicalKernelHistories,
        showKernelTimes: showKernelTimes,
      );
    }
    return DesktopGraph(
      primary: value?.cpuHistory.toList() ?? const <double>[],
      secondary: showKernelTimes
          ? value?.kernelHistory.toList() ?? const <double>[]
          : const <double>[],
    );
  }
}

class _LogicalCpuGraphs extends StatelessWidget {
  const _LogicalCpuGraphs({
    required this.histories,
    required this.kernelHistories,
    required this.showKernelTimes,
  });

  final List<Float64List> histories;
  final List<Float64List> kernelHistories;
  final bool showKernelTimes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = histories.length;
        if (count == 0 ||
            constraints.maxWidth <= 0 ||
            constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }
        const gap = 2.0;
        final columns = _bestColumnCount(
          Size(constraints.maxWidth, constraints.maxHeight),
          count,
          gap,
        );
        final rows = (count / columns).ceil();
        final cellHeight = math.max(
          1.0,
          (constraints.maxHeight - gap * (rows - 1)) / rows,
        );
        return GridView.builder(
          key: ValueKey<String>('logical-cpu-grid-$count'),
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            mainAxisExtent: cellHeight,
          ),
          itemCount: count,
          itemBuilder: (context, index) {
            return _LogicalCpuGraph(
              key: ValueKey<String>('logical-cpu-$index'),
              label: replacePrintf(l10n.formatCpuNumber, <Object>[index]),
              primary: histories[index].toList(growable: false),
              secondary: showKernelTimes && index < kernelHistories.length
                  ? kernelHistories[index].toList(growable: false)
                  : const <double>[],
            );
          },
        );
      },
    );
  }

  int _bestColumnCount(Size size, int count, double gap) {
    var bestColumns = 1;
    var bestScore = double.infinity;
    var bestUnusedSlots = count - 1;
    for (var columns = 1; columns <= count; columns++) {
      final rows = (count / columns).ceil();
      final usableWidth = size.width - gap * (columns - 1);
      final usableHeight = size.height - gap * (rows - 1);
      if (usableWidth <= 0 || usableHeight <= 0) {
        continue;
      }

      // Keep this identical to the archived Win32 layout calculation: choose
      // the closest-to-square pane and add its fixed 32-point empty-slot cost.
      // Flooring reproduces the integer-pixel Win32 partition before Flutter
      // distributes any remaining logical pixels across the grid.
      final paneWidth = (usableWidth / columns).floorToDouble();
      final paneHeight = (usableHeight / rows).floorToDouble();
      if (paneWidth <= 0 || paneHeight <= 0) {
        continue;
      }
      final longerSide = math.max(paneWidth, paneHeight);
      final aspectError = (paneWidth - paneHeight).abs() * 1024 / longerSide;
      final unusedSlots = rows * columns - count;
      final score = aspectError + unusedSlots * 32;
      if (score < bestScore ||
          (score == bestScore && unusedSlots < bestUnusedSlots)) {
        bestScore = score;
        bestColumns = columns;
        bestUnusedSlots = unusedSlots;
      }
    }
    return bestColumns;
  }
}

class _LogicalCpuGraph extends StatelessWidget {
  const _LogicalCpuGraph({
    super.key,
    required this.label,
    required this.primary,
    required this.secondary,
  });

  final String label;
  final List<double> primary;
  final List<double> secondary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DesktopGraph(primary: primary, secondary: secondary),
            if (constraints.maxWidth >= 38 && constraints.maxHeight >= 22)
              Positioned(
                left: 4,
                top: 3,
                child: IgnorePointer(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 8,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MetricGroup extends StatelessWidget {
  const _MetricGroup({required this.label, required this.rows});

  final String label;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return DesktopGroupBox(
      label: label,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
