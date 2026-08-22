// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Windows NT 任务管理器';

  @override
  String get runTitle => '运行';

  @override
  String get runPrompt => 'Windows 将根据你所输入的名称，为你打开相应的程序、文件夹、文档或 Internet 资源。';

  @override
  String get runCommandRequired => '请输入程序、文件夹、文档或 Internet 资源的名称。';

  @override
  String get applicationsPageTitle => '应用程序';

  @override
  String get processesPageTitle => '进程';

  @override
  String get performancePageTitle => '性能';

  @override
  String get cpuPageTitle => 'CPU';

  @override
  String get gpuPageTitle => 'GPU';

  @override
  String get networkingPageTitle => '网络';

  @override
  String get usersPageTitle => '用户';

  @override
  String get taskManagerDisabled => '任务管理器已被管理员停用。';

  @override
  String get warningTitle => '任务管理器警告';

  @override
  String get priorityChangeWarning =>
      '警告: 更改此进程的优先级类别可能会导致意外结果，包括系统不稳定。是否确实要更改该进程的优先级类别？';

  @override
  String get killProcessWarning =>
      '警告: 终止进程可能会导致意外结果，包括数据丢失和系统不稳定。在进程被终止前，它将没有机会保存其状态或数据。是否确实要终止该进程？';

  @override
  String get debugProcessWarning => '警告: 调试此进程可能会导致数据丢失。是否确实要附加调试器？';

  @override
  String get invalidOptionTitle => '无效选项';

  @override
  String get noAffinityMaskMessage => '该进程必须至少与一个处理器相关联。';

  @override
  String get unableToTerminateProcess => '无法终止进程';

  @override
  String get unableToAttachDebugger => '无法附加调试器';

  @override
  String get unableToChangePriority => '无法更改优先级';

  @override
  String get unableToSetAffinity => '无法完成该操作。\n\n';

  @override
  String get formatProcesses => '进程: %d';

  @override
  String get formatCpuUsage => 'CPU 使用率: %d%%';

  @override
  String get formatMemoryUsage => '内存使用: %dK / %dK';

  @override
  String get formatCpuNumber => 'CPU %d';

  @override
  String get totalCpu => 'CPU 总计';

  @override
  String get kernelCpu => '内核 CPU';

  @override
  String get cpuLoading => '正在加载 CPU 诊断信息...';

  @override
  String get cpuLoadingDetails => 'CPU 基础信息已就绪，正在加载性能与固件详情...';

  @override
  String get cpuPartialDetails => '部分 CPU 详情不可用。';

  @override
  String get cpuUnavailable => 'CPU 拓扑信息不可用。';

  @override
  String get cpuRefreshFailed => 'CPU 诊断数据更新失败。';

  @override
  String get cpuRefreshFailedStale => 'CPU 诊断数据更新失败；当前显示上次成功结果。';

  @override
  String get cpuCurrentState => '当前状态';

  @override
  String get cpuSystemDiagnostics => '系统诊断';

  @override
  String get cpuTopologyFeatures => '拓扑与功能';

  @override
  String get cpuHardwareCache => '硬件与缓存';

  @override
  String get cpuAverageFrequency => '平均频率';

  @override
  String get cpuFrequencyRange => '频率范围';

  @override
  String get cpuUserTime => '用户';

  @override
  String get cpuKernelTime => '内核';

  @override
  String get cpuDpcTime => 'DPC';

  @override
  String get cpuInterruptTime => '中断';

  @override
  String get cpuInterruptsPerSecond => '中断数/秒';

  @override
  String get cpuUptime => '运行时间';

  @override
  String get cpuProcessorQueueLength => '处理器队列';

  @override
  String get cpuContextSwitchesPerSecond => '上下文切换/秒';

  @override
  String get cpuSystemCallsPerSecond => '系统调用/秒';

  @override
  String get cpuPackages => '处理器封装';

  @override
  String get cpuNumaNodes => 'NUMA 节点';

  @override
  String get cpuGroups => '处理器组';

  @override
  String get cpuDies => '晶粒';

  @override
  String get cpuModules => '模块';

  @override
  String get cpuPhysicalCores => '物理核心';

  @override
  String get cpuLogicalProcessors => '逻辑处理器';

  @override
  String get cpuCoreClasses => '核心等级';

  @override
  String get cpuSmtCores => 'SMT 核心';

  @override
  String get cpuThreadsPerCore => '每核线程';

  @override
  String get cpuVirtualization => '虚拟化';

  @override
  String get cpuSlat => '二级地址转换';

  @override
  String get cpuManufacturer => '制造商';

  @override
  String get cpuSocket => '插槽';

  @override
  String get cpuProcessorId => '处理器 ID';

  @override
  String get cpuArchitectureWidth => '架构 / 位宽';

  @override
  String get cpuFamilyLevel => '系列 / 级别';

  @override
  String get cpuRevisionStepping => '修订 / 步进';

  @override
  String get cpuFirmwareMaxFrequency => '固件最高频率';

  @override
  String get cpuIsaFeatures => '指令集功能';

  @override
  String get cpuCacheL1Data => 'L1 数据缓存';

  @override
  String get cpuCacheL1Instruction => 'L1 指令缓存';

  @override
  String get cpuCacheL2 => 'L2 缓存';

  @override
  String get cpuCacheL3 => 'L3 缓存';

  @override
  String get cpuUniformClass => '同构';

  @override
  String get cpuYes => '是';

  @override
  String get cpuNo => '否';

  @override
  String get cpuFullyAssociative => '全相联';

  @override
  String get cpuSockets => '个插槽';

  @override
  String get gpuLoading => '正在加载 GPU 数据...';

  @override
  String get gpuLoadingPerformance => 'GPU 基础信息已就绪，正在加载性能数据...';

  @override
  String get gpuLoadingDetails => 'GPU 性能数据已就绪，正在加载硬件详情...';

  @override
  String get gpuPartialDetails => '部分 GPU 详情不可用。';

  @override
  String get noHardwareGpusFound => '未找到硬件 GPU。';

  @override
  String get gpuRequiresWddm2 =>
      '未找到可用的 GPU 性能计数器。此功能需要 WDDM 2.0 或更高版本的显示驱动程序。';

  @override
  String get gpuRefreshFailed => 'GPU 数据更新失败。';

  @override
  String get gpuRefreshFailedStale => 'GPU 数据更新失败；当前显示上次成功采样。';

  @override
  String get gpuCurrentMetrics => '当前';

  @override
  String get gpuAdapterDetails => '适配器详细信息';

  @override
  String get gpuUtilization => '利用率';

  @override
  String get gpuMemory => 'GPU 内存';

  @override
  String get gpuDedicatedMemory => '专用 GPU 内存';

  @override
  String get gpuSharedMemory => '共享 GPU 内存';

  @override
  String get gpuDeviceLocalMemory => '设备本地 GPU 内存';

  @override
  String get gpuSharedSystemMemory => '共享系统内存';

  @override
  String get gpuTemperature => '温度';

  @override
  String get gpuDriverVersion => '驱动程序版本';

  @override
  String get gpuDriverDate => '驱动程序日期';

  @override
  String get gpuDirectXVersion => 'DirectX 版本';

  @override
  String get gpuPhysicalLocation => '物理位置';

  @override
  String get gpuHardwareReservedMemory => '硬件保留的内存';

  @override
  String get gpuKernelDriver => '内核驱动程序';

  @override
  String get gpuKernelModuleVersion => '内核模块版本';

  @override
  String get gpuGraphicsApi => '图形 API';

  @override
  String get gpuDrmPrimaryNode => 'DRM 主设备节点';

  @override
  String get gpuDrmRenderNode => 'DRM 渲染节点';

  @override
  String get gpuPciAddress => 'PCI 地址';

  @override
  String get gpuEngineMemory => '内存';

  @override
  String get gpuEngine3D => '3D';

  @override
  String get gpuEngineCopy => '复制';

  @override
  String get gpuEngineVideoEncode => '视频编码';

  @override
  String get gpuEngineVideoDecode => '视频解码';

  @override
  String get gpuEngineCompute => '计算';

  @override
  String get gpuEngineSecurity => '安全';

  @override
  String get notAvailable => '不可用';

  @override
  String get untitledWindow => '无标题窗口';

  @override
  String get taskColumnTask => '任务';

  @override
  String get taskColumnStatus => '状态';

  @override
  String get taskColumnWinstation => '窗口站';

  @override
  String get taskColumnDesktop => '桌面';

  @override
  String get processColumnImageName => '映像名称';

  @override
  String get processColumnPid => 'PID';

  @override
  String get processColumnCpu => 'CPU';

  @override
  String get processColumnCpuTime => 'CPU 时间';

  @override
  String get processColumnMemoryUsage => '内存使用';

  @override
  String get processColumnMemoryUsageDelta => '内存变化';

  @override
  String get processColumnPageFaults => '页面错误';

  @override
  String get processColumnPageFaultsDelta => '页面错误增量';

  @override
  String get processColumnVirtualMemorySize => '虚拟内存';

  @override
  String get processColumnPagedPool => '分页池';

  @override
  String get processColumnNonPagedPool => '非分页池';

  @override
  String get processColumnBasePriority => '基本优先级';

  @override
  String get processColumnHandleCount => '句柄数';

  @override
  String get processColumnThreadCount => '线程数';

  @override
  String get processColumnSessionId => '会话 ID';

  @override
  String get processColumnUserName => '用户名';

  @override
  String get file => '文件(&F)';

  @override
  String get options => '选项(&O)';

  @override
  String get view => '查看(&V)';

  @override
  String get windows => '窗口(&W)';

  @override
  String get help => '帮助(&H)';

  @override
  String get updateSpeed => '更新速度(&U)';

  @override
  String get cpuHistory => 'CPU 历史记录(&C)';

  @override
  String get newTaskMenu => '运行(&R)...';

  @override
  String get newTaskButton => '运行(&R)...';

  @override
  String get exitTaskManager => '退出任务管理器(&X)';

  @override
  String get alwaysOnTop => '总在最前(&A)';

  @override
  String get minimizeOnUse => '使用后最小化(&M)';

  @override
  String get confirmations => '确认提示(&C)';

  @override
  String get hideWhenMinimized => '最小化时隐藏(&H)';

  @override
  String get refreshNow => '立即刷新(&R)';

  @override
  String get high => '高(&H)';

  @override
  String get normal => '正常(&N)';

  @override
  String get low => '低(&L)';

  @override
  String get paused => '已暂停(&P)';

  @override
  String get largeIcons => '大图标(&G)';

  @override
  String get smallIcons => '小图标(&M)';

  @override
  String get details => '详细信息(&D)';

  @override
  String get tileHorizontally => '横向平铺(&H)';

  @override
  String get tileVertically => '纵向平铺(&V)';

  @override
  String get minimize => '最小化(&M)';

  @override
  String get maximize => '最大化(&X)';

  @override
  String get cascade => '层叠(&C)';

  @override
  String get bringToFront => '切换到前台(&B)';

  @override
  String get helpTopics => '任务管理器帮助主题(&H)';

  @override
  String get helpOpenFailed => '无法打开任务管理器帮助。';

  @override
  String get diagnosticLogs => '诊断日志(&D)...';

  @override
  String get diagnosticLogsTitle => '诊断日志';

  @override
  String get diagnosticStatusLabel => '状态:';

  @override
  String get diagnosticSessionLabel => '会话:';

  @override
  String get diagnosticDirectoryLabel => '目录:';

  @override
  String get diagnosticDetailedCurrentSession => '记录当前会话的详细日志';

  @override
  String get diagnosticIncludeSensitive => '包含敏感信息';

  @override
  String get diagnosticCaptureMinidump => '应用程序崩溃时创建内存转储';

  @override
  String get diagnosticMinidumpPrivacy => '内存转储可能包含隐私信息。';

  @override
  String get diagnosticRestartDetailed => '重启并记录详细日志';

  @override
  String get diagnosticOpenFolder => '打开日志目录';

  @override
  String get diagnosticSaveBundle => '保存诊断包...';

  @override
  String get diagnosticLoggingActive => '日志记录已启用（%s）';

  @override
  String get diagnosticLoggingUnavailable => '文件日志不可用';

  @override
  String get diagnosticDroppedEvents => '丢弃的事件: %s';

  @override
  String get diagnosticExporting => '正在保存诊断包...';

  @override
  String get diagnosticExportSucceeded => '诊断包已成功保存。';

  @override
  String get diagnosticExportFailedTitle => '无法保存诊断包';

  @override
  String get diagnosticSensitiveExportWarning =>
      '此诊断包包含内存转储，或包含启用敏感日志期间记录的字段，可能含有隐私信息。是否继续？';

  @override
  String get diagnosticRestartFailed => '任务管理器无法重启并启用详细日志。';

  @override
  String get diagnosticOpenFolderFailed => '无法打开诊断日志目录。';

  @override
  String get aboutTaskManager => '关于任务管理器(&A)';

  @override
  String get oneGraphAllCpus => '一个图表，显示所有 CPU(&A)';

  @override
  String get oneGraphPerCpu => '每个 CPU 一个图表(&P)';

  @override
  String get selectColumnsMenu => '选择列(&C)...';

  @override
  String get selectColumnsTitle => '选择列';

  @override
  String get selectProcessColumnsDescription => '选择要在任务管理器的“进程”页上显示的列。';

  @override
  String get showKernelTimes => '显示内核时间(&K)';

  @override
  String get restoreTaskManager => '还原任务管理器(&R)';

  @override
  String get endProcess => '结束进程(&E)';

  @override
  String get endProcessTree => '结束进程树(&T)';

  @override
  String get openFileLocation => '打开文件位置(&L)';

  @override
  String get debug => '调试(&D)';

  @override
  String get setPriority => '设置优先级(&P)';

  @override
  String get realtime => '实时(&R)';

  @override
  String get aboveNormal => '高于正常(&A)';

  @override
  String get belowNormal => '低于正常(&B)';

  @override
  String get setAffinity => '设置相关性(&A)...';

  @override
  String get switchTo => '切换到(&S)';

  @override
  String get endTask => '结束任务(&E)';

  @override
  String get goToProcess => '转到进程(&G)';

  @override
  String get disconnect => '断开(&D)';

  @override
  String get logoff => '注销(&L)';

  @override
  String get sendMessage => '发送消息(&S)...';

  @override
  String get sendMessageTitle => '发送消息';

  @override
  String get taskManager => '任务管理器';

  @override
  String get handles => '句柄';

  @override
  String get openFileHandles => '打开的文件句柄';

  @override
  String get threads => '线程';

  @override
  String get processesLabel => '进程';

  @override
  String get cpuUsageHistory => 'CPU 使用记录';

  @override
  String get cpuUsage => 'CPU 使用率';

  @override
  String get memUsage => '内存使用率';

  @override
  String get memoryUsageHistory => '内存使用记录';

  @override
  String get physicalMemoryK => '物理内存 (K)';

  @override
  String get commitChargeK => '提交使用量 (K)';

  @override
  String get kernelMemoryK => '内核内存 (K)';

  @override
  String get virtualMemoryK => '虚拟内存 (K)';

  @override
  String get totals => '总计';

  @override
  String get total => '总计';

  @override
  String get available => '可用';

  @override
  String get fileCache => '文件缓存';

  @override
  String get paged => '分页';

  @override
  String get nonpaged => '非分页';

  @override
  String get limit => '限制';

  @override
  String get peak => '峰值';

  @override
  String get committed => '已提交';

  @override
  String get commitLimit => '提交限制';

  @override
  String get swapUsed => '交换区已用';

  @override
  String get slab => 'Slab';

  @override
  String get kernelStack => '内核栈';

  @override
  String get pageTables => '页表';

  @override
  String get noActiveNetworkAdaptersFound => '未找到活动的网络适配器。';

  @override
  String get ok => '确定';

  @override
  String get cancel => '取消';

  @override
  String get close => '关闭';

  @override
  String get imageName => '映像名称(&I)';

  @override
  String get pidProcessIdentifier => 'PID（进程标识符）';

  @override
  String get userName => '用户名';

  @override
  String get sessionId => '会话 ID';

  @override
  String get cpuTime => 'CPU 时间';

  @override
  String get memoryUsage => '内存使用';

  @override
  String get memoryUsageDelta => '内存使用变化量';

  @override
  String get pageFaults => '页面错误';

  @override
  String get pageFaultsDelta => '页面错误变化量';

  @override
  String get virtualMemorySize => '虚拟内存大小';

  @override
  String get pagedPool => '分页池';

  @override
  String get nonPagedPool => '非分页池';

  @override
  String get basePriority => '基本优先级';

  @override
  String get handleCount => '句柄数';

  @override
  String get threadCount => '线程数';

  @override
  String get processorAffinity => '处理器相关性';

  @override
  String get processors => '处理器';

  @override
  String get processorAffinityDescription => '控制该进程可在所选处理器组中的哪些 CPU 上执行。';

  @override
  String get messageTitleLabel => '消息标题(&M):';

  @override
  String get messageLabel => '消息内容(&S):';

  @override
  String get showFullAccountName => '显示完整帐户名(&S)';

  @override
  String get user => '用户';

  @override
  String get status => '状态';

  @override
  String get clientName => '客户端名称';

  @override
  String get session => '会话';

  @override
  String get adapter => '适配器';

  @override
  String get networkUtilization => '网络利用率';

  @override
  String get linkSpeed => '链路速度';

  @override
  String get state => '状态';

  @override
  String get bytesSent => '已发送字节';

  @override
  String get bytesReceived => '已接收字节';

  @override
  String get bytesTotal => '总字节数';

  @override
  String get connected => '已连接';

  @override
  String get disconnected => '已断开';

  @override
  String get connecting => '正在连接';

  @override
  String get disconnecting => '正在断开';

  @override
  String get hardwareMissing => '硬件缺失';

  @override
  String get hardwareDisabled => '硬件已禁用';

  @override
  String get hardwareMalfunction => '硬件故障';

  @override
  String get unknown => '未知';

  @override
  String get active => '活动';

  @override
  String get connectQuery => '连接查询';

  @override
  String get shadow => '远程控制';

  @override
  String get idle => '空闲';

  @override
  String get listening => '侦听';

  @override
  String get reset => '重置';

  @override
  String get down => '已关闭';

  @override
  String get init => '初始化';

  @override
  String get bitness32Suffix => '(32位)';

  @override
  String get notResponding => '未响应';

  @override
  String get running => '正在运行';

  @override
  String get messageCouldNotBeSent => '无法发送该消息。';

  @override
  String get unableToOpenFileLocation => '无法打开文件位置';

  @override
  String get killProcessTreePrompt =>
      '此操作将尝试终止该进程，以及所有由它直接或间接启动的进程。\n\n以这种方式强制终止进程可能会导致数据丢失和系统不稳定。\n\n是否确实要继续？';

  @override
  String get killProcessTreeFailed => '无法完全结束进程树';

  @override
  String get killProcessTreeFailedBody => '此进程树中的一个或多个进程无法结束。该操作未能完全成功。';

  @override
  String get confirmLogoffSelectedUsers => '确实要注销所选用户吗？';

  @override
  String get confirmDisconnectSelectedUsers => '确实要断开所选用户吗？';

  @override
  String get selectedUserCouldNotBeLoggedOff => '无法注销所选用户。';

  @override
  String get selectedUserCouldNotBeDisconnected => '无法断开所选用户。';

  @override
  String get win32ErrorPrefix => 'Win32 错误:';

  @override
  String get processColumnFileDescriptorCount => '文件描述符';

  @override
  String get processColumnNice => 'nice 值';

  @override
  String get processColumnCgroup => '控制组';

  @override
  String get setNice => '设置 nice 值(&N)...';

  @override
  String get setNiceTitle => '设置 nice 值';

  @override
  String get niceValueLabel => 'nice 值(&N):';

  @override
  String get niceValueDescription => '请输入 -20（最高优先级）到 19（最低优先级）之间的 nice 值。';

  @override
  String get invalidNiceValue => 'nice 值必须是 -20 到 19 之间的整数。';

  @override
  String get niceChangeWarning => '更改进程优先级可能影响系统稳定性。确实要更改 nice 值吗？';
}

/// The translations for Chinese, as used in Hong Kong (`zh_HK`).
class AppLocalizationsZhHk extends AppLocalizationsZh {
  AppLocalizationsZhHk() : super('zh_HK');

  @override
  String get appTitle => 'Windows NT 工作管理員';

  @override
  String get runTitle => '執行';

  @override
  String get runPrompt => 'Windows 將根據你所輸入的名稱，為你開啟相應的程式、資料夾、文件或 Internet 資源。';

  @override
  String get runCommandRequired => '請輸入程式、資料夾、文件或 Internet 資源的名稱。';

  @override
  String get applicationsPageTitle => '應用程式';

  @override
  String get processesPageTitle => '處理程序';

  @override
  String get performancePageTitle => '效能';

  @override
  String get cpuPageTitle => 'CPU';

  @override
  String get gpuPageTitle => 'GPU';

  @override
  String get networkingPageTitle => '網絡';

  @override
  String get usersPageTitle => '使用者';

  @override
  String get taskManagerDisabled => '工作管理員已被系統管理員停用。';

  @override
  String get warningTitle => '工作管理員警告';

  @override
  String get priorityChangeWarning =>
      '警告: 變更此處理程序的優先順序類別可能會造成非預期結果，包括系統不穩定。確定要變更此處理程序的優先順序類別嗎？';

  @override
  String get killProcessWarning =>
      '警告: 終止處理程序可能會造成非預期結果，包括資料遺失與系統不穩定。在處理程序被終止前，它將沒有機會儲存其狀態或資料。確定要終止此處理程序嗎？';

  @override
  String get debugProcessWarning => '警告: 偵錯此處理程序可能導致資料遺失。確定要附加偵錯工具嗎？';

  @override
  String get invalidOptionTitle => '無效選項';

  @override
  String get noAffinityMaskMessage => '此處理程序至少必須與一個處理器相依。';

  @override
  String get unableToTerminateProcess => '無法終止處理程序';

  @override
  String get unableToAttachDebugger => '無法附加偵錯工具';

  @override
  String get unableToChangePriority => '無法變更優先順序';

  @override
  String get unableToSetAffinity => '無法完成此操作。\n\n';

  @override
  String get formatProcesses => '處理程序: %d';

  @override
  String get formatCpuUsage => 'CPU 使用率: %d%%';

  @override
  String get formatMemoryUsage => '記憶體使用量: %dK / %dK';

  @override
  String get formatCpuNumber => 'CPU %d';

  @override
  String get totalCpu => 'CPU 總計';

  @override
  String get kernelCpu => '核心 CPU';

  @override
  String get cpuLoading => '正在載入 CPU 診斷資訊...';

  @override
  String get cpuLoadingDetails => 'CPU 基礎資訊已就緒，正在載入效能與韌體詳細資料...';

  @override
  String get cpuPartialDetails => '部分 CPU 詳細資料無法使用。';

  @override
  String get cpuUnavailable => 'CPU 拓撲資訊無法使用。';

  @override
  String get cpuRefreshFailed => 'CPU 診斷資料更新失敗。';

  @override
  String get cpuRefreshFailedStale => 'CPU 診斷資料更新失敗；目前顯示上次成功結果。';

  @override
  String get cpuCurrentState => '目前狀態';

  @override
  String get cpuSystemDiagnostics => '系統診斷';

  @override
  String get cpuTopologyFeatures => '拓撲與功能';

  @override
  String get cpuHardwareCache => '硬體與快取';

  @override
  String get cpuAverageFrequency => '平均頻率';

  @override
  String get cpuFrequencyRange => '頻率範圍';

  @override
  String get cpuUserTime => '使用者';

  @override
  String get cpuKernelTime => '核心';

  @override
  String get cpuDpcTime => 'DPC';

  @override
  String get cpuInterruptTime => '中斷';

  @override
  String get cpuInterruptsPerSecond => '中斷數/秒';

  @override
  String get cpuUptime => '執行時間';

  @override
  String get cpuProcessorQueueLength => '處理器佇列';

  @override
  String get cpuContextSwitchesPerSecond => '內容切換/秒';

  @override
  String get cpuSystemCallsPerSecond => '系統呼叫/秒';

  @override
  String get cpuPackages => '處理器封裝';

  @override
  String get cpuNumaNodes => 'NUMA 節點';

  @override
  String get cpuGroups => '處理器群組';

  @override
  String get cpuDies => '晶粒';

  @override
  String get cpuModules => '模組';

  @override
  String get cpuPhysicalCores => '實體核心';

  @override
  String get cpuLogicalProcessors => '邏輯處理器';

  @override
  String get cpuCoreClasses => '核心等級';

  @override
  String get cpuSmtCores => 'SMT 核心';

  @override
  String get cpuThreadsPerCore => '每核心執行緒';

  @override
  String get cpuVirtualization => '虛擬化';

  @override
  String get cpuSlat => '第二層位址轉譯';

  @override
  String get cpuManufacturer => '製造商';

  @override
  String get cpuSocket => '插槽';

  @override
  String get cpuProcessorId => '處理器 ID';

  @override
  String get cpuArchitectureWidth => '架構 / 位元寬度';

  @override
  String get cpuFamilyLevel => '系列 / 層級';

  @override
  String get cpuRevisionStepping => '修訂 / 步進';

  @override
  String get cpuFirmwareMaxFrequency => '韌體最高頻率';

  @override
  String get cpuIsaFeatures => '指令集功能';

  @override
  String get cpuCacheL1Data => 'L1 資料快取';

  @override
  String get cpuCacheL1Instruction => 'L1 指令快取';

  @override
  String get cpuCacheL2 => 'L2 快取';

  @override
  String get cpuCacheL3 => 'L3 快取';

  @override
  String get cpuUniformClass => '同質';

  @override
  String get cpuYes => '是';

  @override
  String get cpuNo => '否';

  @override
  String get cpuFullyAssociative => '全相聯';

  @override
  String get cpuSockets => '個插槽';

  @override
  String get gpuLoading => '正在載入 GPU 資料...';

  @override
  String get gpuLoadingPerformance => 'GPU 基礎資訊已就緒，正在載入效能資料...';

  @override
  String get gpuLoadingDetails => 'GPU 效能資料已就緒，正在載入硬體詳細資料...';

  @override
  String get gpuPartialDetails => '部分 GPU 詳細資料無法使用。';

  @override
  String get noHardwareGpusFound => '找不到硬體 GPU。';

  @override
  String get gpuRequiresWddm2 =>
      '找不到可用的 GPU 效能計數器。此功能需要 WDDM 2.0 或更新版本的顯示驅動程式。';

  @override
  String get gpuRefreshFailed => 'GPU 資料更新失敗。';

  @override
  String get gpuRefreshFailedStale => 'GPU 資料更新失敗；目前顯示上次成功取樣。';

  @override
  String get gpuCurrentMetrics => '目前';

  @override
  String get gpuAdapterDetails => '顯示卡詳細資料';

  @override
  String get gpuUtilization => '使用率';

  @override
  String get gpuMemory => 'GPU 記憶體';

  @override
  String get gpuDedicatedMemory => '專用 GPU 記憶體';

  @override
  String get gpuSharedMemory => '共用 GPU 記憶體';

  @override
  String get gpuDeviceLocalMemory => '裝置本地 GPU 記憶體';

  @override
  String get gpuSharedSystemMemory => '共享系統記憶體';

  @override
  String get gpuTemperature => '溫度';

  @override
  String get gpuDriverVersion => '驅動程式版本';

  @override
  String get gpuDriverDate => '驅動程式日期';

  @override
  String get gpuDirectXVersion => 'DirectX 版本';

  @override
  String get gpuPhysicalLocation => '實體位置';

  @override
  String get gpuHardwareReservedMemory => '硬體保留記憶體';

  @override
  String get gpuKernelDriver => '核心驅動程式';

  @override
  String get gpuKernelModuleVersion => '核心模組版本';

  @override
  String get gpuGraphicsApi => '圖形 API';

  @override
  String get gpuDrmPrimaryNode => 'DRM 主要裝置節點';

  @override
  String get gpuDrmRenderNode => 'DRM 轉譯節點';

  @override
  String get gpuPciAddress => 'PCI 位址';

  @override
  String get gpuEngineMemory => '記憶體';

  @override
  String get gpuEngine3D => '3D';

  @override
  String get gpuEngineCopy => '複製';

  @override
  String get gpuEngineVideoEncode => '視訊編碼';

  @override
  String get gpuEngineVideoDecode => '視訊解碼';

  @override
  String get gpuEngineCompute => '計算';

  @override
  String get gpuEngineSecurity => '安全性';

  @override
  String get notAvailable => '無法使用';

  @override
  String get untitledWindow => '未命名視窗';

  @override
  String get taskColumnTask => '工作';

  @override
  String get taskColumnStatus => '狀態';

  @override
  String get taskColumnWinstation => '視窗站';

  @override
  String get taskColumnDesktop => '桌面';

  @override
  String get processColumnImageName => '映像名稱';

  @override
  String get processColumnPid => 'PID';

  @override
  String get processColumnCpu => 'CPU';

  @override
  String get processColumnCpuTime => 'CPU 時間';

  @override
  String get processColumnMemoryUsage => '記憶體使用量';

  @override
  String get processColumnMemoryUsageDelta => '記憶體變化量';

  @override
  String get processColumnPageFaults => '頁面錯誤';

  @override
  String get processColumnPageFaultsDelta => '頁面錯誤變化量';

  @override
  String get processColumnVirtualMemorySize => '虛擬記憶體';

  @override
  String get processColumnPagedPool => '分頁集區';

  @override
  String get processColumnNonPagedPool => '非分頁集區';

  @override
  String get processColumnBasePriority => '基本優先順序';

  @override
  String get processColumnHandleCount => '控制代碼數';

  @override
  String get processColumnThreadCount => '執行緒數';

  @override
  String get processColumnSessionId => '工作階段 ID';

  @override
  String get processColumnUserName => '使用者名稱';

  @override
  String get file => '檔案(&F)';

  @override
  String get options => '選項(&O)';

  @override
  String get view => '檢視(&V)';

  @override
  String get windows => '視窗(&W)';

  @override
  String get help => '說明(&H)';

  @override
  String get updateSpeed => '更新速度(&U)';

  @override
  String get cpuHistory => 'CPU 歷程記錄(&C)';

  @override
  String get newTaskMenu => '執行(&R)...';

  @override
  String get newTaskButton => '執行(&R)...';

  @override
  String get exitTaskManager => '結束工作管理員(&X)';

  @override
  String get alwaysOnTop => '永遠在最上層(&A)';

  @override
  String get minimizeOnUse => '使用後最小化(&M)';

  @override
  String get confirmations => '確認(&C)';

  @override
  String get hideWhenMinimized => '最小化時隱藏(&H)';

  @override
  String get refreshNow => '立即重新整理(&R)';

  @override
  String get high => '高(&H)';

  @override
  String get normal => '正常(&N)';

  @override
  String get low => '低(&L)';

  @override
  String get paused => '暫停(&P)';

  @override
  String get largeIcons => '大圖示(&G)';

  @override
  String get smallIcons => '小圖示(&M)';

  @override
  String get details => '詳細資料(&D)';

  @override
  String get tileHorizontally => '水平並排(&H)';

  @override
  String get tileVertically => '垂直並排(&V)';

  @override
  String get minimize => '最小化(&M)';

  @override
  String get maximize => '最大化(&X)';

  @override
  String get cascade => '重疊顯示(&C)';

  @override
  String get bringToFront => '帶到前景(&B)';

  @override
  String get helpTopics => '工作管理員說明主題(&H)';

  @override
  String get helpOpenFailed => '無法開啟工作管理員說明。';

  @override
  String get diagnosticLogs => '診斷記錄(&D)...';

  @override
  String get diagnosticLogsTitle => '診斷記錄';

  @override
  String get diagnosticStatusLabel => '狀態:';

  @override
  String get diagnosticSessionLabel => '工作階段:';

  @override
  String get diagnosticDirectoryLabel => '目錄:';

  @override
  String get diagnosticDetailedCurrentSession => '記錄目前工作階段的詳細記錄';

  @override
  String get diagnosticIncludeSensitive => '包含敏感資訊';

  @override
  String get diagnosticCaptureMinidump => '應用程式當機時建立記憶體傾印';

  @override
  String get diagnosticMinidumpPrivacy => '記憶體傾印可能包含私人資訊。';

  @override
  String get diagnosticRestartDetailed => '重新啟動並記錄詳細記錄';

  @override
  String get diagnosticOpenFolder => '開啟記錄目錄';

  @override
  String get diagnosticSaveBundle => '儲存診斷套件...';

  @override
  String get diagnosticLoggingActive => '記錄已啟用（%s）';

  @override
  String get diagnosticLoggingUnavailable => '檔案記錄無法使用';

  @override
  String get diagnosticDroppedEvents => '已捨棄的事件: %s';

  @override
  String get diagnosticExporting => '正在儲存診斷套件...';

  @override
  String get diagnosticExportSucceeded => '診斷套件已成功儲存。';

  @override
  String get diagnosticExportFailedTitle => '無法儲存診斷套件';

  @override
  String get diagnosticSensitiveExportWarning =>
      '此套件包含記憶體傾印，或包含啟用敏感記錄期間所記錄的欄位，可能含有私人資訊。是否繼續？';

  @override
  String get diagnosticRestartFailed => '工作管理員無法重新啟動並啟用詳細記錄。';

  @override
  String get diagnosticOpenFolderFailed => '無法開啟診斷記錄目錄。';

  @override
  String get aboutTaskManager => '關於工作管理員(&A)';

  @override
  String get oneGraphAllCpus => '一個圖表，顯示所有 CPU(&A)';

  @override
  String get oneGraphPerCpu => '每個 CPU 一個圖表(&P)';

  @override
  String get selectColumnsMenu => '選擇欄位(&C)...';

  @override
  String get selectColumnsTitle => '選擇欄位';

  @override
  String get selectProcessColumnsDescription => '選擇要在工作管理員的「處理程序」頁面上顯示的欄位。';

  @override
  String get showKernelTimes => '顯示核心時間(&K)';

  @override
  String get restoreTaskManager => '還原工作管理員(&R)';

  @override
  String get endProcess => '結束處理程序(&E)';

  @override
  String get endProcessTree => '結束處理程序樹(&T)';

  @override
  String get openFileLocation => '開啟檔案位置(&L)';

  @override
  String get debug => '偵錯(&D)';

  @override
  String get setPriority => '設定優先順序(&P)';

  @override
  String get realtime => '即時(&R)';

  @override
  String get aboveNormal => '高於正常(&A)';

  @override
  String get belowNormal => '低於正常(&B)';

  @override
  String get setAffinity => '設定相依性(&A)...';

  @override
  String get switchTo => '切換至(&S)';

  @override
  String get endTask => '結束工作(&E)';

  @override
  String get goToProcess => '移至處理程序(&G)';

  @override
  String get disconnect => '中斷連線(&D)';

  @override
  String get logoff => '登出(&L)';

  @override
  String get sendMessage => '傳送訊息(&S)...';

  @override
  String get sendMessageTitle => '傳送訊息';

  @override
  String get taskManager => '工作管理員';

  @override
  String get handles => '控制代碼';

  @override
  String get openFileHandles => '開啟的檔案控制代碼';

  @override
  String get threads => '執行緒';

  @override
  String get processesLabel => '處理程序';

  @override
  String get cpuUsageHistory => 'CPU 使用記錄';

  @override
  String get cpuUsage => 'CPU 使用率';

  @override
  String get memUsage => '記憶體使用量';

  @override
  String get memoryUsageHistory => '記憶體使用記錄';

  @override
  String get physicalMemoryK => '實體記憶體 (K)';

  @override
  String get commitChargeK => '認可的記憶體 (K)';

  @override
  String get kernelMemoryK => '核心記憶體 (K)';

  @override
  String get virtualMemoryK => '虛擬記憶體 (K)';

  @override
  String get totals => '總計';

  @override
  String get total => '總計';

  @override
  String get available => '可用';

  @override
  String get fileCache => '檔案快取';

  @override
  String get paged => '分頁';

  @override
  String get nonpaged => '非分頁';

  @override
  String get limit => '限制';

  @override
  String get peak => '峰值';

  @override
  String get committed => '已認可';

  @override
  String get commitLimit => '認可上限';

  @override
  String get swapUsed => '交換空間已用';

  @override
  String get slab => 'Slab';

  @override
  String get kernelStack => '核心堆疊';

  @override
  String get pageTables => '頁表';

  @override
  String get noActiveNetworkAdaptersFound => '找不到作用中的網絡介面卡。';

  @override
  String get ok => '確定';

  @override
  String get cancel => '取消';

  @override
  String get close => '關閉';

  @override
  String get imageName => '映像名稱(&I)';

  @override
  String get pidProcessIdentifier => 'PID（處理程序識別碼）';

  @override
  String get userName => '使用者名稱';

  @override
  String get sessionId => '工作階段 ID';

  @override
  String get cpuTime => 'CPU 時間';

  @override
  String get memoryUsage => '記憶體使用量';

  @override
  String get memoryUsageDelta => '記憶體使用量變化';

  @override
  String get pageFaults => '頁面錯誤';

  @override
  String get pageFaultsDelta => '頁面錯誤變化量';

  @override
  String get virtualMemorySize => '虛擬記憶體大小';

  @override
  String get pagedPool => '分頁集區';

  @override
  String get nonPagedPool => '非分頁集區';

  @override
  String get basePriority => '基本優先順序';

  @override
  String get handleCount => '控制代碼數';

  @override
  String get threadCount => '執行緒數';

  @override
  String get processorAffinity => '處理器相依性';

  @override
  String get processors => '處理器';

  @override
  String get processorAffinityDescription => '控制此處理程序可在所選處理器群組中的哪些 CPU 上執行。';

  @override
  String get messageTitleLabel => '訊息標題(&M):';

  @override
  String get messageLabel => '訊息內容(&S):';

  @override
  String get showFullAccountName => '顯示完整帳戶名稱(&S)';

  @override
  String get user => '使用者';

  @override
  String get status => '狀態';

  @override
  String get clientName => '用戶端名稱';

  @override
  String get session => '工作階段';

  @override
  String get adapter => '介面卡';

  @override
  String get networkUtilization => '網絡使用率';

  @override
  String get linkSpeed => '連線速度';

  @override
  String get state => '狀態';

  @override
  String get bytesSent => '已傳送位元組';

  @override
  String get bytesReceived => '已接收位元組';

  @override
  String get bytesTotal => '位元組總數';

  @override
  String get connected => '已連線';

  @override
  String get disconnected => '已中斷';

  @override
  String get connecting => '正在連線';

  @override
  String get disconnecting => '正在中斷連線';

  @override
  String get hardwareMissing => '硬體遺失';

  @override
  String get hardwareDisabled => '硬體已停用';

  @override
  String get hardwareMalfunction => '硬體故障';

  @override
  String get unknown => '未知';

  @override
  String get active => '使用中';

  @override
  String get connectQuery => '連線查詢';

  @override
  String get shadow => '遠端控制';

  @override
  String get idle => '閒置';

  @override
  String get listening => '接聽';

  @override
  String get reset => '重設';

  @override
  String get down => '已停止';

  @override
  String get init => '初始化';

  @override
  String get bitness32Suffix => '(32位元)';

  @override
  String get notResponding => '沒有回應';

  @override
  String get running => '執行中';

  @override
  String get messageCouldNotBeSent => '無法傳送訊息。';

  @override
  String get unableToOpenFileLocation => '無法開啟檔案位置';

  @override
  String get killProcessTreePrompt =>
      '此操作會嘗試終止此處理程序，以及所有由它直接或間接啟動的處理程序。\n\n以這種方式強制終止處理程序可能會造成資料遺失與系統不穩定。\n\n確定要繼續嗎？';

  @override
  String get killProcessTreeFailed => '無法完全結束處理程序樹';

  @override
  String get killProcessTreeFailedBody => '此處理程序樹中的一或多個處理程序無法結束。該操作未能完全成功。';

  @override
  String get confirmLogoffSelectedUsers => '確定要將選取的使用者登出嗎？';

  @override
  String get confirmDisconnectSelectedUsers => '確定要中斷選取的使用者嗎？';

  @override
  String get selectedUserCouldNotBeLoggedOff => '無法將選取的使用者登出。';

  @override
  String get selectedUserCouldNotBeDisconnected => '無法中斷選取的使用者。';

  @override
  String get win32ErrorPrefix => 'Win32 錯誤:';

  @override
  String get processColumnFileDescriptorCount => '檔案描述元';

  @override
  String get processColumnNice => 'nice 值';

  @override
  String get processColumnCgroup => '控制群組';

  @override
  String get setNice => '設定 nice 值(&N)...';

  @override
  String get setNiceTitle => '設定 nice 值';

  @override
  String get niceValueLabel => 'nice 值(&N):';

  @override
  String get niceValueDescription => '請輸入 -20（最高優先順序）到 19（最低優先順序）之間的 nice 值。';

  @override
  String get invalidNiceValue => 'nice 值必須是 -20 到 19 之間的整數。';

  @override
  String get niceChangeWarning => '變更處理程序優先順序可能會影響系統穩定性。確定要變更 nice 值嗎？';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => 'Windows NT 工作管理員';

  @override
  String get runTitle => '執行';

  @override
  String get runPrompt => 'Windows 將根據你所輸入的名稱，為你開啟相應的程式、資料夾、文件或 Internet 資源。';

  @override
  String get runCommandRequired => '請輸入程式、資料夾、文件或 Internet 資源的名稱。';

  @override
  String get applicationsPageTitle => '應用程式';

  @override
  String get processesPageTitle => '處理程序';

  @override
  String get performancePageTitle => '效能';

  @override
  String get cpuPageTitle => 'CPU';

  @override
  String get gpuPageTitle => 'GPU';

  @override
  String get networkingPageTitle => '網路';

  @override
  String get usersPageTitle => '使用者';

  @override
  String get taskManagerDisabled => '工作管理員已被系統管理員停用。';

  @override
  String get warningTitle => '工作管理員警告';

  @override
  String get priorityChangeWarning =>
      '警告: 變更此處理程序的優先順序類別可能會造成非預期結果，包括系統不穩定。確定要變更此處理程序的優先順序類別嗎？';

  @override
  String get killProcessWarning =>
      '警告: 終止處理程序可能會造成非預期結果，包括資料遺失與系統不穩定。在處理程序被終止前，它將沒有機會儲存其狀態或資料。確定要終止此處理程序嗎？';

  @override
  String get debugProcessWarning => '警告: 偵錯此處理程序可能導致資料遺失。確定要附加偵錯工具嗎？';

  @override
  String get invalidOptionTitle => '無效選項';

  @override
  String get noAffinityMaskMessage => '此處理程序至少必須與一個處理器相依。';

  @override
  String get unableToTerminateProcess => '無法終止處理程序';

  @override
  String get unableToAttachDebugger => '無法附加偵錯工具';

  @override
  String get unableToChangePriority => '無法變更優先順序';

  @override
  String get unableToSetAffinity => '無法完成此操作。\n\n';

  @override
  String get formatProcesses => '處理程序: %d';

  @override
  String get formatCpuUsage => 'CPU 使用率: %d%%';

  @override
  String get formatMemoryUsage => '記憶體使用量: %dK / %dK';

  @override
  String get formatCpuNumber => 'CPU %d';

  @override
  String get totalCpu => 'CPU 總計';

  @override
  String get kernelCpu => '核心 CPU';

  @override
  String get cpuLoading => '正在載入 CPU 診斷資訊...';

  @override
  String get cpuLoadingDetails => 'CPU 基礎資訊已就緒，正在載入效能與韌體詳細資料...';

  @override
  String get cpuPartialDetails => '部分 CPU 詳細資料無法使用。';

  @override
  String get cpuUnavailable => 'CPU 拓撲資訊無法使用。';

  @override
  String get cpuRefreshFailed => 'CPU 診斷資料更新失敗。';

  @override
  String get cpuRefreshFailedStale => 'CPU 診斷資料更新失敗；目前顯示上次成功結果。';

  @override
  String get cpuCurrentState => '目前狀態';

  @override
  String get cpuSystemDiagnostics => '系統診斷';

  @override
  String get cpuTopologyFeatures => '拓撲與功能';

  @override
  String get cpuHardwareCache => '硬體與快取';

  @override
  String get cpuAverageFrequency => '平均頻率';

  @override
  String get cpuFrequencyRange => '頻率範圍';

  @override
  String get cpuUserTime => '使用者';

  @override
  String get cpuKernelTime => '核心';

  @override
  String get cpuDpcTime => 'DPC';

  @override
  String get cpuInterruptTime => '中斷';

  @override
  String get cpuInterruptsPerSecond => '中斷數/秒';

  @override
  String get cpuUptime => '執行時間';

  @override
  String get cpuProcessorQueueLength => '處理器佇列';

  @override
  String get cpuContextSwitchesPerSecond => '內容切換/秒';

  @override
  String get cpuSystemCallsPerSecond => '系統呼叫/秒';

  @override
  String get cpuPackages => '處理器封裝';

  @override
  String get cpuNumaNodes => 'NUMA 節點';

  @override
  String get cpuGroups => '處理器群組';

  @override
  String get cpuDies => '晶粒';

  @override
  String get cpuModules => '模組';

  @override
  String get cpuPhysicalCores => '實體核心';

  @override
  String get cpuLogicalProcessors => '邏輯處理器';

  @override
  String get cpuCoreClasses => '核心等級';

  @override
  String get cpuSmtCores => 'SMT 核心';

  @override
  String get cpuThreadsPerCore => '每核心執行緒';

  @override
  String get cpuVirtualization => '虛擬化';

  @override
  String get cpuSlat => '第二層位址轉譯';

  @override
  String get cpuManufacturer => '製造商';

  @override
  String get cpuSocket => '插槽';

  @override
  String get cpuProcessorId => '處理器 ID';

  @override
  String get cpuArchitectureWidth => '架構 / 位元寬度';

  @override
  String get cpuFamilyLevel => '系列 / 層級';

  @override
  String get cpuRevisionStepping => '修訂 / 步進';

  @override
  String get cpuFirmwareMaxFrequency => '韌體最高頻率';

  @override
  String get cpuIsaFeatures => '指令集功能';

  @override
  String get cpuCacheL1Data => 'L1 資料快取';

  @override
  String get cpuCacheL1Instruction => 'L1 指令快取';

  @override
  String get cpuCacheL2 => 'L2 快取';

  @override
  String get cpuCacheL3 => 'L3 快取';

  @override
  String get cpuUniformClass => '同質';

  @override
  String get cpuYes => '是';

  @override
  String get cpuNo => '否';

  @override
  String get cpuFullyAssociative => '全相聯';

  @override
  String get cpuSockets => '個插槽';

  @override
  String get gpuLoading => '正在載入 GPU 資料...';

  @override
  String get gpuLoadingPerformance => 'GPU 基礎資訊已就緒，正在載入效能資料...';

  @override
  String get gpuLoadingDetails => 'GPU 效能資料已就緒，正在載入硬體詳細資料...';

  @override
  String get gpuPartialDetails => '部分 GPU 詳細資料無法使用。';

  @override
  String get noHardwareGpusFound => '找不到硬體 GPU。';

  @override
  String get gpuRequiresWddm2 =>
      '找不到可用的 GPU 效能計數器。此功能需要 WDDM 2.0 或更新版本的顯示驅動程式。';

  @override
  String get gpuRefreshFailed => 'GPU 資料更新失敗。';

  @override
  String get gpuRefreshFailedStale => 'GPU 資料更新失敗；目前顯示上次成功取樣。';

  @override
  String get gpuCurrentMetrics => '目前';

  @override
  String get gpuAdapterDetails => '顯示卡詳細資料';

  @override
  String get gpuUtilization => '使用率';

  @override
  String get gpuMemory => 'GPU 記憶體';

  @override
  String get gpuDedicatedMemory => '專用 GPU 記憶體';

  @override
  String get gpuSharedMemory => '共用 GPU 記憶體';

  @override
  String get gpuDeviceLocalMemory => '裝置本機 GPU 記憶體';

  @override
  String get gpuSharedSystemMemory => '共用系統記憶體';

  @override
  String get gpuTemperature => '溫度';

  @override
  String get gpuDriverVersion => '驅動程式版本';

  @override
  String get gpuDriverDate => '驅動程式日期';

  @override
  String get gpuDirectXVersion => 'DirectX 版本';

  @override
  String get gpuPhysicalLocation => '實體位置';

  @override
  String get gpuHardwareReservedMemory => '硬體保留記憶體';

  @override
  String get gpuKernelDriver => '核心驅動程式';

  @override
  String get gpuKernelModuleVersion => '核心模組版本';

  @override
  String get gpuGraphicsApi => '圖形 API';

  @override
  String get gpuDrmPrimaryNode => 'DRM 主要裝置節點';

  @override
  String get gpuDrmRenderNode => 'DRM 轉譯節點';

  @override
  String get gpuPciAddress => 'PCI 位址';

  @override
  String get gpuEngineMemory => '記憶體';

  @override
  String get gpuEngine3D => '3D';

  @override
  String get gpuEngineCopy => '複製';

  @override
  String get gpuEngineVideoEncode => '視訊編碼';

  @override
  String get gpuEngineVideoDecode => '視訊解碼';

  @override
  String get gpuEngineCompute => '計算';

  @override
  String get gpuEngineSecurity => '安全性';

  @override
  String get notAvailable => '無法使用';

  @override
  String get untitledWindow => '未命名視窗';

  @override
  String get taskColumnTask => '工作';

  @override
  String get taskColumnStatus => '狀態';

  @override
  String get taskColumnWinstation => '視窗站';

  @override
  String get taskColumnDesktop => '桌面';

  @override
  String get processColumnImageName => '映像名稱';

  @override
  String get processColumnPid => 'PID';

  @override
  String get processColumnCpu => 'CPU';

  @override
  String get processColumnCpuTime => 'CPU 時間';

  @override
  String get processColumnMemoryUsage => '記憶體使用量';

  @override
  String get processColumnMemoryUsageDelta => '記憶體變化量';

  @override
  String get processColumnPageFaults => '頁面錯誤';

  @override
  String get processColumnPageFaultsDelta => '頁面錯誤變化量';

  @override
  String get processColumnVirtualMemorySize => '虛擬記憶體';

  @override
  String get processColumnPagedPool => '分頁集區';

  @override
  String get processColumnNonPagedPool => '非分頁集區';

  @override
  String get processColumnBasePriority => '基本優先順序';

  @override
  String get processColumnHandleCount => '控制代碼數';

  @override
  String get processColumnThreadCount => '執行緒數';

  @override
  String get processColumnSessionId => '工作階段 ID';

  @override
  String get processColumnUserName => '使用者名稱';

  @override
  String get file => '檔案(&F)';

  @override
  String get options => '選項(&O)';

  @override
  String get view => '檢視(&V)';

  @override
  String get windows => '視窗(&W)';

  @override
  String get help => '說明(&H)';

  @override
  String get updateSpeed => '更新速度(&U)';

  @override
  String get cpuHistory => 'CPU 歷程記錄(&C)';

  @override
  String get newTaskMenu => '執行(&R)...';

  @override
  String get newTaskButton => '執行(&R)...';

  @override
  String get exitTaskManager => '結束工作管理員(&X)';

  @override
  String get alwaysOnTop => '永遠在最上層(&A)';

  @override
  String get minimizeOnUse => '使用後最小化(&M)';

  @override
  String get confirmations => '確認(&C)';

  @override
  String get hideWhenMinimized => '最小化時隱藏(&H)';

  @override
  String get refreshNow => '立即重新整理(&R)';

  @override
  String get high => '高(&H)';

  @override
  String get normal => '正常(&N)';

  @override
  String get low => '低(&L)';

  @override
  String get paused => '暫停(&P)';

  @override
  String get largeIcons => '大圖示(&G)';

  @override
  String get smallIcons => '小圖示(&M)';

  @override
  String get details => '詳細資料(&D)';

  @override
  String get tileHorizontally => '水平並排(&H)';

  @override
  String get tileVertically => '垂直並排(&V)';

  @override
  String get minimize => '最小化(&M)';

  @override
  String get maximize => '最大化(&X)';

  @override
  String get cascade => '重疊顯示(&C)';

  @override
  String get bringToFront => '帶到前景(&B)';

  @override
  String get helpTopics => '工作管理員說明主題(&H)';

  @override
  String get helpOpenFailed => '無法開啟工作管理員說明。';

  @override
  String get diagnosticLogs => '診斷記錄(&D)...';

  @override
  String get diagnosticLogsTitle => '診斷記錄';

  @override
  String get diagnosticStatusLabel => '狀態:';

  @override
  String get diagnosticSessionLabel => '工作階段:';

  @override
  String get diagnosticDirectoryLabel => '目錄:';

  @override
  String get diagnosticDetailedCurrentSession => '記錄目前工作階段的詳細記錄';

  @override
  String get diagnosticIncludeSensitive => '包含敏感資訊';

  @override
  String get diagnosticCaptureMinidump => '應用程式當機時建立記憶體傾印';

  @override
  String get diagnosticMinidumpPrivacy => '記憶體傾印可能包含私人資訊。';

  @override
  String get diagnosticRestartDetailed => '重新啟動並記錄詳細記錄';

  @override
  String get diagnosticOpenFolder => '開啟記錄目錄';

  @override
  String get diagnosticSaveBundle => '儲存診斷套件...';

  @override
  String get diagnosticLoggingActive => '記錄已啟用（%s）';

  @override
  String get diagnosticLoggingUnavailable => '檔案記錄無法使用';

  @override
  String get diagnosticDroppedEvents => '已捨棄的事件: %s';

  @override
  String get diagnosticExporting => '正在儲存診斷套件...';

  @override
  String get diagnosticExportSucceeded => '診斷套件已成功儲存。';

  @override
  String get diagnosticExportFailedTitle => '無法儲存診斷套件';

  @override
  String get diagnosticSensitiveExportWarning =>
      '此套件包含記憶體傾印，或包含啟用敏感記錄期間所記錄的欄位，可能含有私人資訊。是否繼續？';

  @override
  String get diagnosticRestartFailed => '工作管理員無法重新啟動並啟用詳細記錄。';

  @override
  String get diagnosticOpenFolderFailed => '無法開啟診斷記錄目錄。';

  @override
  String get aboutTaskManager => '關於工作管理員(&A)';

  @override
  String get oneGraphAllCpus => '一個圖表，顯示所有 CPU(&A)';

  @override
  String get oneGraphPerCpu => '每個 CPU 一個圖表(&P)';

  @override
  String get selectColumnsMenu => '選擇欄位(&C)...';

  @override
  String get selectColumnsTitle => '選擇欄位';

  @override
  String get selectProcessColumnsDescription => '選擇要在工作管理員的「處理程序」頁面上顯示的欄位。';

  @override
  String get showKernelTimes => '顯示核心時間(&K)';

  @override
  String get restoreTaskManager => '還原工作管理員(&R)';

  @override
  String get endProcess => '結束處理程序(&E)';

  @override
  String get endProcessTree => '結束處理程序樹(&T)';

  @override
  String get openFileLocation => '開啟檔案位置(&L)';

  @override
  String get debug => '偵錯(&D)';

  @override
  String get setPriority => '設定優先順序(&P)';

  @override
  String get realtime => '即時(&R)';

  @override
  String get aboveNormal => '高於正常(&A)';

  @override
  String get belowNormal => '低於正常(&B)';

  @override
  String get setAffinity => '設定相依性(&A)...';

  @override
  String get switchTo => '切換至(&S)';

  @override
  String get endTask => '結束工作(&E)';

  @override
  String get goToProcess => '移至處理程序(&G)';

  @override
  String get disconnect => '中斷連線(&D)';

  @override
  String get logoff => '登出(&L)';

  @override
  String get sendMessage => '傳送訊息(&S)...';

  @override
  String get sendMessageTitle => '傳送訊息';

  @override
  String get taskManager => '工作管理員';

  @override
  String get handles => '控制代碼';

  @override
  String get openFileHandles => '開啟的檔案控制代碼';

  @override
  String get threads => '執行緒';

  @override
  String get processesLabel => '處理程序';

  @override
  String get cpuUsageHistory => 'CPU 使用記錄';

  @override
  String get cpuUsage => 'CPU 使用率';

  @override
  String get memUsage => '記憶體使用量';

  @override
  String get memoryUsageHistory => '記憶體使用記錄';

  @override
  String get physicalMemoryK => '實體記憶體 (K)';

  @override
  String get commitChargeK => '認可的記憶體 (K)';

  @override
  String get kernelMemoryK => '核心記憶體 (K)';

  @override
  String get virtualMemoryK => '虛擬記憶體 (K)';

  @override
  String get totals => '總計';

  @override
  String get total => '總計';

  @override
  String get available => '可用';

  @override
  String get fileCache => '檔案快取';

  @override
  String get paged => '分頁';

  @override
  String get nonpaged => '非分頁';

  @override
  String get limit => '限制';

  @override
  String get peak => '峰值';

  @override
  String get committed => '已認可';

  @override
  String get commitLimit => '認可上限';

  @override
  String get swapUsed => '交換空間已用';

  @override
  String get slab => 'Slab';

  @override
  String get kernelStack => '核心堆疊';

  @override
  String get pageTables => '頁表';

  @override
  String get noActiveNetworkAdaptersFound => '找不到作用中的網路介面卡。';

  @override
  String get ok => '確定';

  @override
  String get cancel => '取消';

  @override
  String get close => '關閉';

  @override
  String get imageName => '映像名稱(&I)';

  @override
  String get pidProcessIdentifier => 'PID（處理程序識別碼）';

  @override
  String get userName => '使用者名稱';

  @override
  String get sessionId => '工作階段 ID';

  @override
  String get cpuTime => 'CPU 時間';

  @override
  String get memoryUsage => '記憶體使用量';

  @override
  String get memoryUsageDelta => '記憶體使用量變化';

  @override
  String get pageFaults => '頁面錯誤';

  @override
  String get pageFaultsDelta => '頁面錯誤變化量';

  @override
  String get virtualMemorySize => '虛擬記憶體大小';

  @override
  String get pagedPool => '分頁集區';

  @override
  String get nonPagedPool => '非分頁集區';

  @override
  String get basePriority => '基本優先順序';

  @override
  String get handleCount => '控制代碼數';

  @override
  String get threadCount => '執行緒數';

  @override
  String get processorAffinity => '處理器相依性';

  @override
  String get processors => '處理器';

  @override
  String get processorAffinityDescription => '控制此處理程序可在所選處理器群組中的哪些 CPU 上執行。';

  @override
  String get messageTitleLabel => '訊息標題(&M):';

  @override
  String get messageLabel => '訊息內容(&S):';

  @override
  String get showFullAccountName => '顯示完整帳戶名稱(&S)';

  @override
  String get user => '使用者';

  @override
  String get status => '狀態';

  @override
  String get clientName => '用戶端名稱';

  @override
  String get session => '工作階段';

  @override
  String get adapter => '介面卡';

  @override
  String get networkUtilization => '網路使用率';

  @override
  String get linkSpeed => '連線速度';

  @override
  String get state => '狀態';

  @override
  String get bytesSent => '已傳送位元組';

  @override
  String get bytesReceived => '已接收位元組';

  @override
  String get bytesTotal => '位元組總數';

  @override
  String get connected => '已連線';

  @override
  String get disconnected => '已中斷';

  @override
  String get connecting => '正在連線';

  @override
  String get disconnecting => '正在中斷連線';

  @override
  String get hardwareMissing => '硬體遺失';

  @override
  String get hardwareDisabled => '硬體已停用';

  @override
  String get hardwareMalfunction => '硬體故障';

  @override
  String get unknown => '未知';

  @override
  String get active => '使用中';

  @override
  String get connectQuery => '連線查詢';

  @override
  String get shadow => '遠端控制';

  @override
  String get idle => '閒置';

  @override
  String get listening => '接聽';

  @override
  String get reset => '重設';

  @override
  String get down => '已停止';

  @override
  String get init => '初始化';

  @override
  String get bitness32Suffix => '(32位元)';

  @override
  String get notResponding => '沒有回應';

  @override
  String get running => '執行中';

  @override
  String get messageCouldNotBeSent => '無法傳送訊息。';

  @override
  String get unableToOpenFileLocation => '無法開啟檔案位置';

  @override
  String get killProcessTreePrompt =>
      '此操作會嘗試終止此處理程序，以及所有由它直接或間接啟動的處理程序。\n\n以這種方式強制終止處理程序可能會造成資料遺失與系統不穩定。\n\n確定要繼續嗎？';

  @override
  String get killProcessTreeFailed => '無法完全結束處理程序樹';

  @override
  String get killProcessTreeFailedBody => '此處理程序樹中的一或多個處理程序無法結束。該操作未能完全成功。';

  @override
  String get confirmLogoffSelectedUsers => '確定要將選取的使用者登出嗎？';

  @override
  String get confirmDisconnectSelectedUsers => '確定要中斷選取的使用者嗎？';

  @override
  String get selectedUserCouldNotBeLoggedOff => '無法將選取的使用者登出。';

  @override
  String get selectedUserCouldNotBeDisconnected => '無法中斷選取的使用者。';

  @override
  String get win32ErrorPrefix => 'Win32 錯誤:';

  @override
  String get processColumnFileDescriptorCount => '檔案描述元';

  @override
  String get processColumnNice => 'nice 值';

  @override
  String get processColumnCgroup => '控制群組';

  @override
  String get setNice => '設定 nice 值(&N)...';

  @override
  String get setNiceTitle => '設定 nice 值';

  @override
  String get niceValueLabel => 'nice 值(&N):';

  @override
  String get niceValueDescription => '請輸入 -20（最高優先順序）到 19（最低優先順序）之間的 nice 值。';

  @override
  String get invalidNiceValue => 'nice 值必須是 -20 到 19 之間的整數。';

  @override
  String get niceChangeWarning => '變更處理程序優先順序可能會影響系統穩定性。確定要變更 nice 值嗎？';
}
