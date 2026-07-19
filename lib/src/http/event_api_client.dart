import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/event.dart';

/// Cliente HTTP para enviar eventos para a API CrashLens
class EventApiClient {
  final String baseUrl;
  final int timeoutMs;
  final http.Client _client;

  EventApiClient({
    required this.baseUrl,
    this.timeoutMs = 15000,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Envia um evento para a API
  Future<bool> sendEvent(CrashLensEvent event) async {
    try {
      final uri = Uri.parse('$baseUrl/events');
      final response = await _client
          .post(
            uri,
            headers: _headers(event.apiKey),
            body: jsonEncode(event.toJson()),
          )
          .timeout(Duration(milliseconds: timeoutMs));

      // 402 = plano excedido — não tenta mais
      if (response.statusCode == 402 || response.statusCode == 429) {
        debugPrint('[CrashLens] Limite do plano atingido (${response.statusCode}). Eventos pausados.');
        return false;
      }

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Envia múltiplos eventos em lote
  Future<bool> sendBatch(List<CrashLensEvent> events) async {
    if (events.isEmpty) return true;
    try {
      final uri = Uri.parse('$baseUrl/events/batch');
      final response = await _client
          .post(
            uri,
            headers: _headers(events.first.apiKey),
            body: jsonEncode(events.map((e) => e.toJson()).toList()),
          )
          .timeout(Duration(milliseconds: timeoutMs));

      if (response.statusCode == 402 || response.statusCode == 429) {
        debugPrint('[CrashLens] Limite do plano atingido em batch. Eventos pausados.');
        return false;
      }

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Envia o início de uma sessão para o backend
  Future<bool> sendSessionStart({
    required String apiKey,
    required String sessionId,
    required String startedAt,
    String? platform,
    String? appVersion,
    String? buildNumber,
    String? deviceId,
    String? release,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/sessions');
      final response = await _client
          .post(
            uri,
            headers: _headers(apiKey),
            body: jsonEncode({
              'sessionId': sessionId,
              'startedAt': startedAt,
              'platform': platform,
              'appVersion': appVersion,
              'buildNumber': buildNumber,
              'deviceId': deviceId,
              'release': release,
            }),
          )
          .timeout(Duration(milliseconds: timeoutMs));

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Envia o fim de uma sessão para o backend
  Future<bool> sendSessionEnd({
    required String apiKey,
    required String sessionId,
    required String endedAt,
    bool crashed = false,
    int? duration,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/sessions/$sessionId/end');
      final response = await _client
          .put(
            uri,
            headers: _headers(apiKey),
            body: jsonEncode({
              'endedAt': endedAt,
              'crashed': crashed,
              'duration': duration,
            }),
          )
          .timeout(Duration(milliseconds: timeoutMs));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Map<String, String> _headers(String apiKey) => {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      };

  void dispose() {
    _client.close();
  }
}
