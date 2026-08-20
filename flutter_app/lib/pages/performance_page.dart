// +-------------------------------------------------------------------------
//
//   taskmgr-rs - 性能页
//
//   文件:       flutter_app/lib/pages/performance_page.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   原 IDD_PERFPAGE DLU 布局；GDI/Direct2D 曲线视觉
// --------------------------------------------------------------------------

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
  });

  final PerformanceData? data;
  final bool showKernelTimes;
  final bool oneGraphPerCpu;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = data;
    final fallback = l10n.notAvailable;
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
                            value: value?.cpuPercent,
                            label: l10n.cpuUsage,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: DesktopGroupBox(
                          label: l10n.memUsage,
                          child: DesktopMeter(
                            value: value?.memoryPercent,
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
                          child:
                              oneGraphPerCpu &&
                                  (value?.logicalCpuHistories.isNotEmpty ??
                                      false)
                              ? _LogicalCpuGraphs(
                                  histories: value!.logicalCpuHistories,
                                )
                              : DesktopGraph(
                                  primary:
                                      value?.cpuHistory.toList() ??
                                      const <double>[],
                                  secondary: showKernelTimes
                                      ? value?.kernelHistory.toList() ??
                                            const <double>[]
                                      : const <double>[],
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: DesktopGroupBox(
                          label: l10n.memoryUsageHistory,
                          child: DesktopGraph(
                            primary:
                                value?.memoryHistory.toList() ??
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
                              l10n.handles,
                              integerOrUnavailable(
                                value?.handleCount,
                                fallback,
                              ),
                            ),
                            (
                              l10n.threads,
                              integerOrUnavailable(
                                value?.threadCount,
                                fallback,
                              ),
                            ),
                            (
                              l10n.processesLabel,
                              integerOrUnavailable(
                                value?.processCount,
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
                                value?.memoryTotalKib,
                                fallback,
                              ),
                            ),
                            (
                              l10n.available,
                              integerOrUnavailable(
                                value?.memoryAvailableKib,
                                fallback,
                              ),
                            ),
                            (
                              l10n.fileCache,
                              integerOrUnavailable(
                                value?.fileCacheKib,
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
                          label: l10n.commitChargeK,
                          rows: <(String, String)>[
                            (
                              l10n.total,
                              integerOrUnavailable(
                                value?.commitTotalKib,
                                fallback,
                              ),
                            ),
                            (
                              l10n.limit,
                              integerOrUnavailable(
                                value?.commitLimitKib,
                                fallback,
                              ),
                            ),
                            (
                              l10n.peak,
                              integerOrUnavailable(
                                value?.commitPeakKib,
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
                          rows: <(String, String)>[
                            (
                              l10n.total,
                              integerOrUnavailable(
                                value?.kernelTotalKib,
                                fallback,
                              ),
                            ),
                            (
                              l10n.paged,
                              integerOrUnavailable(
                                value?.kernelPagedKib,
                                fallback,
                              ),
                            ),
                            (
                              l10n.nonpaged,
                              integerOrUnavailable(
                                value?.kernelNonPagedKib,
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

class _LogicalCpuGraphs extends StatelessWidget {
  const _LogicalCpuGraphs({required this.histories});

  final List<dynamic> histories;

  @override
  Widget build(BuildContext context) {
    final count = histories.length;
    final columns = count <= 4
        ? 2
        : count <= 16
        ? 4
        : 8;
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        final values = histories[index] as Iterable<double>;
        return DesktopGraph(primary: values.toList(growable: false));
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
            .map((row) {
              return Expanded(
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
              );
            })
            .toList(growable: false),
      ),
    );
  }
}
