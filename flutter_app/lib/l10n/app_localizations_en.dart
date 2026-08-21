// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Windows NT Task Manager';

  @override
  String get runTitle => 'Run';

  @override
  String get runPrompt =>
      'Type the name of a program, folder, document, or Internet resource, and Windows will open it for you.';

  @override
  String get runCommandRequired =>
      'Enter the name of a program, folder, document, or Internet resource.';

  @override
  String get applicationsPageTitle => 'Applications';

  @override
  String get processesPageTitle => 'Processes';

  @override
  String get performancePageTitle => 'Performance';

  @override
  String get cpuPageTitle => 'CPU';

  @override
  String get gpuPageTitle => 'GPU';

  @override
  String get networkingPageTitle => 'Networking';

  @override
  String get usersPageTitle => 'Users';

  @override
  String get taskManagerDisabled =>
      'Task Manager has been disabled by your administrator.';

  @override
  String get warningTitle => 'Task Manager Warning';

  @override
  String get priorityChangeWarning =>
      'WARNING: Changing the priority class of this process may\ncause undesired results including system instability.  Are you\nsure you want to change the priority class?';

  @override
  String get killProcessWarning =>
      'WARNING: Terminating a process can cause undesired\nresults including loss of data and system instability.  The\nprocess will not be given the chance to save its state or\ndata before it is terminated.  Are you sure you want to\nterminate the process?';

  @override
  String get debugProcessWarning =>
      'WARNING: Debugging this process may result in loss of data.\nAre you sure you wish to attach the debugger?';

  @override
  String get invalidOptionTitle => 'Invalid Option';

  @override
  String get noAffinityMaskMessage =>
      'The process must have affinity with at least one processor.';

  @override
  String get unableToTerminateProcess => 'Unable to Terminate Process';

  @override
  String get unableToAttachDebugger => 'Unable to Attach Debugger';

  @override
  String get unableToChangePriority => 'Unable to Change Priority';

  @override
  String get unableToSetAffinity => 'The operation could not be completed.\n\n';

  @override
  String get formatProcesses => 'Processes: %d';

  @override
  String get formatCpuUsage => 'CPU Usage: %d%%';

  @override
  String get formatMemoryUsage => 'Mem Usage: %dK / %dK';

  @override
  String get formatCpuNumber => 'CPU %d';

  @override
  String get totalCpu => 'Total CPU';

  @override
  String get kernelCpu => 'Kernel CPU';

  @override
  String get cpuLoading => 'Loading CPU diagnostics...';

  @override
  String get cpuLoadingDetails =>
      'Basic CPU information is ready; loading performance and firmware details...';

  @override
  String get cpuPartialDetails => 'Some CPU details are unavailable.';

  @override
  String get cpuUnavailable => 'CPU topology information is unavailable.';

  @override
  String get cpuRefreshFailed => 'CPU diagnostic data update failed.';

  @override
  String get cpuRefreshFailedStale =>
      'CPU diagnostic data update failed; showing the last successful values.';

  @override
  String get cpuCurrentState => 'Current State';

  @override
  String get cpuSystemDiagnostics => 'System Diagnostics';

  @override
  String get cpuTopologyFeatures => 'Topology and Features';

  @override
  String get cpuHardwareCache => 'Hardware and Cache';

  @override
  String get cpuAverageFrequency => 'Average Frequency';

  @override
  String get cpuFrequencyRange => 'Frequency Range';

  @override
  String get cpuUserTime => 'User';

  @override
  String get cpuKernelTime => 'Kernel';

  @override
  String get cpuDpcTime => 'DPC';

  @override
  String get cpuInterruptTime => 'Interrupt';

  @override
  String get cpuInterruptsPerSecond => 'Interrupts/sec';

  @override
  String get cpuUptime => 'Uptime';

  @override
  String get cpuProcessorQueueLength => 'Processor Queue';

  @override
  String get cpuContextSwitchesPerSecond => 'Context Switches/sec';

  @override
  String get cpuSystemCallsPerSecond => 'System Calls/sec';

  @override
  String get cpuPackages => 'Packages';

  @override
  String get cpuNumaNodes => 'NUMA Nodes';

  @override
  String get cpuGroups => 'Groups';

  @override
  String get cpuDies => 'Dies';

  @override
  String get cpuModules => 'Modules';

  @override
  String get cpuPhysicalCores => 'Physical Cores';

  @override
  String get cpuLogicalProcessors => 'Logical Processors';

  @override
  String get cpuCoreClasses => 'Core Classes';

  @override
  String get cpuSmtCores => 'SMT Cores';

  @override
  String get cpuThreadsPerCore => 'Threads/Core';

  @override
  String get cpuVirtualization => 'Virtualization';

  @override
  String get cpuSlat => 'SLAT';

  @override
  String get cpuManufacturer => 'Manufacturer';

  @override
  String get cpuSocket => 'Socket';

  @override
  String get cpuProcessorId => 'Processor ID';

  @override
  String get cpuArchitectureWidth => 'Architecture / Width';

  @override
  String get cpuFamilyLevel => 'Family / Level';

  @override
  String get cpuRevisionStepping => 'Revision / Stepping';

  @override
  String get cpuFirmwareMaxFrequency => 'Firmware Max Frequency';

  @override
  String get cpuIsaFeatures => 'ISA Features';

  @override
  String get cpuCacheL1Data => 'L1 Data Cache';

  @override
  String get cpuCacheL1Instruction => 'L1 Instruction Cache';

  @override
  String get cpuCacheL2 => 'L2 Cache';

  @override
  String get cpuCacheL3 => 'L3 Cache';

  @override
  String get cpuUniformClass => 'Uniform';

  @override
  String get cpuYes => 'Yes';

  @override
  String get cpuNo => 'No';

  @override
  String get cpuFullyAssociative => 'Fully associative';

  @override
  String get cpuSockets => 'sockets';

  @override
  String get gpuLoading => 'Loading GPU data...';

  @override
  String get gpuLoadingPerformance =>
      'Basic GPU information is ready; loading performance data...';

  @override
  String get gpuLoadingDetails =>
      'GPU performance data is ready; loading hardware details...';

  @override
  String get gpuPartialDetails => 'Some GPU details are unavailable.';

  @override
  String get noHardwareGpusFound => 'No hardware GPUs were found.';

  @override
  String get gpuRequiresWddm2 =>
      'No GPU performance counters are available. This feature requires a WDDM 2.0 or later display driver.';

  @override
  String get gpuRefreshFailed => 'GPU data update failed.';

  @override
  String get gpuRefreshFailedStale =>
      'GPU data update failed; showing the last successful sample.';

  @override
  String get gpuCurrentMetrics => 'Current';

  @override
  String get gpuAdapterDetails => 'Adapter Details';

  @override
  String get gpuUtilization => 'Utilization';

  @override
  String get gpuMemory => 'GPU Memory';

  @override
  String get gpuDedicatedMemory => 'Dedicated GPU Memory';

  @override
  String get gpuSharedMemory => 'Shared GPU Memory';

  @override
  String get gpuDeviceLocalMemory => 'Device-local GPU Memory';

  @override
  String get gpuSharedSystemMemory => 'Shared System Memory';

  @override
  String get gpuTemperature => 'Temperature';

  @override
  String get gpuDriverVersion => 'Driver Version';

  @override
  String get gpuDriverDate => 'Driver Date';

  @override
  String get gpuDirectXVersion => 'DirectX Version';

  @override
  String get gpuPhysicalLocation => 'Physical Location';

  @override
  String get gpuHardwareReservedMemory => 'Hardware Reserved Memory';

  @override
  String get gpuKernelDriver => 'Kernel Driver';

  @override
  String get gpuKernelModuleVersion => 'Kernel Module Version';

  @override
  String get gpuGraphicsApi => 'Graphics API';

  @override
  String get gpuDrmPrimaryNode => 'DRM Primary Node';

  @override
  String get gpuDrmRenderNode => 'DRM Render Node';

  @override
  String get gpuPciAddress => 'PCI Address';

  @override
  String get gpuEngineMemory => 'Memory';

  @override
  String get gpuEngine3D => '3D';

  @override
  String get gpuEngineCopy => 'Copy';

  @override
  String get gpuEngineVideoEncode => 'Video Encode';

  @override
  String get gpuEngineVideoDecode => 'Video Decode';

  @override
  String get gpuEngineCompute => 'Compute';

  @override
  String get gpuEngineSecurity => 'Security';

  @override
  String get notAvailable => 'Not available';

  @override
  String get untitledWindow => 'Untitled window';

  @override
  String get taskColumnTask => 'Task';

  @override
  String get taskColumnStatus => 'Status';

  @override
  String get taskColumnWinstation => 'WinStation';

  @override
  String get taskColumnDesktop => 'Desktop';

  @override
  String get processColumnImageName => 'Image Name';

  @override
  String get processColumnPid => 'PID';

  @override
  String get processColumnCpu => 'CPU';

  @override
  String get processColumnCpuTime => 'CPU Time';

  @override
  String get processColumnMemoryUsage => 'Mem Usage';

  @override
  String get processColumnMemoryUsageDelta => 'Mem Delta';

  @override
  String get processColumnPageFaults => 'Page Faults';

  @override
  String get processColumnPageFaultsDelta => 'PF Delta';

  @override
  String get processColumnVirtualMemorySize => 'VM Size';

  @override
  String get processColumnPagedPool => 'Paged Pool';

  @override
  String get processColumnNonPagedPool => 'NP Pool';

  @override
  String get processColumnBasePriority => 'Base Pri';

  @override
  String get processColumnHandleCount => 'Handles';

  @override
  String get processColumnThreadCount => 'Threads';

  @override
  String get processColumnSessionId => 'Session ID';

  @override
  String get processColumnUserName => 'User Name';

  @override
  String get file => '&File';

  @override
  String get options => '&Options';

  @override
  String get view => '&View';

  @override
  String get windows => '&Windows';

  @override
  String get help => '&Help';

  @override
  String get updateSpeed => '&Update Speed';

  @override
  String get cpuHistory => '&CPU History';

  @override
  String get newTaskMenu => '&Run...';

  @override
  String get newTaskButton => '&Run...';

  @override
  String get exitTaskManager => 'E&xit Task Manager';

  @override
  String get alwaysOnTop => '&Always On Top';

  @override
  String get minimizeOnUse => '&Minimize On Use';

  @override
  String get confirmations => '&Confirmations';

  @override
  String get hideWhenMinimized => '&Hide When Minimized';

  @override
  String get refreshNow => '&Refresh Now';

  @override
  String get high => '&High';

  @override
  String get normal => '&Normal';

  @override
  String get low => '&Low';

  @override
  String get paused => '&Paused';

  @override
  String get largeIcons => 'Lar&ge Icons';

  @override
  String get smallIcons => 'S&mall Icons';

  @override
  String get details => '&Details';

  @override
  String get tileHorizontally => 'Tile &Horizontally';

  @override
  String get tileVertically => 'Tile &Vertically';

  @override
  String get minimize => '&Minimize';

  @override
  String get maximize => 'Ma&ximize';

  @override
  String get cascade => '&Cascade';

  @override
  String get bringToFront => '&Bring to Front';

  @override
  String get helpTopics => 'Task Manager &Help Topics';

  @override
  String get helpOpenFailed => 'Task Manager Help could not be opened.';

  @override
  String get diagnosticLogs => '&Diagnostic Logs...';

  @override
  String get diagnosticLogsTitle => 'Diagnostic Logs';

  @override
  String get diagnosticStatusLabel => 'Status:';

  @override
  String get diagnosticSessionLabel => 'Session:';

  @override
  String get diagnosticDirectoryLabel => 'Directory:';

  @override
  String get diagnosticDetailedCurrentSession =>
      'Record detailed logs for this session';

  @override
  String get diagnosticIncludeSensitive => 'Include sensitive information';

  @override
  String get diagnosticCaptureMinidump =>
      'Create a minidump if the application crashes';

  @override
  String get diagnosticMinidumpPrivacy =>
      'Memory dumps can contain private information.';

  @override
  String get diagnosticRestartDetailed => 'Restart with Detailed Logging';

  @override
  String get diagnosticOpenFolder => 'Open Log Folder';

  @override
  String get diagnosticSaveBundle => 'Save Diagnostic Bundle...';

  @override
  String get diagnosticLoggingActive => 'Logging active (%s)';

  @override
  String get diagnosticLoggingUnavailable => 'File logging unavailable';

  @override
  String get diagnosticDroppedEvents => 'Dropped events: %s';

  @override
  String get diagnosticExporting => 'Saving diagnostic bundle...';

  @override
  String get diagnosticExportSucceeded =>
      'Diagnostic bundle saved successfully.';

  @override
  String get diagnosticExportFailedTitle => 'Unable to Save Diagnostic Bundle';

  @override
  String get diagnosticSensitiveExportWarning =>
      'This bundle includes a memory dump or fields recorded while sensitive logging was enabled. It may contain private information. Continue?';

  @override
  String get diagnosticRestartFailed =>
      'Task Manager could not restart with detailed logging.';

  @override
  String get diagnosticOpenFolderFailed =>
      'The diagnostic log folder could not be opened.';

  @override
  String get aboutTaskManager => '&About Task Manager';

  @override
  String get oneGraphAllCpus => 'One Graph, &All CPUs';

  @override
  String get oneGraphPerCpu => 'One Graph &Per CPU';

  @override
  String get selectColumnsMenu => 'Select &Columns...';

  @override
  String get selectColumnsTitle => 'Select Columns';

  @override
  String get selectProcessColumnsDescription =>
      'Select the columns that will appear on the Process page of the Task Manager.';

  @override
  String get showKernelTimes => 'Show &Kernel Times';

  @override
  String get restoreTaskManager => '&Restore Task Manager';

  @override
  String get endProcess => '&End Process';

  @override
  String get endProcessTree => 'End Process &Tree';

  @override
  String get openFileLocation => 'Open File &Location';

  @override
  String get debug => '&Debug';

  @override
  String get setPriority => 'Set &Priority';

  @override
  String get realtime => '&Realtime';

  @override
  String get aboveNormal => '&Above Normal';

  @override
  String get belowNormal => '&Below Normal';

  @override
  String get setAffinity => 'Set &Affinity...';

  @override
  String get switchTo => '&Switch To';

  @override
  String get endTask => '&End Task';

  @override
  String get goToProcess => '&Go To Process';

  @override
  String get disconnect => '&Disconnect';

  @override
  String get logoff => '&Logoff';

  @override
  String get sendMessage => '&Send Message...';

  @override
  String get sendMessageTitle => 'Send Message';

  @override
  String get taskManager => 'Task Manager';

  @override
  String get handles => 'Handles';

  @override
  String get openFileHandles => 'Open File Handles';

  @override
  String get threads => 'Threads';

  @override
  String get processesLabel => 'Processes';

  @override
  String get cpuUsageHistory => 'CPU Usage History';

  @override
  String get cpuUsage => 'CPU Usage';

  @override
  String get memUsage => 'MEM Usage';

  @override
  String get memoryUsageHistory => 'Memory Usage History';

  @override
  String get physicalMemoryK => 'Physical Memory (K)';

  @override
  String get commitChargeK => 'Commit Charge (K)';

  @override
  String get kernelMemoryK => 'Kernel Memory (K)';

  @override
  String get virtualMemoryK => 'Virtual Memory (K)';

  @override
  String get totals => 'Totals';

  @override
  String get total => 'Total';

  @override
  String get available => 'Available';

  @override
  String get fileCache => 'File Cache';

  @override
  String get paged => 'Paged';

  @override
  String get nonpaged => 'Nonpaged';

  @override
  String get limit => 'Limit';

  @override
  String get peak => 'Peak';

  @override
  String get committed => 'Committed';

  @override
  String get commitLimit => 'Commit Limit';

  @override
  String get swapUsed => 'Swap Used';

  @override
  String get slab => 'Slab';

  @override
  String get kernelStack => 'Kernel Stack';

  @override
  String get pageTables => 'Page Tables';

  @override
  String get noActiveNetworkAdaptersFound =>
      'No Active Network Adapters Found.';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get imageName => '&Image Name';

  @override
  String get pidProcessIdentifier => 'PID (Process Identifier)';

  @override
  String get userName => 'User Name';

  @override
  String get sessionId => 'Session ID';

  @override
  String get cpuTime => 'CPU Time';

  @override
  String get memoryUsage => 'Memory Usage';

  @override
  String get memoryUsageDelta => 'Memory Usage Delta';

  @override
  String get pageFaults => 'Page Faults';

  @override
  String get pageFaultsDelta => 'Page Faults Delta';

  @override
  String get virtualMemorySize => 'Virtual Memory Size';

  @override
  String get pagedPool => 'Paged Pool';

  @override
  String get nonPagedPool => 'Non-paged Pool';

  @override
  String get basePriority => 'Base Priority';

  @override
  String get handleCount => 'Handle Count';

  @override
  String get threadCount => 'Thread Count';

  @override
  String get processorAffinity => 'Processor Affinity';

  @override
  String get processors => 'Processors';

  @override
  String get processorAffinityDescription =>
      'Controls which CPUs in the selected processor group the process may execute on.';

  @override
  String get messageTitleLabel => '&Message title:';

  @override
  String get messageLabel => 'Me&ssage:';

  @override
  String get showFullAccountName => '&Show Full Account Name';

  @override
  String get user => 'User';

  @override
  String get status => 'Status';

  @override
  String get clientName => 'Client Name';

  @override
  String get session => 'Session';

  @override
  String get adapter => 'Adapter';

  @override
  String get networkUtilization => 'Network Utilization';

  @override
  String get linkSpeed => 'Link Speed';

  @override
  String get state => 'State';

  @override
  String get bytesSent => 'Bytes Sent';

  @override
  String get bytesReceived => 'Bytes Received';

  @override
  String get bytesTotal => 'Bytes Total';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get connecting => 'Connecting';

  @override
  String get disconnecting => 'Disconnecting';

  @override
  String get hardwareMissing => 'Hardware Missing';

  @override
  String get hardwareDisabled => 'Hardware Disabled';

  @override
  String get hardwareMalfunction => 'Hardware Malfunction';

  @override
  String get unknown => 'Unknown';

  @override
  String get active => 'Active';

  @override
  String get connectQuery => 'Connect Query';

  @override
  String get shadow => 'Shadow';

  @override
  String get idle => 'Idle';

  @override
  String get listening => 'Listening';

  @override
  String get reset => 'Reset';

  @override
  String get down => 'Down';

  @override
  String get init => 'Init';

  @override
  String get bitness32Suffix => '(32-bit)';

  @override
  String get notResponding => 'Not Responding';

  @override
  String get running => 'Running';

  @override
  String get messageCouldNotBeSent => 'The message could not be sent.';

  @override
  String get unableToOpenFileLocation => 'Unable to Open File Location';

  @override
  String get killProcessTreePrompt =>
      'This operation will attempt to terminate this process and any\nprocesses which were directly or indirectly started by it.\n\nForcing processes to terminate in this manner can cause\ndata loss and system instability.\n\nAre you sure you wish to continue?';

  @override
  String get killProcessTreeFailed =>
      'Unable to Completely End the Process Tree';

  @override
  String get killProcessTreeFailedBody =>
      'One or more of the processes in this process tree could not\nbe ended. The operation was not fully successful.';

  @override
  String get confirmLogoffSelectedUsers =>
      'Are you sure you want to logoff the selected user(s)?';

  @override
  String get confirmDisconnectSelectedUsers =>
      'Are you sure you want to disconnect the selected user(s)?';

  @override
  String get selectedUserCouldNotBeLoggedOff =>
      'The selected user could not be logged off.';

  @override
  String get selectedUserCouldNotBeDisconnected =>
      'The selected user could not be disconnected.';

  @override
  String get win32ErrorPrefix => 'Win32 error:';

  @override
  String get processColumnFileDescriptorCount => 'File Descriptors';

  @override
  String get processColumnNice => 'Nice';

  @override
  String get processColumnCgroup => 'Cgroup';

  @override
  String get setNice => 'Set &Nice Value...';

  @override
  String get setNiceTitle => 'Set Nice Value';

  @override
  String get niceValueLabel => '&Nice value:';

  @override
  String get niceValueDescription =>
      'Enter a nice value from -20 (highest priority) to 19 (lowest priority).';

  @override
  String get invalidNiceValue =>
      'The nice value must be an integer between -20 and 19.';

  @override
  String get niceChangeWarning =>
      'Changing process priority may affect system stability. Are you sure you want to change the nice value?';
}
