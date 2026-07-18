import 'models/event.dart';
import 'models/user.dart';

/// Opções de configuração do CrashLens
class CrashLensOptions {
  /// Chave da API (obrigatória)
  final String apiKey;

  /// URL base da API CrashLens
  final String baseUrl;

  /// Ambiente (production, staging, development)
  final String environment;

  /// Versão da release do app
  final String? release;

  /// Intervalo de envio em segundos (padrão: 5s)
  final int flushIntervalSeconds;

  /// Máximo de breadcrumbs armazenados (padrão: 100)
  final int maxBreadcrumbs;

  /// Ativar captura automática de FlutterError
  final bool enableFlutterErrorCapture;

  /// Ativar captura automática de PlatformDispatcher
  final bool enablePlatformDispatcherCapture;

  /// Ativar captura automática de zonas
  final bool enableZoneCapture;

  /// Ativar breadcrumbs automáticos
  final bool enableAutoBreadcrumbs;

  /// Percentual de amostragem (0.0 a 1.0)
  final double sampleRate;

  /// Enviar eventos mesmo em modo debug
  final bool sendInDebug;

  /// Usuário atual (enviado com todos os eventos)
  final CrashLensUser? user;

  /// Tags globais enviadas com todos os eventos
  final Map<String, dynamic>? tags;

  /// Timeout HTTP em milissegundos
  final int httpTimeoutMs;

  /// Máximo de tentativas de retry
  final int maxRetries;

  /// Callback para antes de enviar um evento (permite modificar/descartar)
  /// Retorne o evento modificado, ou null para descartá-lo.
  final CrashLensEvent? Function(CrashLensEvent event)? beforeSend;

  CrashLensOptions({
    required this.apiKey,
    this.baseUrl = 'https://apicrashlens.laziv.com/api',
    this.environment = 'production',
    this.release,
    this.flushIntervalSeconds = 5,
    this.maxBreadcrumbs = 100,
    this.enableFlutterErrorCapture = true,
    this.enablePlatformDispatcherCapture = true,
    this.enableZoneCapture = true,
    this.enableAutoBreadcrumbs = true,
    this.sampleRate = 1.0,
    this.sendInDebug = false,
    this.user,
    this.tags,
    this.httpTimeoutMs = 15000,
    this.maxRetries = 3,
    this.beforeSend,
  });
}
