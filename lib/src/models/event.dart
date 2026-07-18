import '../enums/event_severity.dart';
import 'breadcrumb.dart';
import 'device_info.dart';
import 'user.dart';

/// Evento enviado para a API CrashLens
class CrashLensEvent {
  final String? eventId;
  final String apiKey;
  final String? projectId;
  final String message;
  final EventSeverity severity;
  final String? exceptionType;
  final String? exceptionMessage;
  final String? stackTrace;
  final String? fingerprint;
  final String? release;
  final String? environment;
  final String? context;
  final CrashLensUser? user;
  final String? url;
  final Map<String, dynamic>? tags;
  final Map<String, dynamic>? extra;
  final List<Breadcrumb> breadcrumbs;
  final DeviceInfoData? deviceInfo;
  final DateTime timestamp;
  final bool handled;
  final String? sessionId;

  /// Objeto de erro original (apenas em tempo de execução).
  /// Não é serializado para JSON. Útil em [beforeSend] para fazer
  /// verificações como `event.error is DioException`.
  final dynamic error;

  CrashLensEvent({
    this.eventId,
    required this.apiKey,
    this.projectId,
    required this.message,
    this.severity = EventSeverity.error,
    String? exceptionType,
    this.exceptionMessage,
    this.stackTrace,
    this.fingerprint,
    this.release,
    this.environment,
    this.context,
    this.user,
    this.url,
    this.tags,
    this.extra,
    this.breadcrumbs = const [],
    this.deviceInfo,
    DateTime? timestamp,
    this.handled = true,
    this.sessionId,
    this.error,
  })  : exceptionType = exceptionType ?? error?.runtimeType.toString(),
        timestamp = timestamp ?? DateTime.now();

  /// Cria uma cópia do evento, sobrescrevendo os campos fornecidos.
  /// Útil em [CrashLensOptions.beforeSend] para modificar eventos.
  CrashLensEvent copyWith({
    String? eventId,
    String? apiKey,
    String? projectId,
    String? message,
    EventSeverity? severity,
    String? exceptionType,
    String? exceptionMessage,
    String? stackTrace,
    String? fingerprint,
    String? release,
    String? environment,
    String? context,
    CrashLensUser? user,
    String? url,
    Map<String, dynamic>? tags,
    Map<String, dynamic>? extra,
    List<Breadcrumb>? breadcrumbs,
    DeviceInfoData? deviceInfo,
    DateTime? timestamp,
    bool? handled,
    Object? error,
  }) =>
      CrashLensEvent(
        eventId: eventId ?? this.eventId,
        apiKey: apiKey ?? this.apiKey,
        projectId: projectId ?? this.projectId,
        message: message ?? this.message,
        severity: severity ?? this.severity,
        exceptionType: exceptionType ?? this.exceptionType,
        exceptionMessage: exceptionMessage ?? this.exceptionMessage,
        stackTrace: stackTrace ?? this.stackTrace,
        fingerprint: fingerprint ?? this.fingerprint,
        release: release ?? this.release,
        environment: environment ?? this.environment,
        context: context ?? this.context,
        user: user ?? this.user,
        url: url ?? this.url,
        tags: tags ?? this.tags,
        extra: extra ?? this.extra,
        breadcrumbs: breadcrumbs ?? this.breadcrumbs,
        deviceInfo: deviceInfo ?? this.deviceInfo,
        timestamp: timestamp ?? this.timestamp,
        handled: handled ?? this.handled,
        error: error ?? this.error,
      );

  Map<String, dynamic> toJson() => {
        'message': message,
        'severity': severity.value,
        'exceptionType': exceptionType,
        'exceptionMessage': exceptionMessage,
        'stackTrace': stackTrace,
        'fingerprint': fingerprint,
        'release': release,
        'environment': environment,
        'context': context,
        'user': user?.toJson(),
        'url': url,
        'tags': tags,
        'extra': extra,
        'breadcrumbs': breadcrumbs.map((b) => b.toJson()).toList(),
        'deviceInfo': deviceInfo?.toJson(),
        'timestamp': timestamp.toIso8601String(),
        'handled': handled,
        'sessionId': sessionId,
      };

  factory CrashLensEvent.fromJson(Map<String, dynamic> json) =>
      CrashLensEvent(
        eventId: json['eventId'] as String?,
        apiKey: json['apiKey'] as String,
        projectId: json['projectId'] as String?,
        message: json['message'] as String,
        severity: EventSeverity.fromString(json['severity'] as String? ?? 'error'),
        exceptionType: json['exceptionType'] as String?,
        exceptionMessage: json['exceptionMessage'] as String?,
        stackTrace: json['stackTrace'] as String?,
        fingerprint: json['fingerprint'] as String?,
        release: json['release'] as String?,
        environment: json['environment'] as String?,
        context: json['context'] as String?,
        user: json['user'] != null
            ? CrashLensUser.fromJson(json['user'] as Map<String, dynamic>)
            : null,
        url: json['url'] as String?,
        tags: json['tags'] as Map<String, dynamic>?,
        extra: json['extra'] as Map<String, dynamic>?,
        breadcrumbs: (json['breadcrumbs'] as List<dynamic>?)
                ?.map((b) => Breadcrumb.fromJson(b as Map<String, dynamic>))
                .toList() ??
            [],
        deviceInfo: json['deviceInfo'] != null
            ? DeviceInfoData.fromJson(json['deviceInfo'] as Map<String, dynamic>)
            : null,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : null,
        handled: json['handled'] as bool? ?? true,
      );
}
