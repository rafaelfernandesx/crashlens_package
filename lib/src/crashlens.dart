import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../crashlens_flutter.dart';
import 'models/platform_device_info.dart';

/// Classe principal do CrashLens SDK
///
/// Uso:
/// ```dart
/// void main() async {
///   await CrashLens.init(
///     options: CrashLensOptions(apiKey: 'sua_chave_api'),
///   );
///   runApp(MyApp());
/// }
/// ```
class CrashLens {
  static CrashLens? _instance;
  static CrashLens get instance {
    if (_instance == null) {
      throw StateError('CrashLens não foi inicializado. Chame CrashLens.init() primeiro.');
    }
    return _instance!;
  }

  CrashLensOptions _options;
  EventQueue? _queue;
  EventApiClient? _apiClient;
  FlutterErrorHandler? _flutterErrorHandler;
  PlatformDispatcherHandler? _platformDispatcherHandler;
  final List<Breadcrumb> _breadcrumbs = [];
  final _uuid = const Uuid();
  DeviceInfoData? _deviceInfo;
  PackageInfo? _packageInfo;
  bool _initialized = false;
  bool _keyValid = true; // validado durante init
  SessionTracker? _session;
  SharedPreferences? _prefs;
  // ignore: unused_field — mantido vivo para evitar GC do AppLifecycleListener
  AppLifecycleListener? _lifecycleListener;

  /// Flag persistente: SDK está pausado por limite de plano excedido
  bool _paused = false;
  DateTime? _pausedUntil;
  Timer? _retryTimer;

  static const _storageKey = 'crashlens_events';
  static const _pausedKey = 'crashlens_paused';
  static const _pausedUntilKey = 'crashlens_paused_until';
  static const _deviceIdKey = 'crashlens_device_id';
  static const _maxLocalErrors = 500;
  static const _retryIntervalMinutes = 15;

  /// ID nativo do dispositivo obtido via device_info_plus (se disponível)
  String? _nativeDeviceId;

  CrashLens._(this._options);

  /// Inicializa o CrashLens SDK
  static Future<void> init({
    required CrashLensOptions options,
  }) async {
    if (_instance != null) {
      debugPrint('[CrashLens] Já inicializado.');
      return;
    }

    final crashlens = CrashLens._(options);
    await crashlens._initialize();
    _instance = crashlens;
  }

  Future<void> _initialize() async {
    // Coleta informações do dispositivo e app
    await _collectDeviceAndAppInfo();

    // Inicializa SharedPreferences (sempre — para persistência e reenvio)
    _prefs = await SharedPreferences.getInstance();

    // Restaura estado de pausa (limite de plano excedido)
    await _restorePausedState();

    // Reenvia eventos pendentes de execuções anteriores
    await _resendPending();

    // Configura client HTTP
    _apiClient = EventApiClient(
      baseUrl: _options.baseUrl,
      timeoutMs: _options.httpTimeoutMs,
    );

    // Valida a API Key antes de ativar qualquer captura
    _keyValid = await _apiClient!.validateApiKey(_options.apiKey);
    if (!_keyValid) {
      _initialized = true;
      debugPrint('[CrashLens] ⚠️ API Key inválida. SDK não capturará eventos.');
      return;
    }

    // Configura fila de eventos — com callback para detectar quota excedida
    _queue = EventQueue(
      apiClient: _apiClient!,
      maxRetries: _options.maxRetries,
      onBatchSent: _onBatchSent,
      onEventsDropped: _onEventsDropped,
      onQuotaExceeded: () => CrashLens.pause(reason: 'Limite do plano atingido (detectado pela API)'),
    );
    _queue!.startAutoFlush(
      interval: Duration(seconds: _options.flushIntervalSeconds),
    );

    // Instala handlers
    if (_options.enableFlutterErrorCapture) {
      _flutterErrorHandler = FlutterErrorHandler();
      _flutterErrorHandler!.install(_onEvent);
    }

    if (_options.enablePlatformDispatcherCapture) {
      _platformDispatcherHandler = PlatformDispatcherHandler();
      _platformDispatcherHandler!.install(_onEvent);
    }

    if (_options.enableZoneCapture) {
      _installZoneCapture();
    }

    if (_options.enableAutoBreadcrumbs) {
      _installAutoBreadcrumbs();
    }

    // Inicia sessão com o client HTTP para enviar start/end ao backend
    if (_keyValid) {
      final persistentDeviceId = await _getOrCreateDeviceId();
      _session = SessionTracker(
        apiKey: _options.apiKey,
        baseUrl: _options.baseUrl,
        apiClient: _apiClient,
        release: _options.release ?? _packageInfo?.version,
        appVersion: _packageInfo?.version,
        buildNumber: _packageInfo?.buildNumber,
        platform: _platformName(),
        deviceId: persistentDeviceId,
        deviceModel: _deviceInfo?.deviceModel,
        deviceManufacturer: _getManufacturer(),
        deviceOs: _deviceInfo?.deviceOs,
        deviceOsVersion: _deviceInfo?.osVersion,
        locale: _deviceInfo?.locale,
        platformInfo: _deviceInfo?.platformInfo?.toJson(),
      );

      // Envia início da sessão para o backend
      await _session!.start();

      // Inicia heartbeat a cada 30s para manter sessão ativa
      _session!.startHeartbeat(const Duration(seconds: 30));

      // Monitora ciclo de vida do app: envia heartbeat ao ir pra background
      _lifecycleListener = AppLifecycleListener(
        onPause: () {
          // Envia heartbeat final ao ir pra background
          _apiClient?.sendHeartbeat(
            apiKey: _options.apiKey,
            sessionId: _session!.sessionId,
          );
          _session!.stopHeartbeat();
        },
        onResume: () {
          // Reinicia heartbeat ao voltar ao foreground
          _apiClient?.sendHeartbeat(
            apiKey: _options.apiKey,
            sessionId: _session!.sessionId,
          );
          _session!.startHeartbeat(const Duration(seconds: 30));
        },
        onDetach: () {
          _session!.stopHeartbeat();
        },
      );
    }

    _initialized = true;
    debugPrint('[CrashLens] Inicializado com sucesso. Sessão: ${_session!.sessionId}');
  }

  /// Converte defaultTargetPlatform para string legível
  static String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return defaultTargetPlatform.toString();
    }
  }

  /// Extrai o fabricante do dispositivo de forma consistente por plataforma.
  /// Usa o valor já coletado em _deviceInfo.deviceManufacturer.
  String? _getManufacturer() {
    return _deviceInfo?.deviceManufacturer;
  }

  /// Retorna um ID único persistente por dispositivo.
  /// Prioriza o ID nativo do dispositivo (ANDROID_ID, IDFV, etc.).
  /// Caso não disponível, usa UUID persistido no SharedPreferences.
  Future<String> _getOrCreateDeviceId() async {
    // Prioriza ID nativo do dispositivo
    if (_nativeDeviceId != null && _nativeDeviceId!.isNotEmpty) {
      debugPrint('[CrashLens] Usando ID nativo do dispositivo');
      return _nativeDeviceId!;
    }

    // Fallback: UUID persistido no SharedPreferences
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final newId = _uuid.v4();
    await prefs.setString(_deviceIdKey, newId);
    debugPrint('[CrashLens] ID nativo indisponível, UUID gerado: $newId');
    return newId;
  }

  Future<void> _collectDeviceAndAppInfo() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {}

    // Coleta locale do dispositivo
    final locale = Platform.localeName;

    // PASSO 1: Coletar o native ID ANTES de chamar _getOrCreateDeviceId()
    // Isso garante que o ID nativo (ANDROID_ID, IDFV, etc.) seja usado
    // em vez de gerar um UUID desnecessário
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await deviceInfoPlugin.androidInfo;
        _nativeDeviceId = info.id; // ANDROID_ID (Settings.Secure)
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await deviceInfoPlugin.iosInfo;
        _nativeDeviceId = info.identifierForVendor; // IDFV
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final info = await deviceInfoPlugin.windowsInfo;
        _nativeDeviceId = info.deviceId; // Windows DeviceId
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final info = await deviceInfoPlugin.macOsInfo;
        _nativeDeviceId = info.systemGUID; // macOS System GUID
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        final info = await deviceInfoPlugin.linuxInfo;
        _nativeDeviceId = info.machineId; // /etc/machine-id
      }
    } catch (_) {}

    // PASSO 2: Agora _nativeDeviceId está definido, obter o deviceId persistente
    // Se _nativeDeviceId existe, será usado; senão, UUID será gerado/recuperado
    final deviceId = await _getOrCreateDeviceId();
    debugPrint('[CrashLens] DeviceId final: $deviceId (native: $_nativeDeviceId)');

    // PASSO 3: Coletar informações detalhadas da plataforma
    PlatformDeviceInfo? platformInfo;

    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await deviceInfoPlugin.androidInfo;
        
        // Coleta informações específicas do Android
        platformInfo = PlatformDeviceInfo(
          android: AndroidPlatformInfo(
            brand: info.brand,
            model: info.model,
            manufacturer: info.manufacturer,
            deviceName: info.device,
            product: info.product,
            board: info.board,
            hardware: info.hardware,
            supportedAbis: info.supportedAbis.join(','),
            bootloader: info.bootloader,
            display: info.display,
            fingerprint: info.fingerprint,
            host: info.host,
            buildId: info.id,
            tags: info.tags,
            type: info.type,
            osVersion: info.version.release,
            sdkInt: info.version.sdkInt,
            securityPatch: info.version.securityPatch,
            codename: info.version.codename,
            isPhysicalDevice: info.isPhysicalDevice,
            isLowRamDevice: info.isLowRamDevice,
            systemFeatures: info.systemFeatures.join(','),
            freeDiskSize: info.freeDiskSize,
            totalDiskSize: info.totalDiskSize,
            physicalRamSize: info.physicalRamSize,
            availableRamSize: info.availableRamSize,
          ),
        );
        
        _deviceInfo = DeviceInfoData(
          deviceId: deviceId,
          deviceName: '${info.brand} ${info.model}',
          deviceModel: info.model,
          deviceManufacturer: info.brand,
          deviceOs: 'android',
          osVersion: info.version.release,
          deviceType: 'mobile',
          isPhysicalDevice: info.isPhysicalDevice,
          cpuArchitecture: info.supportedAbis.isNotEmpty ? info.supportedAbis.first : null,
          locale: locale,
          platformInfo: platformInfo,
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await deviceInfoPlugin.iosInfo;
        
        // Coleta informações específicas do iOS
        platformInfo = PlatformDeviceInfo(
          ios: IosPlatformInfo(
            name: info.name,
            systemName: info.systemName,
            systemVersion: info.systemVersion,
            model: info.model,
            modelName: info.modelName,
            localizedModel: info.localizedModel,
            identifierForVendor: info.identifierForVendor,
            isPhysicalDevice: info.isPhysicalDevice,
            isiOSAppOnMac: info.isiOSAppOnMac,
            isiOSAppOnVision: info.isiOSAppOnVision,
            utsnameSysname: info.utsname.sysname,
            utsnameNodename: info.utsname.nodename,
            utsnameRelease: info.utsname.release,
            utsnameVersion: info.utsname.version,
            utsnameMachine: info.utsname.machine,
            freeDiskSize: info.freeDiskSize,
            totalDiskSize: info.totalDiskSize,
            physicalRamSize: info.physicalRamSize,
            availableRamSize: info.availableRamSize,
          ),
        );
        
        _deviceInfo = DeviceInfoData(
          deviceId: deviceId,
          deviceName: info.name,
          deviceModel: info.model,
          deviceManufacturer: 'Apple',
          deviceOs: 'ios',
          osVersion: info.systemVersion,
          deviceType: 'mobile',
          isPhysicalDevice: info.isPhysicalDevice,
          cpuArchitecture: info.utsname.machine,
          locale: locale,
          platformInfo: platformInfo,
        );
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final info = await deviceInfoPlugin.windowsInfo;
        
        // Coleta informações específicas do Windows
        platformInfo = PlatformDeviceInfo(
          windows: WindowsPlatformInfo(
            computerName: info.computerName,
            userName: info.userName,
            productName: info.productName,
            editionId: info.editionId,
            displayVersion: info.displayVersion,
            releaseId: info.releaseId,
            productId: info.productId,
            majorVersion: info.majorVersion,
            minorVersion: info.minorVersion,
            buildNumber: info.buildNumber,
            platformId: info.platformId,
            csdVersion: info.csdVersion,
            servicePackMajor: info.servicePackMajor,
            servicePackMinor: info.servicePackMinor,
            numberOfCores: info.numberOfCores,
            systemMemoryInMegabytes: info.systemMemoryInMegabytes,
            productType: info.productType,
            suitMask: info.suitMask,
            buildLab: info.buildLab,
            buildLabEx: info.buildLabEx,
            windowsDeviceId: info.deviceId,
            registeredOwner: info.registeredOwner,
            installDate: info.installDate.toIso8601String(),
          ),
        );
        
        _deviceInfo = DeviceInfoData(
          deviceId: deviceId,
          deviceName: info.computerName,
          deviceManufacturer: 'Microsoft',
          deviceOs: 'windows',
          osVersion: '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}',
          deviceType: 'desktop',
          cpuArchitecture: null, // Windows não fornece arquitetura via device_info_plus
          locale: locale,
          platformInfo: platformInfo,
        );
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final info = await deviceInfoPlugin.macOsInfo;
        
        // Coleta informações específicas do macOS
        platformInfo = PlatformDeviceInfo(
          macos: MacOsPlatformInfo(
            computerName: info.computerName,
            hostName: info.hostName,
            model: info.model,
            modelName: info.modelName,
            arch: info.arch,
            kernelVersion: info.kernelVersion,
            osRelease: info.osRelease,
            majorVersion: info.majorVersion,
            minorVersion: info.minorVersion,
            patchVersion: info.patchVersion,
            activeCPUs: info.activeCPUs,
            memorySize: info.memorySize,
            cpuFrequency: info.cpuFrequency,
            systemGUID: info.systemGUID,
          ),
        );
        
        _deviceInfo = DeviceInfoData(
          deviceId: deviceId,
          deviceManufacturer: 'Apple',
          deviceOs: 'macos',
          osVersion: info.osRelease,
          deviceType: 'desktop',
          cpuArchitecture: info.arch,
          locale: locale,
          platformInfo: platformInfo,
        );
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        final info = await deviceInfoPlugin.linuxInfo;
        
        // Coleta informações específicas do Linux
        platformInfo = PlatformDeviceInfo(
          linux: LinuxPlatformInfo(
            name: info.name,
            prettyName: info.prettyName,
            distroId: info.id,
            idLike: info.idLike?.join(','),
            version: info.version,
            versionId: info.versionId,
            versionCodename: info.versionCodename,
            buildId: info.buildId,
            variant: info.variant,
            variantId: info.variantId,
            machineId: info.machineId,
          ),
        );
        
        _deviceInfo = DeviceInfoData(
          deviceId: deviceId,
          deviceName: info.name,
          deviceOs: 'linux',
          osVersion: info.versionId,
          deviceType: 'desktop',
          cpuArchitecture: null, // Linux não fornece arquitetura via device_info_plus
          locale: locale,
          platformInfo: platformInfo,
        );
      }
    } catch (_) {}

    // Preenche info do app (preservando deviceId, locale, manufacturer e platformInfo)
    _deviceInfo = DeviceInfoData(
      deviceId: deviceId,
      deviceName: _deviceInfo?.deviceName,
      deviceModel: _deviceInfo?.deviceModel,
      deviceManufacturer: _deviceInfo?.deviceManufacturer,
      deviceOs: _deviceInfo?.deviceOs,
      osVersion: _deviceInfo?.osVersion,
      deviceType: _deviceInfo?.deviceType,
      screenResolution: _deviceInfo?.screenResolution,
      isPhysicalDevice: _deviceInfo?.isPhysicalDevice,
      cpuArchitecture: _deviceInfo?.cpuArchitecture,
      locale: _deviceInfo?.locale,
      appVersion: _packageInfo?.version,
      buildNumber: _packageInfo?.buildNumber,
      platformInfo: _deviceInfo?.platformInfo,
    );
  }

  void _installZoneCapture() {
    runZonedGuarded(() {
      // A zona já está instalada pelo main()
    }, (Object error, StackTrace stack) {
      final event = CrashLensEvent(
        apiKey: _options.apiKey,
        message: error.toString(),
        severity: EventSeverity.fatal,
        exceptionType: error.runtimeType.toString(),
        error: error,
        exceptionMessage: error.toString(),
        stackTrace: stack.toString(),
        release: _options.release ?? _packageInfo?.version,
        user: _options.user,
        tags: _options.tags,
        deviceInfo: _deviceInfo,
        breadcrumbs: List.from(_breadcrumbs),
        timestamp: DateTime.now(),
        handled: false,
        context: 'Zone.runZonedGuarded',
      );
      _capture(event);
    });
  }

  void _installAutoBreadcrumbs() {
    // Breadcrumbs serão adicionados manualmente ou via wrapper
  }

  /// Callback interno quando um handler captura um evento
  void _onEvent(CrashLensEvent event) {
    _capture(event);
  }

  /// Captura uma exceção manualmente
  static void captureException(
    dynamic error,
    StackTrace? stackTrace, {
    bool handled = true,
    String? context,
    Map<String, dynamic>? tags,
    Map<String, dynamic>? extra,
  }) {
    final instance = CrashLens.instance;
    final stack = stackTrace ?? StackTrace.current;
    final event = CrashLensEvent(
      apiKey: instance._options.apiKey,
      message: error.toString(),
      severity: EventSeverity.error,
      exceptionType: error.runtimeType.toString(),
      error: error,
      exceptionMessage: error.toString(),
      stackTrace: stack.toString(),
      release: instance._options.release ?? instance._packageInfo?.version,
      user: instance._options.user,
      tags: {...?instance._options.tags, ...?tags},
      extra: extra,
      deviceInfo: instance._deviceInfo,
      breadcrumbs: List.from(instance._breadcrumbs),
      timestamp: DateTime.now(),
      handled: handled,
    );
    instance._capture(event);
  }

  /// Captura uma mensagem de log
  static void captureMessage(
    String message, {
    EventSeverity severity = EventSeverity.info,
    Map<String, dynamic>? tags,
    Map<String, dynamic>? extra,
  }) {
    final instance = CrashLens.instance;
    final event = CrashLensEvent(
      apiKey: instance._options.apiKey,
      message: message,
      severity: severity,
      release: instance._options.release ?? instance._packageInfo?.version,
      user: instance._options.user,
      extra: extra,
      deviceInfo: instance._deviceInfo,
      breadcrumbs: List.from(instance._breadcrumbs),
      timestamp: DateTime.now(),
      handled: true,
    );
    instance._capture(event);
  }

  /// Captura um evento personalizado
  static void captureEvent({
    required String message,
    EventSeverity severity = EventSeverity.info,
    dynamic exceptionType,
    String? exceptionMessage,
    String? stackTrace,
    String? fingerprint,
    String? context,
    Map<String, dynamic>? tags,
    Map<String, dynamic>? extra,
  }) {
    final instance = CrashLens.instance;
    final event = CrashLensEvent(
      apiKey: instance._options.apiKey,
      message: message,
      severity: severity,
      exceptionType: exceptionType,
      exceptionMessage: exceptionMessage,
      stackTrace: stackTrace,
      fingerprint: fingerprint,
      release: instance._options.release ?? instance._packageInfo?.version,
      context: context,
      user: instance._options.user,
      tags: {...?instance._options.tags, ...?tags},
      extra: extra,
      deviceInfo: instance._deviceInfo,
      breadcrumbs: List.from(instance._breadcrumbs),
      timestamp: DateTime.now(),
      handled: true,
    );
    instance._capture(event);
  }

  /// Adiciona um breadcrumb
  static void addBreadcrumb(Breadcrumb breadcrumb) {
    final instance = CrashLens.instance;
    instance._breadcrumbs.add(breadcrumb);
    if (instance._breadcrumbs.length > instance._options.maxBreadcrumbs) {
      instance._breadcrumbs.removeAt(0);
    }
  }

  /// Retorna o ID da sessão atual (para vincular a erros manualmente)
  static String? get sessionId => instance._session?.sessionId;

  /// Encerra a sessão atual e envia ao backend.
  /// Chame ao colocar o app em background (AppLifecycleState.paused).
  static Future<void> endSession() async {
    await instance._session?.end();
  }

  /// Marca a sessão atual como crashed
  static void markSessionCrashed() {
    instance._session?.markCrashed();
  }

  // ── Controle de pausa (limite de plano excedido) ──

  /// Pausa o SDK — persiste a flag e para de enviar eventos
  static void pause({String? reason}) {
    final i = instance;
    i._paused = true;
    i._pausedUntil = DateTime.now().add(const Duration(minutes: _retryIntervalMinutes));
    i._prefs?.setBool(_pausedKey, true);
    i._prefs?.setString(_pausedUntilKey, i._pausedUntil!.toIso8601String());
    i._queue?.pause();
    debugPrint('[CrashLens] SDK pausado. Motivo: ${reason ?? "limite de plano"}');
    _scheduleRetry(i);
  }

  /// Agenda verificação periódica para resumir
  static void _scheduleRetry(CrashLens i) {
    i._retryTimer?.cancel();
    i._retryTimer = Timer(const Duration(minutes: _retryIntervalMinutes), () {
      _tryResume(i);
    });
  }

  /// Tenta resumir o SDK — faz uma requisição leve ao backend
  static Future<void> _tryResume(CrashLens i) async {
    if (!i._paused) return;
    if (i._pausedUntil != null && DateTime.now().isBefore(i._pausedUntil!)) {
      _scheduleRetry(i);
      return;
    }

    debugPrint('[CrashLens] Tentando resumir SDK...');
    final ok = await i._apiClient?.sendEvent(
      CrashLensEvent(
        apiKey: i._options.apiKey,
        message: '__crashlens_health_check__',
        severity: EventSeverity.debug,
      ),
    );

    if (ok == true) {
      i._paused = false;
      i._pausedUntil = null;
      i._prefs?.remove(_pausedKey);
      i._prefs?.remove(_pausedUntilKey);
      i._queue?.resume();
      debugPrint('[CrashLens] SDK resumido com sucesso.');
    } else {
      i._pausedUntil = DateTime.now().add(const Duration(minutes: _retryIntervalMinutes));
      i._prefs?.setString(_pausedUntilKey, i._pausedUntil!.toIso8601String());
      _scheduleRetry(i);
    }
  }

  /// Restaura estado de pausa do armazenamento local
  Future<void> _restorePausedState() async {
    final paused = _prefs?.getBool(_pausedKey) ?? false;
    if (paused) {
      final untilStr = _prefs?.getString(_pausedUntilKey);
      final until = untilStr != null ? DateTime.tryParse(untilStr) : null;
      if (until != null && DateTime.now().isBefore(until)) {
        _paused = true;
        _pausedUntil = until;
        _queue?.pause();
        debugPrint('[CrashLens] SDK restaurado como pausado até $until');
        _scheduleRetry(this);
        return;
      }
      // Já passou o tempo de pausa — tenta resumir
      _prefs?.remove(_pausedKey);
      _prefs?.remove(_pausedUntilKey);
    }
  }

  /// Verifica se o SDK está pausado
  static bool get isPaused => instance._paused;

  /// Verifica se a API Key é válida
  static bool get isKeyValid => instance._keyValid;

  /// Define o usuário atual (similar ao [SentryUser]).
  /// As informações serão enviadas com todos os eventos subsequentes.
  static void setUser(CrashLensUser? user) {
    final instance = CrashLens.instance;
    instance._options = CrashLensOptions(
      apiKey: instance._options.apiKey,
      baseUrl: instance._options.baseUrl,
      release: instance._options.release,
      user: user,
      tags: instance._options.tags,
      beforeSend: instance._options.beforeSend,
      // mantém outras opções
      flushIntervalSeconds: instance._options.flushIntervalSeconds,
      maxBreadcrumbs: instance._options.maxBreadcrumbs,
      enableFlutterErrorCapture: instance._options.enableFlutterErrorCapture,
      enablePlatformDispatcherCapture: instance._options.enablePlatformDispatcherCapture,
      enableZoneCapture: instance._options.enableZoneCapture,
      enableAutoBreadcrumbs: instance._options.enableAutoBreadcrumbs,
      sampleRate: instance._options.sampleRate,
      sendInDebug: instance._options.sendInDebug,
      httpTimeoutMs: instance._options.httpTimeoutMs,
      maxRetries: instance._options.maxRetries,
    );
  }

  /// Adiciona uma tag global que será enviada com todos os eventos futuros.
  /// Similar ao [Sentry.configureScope] + setTag.
  static void setTag(String key, dynamic value) {
    final instance = CrashLens.instance;
    final updatedTags = Map<String, dynamic>.from(instance._options.tags ?? {});
    updatedTags[key] = value;
    instance._options = CrashLensOptions(
      apiKey: instance._options.apiKey,
      baseUrl: instance._options.baseUrl,
      release: instance._options.release,
      user: instance._options.user,
      tags: updatedTags,
      beforeSend: instance._options.beforeSend,
      flushIntervalSeconds: instance._options.flushIntervalSeconds,
      maxBreadcrumbs: instance._options.maxBreadcrumbs,
      enableFlutterErrorCapture: instance._options.enableFlutterErrorCapture,
      enablePlatformDispatcherCapture: instance._options.enablePlatformDispatcherCapture,
      enableZoneCapture: instance._options.enableZoneCapture,
      enableAutoBreadcrumbs: instance._options.enableAutoBreadcrumbs,
      sampleRate: instance._options.sampleRate,
      sendInDebug: instance._options.sendInDebug,
      httpTimeoutMs: instance._options.httpTimeoutMs,
      maxRetries: instance._options.maxRetries,
    );
  }

  /// Remove uma tag global.
  static void removeTag(String key) {
    final instance = CrashLens.instance;
    if (instance._options.tags == null) return;
    final updatedTags = Map<String, dynamic>.from(instance._options.tags!);
    updatedTags.remove(key);
    instance._options = CrashLensOptions(
      apiKey: instance._options.apiKey,
      baseUrl: instance._options.baseUrl,
      user: instance._options.user,
      tags: updatedTags,
      beforeSend: instance._options.beforeSend,
      flushIntervalSeconds: instance._options.flushIntervalSeconds,
      maxBreadcrumbs: instance._options.maxBreadcrumbs,
      enableFlutterErrorCapture: instance._options.enableFlutterErrorCapture,
      enablePlatformDispatcherCapture: instance._options.enablePlatformDispatcherCapture,
      enableZoneCapture: instance._options.enableZoneCapture,
      enableAutoBreadcrumbs: instance._options.enableAutoBreadcrumbs,
      sampleRate: instance._options.sampleRate,
      sendInDebug: instance._options.sendInDebug,
      httpTimeoutMs: instance._options.httpTimeoutMs,
      maxRetries: instance._options.maxRetries,
    );
  }

  void _capture(CrashLensEvent event) {
    // API Key inválida — não captura nada
    if (!_keyValid) {
      debugPrint('[CrashLens] API Key inválida. Evento descartado.');
      return;
    }

    // SDK pausado por limite de plano excedido — não captura nada
    if (_paused) {
      debugPrint('[CrashLens] SDK pausado. Evento descartado: ${event.message}');
      return;
    }

    // Verifica sample rate
    if (_options.sampleRate < 1.0 && Random().nextDouble() > _options.sampleRate) {
      return;
    }

    // Não envia em debug a menos que configurado
    if (!_options.sendInDebug && kDebugMode) {
      debugPrint('[CrashLens] Evento suprimido em modo debug: ${event.message}');
      return;
    }

    // Callback beforeSend — permite modificar o evento ou descartar (retornando null)
    if (_options.beforeSend != null) {
      try {
        final modified = _options.beforeSend!(event);
        if (modified == null) {
          debugPrint('[CrashLens] Evento descartado pelo beforeSend: ${event.message}');
          return;
        }
        event = modified;
      } catch (e) {
        debugPrint('[CrashLens] Erro no beforeSend: $e');
        // Continua com o evento original
      }
    }

    // O fingerprint só é enviado quando definido explicitamente pelo desenvolvedor;
    // o agrupamento automático é feito pelo servidor.
    final finalEvent = CrashLensEvent(
      eventId: event.eventId ?? _uuid.v4(),
      apiKey: event.apiKey.isNotEmpty ? event.apiKey : _options.apiKey,
      projectId: event.projectId,
      message: event.message,
      severity: event.severity,
      exceptionType: event.exceptionType,
      exceptionMessage: event.exceptionMessage,
      stackTrace: event.stackTrace,
      fingerprint: event.fingerprint,
      release: event.release ?? _options.release ?? _packageInfo?.version,
      environment: event.environment ?? _options.environment,
      context: event.context,
      user: event.user ?? _options.user,
      url: event.url,
      tags: {...?_options.tags, ...?event.tags},
      sessionId: _session?.sessionId,
      extra: event.extra,
      breadcrumbs: event.breadcrumbs.isEmpty ? List.from(_breadcrumbs) : event.breadcrumbs,
      deviceInfo: event.deviceInfo ?? _deviceInfo,
      timestamp: event.timestamp,
      handled: event.handled,
      error: event.error,
    );

    // Marca sessão como crashed se for erro fatal
    if (event.severity == EventSeverity.fatal || !event.handled) {
      _session?.markCrashed();
    }

    _queue?.enqueue(finalEvent);
    debugPrint('[CrashLens] Evento enfileirado: ${event.severity.value} | ${event.message}');

    // Persiste sempre no SharedPreferences (reenvio em caso de crash)
    if (_prefs != null) {
      _persistError(finalEvent);
    }
  }

  /// Salva erro no SharedPreferences com flag sent=false
  Future<void> _persistError(CrashLensEvent event) async {
    final raw = _prefs!.getStringList(_storageKey) ?? [];
    final stored = _StoredEvent(event: event, sent: false);
    raw.add(jsonEncode(stored.toJson()));
    // Mantém apenas os últimos N erros
    if (raw.length > _maxLocalErrors) {
      raw.removeRange(0, raw.length - _maxLocalErrors);
    }
    await _prefs!.setStringList(_storageKey, raw);
  }

  /// Reenfileira eventos não enviados de execuções anteriores.
  Future<void> _resendPending() async {
    final raw = _prefs?.getStringList(_storageKey) ?? [];
    final unsent = raw
        .map((j) {
          try {
            final decoded = jsonDecode(j) as Map<String, dynamic>;
            return _StoredEvent.fromJson(decoded);
          } catch (_) {
            return null;
          }
        })
        .whereType<_StoredEvent>()
        .where((s) => !s.sent)
        .toList();

    if (unsent.isEmpty) return;
    debugPrint('[CrashLens] Reenviando ${unsent.length} eventos pendentes...');
    for (final stored in unsent) {
      _queue?.enqueue(stored.event);
    }
  }

  /// Callback chamado pela EventQueue quando eventos são rejeitados em definitivo
  /// (400/413/422): remove-os do armazenamento local para não reenviar a cada execução.
  void _onEventsDropped(List<CrashLensEvent> droppedEvents) {
    final prefs = _prefs;
    if (prefs == null) return;

    final raw = prefs.getStringList(_storageKey) ?? [];
    if (raw.isEmpty) return;

    final ids = droppedEvents.map((e) => e.eventId).whereType<String>().toSet();
    final updated = <String>[];
    for (final entry in raw) {
      try {
        final decoded = jsonDecode(entry) as Map<String, dynamic>;
        final stored = _StoredEvent.fromJson(decoded);
        if (stored.event.eventId != null && ids.contains(stored.event.eventId)) {
          continue;
        }
      } catch (_) {
        // Entries inválidas: mantém por segurança
      }
      updated.add(entry);
    }
    prefs.setStringList(_storageKey, updated);
  }

  /// Callback chamado pela EventQueue quando um lote é enviado com sucesso.
  void _onBatchSent(List<CrashLensEvent> sentEvents) {
    final prefs = _prefs;
    if (prefs == null) return;

    final raw = prefs.getStringList(_storageKey) ?? [];
    if (raw.isEmpty) return;

    final sentIds = sentEvents.map((e) => e.eventId).whereType<String>().toSet();
    final updated = <String>[];

    for (final entry in raw) {
      try {
        final decoded = jsonDecode(entry) as Map<String, dynamic>;
        final stored = _StoredEvent.fromJson(decoded);
        final eventId = stored.event.eventId;

        if (eventId != null && sentIds.contains(eventId)) {
          if (_options.captureLocally) {
            // Mantém, marca como enviado
            updated.add(jsonEncode(_StoredEvent(event: stored.event, sent: true).toJson()));
          }
          // captureLocally=false: descarta (não adiciona)
        } else {
          updated.add(entry);
        }
      } catch (_) {
        // Entries inválidas: mantém por segurança
        updated.add(entry);
      }
    }

    var finalList = updated;
    if (_options.captureLocally && finalList.length > _maxLocalErrors) {
      finalList = finalList.sublist(finalList.length - _maxLocalErrors);
    }

    prefs.setStringList(_storageKey, finalList);
  }

  /// Gera um hash SHA-256 do conteúdo completo do evento (excluindo timestamp)
  /// para agrupar eventos exatamente iguais e evitar duplicatas.
  static String computeEventHash(CrashLensEvent event) {
    final buffer = StringBuffer();

    buffer.write(event.message);
    buffer.write('|${event.severity.value}');
    buffer.write('|${event.exceptionType}');
    buffer.write('|${event.exceptionMessage}');
    buffer.write('|${event.stackTrace}');
    buffer.write('|${event.context}');
    buffer.write('|${event.user?.toJson().toString()}');
    buffer.write('|${event.url}');
    buffer.write('|${event.release}');
    buffer.write('|${event.handled}');

    if (event.tags != null) {
      final sortedKeys = event.tags!.keys.toList()..sort();
      buffer.write('|tags:');
      for (final key in sortedKeys) {
        buffer.write('$key=${event.tags![key]}');
      }
    }

    if (event.extra != null) {
      final sortedKeys = event.extra!.keys.toList()..sort();
      buffer.write('|extra:');
      for (final key in sortedKeys) {
        buffer.write('$key=${event.extra![key]}');
      }
    }

    if (event.deviceInfo != null) {
      buffer.write('|device:${jsonEncode(event.deviceInfo!.toJson())}');
    }

    final bytes = utf8.encode(buffer.toString());
    return sha256.convert(bytes).toString();
  }

  /// Força o envio imediato de todos os eventos pendentes
  static Future<void> flush() async {
    final instance = CrashLens.instance;
    await instance._queue?.flush();
  }

  /// Encerra o SDK
  static Future<void> close() async {
    final instance = CrashLens.instance;
    await instance._queue?.flush();
    instance._queue?.dispose();
    instance._flutterErrorHandler?.uninstall();
    instance._platformDispatcherHandler?.uninstall();
    await instance._session?.end();
    _instance = null;
  }

  bool get isInitialized => _initialized;
  int get pendingEvents => _queue?.pendingCount ?? 0;

  /// Verifica se [CrashLensOptions.captureLocally] está ativado.
  /// Útil para condicionar a exibição de telas de logs/erros locais.
  static bool get isCaptureLocallyEnabled => instance._options.captureLocally;

  /// Lista de eventos capturados localmente (persistidos via SharedPreferences).
  /// Retorna lista vazia se [CrashLensOptions.captureLocally] = false.
  static List<CrashLensEvent> get localErrors {
    final instance = CrashLens.instance;
    if (!instance._options.captureLocally) return [];
    final prefs = instance._prefs;
    if (prefs == null) return [];
    final raw = prefs.getStringList(_storageKey) ?? [];
    return raw
        .map((j) {
          try {
            final decoded = jsonDecode(j) as Map<String, dynamic>;
            return _StoredEvent.fromJson(decoded).event;
          } catch (_) {
            return null;
          }
        })
        .whereType<CrashLensEvent>()
        .toList();
  }

  /// Retorna os erros locais do SharedPreferences.
  /// Idêntico a [localErrors], mas sem o aviso de [captureLocally] desativado.
  static List<CrashLensEvent> getLocalErrors() => localErrors;

  /// Remove um único erro local pelo [eventId].
  static Future<void> deleteLocalError(String eventId) async {
    final prefs = instance._prefs;
    if (prefs == null) return;
    final raw = prefs.getStringList(_storageKey) ?? [];
    final updated = <String>[];
    for (final entry in raw) {
      try {
        final decoded = jsonDecode(entry) as Map<String, dynamic>;
        final stored = _StoredEvent.fromJson(decoded);
        if (stored.event.eventId == eventId) continue; // remove
      } catch (_) {}
      updated.add(entry);
    }
    await prefs.setStringList(_storageKey, updated);
  }

  /// Limpa todos os erros persistidos localmente.
  static Future<void> clearLocalErrors() async {
    final prefs = instance._prefs;
    if (prefs == null) return;
    await prefs.remove(_storageKey);
  }
}

/// Evento armazenado no SharedPreferences com flag de envio.
class _StoredEvent {
  final CrashLensEvent event;
  final bool sent;

  const _StoredEvent({required this.event, required this.sent});

  Map<String, dynamic> toJson() => {
        'e': event.toJson(),
        's': sent,
      };

  factory _StoredEvent.fromJson(Map<String, dynamic> json) => _StoredEvent(
        event: CrashLensEvent.fromJson(json['e'] as Map<String, dynamic>),
        sent: json['s'] as bool? ?? false,
      );
}
