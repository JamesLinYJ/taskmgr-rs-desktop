// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Gestionnaire des tâches Windows NT';

  @override
  String get runTitle => 'Exécuter';

  @override
  String get runPrompt =>
      'Tapez le nom d’un programme, dossier, document ou d’une ressource Internet, et Windows l’ouvrira pour vous.';

  @override
  String get runCommandRequired =>
      'Tapez le nom d’un programme, dossier, document ou d’une ressource Internet.';

  @override
  String get applicationsPageTitle => 'Applications';

  @override
  String get processesPageTitle => 'Processus';

  @override
  String get performancePageTitle => 'Performances';

  @override
  String get cpuPageTitle => 'CPU';

  @override
  String get gpuPageTitle => 'GPU';

  @override
  String get networkingPageTitle => 'Réseau';

  @override
  String get usersPageTitle => 'Utilisateurs';

  @override
  String get taskManagerDisabled =>
      'Le Gestionnaire des tâches a été désactivé par votre administrateur.';

  @override
  String get warningTitle => 'Avertissement du Gestionnaire des tâches';

  @override
  String get priorityChangeWarning =>
      'AVERTISSEMENT : la modification de la classe de priorité de ce processus peut entraîner des résultats indésirables, y compris une instabilité du système. Voulez-vous vraiment modifier la classe de priorité ?';

  @override
  String get killProcessWarning =>
      'AVERTISSEMENT : la fin d\'un processus peut entraîner des résultats indésirables, notamment une perte de données et une instabilité du système. Le processus n\'aura pas la possibilité d\'enregistrer son état ou ses données avant d\'être terminé. Voulez-vous vraiment terminer ce processus ?';

  @override
  String get debugProcessWarning =>
      'AVERTISSEMENT : le débogage de ce processus peut entraîner une perte de données. Voulez-vous vraiment attacher le débogueur ?';

  @override
  String get invalidOptionTitle => 'Option non valide';

  @override
  String get noAffinityMaskMessage =>
      'Le processus doit avoir une affinité avec au moins un processeur.';

  @override
  String get unableToTerminateProcess => 'Impossible de terminer le processus';

  @override
  String get unableToAttachDebugger => 'Impossible d’attacher le débogueur';

  @override
  String get unableToChangePriority => 'Impossible de modifier la priorité';

  @override
  String get unableToSetAffinity => 'L’opération n’a pas pu être terminée.\n\n';

  @override
  String get formatProcesses => 'Processus : %d';

  @override
  String get formatCpuUsage => 'Utilisation CPU : %d%%';

  @override
  String get formatMemoryUsage => 'Utilisation mémoire : %dK / %dK';

  @override
  String get formatCpuNumber => 'CPU %d';

  @override
  String get totalCpu => 'CPU total';

  @override
  String get kernelCpu => 'CPU noyau';

  @override
  String get cpuLoading => 'Chargement du diagnostic du processeur...';

  @override
  String get cpuLoadingDetails =>
      'Les informations de base du processeur sont prêtes ; chargement des performances et du micrologiciel...';

  @override
  String get cpuPartialDetails =>
      'Certains détails du processeur ne sont pas disponibles.';

  @override
  String get cpuUnavailable =>
      'Les informations de topologie du processeur ne sont pas disponibles.';

  @override
  String get cpuRefreshFailed =>
      'Échec de la mise à jour du diagnostic du processeur.';

  @override
  String get cpuRefreshFailedStale =>
      'Échec de la mise à jour du processeur ; les dernières valeurs valides sont affichées.';

  @override
  String get cpuCurrentState => 'État actuel';

  @override
  String get cpuSystemDiagnostics => 'Diagnostic système';

  @override
  String get cpuTopologyFeatures => 'Topologie et fonctions';

  @override
  String get cpuHardwareCache => 'Matériel et cache';

  @override
  String get cpuAverageFrequency => 'Fréquence moyenne';

  @override
  String get cpuFrequencyRange => 'Plage de fréquence';

  @override
  String get cpuUserTime => 'Utilisateur';

  @override
  String get cpuKernelTime => 'Noyau';

  @override
  String get cpuDpcTime => 'DPC';

  @override
  String get cpuInterruptTime => 'Interruption';

  @override
  String get cpuInterruptsPerSecond => 'Interruptions/s';

  @override
  String get cpuUptime => 'Durée de fonctionnement';

  @override
  String get cpuProcessorQueueLength => 'File du processeur';

  @override
  String get cpuContextSwitchesPerSecond => 'Changements de contexte/s';

  @override
  String get cpuSystemCallsPerSecond => 'Appels système/s';

  @override
  String get cpuPackages => 'Packages';

  @override
  String get cpuNumaNodes => 'Nœuds NUMA';

  @override
  String get cpuGroups => 'Groupes';

  @override
  String get cpuDies => 'Dies';

  @override
  String get cpuModules => 'Modules';

  @override
  String get cpuPhysicalCores => 'Cœurs physiques';

  @override
  String get cpuLogicalProcessors => 'Processeurs logiques';

  @override
  String get cpuCoreClasses => 'Classes de cœur';

  @override
  String get cpuSmtCores => 'Cœurs SMT';

  @override
  String get cpuThreadsPerCore => 'Threads/cœur';

  @override
  String get cpuVirtualization => 'Virtualisation';

  @override
  String get cpuSlat => 'SLAT';

  @override
  String get cpuManufacturer => 'Fabricant';

  @override
  String get cpuSocket => 'Socket';

  @override
  String get cpuProcessorId => 'ID processeur';

  @override
  String get cpuArchitectureWidth => 'Architecture / largeur';

  @override
  String get cpuFamilyLevel => 'Famille / niveau';

  @override
  String get cpuRevisionStepping => 'Révision / stepping';

  @override
  String get cpuFirmwareMaxFrequency => 'Fréquence max. du firmware';

  @override
  String get cpuIsaFeatures => 'Fonctions ISA';

  @override
  String get cpuCacheL1Data => 'Cache de données L1';

  @override
  String get cpuCacheL1Instruction => 'Cache d’instructions L1';

  @override
  String get cpuCacheL2 => 'Cache L2';

  @override
  String get cpuCacheL3 => 'Cache L3';

  @override
  String get cpuUniformClass => 'Uniforme';

  @override
  String get cpuYes => 'Oui';

  @override
  String get cpuNo => 'Non';

  @override
  String get cpuFullyAssociative => 'Entièrement associatif';

  @override
  String get cpuSockets => 'sockets';

  @override
  String get gpuLoading => 'Chargement des données GPU...';

  @override
  String get gpuLoadingPerformance =>
      'Les informations de base du GPU sont prêtes ; chargement des performances...';

  @override
  String get gpuLoadingDetails =>
      'Les performances du GPU sont prêtes ; chargement des détails matériels...';

  @override
  String get gpuPartialDetails =>
      'Certains détails du GPU ne sont pas disponibles.';

  @override
  String get noHardwareGpusFound => 'Aucun GPU matériel trouvé.';

  @override
  String get gpuRequiresWddm2 =>
      'Aucun compteur de performances GPU n\'est disponible. Cette fonctionnalité nécessite un pilote d\'affichage WDDM 2.0 ou ultérieur.';

  @override
  String get gpuRefreshFailed => 'Échec de la mise à jour des données GPU.';

  @override
  String get gpuRefreshFailedStale =>
      'Échec de la mise à jour des données GPU ; le dernier échantillon valide est affiché.';

  @override
  String get gpuCurrentMetrics => 'Actuel';

  @override
  String get gpuAdapterDetails => 'Détails de l\'adaptateur';

  @override
  String get gpuUtilization => 'Utilisation';

  @override
  String get gpuMemory => 'Mémoire GPU';

  @override
  String get gpuDedicatedMemory => 'Mémoire GPU dédiée';

  @override
  String get gpuSharedMemory => 'Mémoire GPU partagée';

  @override
  String get gpuTemperature => 'Température';

  @override
  String get gpuDriverVersion => 'Version du pilote';

  @override
  String get gpuDriverDate => 'Date du pilote';

  @override
  String get gpuDirectXVersion => 'Version de DirectX';

  @override
  String get gpuPhysicalLocation => 'Emplacement physique';

  @override
  String get gpuHardwareReservedMemory => 'Mémoire réservée au matériel';

  @override
  String get gpuEngine3D => '3D';

  @override
  String get gpuEngineCopy => 'Copie';

  @override
  String get gpuEngineVideoEncode => 'Encodage vidéo';

  @override
  String get gpuEngineVideoDecode => 'Décodage vidéo';

  @override
  String get gpuEngineCompute => 'Calcul';

  @override
  String get gpuEngineSecurity => 'Sécurité';

  @override
  String get notAvailable => 'Non disponible';

  @override
  String get taskColumnTask => 'Tâche';

  @override
  String get taskColumnStatus => 'État';

  @override
  String get taskColumnWinstation => 'Station Win';

  @override
  String get taskColumnDesktop => 'Bureau';

  @override
  String get processColumnImageName => 'Nom de l\'image';

  @override
  String get processColumnPid => 'PID';

  @override
  String get processColumnCpu => 'CPU';

  @override
  String get processColumnCpuTime => 'Temps CPU';

  @override
  String get processColumnMemoryUsage => 'Utilisation mémoire';

  @override
  String get processColumnMemoryUsageDelta => 'Delta mémoire';

  @override
  String get processColumnPageFaults => 'Défauts de page';

  @override
  String get processColumnPageFaultsDelta => 'Delta défauts de page';

  @override
  String get processColumnVirtualMemorySize => 'Taille mémoire virtuelle';

  @override
  String get processColumnPagedPool => 'Pool paginé';

  @override
  String get processColumnNonPagedPool => 'Pool non paginé';

  @override
  String get processColumnBasePriority => 'Priorité de base';

  @override
  String get processColumnHandleCount => 'Handles';

  @override
  String get processColumnThreadCount => 'Threads';

  @override
  String get processColumnSessionId => 'ID de session';

  @override
  String get processColumnUserName => 'Nom d\'utilisateur';

  @override
  String get file => '&Fichier';

  @override
  String get options => '&Options';

  @override
  String get view => '&Affichage';

  @override
  String get windows => '&Fenêtres';

  @override
  String get help => '&Aide';

  @override
  String get updateSpeed => '&Vitesse de mise à jour';

  @override
  String get cpuHistory => '&Historique CPU';

  @override
  String get newTaskMenu => '&Exécuter...';

  @override
  String get newTaskButton => '&Exécuter...';

  @override
  String get exitTaskManager => '&Quitter le Gestionnaire des tâches';

  @override
  String get alwaysOnTop => '&Toujours visible';

  @override
  String get minimizeOnUse => '&Réduire après utilisation';

  @override
  String get confirmations => '&Confirmations';

  @override
  String get hideWhenMinimized => '&Masquer lors de la réduction';

  @override
  String get refreshNow => '&Actualiser';

  @override
  String get high => '&Élevée';

  @override
  String get normal => '&Normale';

  @override
  String get low => '&Faible';

  @override
  String get paused => '&Suspendu';

  @override
  String get largeIcons => '&Grandes icônes';

  @override
  String get smallIcons => '&Petites icônes';

  @override
  String get details => '&Détails';

  @override
  String get tileHorizontally => 'Mosaïque &horizontale';

  @override
  String get tileVertically => 'Mosaïque &verticale';

  @override
  String get minimize => '&Réduire';

  @override
  String get maximize => 'Ma&ximiser';

  @override
  String get cascade => '&Cascade';

  @override
  String get bringToFront => '&Mettre au premier plan';

  @override
  String get helpTopics => '&Rubriques d\'aide du Gestionnaire des tâches';

  @override
  String get helpOpenFailed =>
      'Impossible d’ouvrir l’aide du Gestionnaire des tâches.';

  @override
  String get diagnosticLogs => 'Journaux de &diagnostic...';

  @override
  String get diagnosticLogsTitle => 'Journaux de diagnostic';

  @override
  String get diagnosticStatusLabel => 'État :';

  @override
  String get diagnosticSessionLabel => 'Session :';

  @override
  String get diagnosticDirectoryLabel => 'Dossier :';

  @override
  String get diagnosticDetailedCurrentSession =>
      'Enregistrer les journaux détaillés de cette session';

  @override
  String get diagnosticIncludeSensitive => 'Inclure les informations sensibles';

  @override
  String get diagnosticCaptureMinidump =>
      'Créer un minidump si l\'application se bloque';

  @override
  String get diagnosticMinidumpPrivacy =>
      'Les vidages mémoire peuvent contenir des informations privées.';

  @override
  String get diagnosticRestartDetailed =>
      'Redémarrer avec la journalisation détaillée';

  @override
  String get diagnosticOpenFolder => 'Ouvrir le dossier des journaux';

  @override
  String get diagnosticSaveBundle => 'Enregistrer le paquet de diagnostic...';

  @override
  String get diagnosticLoggingActive => 'Journalisation active (%s)';

  @override
  String get diagnosticLoggingUnavailable =>
      'Journalisation dans un fichier indisponible';

  @override
  String get diagnosticDroppedEvents => 'Événements ignorés : %s';

  @override
  String get diagnosticExporting => 'Enregistrement du paquet de diagnostic...';

  @override
  String get diagnosticExportSucceeded => 'Paquet de diagnostic enregistré.';

  @override
  String get diagnosticExportFailedTitle =>
      'Impossible d\'enregistrer le paquet de diagnostic';

  @override
  String get diagnosticSensitiveExportWarning =>
      'Ce paquet contient un vidage mémoire ou des champs enregistrés avec la journalisation sensible et peut contenir des informations privées. Continuer ?';

  @override
  String get diagnosticRestartFailed =>
      'Le Gestionnaire des tâches n\'a pas pu redémarrer avec la journalisation détaillée.';

  @override
  String get diagnosticOpenFolderFailed =>
      'Impossible d\'ouvrir le dossier des journaux de diagnostic.';

  @override
  String get aboutTaskManager => '&À propos du Gestionnaire des tâches';

  @override
  String get oneGraphAllCpus => 'Un graphique, &tous les CPU';

  @override
  String get oneGraphPerCpu => 'Un graphique &par CPU';

  @override
  String get selectColumnsMenu => 'Choisir les colonnes...';

  @override
  String get selectColumnsTitle => 'Choisir les colonnes';

  @override
  String get selectProcessColumnsDescription =>
      'Sélectionnez les colonnes à afficher dans l\'onglet Processus du Gestionnaire des tâches.';

  @override
  String get showKernelTimes => 'Afficher les temps &noyau';

  @override
  String get restoreTaskManager => '&Restaurer le Gestionnaire des tâches';

  @override
  String get endProcess => '&Terminer le processus';

  @override
  String get endProcessTree => 'End Process &Tree';

  @override
  String get openFileLocation => 'Open File &Location';

  @override
  String get debug => '&Déboguer';

  @override
  String get setPriority => 'Définir la &priorité';

  @override
  String get realtime => '&Temps réel';

  @override
  String get aboveNormal => '&Above Normal';

  @override
  String get belowNormal => '&Below Normal';

  @override
  String get setAffinity => 'Définir l\'&affinité...';

  @override
  String get switchTo => '&Basculer vers';

  @override
  String get endTask => '&Fin de tâche';

  @override
  String get goToProcess => '&Aller au processus';

  @override
  String get disconnect => '&Déconnecter';

  @override
  String get logoff => '&Fermer la session';

  @override
  String get sendMessage => '&Envoyer un message...';

  @override
  String get sendMessageTitle => 'Envoyer un message';

  @override
  String get taskManager => 'Gestionnaire des tâches';

  @override
  String get handles => 'Handles';

  @override
  String get threads => 'Threads';

  @override
  String get processesLabel => 'Processus';

  @override
  String get cpuUsageHistory => 'Historique d\'utilisation CPU';

  @override
  String get cpuUsage => 'Utilisation CPU';

  @override
  String get memUsage => 'Utilisation mémoire';

  @override
  String get memoryUsageHistory => 'Historique d\'utilisation mémoire';

  @override
  String get physicalMemoryK => 'Mémoire physique (K)';

  @override
  String get commitChargeK => 'Mémoire validée (K)';

  @override
  String get kernelMemoryK => 'Mémoire noyau (K)';

  @override
  String get totals => 'Totaux';

  @override
  String get total => 'Total';

  @override
  String get available => 'Disponible';

  @override
  String get fileCache => 'Cache fichiers';

  @override
  String get paged => 'Paginé';

  @override
  String get nonpaged => 'Non paginé';

  @override
  String get limit => 'Limite';

  @override
  String get peak => 'Pic';

  @override
  String get noActiveNetworkAdaptersFound =>
      'Aucun adaptateur réseau actif trouvé.';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Annuler';

  @override
  String get close => 'Fermer';

  @override
  String get imageName => 'Nom de l\'image';

  @override
  String get pidProcessIdentifier => 'PID (identificateur de processus)';

  @override
  String get userName => 'Nom d\'utilisateur';

  @override
  String get sessionId => 'ID de session';

  @override
  String get cpuTime => 'Temps CPU';

  @override
  String get memoryUsage => 'Utilisation mémoire';

  @override
  String get memoryUsageDelta => 'Delta d\'utilisation mémoire';

  @override
  String get pageFaults => 'Défauts de page';

  @override
  String get pageFaultsDelta => 'Delta des défauts de page';

  @override
  String get virtualMemorySize => 'Taille de la mémoire virtuelle';

  @override
  String get pagedPool => 'Pool paginé';

  @override
  String get nonPagedPool => 'Pool non paginé';

  @override
  String get basePriority => 'Priorité de base';

  @override
  String get handleCount => 'Nombre de handles';

  @override
  String get threadCount => 'Nombre de threads';

  @override
  String get processorAffinity => 'Affinité du processeur';

  @override
  String get processors => 'Processeurs';

  @override
  String get processorAffinityDescription =>
      'Determine sur quels CPU du groupe de processeurs selectionne le processus peut s\'executer.';

  @override
  String get messageTitleLabel => 'Titre du message :';

  @override
  String get messageLabel => 'Message :';

  @override
  String get showFullAccountName => 'Afficher le nom complet du compte';

  @override
  String get user => 'Utilisateur';

  @override
  String get status => 'État';

  @override
  String get clientName => 'Nom du client';

  @override
  String get session => 'Session';

  @override
  String get adapter => 'Adaptateur';

  @override
  String get networkUtilization => 'Utilisation réseau';

  @override
  String get linkSpeed => 'Vitesse du lien';

  @override
  String get state => 'État';

  @override
  String get bytesSent => 'Octets envoyés';

  @override
  String get bytesReceived => 'Octets reçus';

  @override
  String get bytesTotal => 'Octets au total';

  @override
  String get connected => 'Connecté';

  @override
  String get disconnected => 'Déconnecté';

  @override
  String get connecting => 'Connexion';

  @override
  String get disconnecting => 'Déconnexion';

  @override
  String get hardwareMissing => 'Matériel manquant';

  @override
  String get hardwareDisabled => 'Matériel désactivé';

  @override
  String get hardwareMalfunction => 'Dysfonctionnement matériel';

  @override
  String get unknown => 'Inconnu';

  @override
  String get active => 'Actif';

  @override
  String get connectQuery => 'Interrogation de connexion';

  @override
  String get shadow => 'Shadow';

  @override
  String get idle => 'Inactif';

  @override
  String get listening => 'En écoute';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get down => 'Hors service';

  @override
  String get init => 'Initialisation';

  @override
  String get bitness32Suffix => '(32 bits)';

  @override
  String get notResponding => 'Ne repond pas';

  @override
  String get running => 'En cours d\'execution';

  @override
  String get messageCouldNotBeSent => 'Le message n\'a pas pu etre envoye.';

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
      'Voulez-vous vraiment fermer la session des utilisateurs selectionnes ?';

  @override
  String get confirmDisconnectSelectedUsers =>
      'Voulez-vous vraiment deconnecter les utilisateurs selectionnes ?';

  @override
  String get selectedUserCouldNotBeLoggedOff =>
      'Impossible de fermer la session de l\'utilisateur selectionne.';

  @override
  String get selectedUserCouldNotBeDisconnected =>
      'Impossible de deconnecter l\'utilisateur selectionne.';

  @override
  String get win32ErrorPrefix => 'Erreur Win32 :';

  @override
  String get processColumnFileDescriptorCount => 'Descripteurs de fichier';

  @override
  String get processColumnNice => 'Valeur nice';

  @override
  String get processColumnCgroup => 'Cgroup';

  @override
  String get setNice => 'Définir la valeur &nice...';

  @override
  String get setNiceTitle => 'Définir la valeur nice';

  @override
  String get niceValueLabel => 'Valeur &nice :';

  @override
  String get niceValueDescription =>
      'Entrez une valeur nice de -20 (priorité la plus élevée) à 19 (priorité la plus basse).';

  @override
  String get invalidNiceValue =>
      'La valeur nice doit être un entier compris entre -20 et 19.';

  @override
  String get niceChangeWarning =>
      'La modification de la priorité du processus peut affecter la stabilité du système. Voulez-vous vraiment modifier la valeur nice ?';
}
