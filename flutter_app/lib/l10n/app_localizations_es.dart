// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Administrador de tareas de Windows NT';

  @override
  String get runTitle => 'Ejecutar';

  @override
  String get runPrompt =>
      'Escriba el nombre de un programa, carpeta, documento o recurso de Internet, y Windows lo abrirá por usted.';

  @override
  String get runCommandRequired =>
      'Escriba el nombre de un programa, carpeta, documento o recurso de Internet.';

  @override
  String get applicationsPageTitle => 'Aplicaciones';

  @override
  String get processesPageTitle => 'Procesos';

  @override
  String get performancePageTitle => 'Rendimiento';

  @override
  String get cpuPageTitle => 'CPU';

  @override
  String get gpuPageTitle => 'GPU';

  @override
  String get networkingPageTitle => 'Red';

  @override
  String get usersPageTitle => 'Usuarios';

  @override
  String get taskManagerDisabled =>
      'El Administrador de tareas ha sido deshabilitado por su administrador.';

  @override
  String get warningTitle => 'Advertencia del Administrador de tareas';

  @override
  String get priorityChangeWarning =>
      'ADVERTENCIA: Cambiar la clase de prioridad de este proceso puede causar resultados no deseados, incluida la inestabilidad del sistema. ¿Seguro que desea cambiar la clase de prioridad?';

  @override
  String get killProcessWarning =>
      'ADVERTENCIA: Finalizar un proceso puede causar resultados no deseados, incluida la pérdida de datos y la inestabilidad del sistema. El proceso no tendrá oportunidad de guardar su estado o sus datos antes de ser finalizado. ¿Seguro que desea finalizar este proceso?';

  @override
  String get debugProcessWarning =>
      'ADVERTENCIA: Depurar este proceso puede causar pérdida de datos. ¿Seguro que desea adjuntar el depurador?';

  @override
  String get invalidOptionTitle => 'Opción no válida';

  @override
  String get noAffinityMaskMessage =>
      'El proceso debe tener afinidad con al menos un procesador.';

  @override
  String get unableToTerminateProcess => 'No se pudo finalizar el proceso';

  @override
  String get unableToAttachDebugger => 'No se pudo adjuntar el depurador';

  @override
  String get unableToChangePriority => 'No se pudo cambiar la prioridad';

  @override
  String get unableToSetAffinity => 'No se pudo completar la operación.\n\n';

  @override
  String get formatProcesses => 'Procesos: %d';

  @override
  String get formatCpuUsage => 'Uso de CPU: %d%%';

  @override
  String get formatMemoryUsage => 'Uso de memoria: %dK / %dK';

  @override
  String get formatCpuNumber => 'CPU %d';

  @override
  String get totalCpu => 'CPU total';

  @override
  String get kernelCpu => 'CPU del núcleo';

  @override
  String get cpuLoading => 'Cargando diagnóstico de CPU...';

  @override
  String get cpuLoadingDetails =>
      'La información básica de la CPU está lista; cargando datos de rendimiento y firmware...';

  @override
  String get cpuPartialDetails =>
      'Algunos detalles de la CPU no están disponibles.';

  @override
  String get cpuUnavailable =>
      'La información de topología de CPU no está disponible.';

  @override
  String get cpuRefreshFailed =>
      'No se pudieron actualizar los datos de diagnóstico de CPU.';

  @override
  String get cpuRefreshFailedStale =>
      'No se pudieron actualizar los datos de CPU; se muestran los últimos valores correctos.';

  @override
  String get cpuCurrentState => 'Estado actual';

  @override
  String get cpuSystemDiagnostics => 'Diagnóstico del sistema';

  @override
  String get cpuTopologyFeatures => 'Topología y funciones';

  @override
  String get cpuHardwareCache => 'Hardware y caché';

  @override
  String get cpuAverageFrequency => 'Frecuencia media';

  @override
  String get cpuFrequencyRange => 'Rango de frecuencia';

  @override
  String get cpuUserTime => 'Usuario';

  @override
  String get cpuKernelTime => 'Núcleo';

  @override
  String get cpuDpcTime => 'DPC';

  @override
  String get cpuInterruptTime => 'Interrupción';

  @override
  String get cpuInterruptsPerSecond => 'Interrupciones/s';

  @override
  String get cpuUptime => 'Tiempo activo';

  @override
  String get cpuProcessorQueueLength => 'Cola del procesador';

  @override
  String get cpuContextSwitchesPerSecond => 'Cambios de contexto/s';

  @override
  String get cpuSystemCallsPerSecond => 'Llamadas del sistema/s';

  @override
  String get cpuPackages => 'Paquetes';

  @override
  String get cpuNumaNodes => 'Nodos NUMA';

  @override
  String get cpuGroups => 'Grupos';

  @override
  String get cpuDies => 'Dies';

  @override
  String get cpuModules => 'Módulos';

  @override
  String get cpuPhysicalCores => 'Núcleos físicos';

  @override
  String get cpuLogicalProcessors => 'Procesadores lógicos';

  @override
  String get cpuCoreClasses => 'Clases de núcleo';

  @override
  String get cpuSmtCores => 'Núcleos SMT';

  @override
  String get cpuThreadsPerCore => 'Hilos/núcleo';

  @override
  String get cpuVirtualization => 'Virtualización';

  @override
  String get cpuSlat => 'SLAT';

  @override
  String get cpuManufacturer => 'Fabricante';

  @override
  String get cpuSocket => 'Zócalo';

  @override
  String get cpuProcessorId => 'Id. de procesador';

  @override
  String get cpuArchitectureWidth => 'Arquitectura / ancho';

  @override
  String get cpuFamilyLevel => 'Familia / nivel';

  @override
  String get cpuRevisionStepping => 'Revisión / stepping';

  @override
  String get cpuFirmwareMaxFrequency => 'Frecuencia máx. de firmware';

  @override
  String get cpuIsaFeatures => 'Funciones ISA';

  @override
  String get cpuCacheL1Data => 'Caché de datos L1';

  @override
  String get cpuCacheL1Instruction => 'Caché de instrucciones L1';

  @override
  String get cpuCacheL2 => 'Caché L2';

  @override
  String get cpuCacheL3 => 'Caché L3';

  @override
  String get cpuUniformClass => 'Uniforme';

  @override
  String get cpuYes => 'Sí';

  @override
  String get cpuNo => 'No';

  @override
  String get cpuFullyAssociative => 'Totalmente asociativa';

  @override
  String get cpuSockets => 'zócalos';

  @override
  String get gpuLoading => 'Cargando datos de GPU...';

  @override
  String get gpuLoadingPerformance =>
      'La información básica de la GPU está lista; cargando datos de rendimiento...';

  @override
  String get gpuLoadingDetails =>
      'Los datos de rendimiento de la GPU están listos; cargando detalles del hardware...';

  @override
  String get gpuPartialDetails =>
      'Algunos detalles de la GPU no están disponibles.';

  @override
  String get noHardwareGpusFound => 'No se encontraron GPU de hardware.';

  @override
  String get gpuRequiresWddm2 =>
      'No hay contadores de rendimiento de GPU disponibles. Esta función requiere un controlador de pantalla WDDM 2.0 o posterior.';

  @override
  String get gpuRefreshFailed =>
      'No se pudieron actualizar los datos de la GPU.';

  @override
  String get gpuRefreshFailedStale =>
      'No se pudieron actualizar los datos de GPU; se muestra la última muestra correcta.';

  @override
  String get gpuCurrentMetrics => 'Actual';

  @override
  String get gpuAdapterDetails => 'Detalles del adaptador';

  @override
  String get gpuUtilization => 'Uso';

  @override
  String get gpuMemory => 'Memoria de GPU';

  @override
  String get gpuDedicatedMemory => 'Memoria de GPU dedicada';

  @override
  String get gpuSharedMemory => 'Memoria de GPU compartida';

  @override
  String get gpuDeviceLocalMemory => 'Memoria de GPU local del dispositivo';

  @override
  String get gpuSharedSystemMemory => 'Memoria del sistema compartida';

  @override
  String get gpuTemperature => 'Temperatura';

  @override
  String get gpuDriverVersion => 'Versión del controlador';

  @override
  String get gpuDriverDate => 'Fecha del controlador';

  @override
  String get gpuDirectXVersion => 'Versión de DirectX';

  @override
  String get gpuPhysicalLocation => 'Ubicación física';

  @override
  String get gpuHardwareReservedMemory => 'Memoria reservada para hardware';

  @override
  String get gpuKernelDriver => 'Controlador del núcleo';

  @override
  String get gpuKernelModuleVersion => 'Versión del módulo del núcleo';

  @override
  String get gpuGraphicsApi => 'API de gráficos';

  @override
  String get gpuDrmPrimaryNode => 'Nodo primario DRM';

  @override
  String get gpuDrmRenderNode => 'Nodo de renderizado DRM';

  @override
  String get gpuPciAddress => 'Dirección PCI';

  @override
  String get gpuEngineMemory => 'Memoria';

  @override
  String get gpuEngine3D => '3D';

  @override
  String get gpuEngineCopy => 'Copia';

  @override
  String get gpuEngineVideoEncode => 'Codificación de vídeo';

  @override
  String get gpuEngineVideoDecode => 'Decodificación de vídeo';

  @override
  String get gpuEngineCompute => 'Cálculo';

  @override
  String get gpuEngineSecurity => 'Seguridad';

  @override
  String get notAvailable => 'No disponible';

  @override
  String get untitledWindow => 'Ventana sin título';

  @override
  String get taskColumnTask => 'Tarea';

  @override
  String get taskColumnStatus => 'Estado';

  @override
  String get taskColumnWinstation => 'Estación Win';

  @override
  String get taskColumnDesktop => 'Escritorio';

  @override
  String get processColumnImageName => 'Nombre de imagen';

  @override
  String get processColumnPid => 'PID';

  @override
  String get processColumnCpu => 'CPU';

  @override
  String get processColumnCpuTime => 'Tiempo de CPU';

  @override
  String get processColumnMemoryUsage => 'Uso de memoria';

  @override
  String get processColumnMemoryUsageDelta => 'Delta de memoria';

  @override
  String get processColumnPageFaults => 'Errores de página';

  @override
  String get processColumnPageFaultsDelta => 'Delta de errores de página';

  @override
  String get processColumnVirtualMemorySize => 'Tamaño de memoria virtual';

  @override
  String get processColumnPagedPool => 'Bloque paginado';

  @override
  String get processColumnNonPagedPool => 'Bloque no paginado';

  @override
  String get processColumnBasePriority => 'Prioridad base';

  @override
  String get processColumnHandleCount => 'Handles';

  @override
  String get processColumnThreadCount => 'Hilos';

  @override
  String get processColumnSessionId => 'Id. de sesión';

  @override
  String get processColumnUserName => 'Nombre de usuario';

  @override
  String get file => '&Archivo';

  @override
  String get options => '&Opciones';

  @override
  String get view => '&Ver';

  @override
  String get windows => '&Ventanas';

  @override
  String get help => 'Ay&uda';

  @override
  String get updateSpeed => '&Velocidad de actualización';

  @override
  String get cpuHistory => '&Historial de CPU';

  @override
  String get newTaskMenu => '&Ejecutar...';

  @override
  String get newTaskButton => '&Ejecutar...';

  @override
  String get exitTaskManager => '&Salir del Administrador de tareas';

  @override
  String get alwaysOnTop => '&Siempre visible';

  @override
  String get minimizeOnUse => '&Minimizar al usar';

  @override
  String get confirmations => '&Confirmaciones';

  @override
  String get hideWhenMinimized => '&Ocultar al minimizar';

  @override
  String get refreshNow => '&Actualizar ahora';

  @override
  String get high => '&Alta';

  @override
  String get normal => '&Normal';

  @override
  String get low => '&Baja';

  @override
  String get paused => '&Pausado';

  @override
  String get largeIcons => 'Iconos &grandes';

  @override
  String get smallIcons => 'Iconos &pequeños';

  @override
  String get details => '&Detalles';

  @override
  String get tileHorizontally => 'Mosaico &horizontal';

  @override
  String get tileVertically => 'Mosaico &vertical';

  @override
  String get minimize => '&Minimizar';

  @override
  String get maximize => 'Ma&ximizar';

  @override
  String get cascade => '&Cascada';

  @override
  String get bringToFront => 'Traer al &frente';

  @override
  String get helpTopics => 'Temas de a&yuda del Administrador de tareas';

  @override
  String get helpOpenFailed =>
      'No se pudo abrir la ayuda del Administrador de tareas.';

  @override
  String get diagnosticLogs => 'Registros de &diagnóstico...';

  @override
  String get diagnosticLogsTitle => 'Registros de diagnóstico';

  @override
  String get diagnosticStatusLabel => 'Estado:';

  @override
  String get diagnosticSessionLabel => 'Sesión:';

  @override
  String get diagnosticDirectoryLabel => 'Carpeta:';

  @override
  String get diagnosticDetailedCurrentSession =>
      'Registrar información detallada para esta sesión';

  @override
  String get diagnosticIncludeSensitive => 'Incluir información confidencial';

  @override
  String get diagnosticCaptureMinidump =>
      'Crear un minivolcado si la aplicación falla';

  @override
  String get diagnosticMinidumpPrivacy =>
      'Los volcados de memoria pueden contener información privada.';

  @override
  String get diagnosticRestartDetailed => 'Reiniciar con registro detallado';

  @override
  String get diagnosticOpenFolder => 'Abrir carpeta de registros';

  @override
  String get diagnosticSaveBundle => 'Guardar paquete de diagnóstico...';

  @override
  String get diagnosticLoggingActive => 'Registro activo (%s)';

  @override
  String get diagnosticLoggingUnavailable =>
      'Registro en archivo no disponible';

  @override
  String get diagnosticDroppedEvents => 'Eventos descartados: %s';

  @override
  String get diagnosticExporting => 'Guardando paquete de diagnóstico...';

  @override
  String get diagnosticExportSucceeded => 'Paquete de diagnóstico guardado.';

  @override
  String get diagnosticExportFailedTitle =>
      'No se pudo guardar el paquete de diagnóstico';

  @override
  String get diagnosticSensitiveExportWarning =>
      'Este paquete contiene un volcado de memoria o campos registrados con el modo confidencial y puede contener información privada. ¿Continuar?';

  @override
  String get diagnosticRestartFailed =>
      'El Administrador de tareas no pudo reiniciarse con el registro detallado.';

  @override
  String get diagnosticOpenFolderFailed =>
      'No se pudo abrir la carpeta de registros de diagnóstico.';

  @override
  String get aboutTaskManager => '&Acerca del Administrador de tareas';

  @override
  String get oneGraphAllCpus => 'Un gráfico, &todas las CPU';

  @override
  String get oneGraphPerCpu => 'Un gráfico &por CPU';

  @override
  String get selectColumnsMenu => 'Seleccionar columnas...';

  @override
  String get selectColumnsTitle => 'Seleccionar columnas';

  @override
  String get selectProcessColumnsDescription =>
      'Seleccione las columnas que aparecerán en la pestaña Procesos del Administrador de tareas.';

  @override
  String get showKernelTimes => 'Mostrar tiempos del &núcleo';

  @override
  String get restoreTaskManager => '&Restaurar el Administrador de tareas';

  @override
  String get endProcess => '&Finalizar proceso';

  @override
  String get endProcessTree => 'End Process &Tree';

  @override
  String get openFileLocation => 'Open File &Location';

  @override
  String get debug => '&Depurar';

  @override
  String get setPriority => 'Establecer &prioridad';

  @override
  String get realtime => '&Tiempo real';

  @override
  String get aboveNormal => '&Above Normal';

  @override
  String get belowNormal => '&Below Normal';

  @override
  String get setAffinity => 'Establecer a&finidad...';

  @override
  String get switchTo => '&Cambiar a';

  @override
  String get endTask => '&Finalizar tarea';

  @override
  String get goToProcess => '&Ir al proceso';

  @override
  String get disconnect => '&Desconectar';

  @override
  String get logoff => 'Ce&rrar sesión';

  @override
  String get sendMessage => '&Enviar mensaje...';

  @override
  String get sendMessageTitle => 'Enviar mensaje';

  @override
  String get taskManager => 'Administrador de tareas';

  @override
  String get handles => 'Handles';

  @override
  String get openFileHandles => 'Archivos abiertos';

  @override
  String get threads => 'Hilos';

  @override
  String get processesLabel => 'Procesos';

  @override
  String get cpuUsageHistory => 'Historial de uso de CPU';

  @override
  String get cpuUsage => 'Uso de CPU';

  @override
  String get memUsage => 'Uso de memoria';

  @override
  String get memoryUsageHistory => 'Historial de uso de memoria';

  @override
  String get physicalMemoryK => 'Memoria física (K)';

  @override
  String get commitChargeK => 'Memoria confirmada (K)';

  @override
  String get kernelMemoryK => 'Memoria del núcleo (K)';

  @override
  String get virtualMemoryK => 'Memoria virtual (K)';

  @override
  String get totals => 'Totales';

  @override
  String get total => 'Total';

  @override
  String get available => 'Disponible';

  @override
  String get fileCache => 'Caché de archivos';

  @override
  String get paged => 'Paginado';

  @override
  String get nonpaged => 'No paginado';

  @override
  String get limit => 'Límite';

  @override
  String get peak => 'Pico';

  @override
  String get committed => 'Confirmada';

  @override
  String get commitLimit => 'Límite de confirmación';

  @override
  String get swapUsed => 'Intercambio usado';

  @override
  String get slab => 'Slab';

  @override
  String get kernelStack => 'Pila del núcleo';

  @override
  String get pageTables => 'Tablas de páginas';

  @override
  String get noActiveNetworkAdaptersFound =>
      'No se encontraron adaptadores de red activos.';

  @override
  String get ok => 'Aceptar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get close => 'Cerrar';

  @override
  String get imageName => 'Nombre de imagen';

  @override
  String get pidProcessIdentifier => 'PID (identificador de proceso)';

  @override
  String get userName => 'Nombre de usuario';

  @override
  String get sessionId => 'Id. de sesión';

  @override
  String get cpuTime => 'Tiempo de CPU';

  @override
  String get memoryUsage => 'Uso de memoria';

  @override
  String get memoryUsageDelta => 'Delta de uso de memoria';

  @override
  String get pageFaults => 'Errores de página';

  @override
  String get pageFaultsDelta => 'Delta de errores de página';

  @override
  String get virtualMemorySize => 'Tamaño de memoria virtual';

  @override
  String get pagedPool => 'Bloque paginado';

  @override
  String get nonPagedPool => 'Bloque no paginado';

  @override
  String get basePriority => 'Prioridad base';

  @override
  String get handleCount => 'Número de handles';

  @override
  String get threadCount => 'Número de hilos';

  @override
  String get processorAffinity => 'Afinidad del procesador';

  @override
  String get processors => 'Procesadores';

  @override
  String get processorAffinityDescription =>
      'Controla en que CPU del grupo de procesadores seleccionado puede ejecutarse el proceso.';

  @override
  String get messageTitleLabel => 'Título del mensaje:';

  @override
  String get messageLabel => 'Mensaje:';

  @override
  String get showFullAccountName => 'Mostrar nombre completo de la cuenta';

  @override
  String get user => 'Usuario';

  @override
  String get status => 'Estado';

  @override
  String get clientName => 'Nombre del cliente';

  @override
  String get session => 'Sesión';

  @override
  String get adapter => 'Adaptador';

  @override
  String get networkUtilization => 'Utilizacion de red';

  @override
  String get linkSpeed => 'Velocidad del vinculo';

  @override
  String get state => 'Estado';

  @override
  String get bytesSent => 'Bytes enviados';

  @override
  String get bytesReceived => 'Bytes recibidos';

  @override
  String get bytesTotal => 'Bytes totales';

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
  String get hardwareDisabled => 'Hardware deshabilitado';

  @override
  String get hardwareMalfunction => 'Fallo de hardware';

  @override
  String get unknown => 'Desconocido';

  @override
  String get active => 'Activo';

  @override
  String get connectQuery => 'Consulta de conexión';

  @override
  String get shadow => 'Sombra';

  @override
  String get idle => 'Inactivo';

  @override
  String get listening => 'Escuchando';

  @override
  String get reset => 'Restablecer';

  @override
  String get down => 'Inactivo';

  @override
  String get init => 'Inicializando';

  @override
  String get bitness32Suffix => '(32 bits)';

  @override
  String get notResponding => 'No responde';

  @override
  String get running => 'En ejecucion';

  @override
  String get messageCouldNotBeSent => 'No se pudo enviar el mensaje.';

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
      '¿Seguro que desea cerrar la sesion de los usuarios seleccionados?';

  @override
  String get confirmDisconnectSelectedUsers =>
      '¿Seguro que desea desconectar a los usuarios seleccionados?';

  @override
  String get selectedUserCouldNotBeLoggedOff =>
      'No se pudo cerrar la sesion del usuario seleccionado.';

  @override
  String get selectedUserCouldNotBeDisconnected =>
      'No se pudo desconectar al usuario seleccionado.';

  @override
  String get win32ErrorPrefix => 'Error de Win32:';

  @override
  String get processColumnFileDescriptorCount => 'Descriptores de archivo';

  @override
  String get processColumnNice => 'Valor nice';

  @override
  String get processColumnCgroup => 'Cgroup';

  @override
  String get setNice => 'Establecer valor &nice...';

  @override
  String get setNiceTitle => 'Establecer valor nice';

  @override
  String get niceValueLabel => 'Valor &nice:';

  @override
  String get niceValueDescription =>
      'Introduzca un valor nice de -20 (prioridad más alta) a 19 (prioridad más baja).';

  @override
  String get invalidNiceValue =>
      'El valor nice debe ser un entero entre -20 y 19.';

  @override
  String get niceChangeWarning =>
      'Cambiar la prioridad del proceso puede afectar a la estabilidad del sistema. ¿Seguro que desea cambiar el valor nice?';
}
