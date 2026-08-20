import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('pt'),
    Locale('ru'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Windows NT Task Manager'**
  String get appTitle;

  /// No description provided for @runTitle.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get runTitle;

  /// No description provided for @runPrompt.
  ///
  /// In en, this message translates to:
  /// **'Type the name of a program, folder, document, or Internet resource, and Windows will open it for you.'**
  String get runPrompt;

  /// No description provided for @runCommandRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the name of a program, folder, document, or Internet resource.'**
  String get runCommandRequired;

  /// No description provided for @applicationsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Applications'**
  String get applicationsPageTitle;

  /// No description provided for @processesPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Processes'**
  String get processesPageTitle;

  /// No description provided for @performancePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performancePageTitle;

  /// No description provided for @cpuPageTitle.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get cpuPageTitle;

  /// No description provided for @gpuPageTitle.
  ///
  /// In en, this message translates to:
  /// **'GPU'**
  String get gpuPageTitle;

  /// No description provided for @networkingPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Networking'**
  String get networkingPageTitle;

  /// No description provided for @usersPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get usersPageTitle;

  /// No description provided for @taskManagerDisabled.
  ///
  /// In en, this message translates to:
  /// **'Task Manager has been disabled by your administrator.'**
  String get taskManagerDisabled;

  /// No description provided for @warningTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Manager Warning'**
  String get warningTitle;

  /// No description provided for @priorityChangeWarning.
  ///
  /// In en, this message translates to:
  /// **'WARNING: Changing the priority class of this process may\ncause undesired results including system instability.  Are you\nsure you want to change the priority class?'**
  String get priorityChangeWarning;

  /// No description provided for @killProcessWarning.
  ///
  /// In en, this message translates to:
  /// **'WARNING: Terminating a process can cause undesired\nresults including loss of data and system instability.  The\nprocess will not be given the chance to save its state or\ndata before it is terminated.  Are you sure you want to\nterminate the process?'**
  String get killProcessWarning;

  /// No description provided for @debugProcessWarning.
  ///
  /// In en, this message translates to:
  /// **'WARNING: Debugging this process may result in loss of data.\nAre you sure you wish to attach the debugger?'**
  String get debugProcessWarning;

  /// No description provided for @invalidOptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Invalid Option'**
  String get invalidOptionTitle;

  /// No description provided for @noAffinityMaskMessage.
  ///
  /// In en, this message translates to:
  /// **'The process must have affinity with at least one processor.'**
  String get noAffinityMaskMessage;

  /// No description provided for @unableToTerminateProcess.
  ///
  /// In en, this message translates to:
  /// **'Unable to Terminate Process'**
  String get unableToTerminateProcess;

  /// No description provided for @unableToAttachDebugger.
  ///
  /// In en, this message translates to:
  /// **'Unable to Attach Debugger'**
  String get unableToAttachDebugger;

  /// No description provided for @unableToChangePriority.
  ///
  /// In en, this message translates to:
  /// **'Unable to Change Priority'**
  String get unableToChangePriority;

  /// No description provided for @unableToSetAffinity.
  ///
  /// In en, this message translates to:
  /// **'The operation could not be completed.\n\n'**
  String get unableToSetAffinity;

  /// No description provided for @formatProcesses.
  ///
  /// In en, this message translates to:
  /// **'Processes: %d'**
  String get formatProcesses;

  /// No description provided for @formatCpuUsage.
  ///
  /// In en, this message translates to:
  /// **'CPU Usage: %d%%'**
  String get formatCpuUsage;

  /// No description provided for @formatMemoryUsage.
  ///
  /// In en, this message translates to:
  /// **'Mem Usage: %dK / %dK'**
  String get formatMemoryUsage;

  /// No description provided for @formatCpuNumber.
  ///
  /// In en, this message translates to:
  /// **'CPU %d'**
  String get formatCpuNumber;

  /// No description provided for @totalCpu.
  ///
  /// In en, this message translates to:
  /// **'Total CPU'**
  String get totalCpu;

  /// No description provided for @kernelCpu.
  ///
  /// In en, this message translates to:
  /// **'Kernel CPU'**
  String get kernelCpu;

  /// No description provided for @cpuLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading CPU diagnostics...'**
  String get cpuLoading;

  /// No description provided for @cpuLoadingDetails.
  ///
  /// In en, this message translates to:
  /// **'Basic CPU information is ready; loading performance and firmware details...'**
  String get cpuLoadingDetails;

  /// No description provided for @cpuPartialDetails.
  ///
  /// In en, this message translates to:
  /// **'Some CPU details are unavailable.'**
  String get cpuPartialDetails;

  /// No description provided for @cpuUnavailable.
  ///
  /// In en, this message translates to:
  /// **'CPU topology information is unavailable.'**
  String get cpuUnavailable;

  /// No description provided for @cpuRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'CPU diagnostic data update failed.'**
  String get cpuRefreshFailed;

  /// No description provided for @cpuRefreshFailedStale.
  ///
  /// In en, this message translates to:
  /// **'CPU diagnostic data update failed; showing the last successful values.'**
  String get cpuRefreshFailedStale;

  /// No description provided for @cpuCurrentState.
  ///
  /// In en, this message translates to:
  /// **'Current State'**
  String get cpuCurrentState;

  /// No description provided for @cpuSystemDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'System Diagnostics'**
  String get cpuSystemDiagnostics;

  /// No description provided for @cpuTopologyFeatures.
  ///
  /// In en, this message translates to:
  /// **'Topology and Features'**
  String get cpuTopologyFeatures;

  /// No description provided for @cpuHardwareCache.
  ///
  /// In en, this message translates to:
  /// **'Hardware and Cache'**
  String get cpuHardwareCache;

  /// No description provided for @cpuAverageFrequency.
  ///
  /// In en, this message translates to:
  /// **'Average Frequency'**
  String get cpuAverageFrequency;

  /// No description provided for @cpuFrequencyRange.
  ///
  /// In en, this message translates to:
  /// **'Frequency Range'**
  String get cpuFrequencyRange;

  /// No description provided for @cpuUserTime.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get cpuUserTime;

  /// No description provided for @cpuKernelTime.
  ///
  /// In en, this message translates to:
  /// **'Kernel'**
  String get cpuKernelTime;

  /// No description provided for @cpuDpcTime.
  ///
  /// In en, this message translates to:
  /// **'DPC'**
  String get cpuDpcTime;

  /// No description provided for @cpuInterruptTime.
  ///
  /// In en, this message translates to:
  /// **'Interrupt'**
  String get cpuInterruptTime;

  /// No description provided for @cpuInterruptsPerSecond.
  ///
  /// In en, this message translates to:
  /// **'Interrupts/sec'**
  String get cpuInterruptsPerSecond;

  /// No description provided for @cpuUptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get cpuUptime;

  /// No description provided for @cpuProcessorQueueLength.
  ///
  /// In en, this message translates to:
  /// **'Processor Queue'**
  String get cpuProcessorQueueLength;

  /// No description provided for @cpuContextSwitchesPerSecond.
  ///
  /// In en, this message translates to:
  /// **'Context Switches/sec'**
  String get cpuContextSwitchesPerSecond;

  /// No description provided for @cpuSystemCallsPerSecond.
  ///
  /// In en, this message translates to:
  /// **'System Calls/sec'**
  String get cpuSystemCallsPerSecond;

  /// No description provided for @cpuPackages.
  ///
  /// In en, this message translates to:
  /// **'Packages'**
  String get cpuPackages;

  /// No description provided for @cpuNumaNodes.
  ///
  /// In en, this message translates to:
  /// **'NUMA Nodes'**
  String get cpuNumaNodes;

  /// No description provided for @cpuGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get cpuGroups;

  /// No description provided for @cpuDies.
  ///
  /// In en, this message translates to:
  /// **'Dies'**
  String get cpuDies;

  /// No description provided for @cpuModules.
  ///
  /// In en, this message translates to:
  /// **'Modules'**
  String get cpuModules;

  /// No description provided for @cpuPhysicalCores.
  ///
  /// In en, this message translates to:
  /// **'Physical Cores'**
  String get cpuPhysicalCores;

  /// No description provided for @cpuLogicalProcessors.
  ///
  /// In en, this message translates to:
  /// **'Logical Processors'**
  String get cpuLogicalProcessors;

  /// No description provided for @cpuCoreClasses.
  ///
  /// In en, this message translates to:
  /// **'Core Classes'**
  String get cpuCoreClasses;

  /// No description provided for @cpuSmtCores.
  ///
  /// In en, this message translates to:
  /// **'SMT Cores'**
  String get cpuSmtCores;

  /// No description provided for @cpuThreadsPerCore.
  ///
  /// In en, this message translates to:
  /// **'Threads/Core'**
  String get cpuThreadsPerCore;

  /// No description provided for @cpuVirtualization.
  ///
  /// In en, this message translates to:
  /// **'Virtualization'**
  String get cpuVirtualization;

  /// No description provided for @cpuSlat.
  ///
  /// In en, this message translates to:
  /// **'SLAT'**
  String get cpuSlat;

  /// No description provided for @cpuManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get cpuManufacturer;

  /// No description provided for @cpuSocket.
  ///
  /// In en, this message translates to:
  /// **'Socket'**
  String get cpuSocket;

  /// No description provided for @cpuProcessorId.
  ///
  /// In en, this message translates to:
  /// **'Processor ID'**
  String get cpuProcessorId;

  /// No description provided for @cpuArchitectureWidth.
  ///
  /// In en, this message translates to:
  /// **'Architecture / Width'**
  String get cpuArchitectureWidth;

  /// No description provided for @cpuFamilyLevel.
  ///
  /// In en, this message translates to:
  /// **'Family / Level'**
  String get cpuFamilyLevel;

  /// No description provided for @cpuRevisionStepping.
  ///
  /// In en, this message translates to:
  /// **'Revision / Stepping'**
  String get cpuRevisionStepping;

  /// No description provided for @cpuFirmwareMaxFrequency.
  ///
  /// In en, this message translates to:
  /// **'Firmware Max Frequency'**
  String get cpuFirmwareMaxFrequency;

  /// No description provided for @cpuIsaFeatures.
  ///
  /// In en, this message translates to:
  /// **'ISA Features'**
  String get cpuIsaFeatures;

  /// No description provided for @cpuCacheL1Data.
  ///
  /// In en, this message translates to:
  /// **'L1 Data Cache'**
  String get cpuCacheL1Data;

  /// No description provided for @cpuCacheL1Instruction.
  ///
  /// In en, this message translates to:
  /// **'L1 Instruction Cache'**
  String get cpuCacheL1Instruction;

  /// No description provided for @cpuCacheL2.
  ///
  /// In en, this message translates to:
  /// **'L2 Cache'**
  String get cpuCacheL2;

  /// No description provided for @cpuCacheL3.
  ///
  /// In en, this message translates to:
  /// **'L3 Cache'**
  String get cpuCacheL3;

  /// No description provided for @cpuUniformClass.
  ///
  /// In en, this message translates to:
  /// **'Uniform'**
  String get cpuUniformClass;

  /// No description provided for @cpuYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get cpuYes;

  /// No description provided for @cpuNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get cpuNo;

  /// No description provided for @cpuFullyAssociative.
  ///
  /// In en, this message translates to:
  /// **'Fully associative'**
  String get cpuFullyAssociative;

  /// No description provided for @cpuSockets.
  ///
  /// In en, this message translates to:
  /// **'sockets'**
  String get cpuSockets;

  /// No description provided for @gpuLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading GPU data...'**
  String get gpuLoading;

  /// No description provided for @gpuLoadingPerformance.
  ///
  /// In en, this message translates to:
  /// **'Basic GPU information is ready; loading performance data...'**
  String get gpuLoadingPerformance;

  /// No description provided for @gpuLoadingDetails.
  ///
  /// In en, this message translates to:
  /// **'GPU performance data is ready; loading hardware details...'**
  String get gpuLoadingDetails;

  /// No description provided for @gpuPartialDetails.
  ///
  /// In en, this message translates to:
  /// **'Some GPU details are unavailable.'**
  String get gpuPartialDetails;

  /// No description provided for @noHardwareGpusFound.
  ///
  /// In en, this message translates to:
  /// **'No hardware GPUs were found.'**
  String get noHardwareGpusFound;

  /// No description provided for @gpuRequiresWddm2.
  ///
  /// In en, this message translates to:
  /// **'No GPU performance counters are available. This feature requires a WDDM 2.0 or later display driver.'**
  String get gpuRequiresWddm2;

  /// No description provided for @gpuRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'GPU data update failed.'**
  String get gpuRefreshFailed;

  /// No description provided for @gpuRefreshFailedStale.
  ///
  /// In en, this message translates to:
  /// **'GPU data update failed; showing the last successful sample.'**
  String get gpuRefreshFailedStale;

  /// No description provided for @gpuCurrentMetrics.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get gpuCurrentMetrics;

  /// No description provided for @gpuAdapterDetails.
  ///
  /// In en, this message translates to:
  /// **'Adapter Details'**
  String get gpuAdapterDetails;

  /// No description provided for @gpuUtilization.
  ///
  /// In en, this message translates to:
  /// **'Utilization'**
  String get gpuUtilization;

  /// No description provided for @gpuMemory.
  ///
  /// In en, this message translates to:
  /// **'GPU Memory'**
  String get gpuMemory;

  /// No description provided for @gpuDedicatedMemory.
  ///
  /// In en, this message translates to:
  /// **'Dedicated GPU Memory'**
  String get gpuDedicatedMemory;

  /// No description provided for @gpuSharedMemory.
  ///
  /// In en, this message translates to:
  /// **'Shared GPU Memory'**
  String get gpuSharedMemory;

  /// No description provided for @gpuTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get gpuTemperature;

  /// No description provided for @gpuDriverVersion.
  ///
  /// In en, this message translates to:
  /// **'Driver Version'**
  String get gpuDriverVersion;

  /// No description provided for @gpuDriverDate.
  ///
  /// In en, this message translates to:
  /// **'Driver Date'**
  String get gpuDriverDate;

  /// No description provided for @gpuDirectXVersion.
  ///
  /// In en, this message translates to:
  /// **'DirectX Version'**
  String get gpuDirectXVersion;

  /// No description provided for @gpuPhysicalLocation.
  ///
  /// In en, this message translates to:
  /// **'Physical Location'**
  String get gpuPhysicalLocation;

  /// No description provided for @gpuHardwareReservedMemory.
  ///
  /// In en, this message translates to:
  /// **'Hardware Reserved Memory'**
  String get gpuHardwareReservedMemory;

  /// No description provided for @gpuEngine3D.
  ///
  /// In en, this message translates to:
  /// **'3D'**
  String get gpuEngine3D;

  /// No description provided for @gpuEngineCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get gpuEngineCopy;

  /// No description provided for @gpuEngineVideoEncode.
  ///
  /// In en, this message translates to:
  /// **'Video Encode'**
  String get gpuEngineVideoEncode;

  /// No description provided for @gpuEngineVideoDecode.
  ///
  /// In en, this message translates to:
  /// **'Video Decode'**
  String get gpuEngineVideoDecode;

  /// No description provided for @gpuEngineCompute.
  ///
  /// In en, this message translates to:
  /// **'Compute'**
  String get gpuEngineCompute;

  /// No description provided for @gpuEngineSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get gpuEngineSecurity;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @taskColumnTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskColumnTask;

  /// No description provided for @taskColumnStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get taskColumnStatus;

  /// No description provided for @taskColumnWinstation.
  ///
  /// In en, this message translates to:
  /// **'WinStation'**
  String get taskColumnWinstation;

  /// No description provided for @taskColumnDesktop.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get taskColumnDesktop;

  /// No description provided for @processColumnImageName.
  ///
  /// In en, this message translates to:
  /// **'Image Name'**
  String get processColumnImageName;

  /// No description provided for @processColumnPid.
  ///
  /// In en, this message translates to:
  /// **'PID'**
  String get processColumnPid;

  /// No description provided for @processColumnCpu.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get processColumnCpu;

  /// No description provided for @processColumnCpuTime.
  ///
  /// In en, this message translates to:
  /// **'CPU Time'**
  String get processColumnCpuTime;

  /// No description provided for @processColumnMemoryUsage.
  ///
  /// In en, this message translates to:
  /// **'Mem Usage'**
  String get processColumnMemoryUsage;

  /// No description provided for @processColumnMemoryUsageDelta.
  ///
  /// In en, this message translates to:
  /// **'Mem Delta'**
  String get processColumnMemoryUsageDelta;

  /// No description provided for @processColumnPageFaults.
  ///
  /// In en, this message translates to:
  /// **'Page Faults'**
  String get processColumnPageFaults;

  /// No description provided for @processColumnPageFaultsDelta.
  ///
  /// In en, this message translates to:
  /// **'PF Delta'**
  String get processColumnPageFaultsDelta;

  /// No description provided for @processColumnVirtualMemorySize.
  ///
  /// In en, this message translates to:
  /// **'VM Size'**
  String get processColumnVirtualMemorySize;

  /// No description provided for @processColumnPagedPool.
  ///
  /// In en, this message translates to:
  /// **'Paged Pool'**
  String get processColumnPagedPool;

  /// No description provided for @processColumnNonPagedPool.
  ///
  /// In en, this message translates to:
  /// **'NP Pool'**
  String get processColumnNonPagedPool;

  /// No description provided for @processColumnBasePriority.
  ///
  /// In en, this message translates to:
  /// **'Base Pri'**
  String get processColumnBasePriority;

  /// No description provided for @processColumnHandleCount.
  ///
  /// In en, this message translates to:
  /// **'Handles'**
  String get processColumnHandleCount;

  /// No description provided for @processColumnThreadCount.
  ///
  /// In en, this message translates to:
  /// **'Threads'**
  String get processColumnThreadCount;

  /// No description provided for @processColumnSessionId.
  ///
  /// In en, this message translates to:
  /// **'Session ID'**
  String get processColumnSessionId;

  /// No description provided for @processColumnUserName.
  ///
  /// In en, this message translates to:
  /// **'User Name'**
  String get processColumnUserName;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'&File'**
  String get file;

  /// No description provided for @options.
  ///
  /// In en, this message translates to:
  /// **'&Options'**
  String get options;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'&View'**
  String get view;

  /// No description provided for @windows.
  ///
  /// In en, this message translates to:
  /// **'&Windows'**
  String get windows;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'&Help'**
  String get help;

  /// No description provided for @updateSpeed.
  ///
  /// In en, this message translates to:
  /// **'&Update Speed'**
  String get updateSpeed;

  /// No description provided for @cpuHistory.
  ///
  /// In en, this message translates to:
  /// **'&CPU History'**
  String get cpuHistory;

  /// No description provided for @newTaskMenu.
  ///
  /// In en, this message translates to:
  /// **'&Run...'**
  String get newTaskMenu;

  /// No description provided for @newTaskButton.
  ///
  /// In en, this message translates to:
  /// **'&Run...'**
  String get newTaskButton;

  /// No description provided for @exitTaskManager.
  ///
  /// In en, this message translates to:
  /// **'E&xit Task Manager'**
  String get exitTaskManager;

  /// No description provided for @alwaysOnTop.
  ///
  /// In en, this message translates to:
  /// **'&Always On Top'**
  String get alwaysOnTop;

  /// No description provided for @minimizeOnUse.
  ///
  /// In en, this message translates to:
  /// **'&Minimize On Use'**
  String get minimizeOnUse;

  /// No description provided for @confirmations.
  ///
  /// In en, this message translates to:
  /// **'&Confirmations'**
  String get confirmations;

  /// No description provided for @hideWhenMinimized.
  ///
  /// In en, this message translates to:
  /// **'&Hide When Minimized'**
  String get hideWhenMinimized;

  /// No description provided for @refreshNow.
  ///
  /// In en, this message translates to:
  /// **'&Refresh Now'**
  String get refreshNow;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'&High'**
  String get high;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'&Normal'**
  String get normal;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'&Low'**
  String get low;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'&Paused'**
  String get paused;

  /// No description provided for @largeIcons.
  ///
  /// In en, this message translates to:
  /// **'Lar&ge Icons'**
  String get largeIcons;

  /// No description provided for @smallIcons.
  ///
  /// In en, this message translates to:
  /// **'S&mall Icons'**
  String get smallIcons;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'&Details'**
  String get details;

  /// No description provided for @tileHorizontally.
  ///
  /// In en, this message translates to:
  /// **'Tile &Horizontally'**
  String get tileHorizontally;

  /// No description provided for @tileVertically.
  ///
  /// In en, this message translates to:
  /// **'Tile &Vertically'**
  String get tileVertically;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'&Minimize'**
  String get minimize;

  /// No description provided for @maximize.
  ///
  /// In en, this message translates to:
  /// **'Ma&ximize'**
  String get maximize;

  /// No description provided for @cascade.
  ///
  /// In en, this message translates to:
  /// **'&Cascade'**
  String get cascade;

  /// No description provided for @bringToFront.
  ///
  /// In en, this message translates to:
  /// **'&Bring to Front'**
  String get bringToFront;

  /// No description provided for @helpTopics.
  ///
  /// In en, this message translates to:
  /// **'Task Manager &Help Topics'**
  String get helpTopics;

  /// No description provided for @helpOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Task Manager Help could not be opened.'**
  String get helpOpenFailed;

  /// No description provided for @diagnosticLogs.
  ///
  /// In en, this message translates to:
  /// **'&Diagnostic Logs...'**
  String get diagnosticLogs;

  /// No description provided for @diagnosticLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic Logs'**
  String get diagnosticLogsTitle;

  /// No description provided for @diagnosticStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status:'**
  String get diagnosticStatusLabel;

  /// No description provided for @diagnosticSessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Session:'**
  String get diagnosticSessionLabel;

  /// No description provided for @diagnosticDirectoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Directory:'**
  String get diagnosticDirectoryLabel;

  /// No description provided for @diagnosticDetailedCurrentSession.
  ///
  /// In en, this message translates to:
  /// **'Record detailed logs for this session'**
  String get diagnosticDetailedCurrentSession;

  /// No description provided for @diagnosticIncludeSensitive.
  ///
  /// In en, this message translates to:
  /// **'Include sensitive information'**
  String get diagnosticIncludeSensitive;

  /// No description provided for @diagnosticCaptureMinidump.
  ///
  /// In en, this message translates to:
  /// **'Create a minidump if the application crashes'**
  String get diagnosticCaptureMinidump;

  /// No description provided for @diagnosticMinidumpPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Memory dumps can contain private information.'**
  String get diagnosticMinidumpPrivacy;

  /// No description provided for @diagnosticRestartDetailed.
  ///
  /// In en, this message translates to:
  /// **'Restart with Detailed Logging'**
  String get diagnosticRestartDetailed;

  /// No description provided for @diagnosticOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open Log Folder'**
  String get diagnosticOpenFolder;

  /// No description provided for @diagnosticSaveBundle.
  ///
  /// In en, this message translates to:
  /// **'Save Diagnostic Bundle...'**
  String get diagnosticSaveBundle;

  /// No description provided for @diagnosticLoggingActive.
  ///
  /// In en, this message translates to:
  /// **'Logging active (%s)'**
  String get diagnosticLoggingActive;

  /// No description provided for @diagnosticLoggingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'File logging unavailable'**
  String get diagnosticLoggingUnavailable;

  /// No description provided for @diagnosticDroppedEvents.
  ///
  /// In en, this message translates to:
  /// **'Dropped events: %s'**
  String get diagnosticDroppedEvents;

  /// No description provided for @diagnosticExporting.
  ///
  /// In en, this message translates to:
  /// **'Saving diagnostic bundle...'**
  String get diagnosticExporting;

  /// No description provided for @diagnosticExportSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic bundle saved successfully.'**
  String get diagnosticExportSucceeded;

  /// No description provided for @diagnosticExportFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to Save Diagnostic Bundle'**
  String get diagnosticExportFailedTitle;

  /// No description provided for @diagnosticSensitiveExportWarning.
  ///
  /// In en, this message translates to:
  /// **'This bundle includes a memory dump or fields recorded while sensitive logging was enabled. It may contain private information. Continue?'**
  String get diagnosticSensitiveExportWarning;

  /// No description provided for @diagnosticRestartFailed.
  ///
  /// In en, this message translates to:
  /// **'Task Manager could not restart with detailed logging.'**
  String get diagnosticRestartFailed;

  /// No description provided for @diagnosticOpenFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'The diagnostic log folder could not be opened.'**
  String get diagnosticOpenFolderFailed;

  /// No description provided for @aboutTaskManager.
  ///
  /// In en, this message translates to:
  /// **'&About Task Manager'**
  String get aboutTaskManager;

  /// No description provided for @oneGraphAllCpus.
  ///
  /// In en, this message translates to:
  /// **'One Graph, &All CPUs'**
  String get oneGraphAllCpus;

  /// No description provided for @oneGraphPerCpu.
  ///
  /// In en, this message translates to:
  /// **'One Graph &Per CPU'**
  String get oneGraphPerCpu;

  /// No description provided for @selectColumnsMenu.
  ///
  /// In en, this message translates to:
  /// **'Select &Columns...'**
  String get selectColumnsMenu;

  /// No description provided for @selectColumnsTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Columns'**
  String get selectColumnsTitle;

  /// No description provided for @selectProcessColumnsDescription.
  ///
  /// In en, this message translates to:
  /// **'Select the columns that will appear on the Process page of the Task Manager.'**
  String get selectProcessColumnsDescription;

  /// No description provided for @showKernelTimes.
  ///
  /// In en, this message translates to:
  /// **'Show &Kernel Times'**
  String get showKernelTimes;

  /// No description provided for @restoreTaskManager.
  ///
  /// In en, this message translates to:
  /// **'&Restore Task Manager'**
  String get restoreTaskManager;

  /// No description provided for @endProcess.
  ///
  /// In en, this message translates to:
  /// **'&End Process'**
  String get endProcess;

  /// No description provided for @endProcessTree.
  ///
  /// In en, this message translates to:
  /// **'End Process &Tree'**
  String get endProcessTree;

  /// No description provided for @openFileLocation.
  ///
  /// In en, this message translates to:
  /// **'Open File &Location'**
  String get openFileLocation;

  /// No description provided for @debug.
  ///
  /// In en, this message translates to:
  /// **'&Debug'**
  String get debug;

  /// No description provided for @setPriority.
  ///
  /// In en, this message translates to:
  /// **'Set &Priority'**
  String get setPriority;

  /// No description provided for @realtime.
  ///
  /// In en, this message translates to:
  /// **'&Realtime'**
  String get realtime;

  /// No description provided for @aboveNormal.
  ///
  /// In en, this message translates to:
  /// **'&Above Normal'**
  String get aboveNormal;

  /// No description provided for @belowNormal.
  ///
  /// In en, this message translates to:
  /// **'&Below Normal'**
  String get belowNormal;

  /// No description provided for @setAffinity.
  ///
  /// In en, this message translates to:
  /// **'Set &Affinity...'**
  String get setAffinity;

  /// No description provided for @switchTo.
  ///
  /// In en, this message translates to:
  /// **'&Switch To'**
  String get switchTo;

  /// No description provided for @endTask.
  ///
  /// In en, this message translates to:
  /// **'&End Task'**
  String get endTask;

  /// No description provided for @goToProcess.
  ///
  /// In en, this message translates to:
  /// **'&Go To Process'**
  String get goToProcess;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'&Disconnect'**
  String get disconnect;

  /// No description provided for @logoff.
  ///
  /// In en, this message translates to:
  /// **'&Logoff'**
  String get logoff;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'&Send Message...'**
  String get sendMessage;

  /// No description provided for @sendMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Message'**
  String get sendMessageTitle;

  /// No description provided for @taskManager.
  ///
  /// In en, this message translates to:
  /// **'Task Manager'**
  String get taskManager;

  /// No description provided for @handles.
  ///
  /// In en, this message translates to:
  /// **'Handles'**
  String get handles;

  /// No description provided for @threads.
  ///
  /// In en, this message translates to:
  /// **'Threads'**
  String get threads;

  /// No description provided for @processesLabel.
  ///
  /// In en, this message translates to:
  /// **'Processes'**
  String get processesLabel;

  /// No description provided for @cpuUsageHistory.
  ///
  /// In en, this message translates to:
  /// **'CPU Usage History'**
  String get cpuUsageHistory;

  /// No description provided for @cpuUsage.
  ///
  /// In en, this message translates to:
  /// **'CPU Usage'**
  String get cpuUsage;

  /// No description provided for @memUsage.
  ///
  /// In en, this message translates to:
  /// **'MEM Usage'**
  String get memUsage;

  /// No description provided for @memoryUsageHistory.
  ///
  /// In en, this message translates to:
  /// **'Memory Usage History'**
  String get memoryUsageHistory;

  /// No description provided for @physicalMemoryK.
  ///
  /// In en, this message translates to:
  /// **'Physical Memory (K)'**
  String get physicalMemoryK;

  /// No description provided for @commitChargeK.
  ///
  /// In en, this message translates to:
  /// **'Commit Charge (K)'**
  String get commitChargeK;

  /// No description provided for @kernelMemoryK.
  ///
  /// In en, this message translates to:
  /// **'Kernel Memory (K)'**
  String get kernelMemoryK;

  /// No description provided for @totals.
  ///
  /// In en, this message translates to:
  /// **'Totals'**
  String get totals;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @fileCache.
  ///
  /// In en, this message translates to:
  /// **'File Cache'**
  String get fileCache;

  /// No description provided for @paged.
  ///
  /// In en, this message translates to:
  /// **'Paged'**
  String get paged;

  /// No description provided for @nonpaged.
  ///
  /// In en, this message translates to:
  /// **'Nonpaged'**
  String get nonpaged;

  /// No description provided for @limit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get limit;

  /// No description provided for @peak.
  ///
  /// In en, this message translates to:
  /// **'Peak'**
  String get peak;

  /// No description provided for @noActiveNetworkAdaptersFound.
  ///
  /// In en, this message translates to:
  /// **'No Active Network Adapters Found.'**
  String get noActiveNetworkAdaptersFound;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @imageName.
  ///
  /// In en, this message translates to:
  /// **'&Image Name'**
  String get imageName;

  /// No description provided for @pidProcessIdentifier.
  ///
  /// In en, this message translates to:
  /// **'PID (Process Identifier)'**
  String get pidProcessIdentifier;

  /// No description provided for @userName.
  ///
  /// In en, this message translates to:
  /// **'User Name'**
  String get userName;

  /// No description provided for @sessionId.
  ///
  /// In en, this message translates to:
  /// **'Session ID'**
  String get sessionId;

  /// No description provided for @cpuTime.
  ///
  /// In en, this message translates to:
  /// **'CPU Time'**
  String get cpuTime;

  /// No description provided for @memoryUsage.
  ///
  /// In en, this message translates to:
  /// **'Memory Usage'**
  String get memoryUsage;

  /// No description provided for @memoryUsageDelta.
  ///
  /// In en, this message translates to:
  /// **'Memory Usage Delta'**
  String get memoryUsageDelta;

  /// No description provided for @pageFaults.
  ///
  /// In en, this message translates to:
  /// **'Page Faults'**
  String get pageFaults;

  /// No description provided for @pageFaultsDelta.
  ///
  /// In en, this message translates to:
  /// **'Page Faults Delta'**
  String get pageFaultsDelta;

  /// No description provided for @virtualMemorySize.
  ///
  /// In en, this message translates to:
  /// **'Virtual Memory Size'**
  String get virtualMemorySize;

  /// No description provided for @pagedPool.
  ///
  /// In en, this message translates to:
  /// **'Paged Pool'**
  String get pagedPool;

  /// No description provided for @nonPagedPool.
  ///
  /// In en, this message translates to:
  /// **'Non-paged Pool'**
  String get nonPagedPool;

  /// No description provided for @basePriority.
  ///
  /// In en, this message translates to:
  /// **'Base Priority'**
  String get basePriority;

  /// No description provided for @handleCount.
  ///
  /// In en, this message translates to:
  /// **'Handle Count'**
  String get handleCount;

  /// No description provided for @threadCount.
  ///
  /// In en, this message translates to:
  /// **'Thread Count'**
  String get threadCount;

  /// No description provided for @processorAffinity.
  ///
  /// In en, this message translates to:
  /// **'Processor Affinity'**
  String get processorAffinity;

  /// No description provided for @processors.
  ///
  /// In en, this message translates to:
  /// **'Processors'**
  String get processors;

  /// No description provided for @processorAffinityDescription.
  ///
  /// In en, this message translates to:
  /// **'Controls which CPUs in the selected processor group the process may execute on.'**
  String get processorAffinityDescription;

  /// No description provided for @messageTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'&Message title:'**
  String get messageTitleLabel;

  /// No description provided for @messageLabel.
  ///
  /// In en, this message translates to:
  /// **'Me&ssage:'**
  String get messageLabel;

  /// No description provided for @showFullAccountName.
  ///
  /// In en, this message translates to:
  /// **'&Show Full Account Name'**
  String get showFullAccountName;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @clientName.
  ///
  /// In en, this message translates to:
  /// **'Client Name'**
  String get clientName;

  /// No description provided for @session.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get session;

  /// No description provided for @adapter.
  ///
  /// In en, this message translates to:
  /// **'Adapter'**
  String get adapter;

  /// No description provided for @networkUtilization.
  ///
  /// In en, this message translates to:
  /// **'Network Utilization'**
  String get networkUtilization;

  /// No description provided for @linkSpeed.
  ///
  /// In en, this message translates to:
  /// **'Link Speed'**
  String get linkSpeed;

  /// No description provided for @state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// No description provided for @bytesSent.
  ///
  /// In en, this message translates to:
  /// **'Bytes Sent'**
  String get bytesSent;

  /// No description provided for @bytesReceived.
  ///
  /// In en, this message translates to:
  /// **'Bytes Received'**
  String get bytesReceived;

  /// No description provided for @bytesTotal.
  ///
  /// In en, this message translates to:
  /// **'Bytes Total'**
  String get bytesTotal;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// No description provided for @disconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting'**
  String get disconnecting;

  /// No description provided for @hardwareMissing.
  ///
  /// In en, this message translates to:
  /// **'Hardware Missing'**
  String get hardwareMissing;

  /// No description provided for @hardwareDisabled.
  ///
  /// In en, this message translates to:
  /// **'Hardware Disabled'**
  String get hardwareDisabled;

  /// No description provided for @hardwareMalfunction.
  ///
  /// In en, this message translates to:
  /// **'Hardware Malfunction'**
  String get hardwareMalfunction;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @connectQuery.
  ///
  /// In en, this message translates to:
  /// **'Connect Query'**
  String get connectQuery;

  /// No description provided for @shadow.
  ///
  /// In en, this message translates to:
  /// **'Shadow'**
  String get shadow;

  /// No description provided for @idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idle;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get listening;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @down.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get down;

  /// No description provided for @init.
  ///
  /// In en, this message translates to:
  /// **'Init'**
  String get init;

  /// No description provided for @bitness32Suffix.
  ///
  /// In en, this message translates to:
  /// **'(32-bit)'**
  String get bitness32Suffix;

  /// No description provided for @notResponding.
  ///
  /// In en, this message translates to:
  /// **'Not Responding'**
  String get notResponding;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @messageCouldNotBeSent.
  ///
  /// In en, this message translates to:
  /// **'The message could not be sent.'**
  String get messageCouldNotBeSent;

  /// No description provided for @unableToOpenFileLocation.
  ///
  /// In en, this message translates to:
  /// **'Unable to Open File Location'**
  String get unableToOpenFileLocation;

  /// No description provided for @killProcessTreePrompt.
  ///
  /// In en, this message translates to:
  /// **'This operation will attempt to terminate this process and any\nprocesses which were directly or indirectly started by it.\n\nForcing processes to terminate in this manner can cause\ndata loss and system instability.\n\nAre you sure you wish to continue?'**
  String get killProcessTreePrompt;

  /// No description provided for @killProcessTreeFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to Completely End the Process Tree'**
  String get killProcessTreeFailed;

  /// No description provided for @killProcessTreeFailedBody.
  ///
  /// In en, this message translates to:
  /// **'One or more of the processes in this process tree could not\nbe ended. The operation was not fully successful.'**
  String get killProcessTreeFailedBody;

  /// No description provided for @confirmLogoffSelectedUsers.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logoff the selected user(s)?'**
  String get confirmLogoffSelectedUsers;

  /// No description provided for @confirmDisconnectSelectedUsers.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to disconnect the selected user(s)?'**
  String get confirmDisconnectSelectedUsers;

  /// No description provided for @selectedUserCouldNotBeLoggedOff.
  ///
  /// In en, this message translates to:
  /// **'The selected user could not be logged off.'**
  String get selectedUserCouldNotBeLoggedOff;

  /// No description provided for @selectedUserCouldNotBeDisconnected.
  ///
  /// In en, this message translates to:
  /// **'The selected user could not be disconnected.'**
  String get selectedUserCouldNotBeDisconnected;

  /// No description provided for @win32ErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Win32 error:'**
  String get win32ErrorPrefix;

  /// No description provided for @processColumnFileDescriptorCount.
  ///
  /// In en, this message translates to:
  /// **'File Descriptors'**
  String get processColumnFileDescriptorCount;

  /// No description provided for @processColumnNice.
  ///
  /// In en, this message translates to:
  /// **'Nice'**
  String get processColumnNice;

  /// No description provided for @processColumnCgroup.
  ///
  /// In en, this message translates to:
  /// **'Cgroup'**
  String get processColumnCgroup;

  /// No description provided for @setNice.
  ///
  /// In en, this message translates to:
  /// **'Set &Nice Value...'**
  String get setNice;

  /// No description provided for @setNiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Nice Value'**
  String get setNiceTitle;

  /// No description provided for @niceValueLabel.
  ///
  /// In en, this message translates to:
  /// **'&Nice value:'**
  String get niceValueLabel;

  /// No description provided for @niceValueDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a nice value from -20 (highest priority) to 19 (lowest priority).'**
  String get niceValueDescription;

  /// No description provided for @invalidNiceValue.
  ///
  /// In en, this message translates to:
  /// **'The nice value must be an integer between -20 and 19.'**
  String get invalidNiceValue;

  /// No description provided for @niceChangeWarning.
  ///
  /// In en, this message translates to:
  /// **'Changing process priority may affect system stability. Are you sure you want to change the nice value?'**
  String get niceChangeWarning;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'pt',
    'ru',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
