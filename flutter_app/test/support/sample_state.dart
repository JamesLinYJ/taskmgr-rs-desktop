// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Flutter 测试快照夹具
//
//   文件:       flutter_app/test/support/sample_state.dart
//
//   日期:       2026年08月20日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；Dart 3.12.2
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   项目 FRB 协议 v1；七页桌面 golden 基线
// --------------------------------------------------------------------------

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:taskmgr_rs/app/backend_state.dart';
import 'package:taskmgr_rs/src/native_bridge/third_party/taskmgr_core.dart';

BackendState sampleState(PageId activePage) {
  final history = _history(8, 72);
  final secondHistory = _history(16, 38);
  final settings = UiSettings(
    schemaVersion: 1,
    activePage: activePage,
    updateSpeed: UpdateSpeed.normal,
    alwaysOnTop: false,
    minimizeOnUse: false,
    confirmations: true,
    hideWhenMinimized: false,
    showKernelTimes: true,
    oneGraphPerCpu: false,
    applicationViewMode: ApplicationViewMode.details,
    window: const WindowGeometry(width: 800, height: 600, maximized: false),
    processColumns: const <ColumnLayout>[],
  );
  final pages = PageId.values
      .map(
        (page) => PageCapability(
          page: page,
          availability: Availability.supported,
          columns: ColumnId.values,
          actions: ActionKind.values,
        ),
      )
      .toList(growable: false);
  final performance = PerformanceData(
    processCount: BigInt.from(128),
    threadCount: BigInt.from(1936),
    handleCount: BigInt.from(58240),
    memoryTotalKib: BigInt.from(33554432),
    memoryAvailableKib: BigInt.from(12873664),
    fileCacheKib: BigInt.from(4890624),
    commitTotalKib: BigInt.from(21757952),
    commitLimitKib: BigInt.from(50331648),
    commitPeakKib: BigInt.from(26378240),
    kernelTotalKib: BigInt.from(1153024),
    kernelPagedKib: BigInt.from(743424),
    kernelNonPagedKib: BigInt.from(409600),
    cpuPercent: 36,
    memoryPercent: 61.6,
    cpuHistory: history,
    kernelHistory: secondHistory,
    memoryHistory: _history(38, 70),
    logicalCpuHistories: List<Float64List>.generate(
      8,
      (index) => _history(index * 5, 45 + index * 4),
    ),
  );
  return BackendState(
    loading: false,
    activePage: activePage,
    updateSpeed: UpdateSpeed.normal,
    settings: settings,
    capabilities: PlatformCapabilities(
      protocolVersion: 1,
      platform: PlatformKind.linux,
      architecture: Architecture.x8664,
      pages: pages,
      privilegedDetails: Availability.partial,
      tray: Availability.partial,
      compositor: 'Test compositor',
      logicalProcessors: Uint32List.fromList(<int>[0, 1, 2, 3]),
    ),
    applications: ApplicationsData(
      rows: <ApplicationRow>[
        ApplicationRow(
          identity: ApplicationIdentity(nativeId: BigInt.one),
          title: 'Project Notes — Text Editor',
          status: ApplicationStatus.running,
          windowStation: 'WinSta0',
          desktop: 'Default',
          allowedActions: const <ActionKind>[
            ActionKind.switchTo,
            ActionKind.bringToFront,
            ActionKind.minimize,
            ActionKind.maximize,
            ActionKind.endTask,
          ],
        ),
        ApplicationRow(
          identity: ApplicationIdentity(nativeId: BigInt.two),
          title: 'Build output',
          status: ApplicationStatus.notResponding,
          allowedActions: const <ActionKind>[ActionKind.endTask],
        ),
      ],
    ),
    processes: ProcessesData(
      rows: <ProcessRow>[
        ProcessRow(
          identity: ProcessIdentity(pid: 2341, startTime: BigInt.from(99123)),
          parentPid: 1,
          imageName: 'taskmgr_rs',
          executablePath: '/usr/bin/taskmgr_rs',
          userName: 'james',
          sessionId: 2,
          cpuPercent: 4.8,
          cpuTimeMillis: BigInt.from(84321),
          memoryKib: BigInt.from(132608),
          memoryDeltaKib: 512,
          pageFaults: BigInt.from(18742),
          pageFaultsDelta: 12,
          virtualMemoryKib: BigInt.from(1245184),
          basePriority: 'Normal',
          threadCount: BigInt.from(18),
          fileDescriptorCount: BigInt.from(46),
          nice: 0,
          cgroup: '/user.slice/user-1000.slice',
          affinity: Uint32List.fromList(<int>[0, 1, 2, 3]),
        ),
        ProcessRow(
          identity: ProcessIdentity(pid: 992, startTime: BigInt.from(8711)),
          parentPid: 1,
          imageName: 'system-service',
          userName: 'root',
          cpuPercent: 0.3,
          cpuTimeMillis: BigInt.from(914225),
          memoryKib: BigInt.from(45824),
          threadCount: BigInt.from(7),
          fileDescriptorCount: BigInt.from(22),
          nice: -5,
          affinity: Uint32List.fromList(<int>[0, 1]),
        ),
      ],
    ),
    performance: performance,
    cpu: CpuData(
      model: 'AMD Ryzen 9 9955HX with Radeon Graphics',
      status: 'Current state',
      utilizationPercent: 36,
      history: history,
      groups: <CpuMetricGroup>[
        _cpuGroup('System diagnostics', <(String, String)>[
          ('Average frequency', '3.82 GHz'),
          ('Uptime', '1:12:34:56'),
          ('Queue length', '1'),
          ('Context switches/s', '21,402'),
          ('System calls/s', '9,842'),
          ('Interrupts/s', '3,015'),
        ]),
        _cpuGroup('Topology and features', <(String, String)>[
          ('Sockets', '1'),
          ('Physical cores', '16'),
          ('Logical processors', '32'),
          ('Virtualization', 'Yes'),
        ]),
        _cpuGroup('Processor', <(String, String)>[
          ('Manufacturer', 'AuthenticAMD'),
          ('Architecture', '64-bit'),
          ('Family', '26'),
          ('Stepping', '0'),
          ('ISA', 'SSE4, AVX2'),
          ('SMT cores', '16'),
        ]),
        _cpuGroup('Hardware cache', <(String, String)>[
          ('L1 data', '768 KiB'),
          ('L1 instruction', '512 KiB'),
          ('L2', '16 MiB'),
          ('L3', '64 MiB'),
        ]),
      ],
    ),
    gpu: GpuData(
      selectedAdapter: BigInt.zero,
      adapters: <GpuAdapter>[
        GpuAdapter(
          id: 'card0',
          name: 'AMD Radeon Graphics',
          utilizationPercent: 42,
          dedicatedUsedBytes: BigInt.from(2147483648),
          dedicatedTotalBytes: BigInt.from(8589934592),
          sharedUsedBytes: BigInt.from(536870912),
          sharedTotalBytes: BigInt.from(17179869184),
          temperatureCelsius: 58,
          driverVersion: 'amdgpu 6.18',
          driverDate: '2026-07-14',
          graphicsApi: 'Vulkan 1.4',
          physicalLocation: 'PCI 0000:65:00.0',
          hardwareReservedBytes: BigInt.from(16777216),
          engines: <GpuEngine>[
            GpuEngine(name: '3D', utilizationPercent: 42, history: history),
            GpuEngine(
              name: 'Copy',
              utilizationPercent: 8,
              history: secondHistory,
            ),
            GpuEngine(
              name: 'Video Encode',
              utilizationPercent: 2,
              history: _history(5, 18),
            ),
            GpuEngine(
              name: 'Video Decode',
              utilizationPercent: 16,
              history: _history(12, 32),
            ),
          ],
          dedicatedHistory: _history(18, 44),
          sharedHistory: _history(8, 26),
        ),
      ],
    ),
    network: NetworkData(
      interfaces: <NetworkInterface>[
        NetworkInterface(
          id: 'eth0',
          name: 'Ethernet',
          description: 'Intel 2.5GbE Controller',
          operational: true,
          linkSpeedBitsPerSecond: BigInt.from(2500000000),
          receivedBytesPerSecond: 1843200,
          sentBytesPerSecond: 532480,
          utilizationPercent: 0.76,
          receivedHistory: _history(12, 64),
          sentHistory: _history(4, 28),
        ),
        NetworkInterface(
          id: 'wlan0',
          name: 'Wi-Fi',
          description: 'Wireless LAN adapter',
          operational: false,
          linkSpeedBitsPerSecond: BigInt.from(866000000),
          receivedHistory: Float64List(60),
          sentHistory: Float64List(60),
        ),
      ],
    ),
    users: UsersData(
      sessions: <UserSession>[
        UserSession(
          identity: UserSessionIdentity(
            id: '2',
            loginTime: BigInt.from(1710000000),
          ),
          userName: 'james',
          session: 'tty2',
          clientName: 'localhost',
          state: 'active',
          idleSeconds: BigInt.from(42),
          allowedActions: const <ActionKind>[
            ActionKind.disconnectSession,
            ActionKind.logoffSession,
            ActionKind.sendMessage,
          ],
        ),
        UserSession(
          identity: UserSessionIdentity(id: '7'),
          userName: 'guest',
          session: 'pts/4',
          state: 'idle',
          allowedActions: const <ActionKind>[ActionKind.logoffSession],
        ),
      ],
    ),
  );
}

CpuMetricGroup _cpuGroup(String title, List<(String, String)> values) {
  return CpuMetricGroup(
    title: title,
    metrics: values
        .map((value) => MetricValue(label: value.$1, value: value.$2))
        .toList(growable: false),
  );
}

Float64List _history(double phase, double ceiling) {
  return Float64List.fromList(
    List<double>.generate(
      60,
      (index) => (ceiling * (0.56 + 0.34 * math.sin((index + phase) / 7)))
          .clamp(0, 100)
          .toDouble(),
    ),
  );
}
