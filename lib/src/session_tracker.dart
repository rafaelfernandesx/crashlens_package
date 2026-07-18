import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Gerencia sessões do usuário, similar ao Sentry Sessions.
/// Cada sessão rastreia se houve crash e é enviada ao backend.
class SessionTracker {
  final String apiKey;
  final String baseUrl;
  final String sessionId;
  final DateTime startedAt;
  final String? release;
  final String environment;
  final String? appVersion;
  final String? buildNumber;
  final String? platform;
  final String? deviceId;

  bool _crashed = false;
  bool _ended = false;
  DateTime? _endedAt;
  Timer? _heartbeat;

  SessionTracker({
    required this.apiKey,
    required this.baseUrl,
    required this.environment,
    String? sessionId,
    this.release,
    this.appVersion,
    this.buildNumber,
    this.platform,
    this.deviceId,
  })  : sessionId = sessionId ?? const Uuid().v4(),
        startedAt = DateTime.now();

  void markCrashed() {
    _crashed = true;
  }

  bool get crashed => _crashed;
  bool get isEnded => _ended;

  /// Inicia heartbeat para detectar sessões abandonadas
  void startHeartbeat(Duration interval) {
    _heartbeat = Timer.periodic(interval, (_) {
      if (_ended) {
        _heartbeat?.cancel();
      }
    });
  }

  /// Encerra a sessão e a envia ao backend
  Future<void> end() async {
    if (_ended) return;
    _ended = true;
    _endedAt = DateTime.now();
    _heartbeat?.cancel();

    final duration = _endedAt!.difference(startedAt).inSeconds;
    debugPrint('[CrashLens] Session ended: $sessionId (${duration}s, crashed: $_crashed)');
  }
}
