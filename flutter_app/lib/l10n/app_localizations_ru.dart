// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Диспетчер задач Windows NT';

  @override
  String get runTitle => 'Выполнить';

  @override
  String get runPrompt =>
      'Введите имя программы, папки, документа или интернет-ресурса, и Windows откроет его.';

  @override
  String get runCommandRequired =>
      'Введите имя программы, папки, документа или интернет-ресурса.';

  @override
  String get applicationsPageTitle => 'Приложения';

  @override
  String get processesPageTitle => 'Процессы';

  @override
  String get performancePageTitle => 'Быстродействие';

  @override
  String get cpuPageTitle => 'ЦП';

  @override
  String get gpuPageTitle => 'GPU';

  @override
  String get networkingPageTitle => 'Сеть';

  @override
  String get usersPageTitle => 'Пользователи';

  @override
  String get taskManagerDisabled => 'Диспетчер задач отключен администратором.';

  @override
  String get warningTitle => 'Предупреждение диспетчера задач';

  @override
  String get priorityChangeWarning =>
      'ПРЕДУПРЕЖДЕНИЕ: изменение класса приоритета этого процесса может привести к нежелательным последствиям, включая нестабильность системы. Вы действительно хотите изменить класс приоритета?';

  @override
  String get killProcessWarning =>
      'ПРЕДУПРЕЖДЕНИЕ: завершение процесса может привести к нежелательным последствиям, включая потерю данных и нестабильность системы. Перед завершением процесс не сможет сохранить свое состояние или данные. Вы действительно хотите завершить этот процесс?';

  @override
  String get debugProcessWarning =>
      'ПРЕДУПРЕЖДЕНИЕ: отладка этого процесса может привести к потере данных. Вы действительно хотите подключить отладчик?';

  @override
  String get invalidOptionTitle => 'Недопустимый параметр';

  @override
  String get noAffinityMaskMessage =>
      'Процесс должен иметь привязку как минимум к одному процессору.';

  @override
  String get unableToTerminateProcess => 'Не удалось завершить процесс';

  @override
  String get unableToAttachDebugger => 'Не удалось подключить отладчик';

  @override
  String get unableToChangePriority => 'Не удалось изменить приоритет';

  @override
  String get unableToSetAffinity => 'Не удалось выполнить операцию.\n\n';

  @override
  String get formatProcesses => 'Процессы: %d';

  @override
  String get formatCpuUsage => 'Загрузка CPU: %d%%';

  @override
  String get formatMemoryUsage => 'Использование памяти: %dK / %dK';

  @override
  String get formatCpuNumber => 'CPU %d';

  @override
  String get totalCpu => 'Общий CPU';

  @override
  String get kernelCpu => 'CPU ядра';

  @override
  String get cpuLoading => 'Загрузка диагностики ЦП...';

  @override
  String get cpuLoadingDetails =>
      'Основные сведения о ЦП готовы; загружаются данные о производительности и прошивке...';

  @override
  String get cpuPartialDetails => 'Некоторые сведения о ЦП недоступны.';

  @override
  String get cpuUnavailable => 'Сведения о топологии ЦП недоступны.';

  @override
  String get cpuRefreshFailed =>
      'Не удалось обновить диагностические данные ЦП.';

  @override
  String get cpuRefreshFailedStale =>
      'Не удалось обновить данные ЦП; показаны последние успешные значения.';

  @override
  String get cpuCurrentState => 'Текущее состояние';

  @override
  String get cpuSystemDiagnostics => 'Диагностика системы';

  @override
  String get cpuTopologyFeatures => 'Топология и возможности';

  @override
  String get cpuHardwareCache => 'Оборудование и кэш';

  @override
  String get cpuAverageFrequency => 'Средняя частота';

  @override
  String get cpuFrequencyRange => 'Диапазон частот';

  @override
  String get cpuUserTime => 'Пользователь';

  @override
  String get cpuKernelTime => 'Ядро';

  @override
  String get cpuDpcTime => 'DPC';

  @override
  String get cpuInterruptTime => 'Прерывания';

  @override
  String get cpuInterruptsPerSecond => 'Прерываний/с';

  @override
  String get cpuUptime => 'Время работы';

  @override
  String get cpuProcessorQueueLength => 'Очередь процессора';

  @override
  String get cpuContextSwitchesPerSecond => 'Переключений контекста/с';

  @override
  String get cpuSystemCallsPerSecond => 'Системных вызовов/с';

  @override
  String get cpuPackages => 'Пакеты';

  @override
  String get cpuNumaNodes => 'Узлы NUMA';

  @override
  String get cpuGroups => 'Группы';

  @override
  String get cpuDies => 'Кристаллы';

  @override
  String get cpuModules => 'Модули';

  @override
  String get cpuPhysicalCores => 'Физические ядра';

  @override
  String get cpuLogicalProcessors => 'Логические процессоры';

  @override
  String get cpuCoreClasses => 'Классы ядер';

  @override
  String get cpuSmtCores => 'Ядра SMT';

  @override
  String get cpuThreadsPerCore => 'Потоков/ядро';

  @override
  String get cpuVirtualization => 'Виртуализация';

  @override
  String get cpuSlat => 'SLAT';

  @override
  String get cpuManufacturer => 'Изготовитель';

  @override
  String get cpuSocket => 'Сокет';

  @override
  String get cpuProcessorId => 'ИД процессора';

  @override
  String get cpuArchitectureWidth => 'Архитектура / разрядность';

  @override
  String get cpuFamilyLevel => 'Семейство / уровень';

  @override
  String get cpuRevisionStepping => 'Ревизия / степпинг';

  @override
  String get cpuFirmwareMaxFrequency => 'Макс. частота прошивки';

  @override
  String get cpuIsaFeatures => 'Возможности ISA';

  @override
  String get cpuCacheL1Data => 'Кэш данных L1';

  @override
  String get cpuCacheL1Instruction => 'Кэш инструкций L1';

  @override
  String get cpuCacheL2 => 'Кэш L2';

  @override
  String get cpuCacheL3 => 'Кэш L3';

  @override
  String get cpuUniformClass => 'Однородные';

  @override
  String get cpuYes => 'Да';

  @override
  String get cpuNo => 'Нет';

  @override
  String get cpuFullyAssociative => 'Полностью ассоциативный';

  @override
  String get cpuSockets => 'сокетов';

  @override
  String get gpuLoading => 'Загрузка данных GPU...';

  @override
  String get gpuLoadingPerformance =>
      'Основные сведения о GPU готовы; загружаются данные производительности...';

  @override
  String get gpuLoadingDetails =>
      'Данные производительности GPU готовы; загружаются сведения об оборудовании...';

  @override
  String get gpuPartialDetails => 'Некоторые сведения о GPU недоступны.';

  @override
  String get noHardwareGpusFound => 'Аппаратные GPU не найдены.';

  @override
  String get gpuRequiresWddm2 =>
      'Счётчики производительности GPU недоступны. Для этой функции требуется драйвер дисплея WDDM 2.0 или новее.';

  @override
  String get gpuRefreshFailed => 'Не удалось обновить данные GPU.';

  @override
  String get gpuRefreshFailedStale =>
      'Не удалось обновить данные GPU; показаны последние успешно полученные данные.';

  @override
  String get gpuCurrentMetrics => 'Текущие значения';

  @override
  String get gpuAdapterDetails => 'Сведения об адаптере';

  @override
  String get gpuUtilization => 'Использование';

  @override
  String get gpuMemory => 'Память GPU';

  @override
  String get gpuDedicatedMemory => 'Выделенная память GPU';

  @override
  String get gpuSharedMemory => 'Общая память GPU';

  @override
  String get gpuDeviceLocalMemory => 'Локальная память устройства';

  @override
  String get gpuSharedSystemMemory => 'Общая системная память';

  @override
  String get gpuTemperature => 'Температура';

  @override
  String get gpuDriverVersion => 'Версия драйвера';

  @override
  String get gpuDriverDate => 'Дата драйвера';

  @override
  String get gpuDirectXVersion => 'Версия DirectX';

  @override
  String get gpuPhysicalLocation => 'Физическое расположение';

  @override
  String get gpuHardwareReservedMemory => 'Аппаратно зарезервированная память';

  @override
  String get gpuKernelDriver => 'Драйвер ядра';

  @override
  String get gpuKernelModuleVersion => 'Версия модуля ядра';

  @override
  String get gpuGraphicsApi => 'Графический API';

  @override
  String get gpuDrmPrimaryNode => 'Основной узел DRM';

  @override
  String get gpuDrmRenderNode => 'Узел рендеринга DRM';

  @override
  String get gpuPciAddress => 'Адрес PCI';

  @override
  String get gpuEngineMemory => 'Память';

  @override
  String get gpuEngine3D => '3D';

  @override
  String get gpuEngineCopy => 'Копирование';

  @override
  String get gpuEngineVideoEncode => 'Кодирование видео';

  @override
  String get gpuEngineVideoDecode => 'Декодирование видео';

  @override
  String get gpuEngineCompute => 'Вычисления';

  @override
  String get gpuEngineSecurity => 'Безопасность';

  @override
  String get notAvailable => 'Недоступно';

  @override
  String get untitledWindow => 'Окно без названия';

  @override
  String get taskColumnTask => 'Задача';

  @override
  String get taskColumnStatus => 'Состояние';

  @override
  String get taskColumnWinstation => 'Станция Win';

  @override
  String get taskColumnDesktop => 'Рабочий стол';

  @override
  String get processColumnImageName => 'Имя образа';

  @override
  String get processColumnPid => 'PID';

  @override
  String get processColumnCpu => 'CPU';

  @override
  String get processColumnCpuTime => 'Время CPU';

  @override
  String get processColumnMemoryUsage => 'Использование памяти';

  @override
  String get processColumnMemoryUsageDelta => 'Изменение памяти';

  @override
  String get processColumnPageFaults => 'Ошибки страниц';

  @override
  String get processColumnPageFaultsDelta => 'Изменение ошибок страниц';

  @override
  String get processColumnVirtualMemorySize => 'Размер виртуальной памяти';

  @override
  String get processColumnPagedPool => 'Выгружаемый пул';

  @override
  String get processColumnNonPagedPool => 'Невыгружаемый пул';

  @override
  String get processColumnBasePriority => 'Базовый приоритет';

  @override
  String get processColumnHandleCount => 'Дескрипторы';

  @override
  String get processColumnThreadCount => 'Потоки';

  @override
  String get processColumnSessionId => 'ID сеанса';

  @override
  String get processColumnUserName => 'Имя пользователя';

  @override
  String get file => '&Файл';

  @override
  String get options => '&Параметры';

  @override
  String get view => '&Вид';

  @override
  String get windows => '&Окна';

  @override
  String get help => '&Справка';

  @override
  String get updateSpeed => '&Скорость обновления';

  @override
  String get cpuHistory => '&Журнал CPU';

  @override
  String get newTaskMenu => '&Выполнить...';

  @override
  String get newTaskButton => '&Выполнить...';

  @override
  String get exitTaskManager => '&Выход из диспетчера задач';

  @override
  String get alwaysOnTop => '&Поверх всех окон';

  @override
  String get minimizeOnUse => '&Сворачивать после использования';

  @override
  String get confirmations => '&Подтверждения';

  @override
  String get hideWhenMinimized => '&Скрывать при сворачивании';

  @override
  String get refreshNow => '&Обновить';

  @override
  String get high => '&Высокая';

  @override
  String get normal => '&Обычная';

  @override
  String get low => '&Низкая';

  @override
  String get paused => '&Пауза';

  @override
  String get largeIcons => '&Крупные значки';

  @override
  String get smallIcons => '&Мелкие значки';

  @override
  String get details => '&Подробности';

  @override
  String get tileHorizontally => 'Расположить &горизонтально';

  @override
  String get tileVertically => 'Расположить &вертикально';

  @override
  String get minimize => '&Свернуть';

  @override
  String get maximize => 'Ра&звернуть';

  @override
  String get cascade => '&Каскадом';

  @override
  String get bringToFront => 'На &передний план';

  @override
  String get helpTopics => '&Разделы справки диспетчера задач';

  @override
  String get helpOpenFailed => 'Не удалось открыть справку диспетчера задач.';

  @override
  String get diagnosticLogs => 'Журналы &диагностики...';

  @override
  String get diagnosticLogsTitle => 'Журналы диагностики';

  @override
  String get diagnosticStatusLabel => 'Состояние:';

  @override
  String get diagnosticSessionLabel => 'Сеанс:';

  @override
  String get diagnosticDirectoryLabel => 'Папка:';

  @override
  String get diagnosticDetailedCurrentSession =>
      'Записывать подробный журнал этого сеанса';

  @override
  String get diagnosticIncludeSensitive => 'Включать конфиденциальные сведения';

  @override
  String get diagnosticCaptureMinidump =>
      'Создать минидамп при сбое приложения';

  @override
  String get diagnosticMinidumpPrivacy =>
      'Дампы памяти могут содержать личные сведения.';

  @override
  String get diagnosticRestartDetailed => 'Перезапустить с подробным журналом';

  @override
  String get diagnosticOpenFolder => 'Открыть папку журналов';

  @override
  String get diagnosticSaveBundle => 'Сохранить пакет диагностики...';

  @override
  String get diagnosticLoggingActive => 'Журналирование включено (%s)';

  @override
  String get diagnosticLoggingUnavailable => 'Запись журнала в файл недоступна';

  @override
  String get diagnosticDroppedEvents => 'Отброшено событий: %s';

  @override
  String get diagnosticExporting => 'Сохранение пакета диагностики...';

  @override
  String get diagnosticExportSucceeded => 'Пакет диагностики сохранён.';

  @override
  String get diagnosticExportFailedTitle =>
      'Не удалось сохранить пакет диагностики';

  @override
  String get diagnosticSensitiveExportWarning =>
      'Пакет содержит дамп памяти или поля, записанные в конфиденциальном режиме, и может содержать личные сведения. Продолжить?';

  @override
  String get diagnosticRestartFailed =>
      'Не удалось перезапустить диспетчер задач с подробным журналом.';

  @override
  String get diagnosticOpenFolderFailed =>
      'Не удалось открыть папку журналов диагностики.';

  @override
  String get aboutTaskManager => '&О диспетчере задач';

  @override
  String get oneGraphAllCpus => 'Один график, &все CPU';

  @override
  String get oneGraphPerCpu => 'Один график &на CPU';

  @override
  String get selectColumnsMenu => 'Выбрать столбцы...';

  @override
  String get selectColumnsTitle => 'Выбор столбцов';

  @override
  String get selectProcessColumnsDescription =>
      'Выберите столбцы, которые будут отображаться на вкладке Процессы диспетчера задач.';

  @override
  String get showKernelTimes => 'Показывать время &ядра';

  @override
  String get restoreTaskManager => '&Восстановить диспетчер задач';

  @override
  String get endProcess => '&Завершить процесс';

  @override
  String get endProcessTree => 'End Process &Tree';

  @override
  String get openFileLocation => 'Open File &Location';

  @override
  String get debug => '&Отладка';

  @override
  String get setPriority => 'Задать &приоритет';

  @override
  String get realtime => '&Реального времени';

  @override
  String get aboveNormal => '&Above Normal';

  @override
  String get belowNormal => '&Below Normal';

  @override
  String get setAffinity => 'Задать &привязку...';

  @override
  String get switchTo => 'Пере&ключить';

  @override
  String get endTask => '&Снять задачу';

  @override
  String get goToProcess => '&Перейти к процессу';

  @override
  String get disconnect => '&Отключить';

  @override
  String get logoff => '&Выход из системы';

  @override
  String get sendMessage => '&Отправить сообщение...';

  @override
  String get sendMessageTitle => 'Отправить сообщение';

  @override
  String get taskManager => 'Диспетчер задач';

  @override
  String get handles => 'Дескрипторы';

  @override
  String get openFileHandles => 'Открытые файлы';

  @override
  String get threads => 'Потоки';

  @override
  String get processesLabel => 'Процессы';

  @override
  String get cpuUsageHistory => 'Журнал загрузки CPU';

  @override
  String get cpuUsage => 'Загрузка CPU';

  @override
  String get memUsage => 'Использование памяти';

  @override
  String get memoryUsageHistory => 'История использования памяти';

  @override
  String get physicalMemoryK => 'Физическая память (K)';

  @override
  String get commitChargeK => 'Выделенная память (K)';

  @override
  String get kernelMemoryK => 'Память ядра (K)';

  @override
  String get virtualMemoryK => 'Виртуальная память (K)';

  @override
  String get totals => 'Итоги';

  @override
  String get total => 'Всего';

  @override
  String get available => 'Доступно';

  @override
  String get fileCache => 'Файловый кэш';

  @override
  String get paged => 'Выгружаемая';

  @override
  String get nonpaged => 'Невыгружаемая';

  @override
  String get limit => 'Предел';

  @override
  String get peak => 'Пик';

  @override
  String get committed => 'Выделено';

  @override
  String get commitLimit => 'Предел выделения';

  @override
  String get swapUsed => 'Подкачка занята';

  @override
  String get slab => 'Slab';

  @override
  String get kernelStack => 'Стек ядра';

  @override
  String get pageTables => 'Таблицы страниц';

  @override
  String get noActiveNetworkAdaptersFound =>
      'Активные сетевые адаптеры не найдены.';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Отмена';

  @override
  String get close => 'Закрыть';

  @override
  String get imageName => 'Имя образа';

  @override
  String get pidProcessIdentifier => 'PID (идентификатор процесса)';

  @override
  String get userName => 'Имя пользователя';

  @override
  String get sessionId => 'ID сеанса';

  @override
  String get cpuTime => 'Время CPU';

  @override
  String get memoryUsage => 'Использование памяти';

  @override
  String get memoryUsageDelta => 'Изменение использования памяти';

  @override
  String get pageFaults => 'Ошибки страниц';

  @override
  String get pageFaultsDelta => 'Изменение ошибок страниц';

  @override
  String get virtualMemorySize => 'Размер виртуальной памяти';

  @override
  String get pagedPool => 'Выгружаемый пул';

  @override
  String get nonPagedPool => 'Невыгружаемый пул';

  @override
  String get basePriority => 'Базовый приоритет';

  @override
  String get handleCount => 'Число дескрипторов';

  @override
  String get threadCount => 'Число потоков';

  @override
  String get processorAffinity => 'Привязка процессора';

  @override
  String get processors => 'Процессоры';

  @override
  String get processorAffinityDescription =>
      'Определяет, на каких CPU выбранной группы процессоров может выполняться процесс.';

  @override
  String get messageTitleLabel => 'Заголовок сообщения:';

  @override
  String get messageLabel => 'Сообщение:';

  @override
  String get showFullAccountName => 'Показывать полное имя учетной записи';

  @override
  String get user => 'Пользователь';

  @override
  String get status => 'Состояние';

  @override
  String get clientName => 'Имя клиента';

  @override
  String get session => 'Сеанс';

  @override
  String get adapter => 'Адаптер';

  @override
  String get networkUtilization => 'Использование сети';

  @override
  String get linkSpeed => 'Скорость канала';

  @override
  String get state => 'Состояние';

  @override
  String get bytesSent => 'Отправлено байт';

  @override
  String get bytesReceived => 'Получено байт';

  @override
  String get bytesTotal => 'Всего байт';

  @override
  String get connected => 'Подключено';

  @override
  String get disconnected => 'Отключено';

  @override
  String get connecting => 'Подключение';

  @override
  String get disconnecting => 'Отключение';

  @override
  String get hardwareMissing => 'Оборудование отсутствует';

  @override
  String get hardwareDisabled => 'Оборудование отключено';

  @override
  String get hardwareMalfunction => 'Сбой оборудования';

  @override
  String get unknown => 'Неизвестно';

  @override
  String get active => 'Активно';

  @override
  String get connectQuery => 'Запрос подключения';

  @override
  String get shadow => 'Теневая';

  @override
  String get idle => 'Ожидание';

  @override
  String get listening => 'Ожидание подключения';

  @override
  String get reset => 'Сброс';

  @override
  String get down => 'Отключено';

  @override
  String get init => 'Инициализация';

  @override
  String get bitness32Suffix => '(32-разрядный)';

  @override
  String get notResponding => 'Не отвечает';

  @override
  String get running => 'Работает';

  @override
  String get messageCouldNotBeSent => 'Сообщение не удалось отправить.';

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
      'Вы действительно хотите завершить сеанс выбранных пользователей?';

  @override
  String get confirmDisconnectSelectedUsers =>
      'Вы действительно хотите отключить выбранных пользователей?';

  @override
  String get selectedUserCouldNotBeLoggedOff =>
      'Не удалось завершить сеанс выбранного пользователя.';

  @override
  String get selectedUserCouldNotBeDisconnected =>
      'Не удалось отключить выбранного пользователя.';

  @override
  String get win32ErrorPrefix => 'Ошибка Win32:';

  @override
  String get processColumnFileDescriptorCount => 'Файловые дескрипторы';

  @override
  String get processColumnNice => 'Nice';

  @override
  String get processColumnCgroup => 'Cgroup';

  @override
  String get setNice => 'Задать значение &nice...';

  @override
  String get setNiceTitle => 'Задать значение nice';

  @override
  String get niceValueLabel => 'Значение &nice:';

  @override
  String get niceValueDescription =>
      'Введите значение nice от -20 (наивысший приоритет) до 19 (самый низкий приоритет).';

  @override
  String get invalidNiceValue =>
      'Значение nice должно быть целым числом от -20 до 19.';

  @override
  String get niceChangeWarning =>
      'Изменение приоритета процесса может повлиять на стабильность системы. Изменить значение nice?';
}
