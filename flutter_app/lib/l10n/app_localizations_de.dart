// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Windows NT Task-Manager';

  @override
  String get runTitle => 'Ausführen';

  @override
  String get runPrompt =>
      'Geben Sie den Namen eines Programms, Ordners, Dokuments oder einer Internetressource ein, und Windows wird es für Sie öffnen.';

  @override
  String get runCommandRequired =>
      'Geben Sie den Namen eines Programms, Ordners, Dokuments oder einer Internetressource ein.';

  @override
  String get applicationsPageTitle => 'Anwendungen';

  @override
  String get processesPageTitle => 'Prozesse';

  @override
  String get performancePageTitle => 'Leistung';

  @override
  String get cpuPageTitle => 'CPU';

  @override
  String get gpuPageTitle => 'GPU';

  @override
  String get networkingPageTitle => 'Netzwerk';

  @override
  String get usersPageTitle => 'Benutzer';

  @override
  String get taskManagerDisabled =>
      'Der Task-Manager wurde durch den Administrator deaktiviert.';

  @override
  String get warningTitle => 'Task-Manager-Warnung';

  @override
  String get priorityChangeWarning =>
      'WARNUNG: Das Ändern der Prioritätsklasse dieses Prozesses kann unerwünschte Folgen bis hin zur Systeminstabilität haben. Möchten Sie die Prioritätsklasse wirklich ändern?';

  @override
  String get killProcessWarning =>
      'WARNUNG: Das Beenden eines Prozesses kann unerwünschte Folgen einschließlich Datenverlust und Systeminstabilität haben. Der Prozess kann seinen Zustand oder Daten vor dem Beenden nicht speichern. Möchten Sie den Prozess wirklich beenden?';

  @override
  String get debugProcessWarning =>
      'WARNUNG: Das Debuggen dieses Prozesses kann zu Datenverlust führen. Möchten Sie den Debugger wirklich anhängen?';

  @override
  String get invalidOptionTitle => 'Ungültige Option';

  @override
  String get noAffinityMaskMessage =>
      'Der Prozess muss mindestens einem Prozessor zugeordnet sein.';

  @override
  String get unableToTerminateProcess => 'Prozess konnte nicht beendet werden';

  @override
  String get unableToAttachDebugger => 'Debugger konnte nicht angefügt werden';

  @override
  String get unableToChangePriority => 'Priorität konnte nicht geändert werden';

  @override
  String get unableToSetAffinity =>
      'Der Vorgang konnte nicht abgeschlossen werden.\n\n';

  @override
  String get formatProcesses => 'Prozesse: %d';

  @override
  String get formatCpuUsage => 'CPU-Auslastung: %d%%';

  @override
  String get formatMemoryUsage => 'Speicherauslastung: %dK / %dK';

  @override
  String get formatCpuNumber => 'CPU %d';

  @override
  String get totalCpu => 'Gesamt-CPU';

  @override
  String get kernelCpu => 'Kernel-CPU';

  @override
  String get cpuLoading => 'CPU-Diagnosedaten werden geladen...';

  @override
  String get cpuLoadingDetails =>
      'CPU-Basisinformationen sind bereit; Leistungs- und Firmwaredetails werden geladen...';

  @override
  String get cpuPartialDetails => 'Einige CPU-Details sind nicht verfügbar.';

  @override
  String get cpuUnavailable =>
      'CPU-Topologieinformationen sind nicht verfügbar.';

  @override
  String get cpuRefreshFailed =>
      'CPU-Diagnosedaten konnten nicht aktualisiert werden.';

  @override
  String get cpuRefreshFailedStale =>
      'CPU-Diagnosedaten konnten nicht aktualisiert werden; die letzten erfolgreichen Werte werden angezeigt.';

  @override
  String get cpuCurrentState => 'Aktueller Zustand';

  @override
  String get cpuSystemDiagnostics => 'Systemdiagnose';

  @override
  String get cpuTopologyFeatures => 'Topologie und Funktionen';

  @override
  String get cpuHardwareCache => 'Hardware und Cache';

  @override
  String get cpuAverageFrequency => 'Durchschnittsfrequenz';

  @override
  String get cpuFrequencyRange => 'Frequenzbereich';

  @override
  String get cpuUserTime => 'Benutzer';

  @override
  String get cpuKernelTime => 'Kernel';

  @override
  String get cpuDpcTime => 'DPC';

  @override
  String get cpuInterruptTime => 'Interrupt';

  @override
  String get cpuInterruptsPerSecond => 'Interrupts/s';

  @override
  String get cpuUptime => 'Betriebszeit';

  @override
  String get cpuProcessorQueueLength => 'Prozessorwarteschlange';

  @override
  String get cpuContextSwitchesPerSecond => 'Kontextwechsel/s';

  @override
  String get cpuSystemCallsPerSecond => 'Systemaufrufe/s';

  @override
  String get cpuPackages => 'Pakete';

  @override
  String get cpuNumaNodes => 'NUMA-Knoten';

  @override
  String get cpuGroups => 'Gruppen';

  @override
  String get cpuDies => 'Dies';

  @override
  String get cpuModules => 'Module';

  @override
  String get cpuPhysicalCores => 'Physische Kerne';

  @override
  String get cpuLogicalProcessors => 'Logische Prozessoren';

  @override
  String get cpuCoreClasses => 'Kernklassen';

  @override
  String get cpuSmtCores => 'SMT-Kerne';

  @override
  String get cpuThreadsPerCore => 'Threads/Kern';

  @override
  String get cpuVirtualization => 'Virtualisierung';

  @override
  String get cpuSlat => 'SLAT';

  @override
  String get cpuManufacturer => 'Hersteller';

  @override
  String get cpuSocket => 'Sockel';

  @override
  String get cpuProcessorId => 'Prozessor-ID';

  @override
  String get cpuArchitectureWidth => 'Architektur / Breite';

  @override
  String get cpuFamilyLevel => 'Familie / Ebene';

  @override
  String get cpuRevisionStepping => 'Revision / Stepping';

  @override
  String get cpuFirmwareMaxFrequency => 'Firmware-Maximalfrequenz';

  @override
  String get cpuIsaFeatures => 'ISA-Funktionen';

  @override
  String get cpuCacheL1Data => 'L1-Datencache';

  @override
  String get cpuCacheL1Instruction => 'L1-Befehlscache';

  @override
  String get cpuCacheL2 => 'L2-Cache';

  @override
  String get cpuCacheL3 => 'L3-Cache';

  @override
  String get cpuUniformClass => 'Einheitlich';

  @override
  String get cpuYes => 'Ja';

  @override
  String get cpuNo => 'Nein';

  @override
  String get cpuFullyAssociative => 'Vollassoziativ';

  @override
  String get cpuSockets => 'Sockel';

  @override
  String get gpuLoading => 'GPU-Daten werden geladen...';

  @override
  String get gpuLoadingPerformance =>
      'GPU-Basisinformationen sind bereit; Leistungsdaten werden geladen...';

  @override
  String get gpuLoadingDetails =>
      'GPU-Leistungsdaten sind bereit; Hardwaredetails werden geladen...';

  @override
  String get gpuPartialDetails => 'Einige GPU-Details sind nicht verfügbar.';

  @override
  String get noHardwareGpusFound => 'Keine Hardware-GPUs gefunden.';

  @override
  String get gpuRequiresWddm2 =>
      'Es sind keine GPU-Leistungsindikatoren verfügbar. Diese Funktion erfordert einen WDDM-2.0- oder neueren Anzeigetreiber.';

  @override
  String get gpuRefreshFailed => 'GPU-Daten konnten nicht aktualisiert werden.';

  @override
  String get gpuRefreshFailedStale =>
      'GPU-Daten konnten nicht aktualisiert werden; die letzte erfolgreiche Messung wird angezeigt.';

  @override
  String get gpuCurrentMetrics => 'Aktuell';

  @override
  String get gpuAdapterDetails => 'Adapterdetails';

  @override
  String get gpuUtilization => 'Auslastung';

  @override
  String get gpuMemory => 'GPU-Speicher';

  @override
  String get gpuDedicatedMemory => 'Dedizierter GPU-Speicher';

  @override
  String get gpuSharedMemory => 'Gemeinsam genutzter GPU-Speicher';

  @override
  String get gpuTemperature => 'Temperatur';

  @override
  String get gpuDriverVersion => 'Treiberversion';

  @override
  String get gpuDriverDate => 'Treiberdatum';

  @override
  String get gpuDirectXVersion => 'DirectX-Version';

  @override
  String get gpuPhysicalLocation => 'Physischer Speicherort';

  @override
  String get gpuHardwareReservedMemory => 'Für Hardware reservierter Speicher';

  @override
  String get gpuEngine3D => '3D';

  @override
  String get gpuEngineCopy => 'Kopieren';

  @override
  String get gpuEngineVideoEncode => 'Videocodierung';

  @override
  String get gpuEngineVideoDecode => 'Videodecodierung';

  @override
  String get gpuEngineCompute => 'Berechnung';

  @override
  String get gpuEngineSecurity => 'Sicherheit';

  @override
  String get notAvailable => 'Nicht verfügbar';

  @override
  String get taskColumnTask => 'Task';

  @override
  String get taskColumnStatus => 'Status';

  @override
  String get taskColumnWinstation => 'Fensterstation';

  @override
  String get taskColumnDesktop => 'Desktop';

  @override
  String get processColumnImageName => 'Abbildname';

  @override
  String get processColumnPid => 'PID';

  @override
  String get processColumnCpu => 'CPU';

  @override
  String get processColumnCpuTime => 'CPU-Zeit';

  @override
  String get processColumnMemoryUsage => 'Speicherauslastung';

  @override
  String get processColumnMemoryUsageDelta => 'Speicherdelta';

  @override
  String get processColumnPageFaults => 'Seitenfehler';

  @override
  String get processColumnPageFaultsDelta => 'PF-Delta';

  @override
  String get processColumnVirtualMemorySize => 'VM-Groesse';

  @override
  String get processColumnPagedPool => 'Ausgelagerter Pool';

  @override
  String get processColumnNonPagedPool => 'Nicht ausgelagerter Pool';

  @override
  String get processColumnBasePriority => 'Basisprioritaet';

  @override
  String get processColumnHandleCount => 'Handles';

  @override
  String get processColumnThreadCount => 'Threads';

  @override
  String get processColumnSessionId => 'Sitzungs-ID';

  @override
  String get processColumnUserName => 'Benutzername';

  @override
  String get file => '&Datei';

  @override
  String get options => '&Optionen';

  @override
  String get view => '&Ansicht';

  @override
  String get windows => '&Fenster';

  @override
  String get help => '&Hilfe';

  @override
  String get updateSpeed => '&Aktualisierungsgeschwindigkeit';

  @override
  String get cpuHistory => '&CPU-Verlauf';

  @override
  String get newTaskMenu => '&Ausführen...';

  @override
  String get newTaskButton => '&Ausführen...';

  @override
  String get exitTaskManager => 'Task-Manager be&enden';

  @override
  String get alwaysOnTop => '&Immer im Vordergrund';

  @override
  String get minimizeOnUse => 'Nach Verwendung &minimieren';

  @override
  String get confirmations => '&Bestaetigungen';

  @override
  String get hideWhenMinimized => 'Beim Minimieren &ausblenden';

  @override
  String get refreshNow => '&Jetzt aktualisieren';

  @override
  String get high => '&Hoch';

  @override
  String get normal => '&Normal';

  @override
  String get low => '&Niedrig';

  @override
  String get paused => '&Angehalten';

  @override
  String get largeIcons => 'Gro&sse Symbole';

  @override
  String get smallIcons => '&Kleine Symbole';

  @override
  String get details => '&Details';

  @override
  String get tileHorizontally => 'Hori&zontal anordnen';

  @override
  String get tileVertically => '&Vertikal anordnen';

  @override
  String get minimize => '&Minimieren';

  @override
  String get maximize => 'Ma&ximieren';

  @override
  String get cascade => '&Ueberlappend';

  @override
  String get bringToFront => 'In den &Vordergrund';

  @override
  String get helpTopics => 'Task-Manager-&Hilfethemen';

  @override
  String get helpOpenFailed =>
      'Die Task-Manager-Hilfe konnte nicht geöffnet werden.';

  @override
  String get diagnosticLogs => '&Diagnoseprotokolle...';

  @override
  String get diagnosticLogsTitle => 'Diagnoseprotokolle';

  @override
  String get diagnosticStatusLabel => 'Status:';

  @override
  String get diagnosticSessionLabel => 'Sitzung:';

  @override
  String get diagnosticDirectoryLabel => 'Ordner:';

  @override
  String get diagnosticDetailedCurrentSession =>
      'Detaillierte Protokolle für diese Sitzung aufzeichnen';

  @override
  String get diagnosticIncludeSensitive =>
      'Vertrauliche Informationen einschließen';

  @override
  String get diagnosticCaptureMinidump =>
      'Bei einem Absturz ein Speicherabbild erstellen';

  @override
  String get diagnosticMinidumpPrivacy =>
      'Speicherabbilder können private Informationen enthalten.';

  @override
  String get diagnosticRestartDetailed =>
      'Mit detaillierter Protokollierung neu starten';

  @override
  String get diagnosticOpenFolder => 'Protokollordner öffnen';

  @override
  String get diagnosticSaveBundle => 'Diagnosepaket speichern...';

  @override
  String get diagnosticLoggingActive => 'Protokollierung aktiv (%s)';

  @override
  String get diagnosticLoggingUnavailable =>
      'Dateiprotokollierung nicht verfügbar';

  @override
  String get diagnosticDroppedEvents => 'Verworfene Ereignisse: %s';

  @override
  String get diagnosticExporting => 'Diagnosepaket wird gespeichert...';

  @override
  String get diagnosticExportSucceeded => 'Diagnosepaket wurde gespeichert.';

  @override
  String get diagnosticExportFailedTitle =>
      'Diagnosepaket konnte nicht gespeichert werden';

  @override
  String get diagnosticSensitiveExportWarning =>
      'Dieses Paket enthält ein Speicherabbild oder während der vertraulichen Protokollierung erfasste Felder und kann private Informationen enthalten. Fortfahren?';

  @override
  String get diagnosticRestartFailed =>
      'Der Task-Manager konnte nicht mit detaillierter Protokollierung neu gestartet werden.';

  @override
  String get diagnosticOpenFolderFailed =>
      'Der Diagnoseprotokollordner konnte nicht geöffnet werden.';

  @override
  String get aboutTaskManager => '&Info zu Task-Manager';

  @override
  String get oneGraphAllCpus => 'Ein Diagramm, &alle CPUs';

  @override
  String get oneGraphPerCpu => 'Ein Diagramm &pro CPU';

  @override
  String get selectColumnsMenu => 'Spalten auswaehlen...';

  @override
  String get selectColumnsTitle => 'Spalten auswaehlen';

  @override
  String get selectProcessColumnsDescription =>
      'Waehlen Sie die Spalten aus, die auf der Prozessseite des Task-Managers angezeigt werden sollen.';

  @override
  String get showKernelTimes => '&Kernelzeiten anzeigen';

  @override
  String get restoreTaskManager => 'Task-Manager &wiederherstellen';

  @override
  String get endProcess => 'Prozess &beenden';

  @override
  String get endProcessTree => 'End Process &Tree';

  @override
  String get openFileLocation => 'Open File &Location';

  @override
  String get debug => '&Debuggen';

  @override
  String get setPriority => '&Prioritaet festlegen';

  @override
  String get realtime => '&Echtzeit';

  @override
  String get aboveNormal => '&Above Normal';

  @override
  String get belowNormal => '&Below Normal';

  @override
  String get setAffinity => '&Affinitaet festlegen...';

  @override
  String get switchTo => '&Wechseln zu';

  @override
  String get endTask => 'Task &beenden';

  @override
  String get goToProcess => '&Zum Prozess wechseln';

  @override
  String get disconnect => '&Trennen';

  @override
  String get logoff => 'A&bmelden';

  @override
  String get sendMessage => '&Nachricht senden...';

  @override
  String get sendMessageTitle => 'Nachricht senden';

  @override
  String get taskManager => 'Task-Manager';

  @override
  String get handles => 'Handles';

  @override
  String get threads => 'Threads';

  @override
  String get processesLabel => 'Prozesse';

  @override
  String get cpuUsageHistory => 'CPU-Auslastungsverlauf';

  @override
  String get cpuUsage => 'CPU-Auslastung';

  @override
  String get memUsage => 'Speicherauslastung';

  @override
  String get memoryUsageHistory => 'Speicherauslastungsverlauf';

  @override
  String get physicalMemoryK => 'Physischer Speicher (K)';

  @override
  String get commitChargeK => 'Zugesicherter Speicher (K)';

  @override
  String get kernelMemoryK => 'Kernelspeicher (K)';

  @override
  String get totals => 'Summen';

  @override
  String get total => 'Gesamt';

  @override
  String get available => 'Verfuegbar';

  @override
  String get fileCache => 'Dateicache';

  @override
  String get paged => 'Ausgelagert';

  @override
  String get nonpaged => 'Nicht ausgelagert';

  @override
  String get limit => 'Limit';

  @override
  String get peak => 'Spitze';

  @override
  String get noActiveNetworkAdaptersFound =>
      'Keine aktiven Netzwerkadapter gefunden.';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get close => 'Schließen';

  @override
  String get imageName => 'Abbildname';

  @override
  String get pidProcessIdentifier => 'PID (Prozesskennung)';

  @override
  String get userName => 'Benutzername';

  @override
  String get sessionId => 'Sitzungs-ID';

  @override
  String get cpuTime => 'CPU-Zeit';

  @override
  String get memoryUsage => 'Speicherauslastung';

  @override
  String get memoryUsageDelta => 'Aenderung der Speicherauslastung';

  @override
  String get pageFaults => 'Seitenfehler';

  @override
  String get pageFaultsDelta => 'Aenderung der Seitenfehler';

  @override
  String get virtualMemorySize => 'Groesse des virtuellen Speichers';

  @override
  String get pagedPool => 'Ausgelagerter Pool';

  @override
  String get nonPagedPool => 'Nicht ausgelagerter Pool';

  @override
  String get basePriority => 'Basisprioritaet';

  @override
  String get handleCount => 'Handleanzahl';

  @override
  String get threadCount => 'Threadanzahl';

  @override
  String get processorAffinity => 'Prozessoraffinitaet';

  @override
  String get processors => 'Prozessoren';

  @override
  String get processorAffinityDescription =>
      'Legt fest, auf welchen CPUs der ausgewaehlten Prozessorgruppe der Prozess ausgefuehrt werden darf.';

  @override
  String get messageTitleLabel => 'Nachrichtentitel:';

  @override
  String get messageLabel => 'Nachricht:';

  @override
  String get showFullAccountName => 'Vollständigen Kontonamen anzeigen';

  @override
  String get user => 'Benutzer';

  @override
  String get status => 'Status';

  @override
  String get clientName => 'Clientname';

  @override
  String get session => 'Sitzung';

  @override
  String get adapter => 'Adapter';

  @override
  String get networkUtilization => 'Netzwerkauslastung';

  @override
  String get linkSpeed => 'Verbindungsgeschwindigkeit';

  @override
  String get state => 'Status';

  @override
  String get bytesSent => 'Gesendete Bytes';

  @override
  String get bytesReceived => 'Empfangene Bytes';

  @override
  String get bytesTotal => 'Bytes gesamt';

  @override
  String get connected => 'Verbunden';

  @override
  String get disconnected => 'Getrennt';

  @override
  String get connecting => 'Wird verbunden';

  @override
  String get disconnecting => 'Wird getrennt';

  @override
  String get hardwareMissing => 'Hardware fehlt';

  @override
  String get hardwareDisabled => 'Hardware deaktiviert';

  @override
  String get hardwareMalfunction => 'Hardwarefehler';

  @override
  String get unknown => 'Unbekannt';

  @override
  String get active => 'Aktiv';

  @override
  String get connectQuery => 'Verbindungsabfrage';

  @override
  String get shadow => 'Schatten';

  @override
  String get idle => 'Leerlauf';

  @override
  String get listening => 'Lauscht';

  @override
  String get reset => 'Zuruecksetzen';

  @override
  String get down => 'Inaktiv';

  @override
  String get init => 'Initialisierung';

  @override
  String get bitness32Suffix => '(32-Bit)';

  @override
  String get notResponding => 'Keine Rueckmeldung';

  @override
  String get running => 'Wird ausgefuehrt';

  @override
  String get messageCouldNotBeSent =>
      'Die Nachricht konnte nicht gesendet werden.';

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
      'Moechten Sie die ausgewaehlten Benutzer wirklich abmelden?';

  @override
  String get confirmDisconnectSelectedUsers =>
      'Moechten Sie die ausgewaehlten Benutzer wirklich trennen?';

  @override
  String get selectedUserCouldNotBeLoggedOff =>
      'Der ausgewaehlte Benutzer konnte nicht abgemeldet werden.';

  @override
  String get selectedUserCouldNotBeDisconnected =>
      'Der ausgewaehlte Benutzer konnte nicht getrennt werden.';

  @override
  String get win32ErrorPrefix => 'Win32-Fehler:';

  @override
  String get processColumnFileDescriptorCount => 'Dateideskriptoren';

  @override
  String get processColumnNice => 'Nice-Wert';

  @override
  String get processColumnCgroup => 'Cgroup';

  @override
  String get setNice => '&Nice-Wert festlegen...';

  @override
  String get setNiceTitle => 'Nice-Wert festlegen';

  @override
  String get niceValueLabel => '&Nice-Wert:';

  @override
  String get niceValueDescription =>
      'Geben Sie einen Nice-Wert von -20 (hoechste Prioritaet) bis 19 (niedrigste Prioritaet) ein.';

  @override
  String get invalidNiceValue =>
      'Der Nice-Wert muss eine ganze Zahl zwischen -20 und 19 sein.';

  @override
  String get niceChangeWarning =>
      'Das Aendern der Prozessprioritaet kann die Systemstabilitaet beeintraechtigen. Moechten Sie den Nice-Wert wirklich aendern?';
}
