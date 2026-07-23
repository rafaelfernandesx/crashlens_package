import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'http/event_api_client.dart';

/// Gerencia sessões do usuário, similar ao Sentry Sessions.
/// Cada sessão rastreia se houve crash e é enviada ao backend.
class SessionTracker {
  final String apiKey;
  final String baseUrl;
  final String sessionId;
  final DateTime startedAt;
  final String? release;
  final String? appVersion;
  final String? buildNumber;
  final String? platform;
  final String? deviceId;
  final EventApiClient? _apiClient;

  bool _crashed = false;
  bool _ended = false;
  bool _started = false;
  DateTime? _endedAt;
  Timer? _heartbeat;

  SessionTracker({
    required this.apiKey,
    required this.baseUrl,
    String? sessionId,
    this.release,
    this.appVersion,
    this.buildNumber,
    this.platform,
    this.deviceId,
    EventApiClient? apiClient,
  })  : sessionId = sessionId ?? const Uuid().v4(),
        startedAt = DateTime.now(),
        _apiClient = apiClient;

  void markCrashed() {
    _crashed = true;
  }

  bool get crashed => _crashed;
  bool get isEnded => _ended;

  /// Inicia heartbeat para manter a sessão ativa no backend
  void startHeartbeat(Duration interval) {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(interval, (_) async {
      if (_ended) {
        _heartbeat?.cancel();
        return;
      }
      if (_apiClient != null) {
        await _apiClient!.sendHeartbeat(
          apiKey: apiKey,
          sessionId: sessionId,
        );
      }
    });
  }

  /// Para o heartbeat
  void stopHeartbeat() {
    _heartbeat?.cancel();
  }

  /// Envia o início da sessão ao backend
  Future<void> start() async {
    if (_started) return;
    _started = true;

    if (_apiClient == null) {
      debugPrint('[CrashLens] Session API client não configurado. Sessão local: $sessionId');
      return;
    }

    final ok = await _apiClient!.sendSessionStart(
      apiKey: apiKey,
      sessionId: sessionId,
      startedAt: startedAt.toIso8601String(),
      platform: platform,
      appVersion: appVersion,
      buildNumber: buildNumber,
      deviceId: deviceId,
      release: release,
    );

    if (ok) {
      debugPrint('[CrashLens] Sessão iniciada no backend: $sessionId');
    } else {
      debugPrint('[CrashLens] Falha ao enviar início da sessão: $sessionId');
    }
  }

  /// Encerra a sessão e a envia ao backend
  Future<void> end() async {
    if (_ended) return;
    _ended = true;
    _endedAt = DateTime.now();
    _heartbeat?.cancel();

    final duration = _endedAt!.difference(startedAt).inSeconds;

    if (_apiClient != null) {
      await _apiClient!.sendSessionEnd(
        apiKey: apiKey,
        sessionId: sessionId,
        endedAt: _endedAt!.toIso8601String(),
        crashed: _crashed,
        duration: duration,
      );
    }

    debugPrint('[CrashLens] Session ended: $sessionId (${duration}s, crashed: $_crashed)');
  }
}
