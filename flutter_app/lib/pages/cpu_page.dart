// +-------------------------------------------------------------------------
//
//   taskmgr-rs - CPU 详情页
//
//   文件:       flutter_app/lib/pages/cpu_page.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   原 IDD_CPUPAGE DLU 布局；Linux sysfs/procfs CPU 语义
// --------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../src/native_bridge/third_party/taskmgr_core.dart';
import '../ui/desktop_controls.dart';
import '../ui/desktop_graph.dart';

class CpuPage extends StatelessWidget {
  const CpuPage({
    super.key,
    required this.data,
    this.kernelHistory = const <double>[],
    this.showKernelTimes = false,
  });

  final CpuData? data;
  final List<double> kernelHistory;
  final bool showKernelTimes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = data?.groups ?? const <CpuMetricGroup>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
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
                child: Text(
                  data?.model ?? l10n.notAvailable,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                data?.utilizationPercent == null
                    ? ''
                    : '${data!.utilizationPercent!.round()}%',
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            data?.status ?? l10n.cpuLoading,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Expanded(
            flex: 46,
            child: DesktopGraph(
              primary: data?.history.toList() ?? const <double>[],
              secondary: showKernelTimes ? kernelHistory : const <double>[],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            flex: 54,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 2.25,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                final group = index < groups.length ? groups[index] : null;
                return _CpuMetricGroup(
                  title: group?.title ?? '',
                  metrics: group?.metrics ?? const <MetricValue>[],
                  fallback: l10n.notAvailable,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CpuMetricGroup extends StatelessWidget {
  const _CpuMetricGroup({
    required this.title,
    required this.metrics,
    required this.fallback,
  });

  final String title;
  final List<MetricValue> metrics;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return DesktopGroupBox(
      label: title,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rows = (metrics.length / 2).ceil().clamp(1, 6);
          return Column(
            children: List<Widget>.generate(rows, (rowIndex) {
              return Expanded(
                child: Row(
                  children: List<Widget>.generate(2, (columnIndex) {
                    final index = rowIndex * 2 + columnIndex;
                    if (index >= metrics.length) {
                      return const Expanded(child: SizedBox.shrink());
                    }
                    final metric = metrics[index];
                    return Expanded(
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              metric.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              metric.value ?? fallback,
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
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
          );
        },
      ),
    );
  }
}
