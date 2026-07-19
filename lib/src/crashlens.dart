import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stack_trace/stack_trace.dart' as st;
import 'package:uuid/uuid.dart';
import '../crashlens_flutter.dart';

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
  SessionTracker? _session;
  SharedPreferences? _prefs;

  static const _storageKey = 'crashlens_events';
  static const _maxLocalErrors = 500;

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

    // Reenvia eventos pendentes de execuções anteriores
    await _resendPending();

    // Configura client HTTP
    _apiClient = EventApiClient(
      baseUrl: _options.baseUrl,
      timeoutMs: _options.httpTimeoutMs,
    );

    // Configura fila de eventos
    _queue = EventQueue(
      apiClient: _apiClient!,
      maxRetries: _options.maxRetries,
      onBatchSent: _onBatchSent,
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
    _session = SessionTracker(
      apiKey: _options.apiKey,
      baseUrl: _options.baseUrl,
      apiClient: _apiClient,
      release: _options.release ?? _packageInfo?.version,
      appVersion: _packageInfo?.version,
      buildNumber: _packageInfo?.buildNumber,
      platform: _platformName(),
      deviceId: _deviceInfo?.deviceModel,
    );

    // Envia início da sessão para o backend
    await _session!.start();

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

  Future<void> _collectDeviceAndAppInfo() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {}

    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await deviceInfoPlugin.androidInfo;
        _deviceInfo = DeviceInfoData(
          deviceName: '${info.brand} ${info.model}',
          deviceModel: info.model,
          deviceOs: 'android',
          osVersion: info.version.release,
          deviceType: 'phone',
          isPhysicalDevice: info.isPhysicalDevice,
          cpuArchitecture: info.supportedAbis.isNotEmpty ? info.supportedAbis.first : null,
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await deviceInfoPlugin.iosInfo;
        _deviceInfo = DeviceInfoData(
          deviceName: info.name,
          deviceModel: info.model,
          deviceOs: 'ios',
          osVersion: info.systemVersion,
          deviceType: 'phone',
          isPhysicalDevice: info.isPhysicalDevice,
          cpuArchitecture: null,
        );
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final info = await deviceInfoPlugin.windowsInfo;
        _deviceInfo = DeviceInfoData(
          deviceName: info.computerName,
          deviceOs: 'windows',
          osVersion: '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}',
          deviceType: 'desktop',
          cpuArchitecture: '${info.majorVersion}.${info.minorVersion}.${info.buildNumber}',
        );
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final info = await deviceInfoPlugin.macOsInfo;
        _deviceInfo = DeviceInfoData(
          deviceOs: 'macos',
          osVersion: info.osRelease,
          deviceType: 'desktop',
        );
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        final info = await deviceInfoPlugin.linuxInfo;
        _deviceInfo = DeviceInfoData(
          deviceName: info.name,
          deviceOs: 'linux',
          osVersion: info.versionId,
          deviceType: 'desktop',
        );
      }
    } catch (_) {}

    // Preenche info do app
    _deviceInfo = DeviceInfoData(
      deviceName: _deviceInfo?.deviceName,
      deviceModel: _deviceInfo?.deviceModel,
      deviceOs: _deviceInfo?.deviceOs,
      osVersion: _deviceInfo?.osVersion,
      deviceType: _deviceInfo?.deviceType,
      screenResolution: _deviceInfo?.screenResolution,
      isPhysicalDevice: _deviceInfo?.isPhysicalDevice,
      cpuArchitecture: _deviceInfo?.cpuArchitecture,
      appVersion: _packageInfo?.version,
      buildNumber: _packageInfo?.buildNumber,
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
        fingerprint: _generateFingerprint(error, stack),
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
      fingerprint: instance._generateFingerprint(error, stack),
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

    // Adiciona eventId e fingerprint se não definido
    final effectiveFingerprint = event.fingerprint ?? computeEventHash(event);
    final finalEvent = CrashLensEvent(
      eventId: _uuid.v4(),
      apiKey: event.apiKey.isNotEmpty ? event.apiKey : _options.apiKey,
      projectId: event.projectId,
      message: event.message,
      severity: event.severity,
      exceptionType: event.exceptionType,
      exceptionMessage: event.exceptionMessage,
      stackTrace: event.stackTrace,
      fingerprint: effectiveFingerprint,
      release: event.release ?? _options.release ?? _packageInfo?.version,
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

  /// Gera um fingerprint único baseado no erro e stack trace
  String _generateFingerprint(dynamic error, StackTrace stackTrace) {
    try {
      final chain = st.Trace.from(stackTrace);
      final frames = chain.frames;

      if (frames.isEmpty) {
        return '${error.runtimeType.hashCode}-no-frames';
      }

      // Pega os 5 frames principais
      final keyFrames = frames.take(5).map((f) {
        return '${f.uri}:${f.line}';
      }).join('|');

      final type = error.runtimeType.toString();
      return '${type.hashCode}-${keyFrames.hashCode}';
    } catch (_) {
      try {
        return '${error.runtimeType.hashCode}-${stackTrace.hashCode}';
      } catch (_) {
        return DateTime.now().millisecondsSinceEpoch.toString();
      }
    }
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
