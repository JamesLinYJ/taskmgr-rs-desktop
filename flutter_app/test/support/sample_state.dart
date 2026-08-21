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

BackendState sampleState(
  PageId activePage, {
  PlatformKind platform = PlatformKind.linux,
  Availability tray = Availability.partial,
}) {
  final history = _history(8, 72);
  final secondHistory = _history(16, 38);
  final settings = UiSettings(
    schemaVersion: 3,
    activePage: activePage,
    updateSpeed: UpdateSpeed.normal,
    alwaysOnTop: false,
    minimizeOnUse: false,
    confirmations: true,
    hideWhenMinimized: false,
    showKernelTimes: true,
    oneGraphPerCpu: true,
    tinyFootprint: false,
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
    handleCount: platform == PlatformKind.windows ? BigInt.from(58240) : null,
    openFileCount: platform == PlatformKind.linux ? BigInt.from(58240) : null,
    memoryTotalKib: BigInt.from(33554432),
    memoryAvailableKib: BigInt.from(12873664),
    fileCacheKib: BigInt.from(4890624),
    commitTotalKib: BigInt.from(21757952),
    commitLimitKib: BigInt.from(50331648),
    commitPeakKib: platform == PlatformKind.windows
        ? BigInt.from(26378240)
        : null,
    kernelTotalKib: platform == PlatformKind.windows
        ? BigInt.from(1153024)
        : null,
    kernelPagedKib: platform == PlatformKind.windows
        ? BigInt.from(743424)
        : null,
    kernelNonPagedKib: platform == PlatformKind.windows
        ? BigInt.from(409600)
        : null,
    swapUsedKib: platform == PlatformKind.linux ? BigInt.from(2097152) : null,
    slabKib: platform == PlatformKind.linux ? BigInt.from(743424) : null,
    kernelStackKib: platform == PlatformKind.linux ? BigInt.from(65536) : null,
    pageTablesKib: platform == PlatformKind.linux ? BigInt.from(344064) : null,
    cpuPercent: 36,
    memoryPercent: 61.6,
    cpuHistory: history,
    kernelHistory: secondHistory,
    memoryHistory: _history(38, 70),
    logicalCpuHistories: List<Float64List>.generate(
      8,
      (index) => _history(index * 5, 45 + index * 4),
    ),
    logicalKernelHistories: List<Float64List>.generate(
      8,
      (index) => _history(index * 3, 16 + index * 2),
    ),
  );
  return BackendState(
    loading: false,
    activePage: activePage,
    updateSpeed: UpdateSpeed.normal,
    settings: settings,
    capabilities: PlatformCapabilities(
      protocolVersion: 1,
      platform: platform,
      architecture: Architecture.x8664,
      pages: pages,
      privilegedDetails: Availability.partial,
      tray: tray,
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
      utilizationPercent: 36,
      history: history,
      kernelHistory: secondHistory,
      current: CpuCurrentMetrics(
        averageFrequencyMhz: 3820,
        minimumFrequencyMhz: 540,
        maximumFrequencyMhz: 5450,
        userPercent: 23.4,
        kernelPercent: 12.6,
        dpcPercent: 0.4,
        interruptPercent: 1.2,
        interruptsPerSecond: BigInt.from(3015),
        uptimeSeconds: BigInt.from(131696),
      ),
      system: CpuSystemMetrics(
        processCount: BigInt.from(128),
        threadCount: BigInt.from(1936),
        handleCount: platform == PlatformKind.windows
            ? BigInt.from(58240)
            : null,
        openFileCount: platform == PlatformKind.linux
            ? BigInt.from(58240)
            : null,
        processorQueueLength: BigInt.one,
        contextSwitchesPerSecond: BigInt.from(21402),
        systemCallsPerSecond: BigInt.from(9842),
      ),
      topology: const CpuTopologyMetrics(
        packageCount: 1,
        numaNodeCount: 1,
        processorGroupCount: 1,
        dieCount: 1,
        moduleCount: 2,
        physicalCoreCount: 16,
        logicalProcessorCount: 32,
        coreClasses: <CpuCoreClass>[CpuCoreClass(coreCount: 16)],
        smtCoreCount: 16,
        minimumThreadsPerCore: 2,
        maximumThreadsPerCore: 2,
        virtualization: true,
        secondLevelAddressTranslation: true,
      ),
      hardware: CpuHardwareMetrics(
        manufacturer: 'AuthenticAMD',
        socket: '0',
        processorId: 'AMD64 Family 26 Model 36',
        architecture: 'x86_64',
        addressWidthBits: 64,
        dataWidthBits: 64,
        family: '26',
        level: '25',
        revision: '0xB201',
        stepping: '1',
        firmwareMaxFrequencyMhz: 5450,
        isaFeatures: const <String>['sse4', 'avx2', 'aes', 'sha'],
        caches: <CpuCache>[
          CpuCache(
            level: 1,
            kind: CpuCacheKind.data,
            sizeBytes: BigInt.from(49152),
            instanceCount: 16,
            associativity: 12,
            lineSizeBytes: 64,
          ),
          CpuCache(
            level: 1,
            kind: CpuCacheKind.instruction,
            sizeBytes: BigInt.from(32768),
            instanceCount: 16,
            associativity: 8,
            lineSizeBytes: 64,
          ),
          CpuCache(
            level: 2,
            kind: CpuCacheKind.unified,
            sizeBytes: BigInt.from(1048576),
            instanceCount: 16,
          ),
          CpuCache(
            level: 3,
            kind: CpuCacheKind.unified,
            sizeBytes: BigInt.from(33554432),
            instanceCount: 2,
          ),
        ],
      ),
    ),
    gpu: GpuData(
      selectedAdapter: BigInt.zero,
      adapters: <GpuAdapter>[
        GpuAdapter(
          id: 'card0',
          name: 'AMD Radeon Graphics',
          driverModel: GpuDriverModel.linuxDrm,
          utilizationPercent: 42,
          dedicatedUsedBytes: BigInt.from(2147483648),
          dedicatedTotalBytes: BigInt.from(8589934592),
          sharedUsedBytes: BigInt.from(536870912),
          sharedTotalBytes: BigInt.from(17179869184),
          temperatureCelsius: 58,
          driverName: 'amdgpu',
          driverVersion: '6.18.0',
          graphicsApi: 'Vulkan 1.4',
          physicalLocation: '0000:65:00.0',
          primaryDeviceNode: '/dev/dri/card0',
          renderDeviceNode: '/dev/dri/renderD128',
          engines: <GpuEngine>[
            GpuEngine(
              id: '3d:0',
              kind: GpuEngineKind.threeD,
              ordinal: 0,
              utilizationPercent: 42,
              history: history,
            ),
            GpuEngine(
              id: 'copy:0',
              kind: GpuEngineKind.copy,
              ordinal: 0,
              utilizationPercent: 8,
              history: secondHistory,
            ),
            GpuEngine(
              id: 'video-encode:0',
              kind: GpuEngineKind.videoEncode,
              ordinal: 0,
              utilizationPercent: 2,
              history: _history(5, 18),
            ),
            GpuEngine(
              id: 'video-decode:0',
              kind: GpuEngineKind.videoDecode,
              ordinal: 0,
              utilizationPercent: 16,
              history: _history(12, 32),
            ),
          ],
          dedicatedUsageHistoryPercent: _history(18, 44),
          sharedUsageHistoryPercent: _history(8, 26),
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
