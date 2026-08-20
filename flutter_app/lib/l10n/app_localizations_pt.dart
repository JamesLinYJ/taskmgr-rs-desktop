// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Gerenciador de Tarefas do Windows NT';

  @override
  String get runTitle => 'Executar';

  @override
  String get runPrompt =>
      'Digite o nome de um programa, pasta, documento ou recurso da Internet, e o Windows o abrirá para você.';

  @override
  String get runCommandRequired =>
      'Digite o nome de um programa, pasta, documento ou recurso da Internet.';

  @override
  String get applicationsPageTitle => 'Aplicativos';

  @override
  String get processesPageTitle => 'Processos';

  @override
  String get performancePageTitle => 'Desempenho';

  @override
  String get cpuPageTitle => 'CPU';

  @override
  String get gpuPageTitle => 'GPU';

  @override
  String get networkingPageTitle => 'Rede';

  @override
  String get usersPageTitle => 'Usuários';

  @override
  String get taskManagerDisabled =>
      'O Gerenciador de Tarefas foi desativado pelo administrador.';

  @override
  String get warningTitle => 'Aviso do Gerenciador de Tarefas';

  @override
  String get priorityChangeWarning =>
      'AVISO: Alterar a classe de prioridade deste processo pode causar resultados indesejados, incluindo instabilidade do sistema. Tem certeza de que deseja alterar a classe de prioridade?';

  @override
  String get killProcessWarning =>
      'AVISO: Encerrar um processo pode causar resultados indesejados, incluindo perda de dados e instabilidade do sistema. O processo não terá chance de salvar seu estado ou seus dados antes de ser encerrado. Tem certeza de que deseja encerrar este processo?';

  @override
  String get debugProcessWarning =>
      'AVISO: Depurar este processo pode resultar em perda de dados. Tem certeza de que deseja anexar o depurador?';

  @override
  String get invalidOptionTitle => 'Opção inválida';

  @override
  String get noAffinityMaskMessage =>
      'O processo deve ter afinidade com pelo menos um processador.';

  @override
  String get unableToTerminateProcess => 'Não foi possível encerrar o processo';

  @override
  String get unableToAttachDebugger => 'Não foi possível anexar o depurador';

  @override
  String get unableToChangePriority => 'Não foi possível alterar a prioridade';

  @override
  String get unableToSetAffinity => 'A operação não pôde ser concluída.\n\n';

  @override
  String get formatProcesses => 'Processos: %d';

  @override
  String get formatCpuUsage => 'Uso da CPU: %d%%';

  @override
  String get formatMemoryUsage => 'Uso de memória: %dK / %dK';

  @override
  String get formatCpuNumber => 'CPU %d';

  @override
  String get totalCpu => 'CPU total';

  @override
  String get kernelCpu => 'CPU do kernel';

  @override
  String get cpuLoading => 'A carregar diagnóstico da CPU...';

  @override
  String get cpuLoadingDetails =>
      'As informações básicas da CPU estão prontas; a carregar desempenho e firmware...';

  @override
  String get cpuPartialDetails =>
      'Alguns detalhes da CPU não estão disponíveis.';

  @override
  String get cpuUnavailable =>
      'As informações de topologia da CPU não estão disponíveis.';

  @override
  String get cpuRefreshFailed =>
      'Falha ao atualizar os dados de diagnóstico da CPU.';

  @override
  String get cpuRefreshFailedStale =>
      'Falha ao atualizar a CPU; os últimos valores válidos estão a ser apresentados.';

  @override
  String get cpuCurrentState => 'Estado atual';

  @override
  String get cpuSystemDiagnostics => 'Diagnóstico do sistema';

  @override
  String get cpuTopologyFeatures => 'Topologia e recursos';

  @override
  String get cpuHardwareCache => 'Hardware e cache';

  @override
  String get cpuAverageFrequency => 'Frequência média';

  @override
  String get cpuFrequencyRange => 'Faixa de frequência';

  @override
  String get cpuUserTime => 'Utilizador';

  @override
  String get cpuKernelTime => 'Kernel';

  @override
  String get cpuDpcTime => 'DPC';

  @override
  String get cpuInterruptTime => 'Interrupção';

  @override
  String get cpuInterruptsPerSecond => 'Interrupções/s';

  @override
  String get cpuUptime => 'Tempo de atividade';

  @override
  String get cpuProcessorQueueLength => 'Fila do processador';

  @override
  String get cpuContextSwitchesPerSecond => 'Trocas de contexto/s';

  @override
  String get cpuSystemCallsPerSecond => 'Chamadas do sistema/s';

  @override
  String get cpuPackages => 'Pacotes';

  @override
  String get cpuNumaNodes => 'Nós NUMA';

  @override
  String get cpuGroups => 'Grupos';

  @override
  String get cpuDies => 'Dies';

  @override
  String get cpuModules => 'Módulos';

  @override
  String get cpuPhysicalCores => 'Núcleos físicos';

  @override
  String get cpuLogicalProcessors => 'Processadores lógicos';

  @override
  String get cpuCoreClasses => 'Classes de núcleo';

  @override
  String get cpuSmtCores => 'Núcleos SMT';

  @override
  String get cpuThreadsPerCore => 'Threads/núcleo';

  @override
  String get cpuVirtualization => 'Virtualização';

  @override
  String get cpuSlat => 'SLAT';

  @override
  String get cpuManufacturer => 'Fabricante';

  @override
  String get cpuSocket => 'Soquete';

  @override
  String get cpuProcessorId => 'ID do processador';

  @override
  String get cpuArchitectureWidth => 'Arquitetura / largura';

  @override
  String get cpuFamilyLevel => 'Família / nível';

  @override
  String get cpuRevisionStepping => 'Revisão / stepping';

  @override
  String get cpuFirmwareMaxFrequency => 'Frequência máx. do firmware';

  @override
  String get cpuIsaFeatures => 'Recursos ISA';

  @override
  String get cpuCacheL1Data => 'Cache de dados L1';

  @override
  String get cpuCacheL1Instruction => 'Cache de instruções L1';

  @override
  String get cpuCacheL2 => 'Cache L2';

  @override
  String get cpuCacheL3 => 'Cache L3';

  @override
  String get cpuUniformClass => 'Uniforme';

  @override
  String get cpuYes => 'Sim';

  @override
  String get cpuNo => 'Não';

  @override
  String get cpuFullyAssociative => 'Totalmente associativo';

  @override
  String get cpuSockets => 'soquetes';

  @override
  String get gpuLoading => 'A carregar dados da GPU...';

  @override
  String get gpuLoadingPerformance =>
      'As informações básicas da GPU estão prontas; a carregar dados de desempenho...';

  @override
  String get gpuLoadingDetails =>
      'Os dados de desempenho da GPU estão prontos; a carregar detalhes do hardware...';

  @override
  String get gpuPartialDetails =>
      'Alguns detalhes da GPU não estão disponíveis.';

  @override
  String get noHardwareGpusFound => 'Não foram encontradas GPUs de hardware.';

  @override
  String get gpuRequiresWddm2 =>
      'Não existem contadores de desempenho da GPU disponíveis. Esta funcionalidade requer um controlador de ecrã WDDM 2.0 ou posterior.';

  @override
  String get gpuRefreshFailed => 'Não foi possível atualizar os dados da GPU.';

  @override
  String get gpuRefreshFailedStale =>
      'Falha ao atualizar os dados da GPU; é apresentada a última amostra válida.';

  @override
  String get gpuCurrentMetrics => 'Atual';

  @override
  String get gpuAdapterDetails => 'Detalhes do adaptador';

  @override
  String get gpuUtilization => 'Utilização';

  @override
  String get gpuMemory => 'Memória da GPU';

  @override
  String get gpuDedicatedMemory => 'Memória dedicada da GPU';

  @override
  String get gpuSharedMemory => 'Memória partilhada da GPU';

  @override
  String get gpuTemperature => 'Temperatura';

  @override
  String get gpuDriverVersion => 'Versão do controlador';

  @override
  String get gpuDriverDate => 'Data do controlador';

  @override
  String get gpuDirectXVersion => 'Versão do DirectX';

  @override
  String get gpuPhysicalLocation => 'Localização física';

  @override
  String get gpuHardwareReservedMemory => 'Memória reservada para hardware';

  @override
  String get gpuEngine3D => '3D';

  @override
  String get gpuEngineCopy => 'Cópia';

  @override
  String get gpuEngineVideoEncode => 'Codificação de vídeo';

  @override
  String get gpuEngineVideoDecode => 'Descodificação de vídeo';

  @override
  String get gpuEngineCompute => 'Cálculo';

  @override
  String get gpuEngineSecurity => 'Segurança';

  @override
  String get notAvailable => 'Não disponível';

  @override
  String get taskColumnTask => 'Tarefa';

  @override
  String get taskColumnStatus => 'Status';

  @override
  String get taskColumnWinstation => 'Estação Win';

  @override
  String get taskColumnDesktop => 'Área de trabalho';

  @override
  String get processColumnImageName => 'Nome da imagem';

  @override
  String get processColumnPid => 'PID';

  @override
  String get processColumnCpu => 'CPU';

  @override
  String get processColumnCpuTime => 'Tempo de CPU';

  @override
  String get processColumnMemoryUsage => 'Uso de memória';

  @override
  String get processColumnMemoryUsageDelta => 'Delta de memória';

  @override
  String get processColumnPageFaults => 'Falhas de página';

  @override
  String get processColumnPageFaultsDelta => 'Delta de falhas de página';

  @override
  String get processColumnVirtualMemorySize => 'Tamanho da memória virtual';

  @override
  String get processColumnPagedPool => 'Pool paginado';

  @override
  String get processColumnNonPagedPool => 'Pool não paginado';

  @override
  String get processColumnBasePriority => 'Prioridade básica';

  @override
  String get processColumnHandleCount => 'Handles';

  @override
  String get processColumnThreadCount => 'Threads';

  @override
  String get processColumnSessionId => 'ID da sessão';

  @override
  String get processColumnUserName => 'Nome de usuário';

  @override
  String get file => '&Arquivo';

  @override
  String get options => '&Opções';

  @override
  String get view => 'E&xibir';

  @override
  String get windows => '&Janelas';

  @override
  String get help => 'A&juda';

  @override
  String get updateSpeed => '&Velocidade de atualização';

  @override
  String get cpuHistory => '&Histórico da CPU';

  @override
  String get newTaskMenu => '&Executar...';

  @override
  String get newTaskButton => '&Executar...';

  @override
  String get exitTaskManager => 'Sai&r do Gerenciador de Tarefas';

  @override
  String get alwaysOnTop => '&Sempre visível';

  @override
  String get minimizeOnUse => '&Minimizar ao usar';

  @override
  String get confirmations => '&Confirmações';

  @override
  String get hideWhenMinimized => '&Ocultar ao minimizar';

  @override
  String get refreshNow => '&Atualizar agora';

  @override
  String get high => '&Alta';

  @override
  String get normal => '&Normal';

  @override
  String get low => '&Baixa';

  @override
  String get paused => '&Pausado';

  @override
  String get largeIcons => 'Ícones &grandes';

  @override
  String get smallIcons => 'Ícones &pequenos';

  @override
  String get details => '&Detalhes';

  @override
  String get tileHorizontally => 'Lado a lado &horizontalmente';

  @override
  String get tileVertically => 'Lado a lado &verticalmente';

  @override
  String get minimize => '&Minimizar';

  @override
  String get maximize => 'Ma&ximizar';

  @override
  String get cascade => '&Em cascata';

  @override
  String get bringToFront => 'Trazer para &frente';

  @override
  String get helpTopics => 'Tópicos de &ajuda do Gerenciador de Tarefas';

  @override
  String get helpOpenFailed =>
      'Não foi possível abrir a ajuda do Gerenciador de Tarefas.';

  @override
  String get diagnosticLogs => 'Logs de &diagnóstico...';

  @override
  String get diagnosticLogsTitle => 'Logs de diagnóstico';

  @override
  String get diagnosticStatusLabel => 'Status:';

  @override
  String get diagnosticSessionLabel => 'Sessão:';

  @override
  String get diagnosticDirectoryLabel => 'Pasta:';

  @override
  String get diagnosticDetailedCurrentSession =>
      'Registrar logs detalhados nesta sessão';

  @override
  String get diagnosticIncludeSensitive => 'Incluir informações confidenciais';

  @override
  String get diagnosticCaptureMinidump =>
      'Criar um minidump se o aplicativo falhar';

  @override
  String get diagnosticMinidumpPrivacy =>
      'Despejos de memória podem conter informações privadas.';

  @override
  String get diagnosticRestartDetailed => 'Reiniciar com log detalhado';

  @override
  String get diagnosticOpenFolder => 'Abrir pasta de logs';

  @override
  String get diagnosticSaveBundle => 'Salvar pacote de diagnóstico...';

  @override
  String get diagnosticLoggingActive => 'Log ativo (%s)';

  @override
  String get diagnosticLoggingUnavailable => 'Log em arquivo indisponível';

  @override
  String get diagnosticDroppedEvents => 'Eventos descartados: %s';

  @override
  String get diagnosticExporting => 'Salvando pacote de diagnóstico...';

  @override
  String get diagnosticExportSucceeded => 'Pacote de diagnóstico salvo.';

  @override
  String get diagnosticExportFailedTitle =>
      'Não foi possível salvar o pacote de diagnóstico';

  @override
  String get diagnosticSensitiveExportWarning =>
      'Este pacote contém um despejo de memória ou campos registrados com o modo confidencial e pode conter informações privadas. Continuar?';

  @override
  String get diagnosticRestartFailed =>
      'O Gerenciador de Tarefas não pôde reiniciar com log detalhado.';

  @override
  String get diagnosticOpenFolderFailed =>
      'Não foi possível abrir a pasta de logs de diagnóstico.';

  @override
  String get aboutTaskManager => '&Sobre o Gerenciador de Tarefas';

  @override
  String get oneGraphAllCpus => 'Um gráfico, &todas as CPUs';

  @override
  String get oneGraphPerCpu => 'Um gráfico &por CPU';

  @override
  String get selectColumnsMenu => 'Selecionar colunas...';

  @override
  String get selectColumnsTitle => 'Selecionar colunas';

  @override
  String get selectProcessColumnsDescription =>
      'Selecione as colunas que serao exibidas na guia Processos do Gerenciador de Tarefas.';

  @override
  String get showKernelTimes => 'Mostrar tempos do &kernel';

  @override
  String get restoreTaskManager => '&Restaurar o Gerenciador de Tarefas';

  @override
  String get endProcess => '&Finalizar processo';

  @override
  String get endProcessTree => 'End Process &Tree';

  @override
  String get openFileLocation => 'Open File &Location';

  @override
  String get debug => '&Depurar';

  @override
  String get setPriority => 'Definir &prioridade';

  @override
  String get realtime => '&Tempo real';

  @override
  String get aboveNormal => '&Above Normal';

  @override
  String get belowNormal => '&Below Normal';

  @override
  String get setAffinity => 'Definir a&finidade...';

  @override
  String get switchTo => '&Alternar para';

  @override
  String get endTask => '&Finalizar tarefa';

  @override
  String get goToProcess => '&Ir para o processo';

  @override
  String get disconnect => '&Desconectar';

  @override
  String get logoff => '&Logoff';

  @override
  String get sendMessage => '&Enviar mensagem...';

  @override
  String get sendMessageTitle => 'Enviar mensagem';

  @override
  String get taskManager => 'Gerenciador de Tarefas';

  @override
  String get handles => 'Handles';

  @override
  String get threads => 'Threads';

  @override
  String get processesLabel => 'Processos';

  @override
  String get cpuUsageHistory => 'Histórico de uso da CPU';

  @override
  String get cpuUsage => 'Uso da CPU';

  @override
  String get memUsage => 'Uso de memória';

  @override
  String get memoryUsageHistory => 'Histórico de uso de memória';

  @override
  String get physicalMemoryK => 'Memória física (K)';

  @override
  String get commitChargeK => 'Memória confirmada (K)';

  @override
  String get kernelMemoryK => 'Memória do kernel (K)';

  @override
  String get totals => 'Totais';

  @override
  String get total => 'Total';

  @override
  String get available => 'Disponível';

  @override
  String get fileCache => 'Cache de arquivos';

  @override
  String get paged => 'Paginado';

  @override
  String get nonpaged => 'Não paginado';

  @override
  String get limit => 'Limite';

  @override
  String get peak => 'Pico';

  @override
  String get noActiveNetworkAdaptersFound =>
      'Nenhum adaptador de rede ativo encontrado.';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancelar';

  @override
  String get close => 'Fechar';

  @override
  String get imageName => 'Nome da imagem';

  @override
  String get pidProcessIdentifier => 'PID (identificador do processo)';

  @override
  String get userName => 'Nome de usuário';

  @override
  String get sessionId => 'ID da sessão';

  @override
  String get cpuTime => 'Tempo de CPU';

  @override
  String get memoryUsage => 'Uso de memória';

  @override
  String get memoryUsageDelta => 'Delta de uso de memória';

  @override
  String get pageFaults => 'Falhas de página';

  @override
  String get pageFaultsDelta => 'Delta de falhas de página';

  @override
  String get virtualMemorySize => 'Tamanho da memória virtual';

  @override
  String get pagedPool => 'Pool paginado';

  @override
  String get nonPagedPool => 'Pool não paginado';

  @override
  String get basePriority => 'Prioridade básica';

  @override
  String get handleCount => 'Contagem de handles';

  @override
  String get threadCount => 'Contagem de threads';

  @override
  String get processorAffinity => 'Afinidade do processador';

  @override
  String get processors => 'Processadores';

  @override
  String get processorAffinityDescription =>
      'Controla em quais CPUs do grupo de processadores selecionado o processo pode ser executado.';

  @override
  String get messageTitleLabel => 'Título da mensagem:';

  @override
  String get messageLabel => 'Mensagem:';

  @override
  String get showFullAccountName => 'Mostrar nome completo da conta';

  @override
  String get user => 'Usuário';

  @override
  String get status => 'Status';

  @override
  String get clientName => 'Nome do cliente';

  @override
  String get session => 'Sessão';

  @override
  String get adapter => 'Adaptador';

  @override
  String get networkUtilization => 'Utilização da rede';

  @override
  String get linkSpeed => 'Velocidade do link';

  @override
  String get state => 'Status';

  @override
  String get bytesSent => 'Bytes enviados';

  @override
  String get bytesReceived => 'Bytes recebidos';

  @override
  String get bytesTotal => 'Total de bytes';

  @override
  String get connected => 'Conectado';

  @override
  String get disconnected => 'Desconectado';

  @override
  String get connecting => 'Conectando';

  @override
  String get disconnecting => 'Desconectando';

  @override
  String get hardwareMissing => 'Hardware ausente';

  @override
  String get hardwareDisabled => 'Hardware desabilitado';

  @override
  String get hardwareMalfunction => 'Falha de hardware';

  @override
  String get unknown => 'Desconhecido';

  @override
  String get active => 'Ativo';

  @override
  String get connectQuery => 'Consulta de conexão';

  @override
  String get shadow => 'Sombra';

  @override
  String get idle => 'Inativo';

  @override
  String get listening => 'Escutando';

  @override
  String get reset => 'Redefinir';

  @override
  String get down => 'Inativo';

  @override
  String get init => 'Inicializando';

  @override
  String get bitness32Suffix => '(32 bits)';

  @override
  String get notResponding => 'Nao esta respondendo';

  @override
  String get running => 'Em execucao';

  @override
  String get messageCouldNotBeSent => 'Nao foi possivel enviar a mensagem.';

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
      'Tem certeza de que deseja fazer logoff dos usuarios selecionados?';

  @override
  String get confirmDisconnectSelectedUsers =>
      'Tem certeza de que deseja desconectar os usuarios selecionados?';

  @override
  String get selectedUserCouldNotBeLoggedOff =>
      'Nao foi possivel fazer logoff do usuario selecionado.';

  @override
  String get selectedUserCouldNotBeDisconnected =>
      'Nao foi possivel desconectar o usuario selecionado.';

  @override
  String get win32ErrorPrefix => 'Erro do Win32:';

  @override
  String get processColumnFileDescriptorCount => 'Descritores de arquivo';

  @override
  String get processColumnNice => 'Valor nice';

  @override
  String get processColumnCgroup => 'Cgroup';

  @override
  String get setNice => 'Definir valor &nice...';

  @override
  String get setNiceTitle => 'Definir valor nice';

  @override
  String get niceValueLabel => 'Valor &nice:';

  @override
  String get niceValueDescription =>
      'Insira um valor nice de -20 (prioridade mais alta) a 19 (prioridade mais baixa).';

  @override
  String get invalidNiceValue =>
      'O valor nice deve ser um número inteiro entre -20 e 19.';

  @override
  String get niceChangeWarning =>
      'Alterar a prioridade do processo pode afetar a estabilidade do sistema. Tem certeza de que deseja alterar o valor nice?';
}
