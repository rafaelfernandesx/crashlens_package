import 'dart:convert';
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
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': event.apiKey,
            },
            body: jsonEncode(event.toJson()),
          )
          .timeout(Duration(milliseconds: timeoutMs));

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
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': events.first.apiKey,
            },
            body: jsonEncode(events.map((e) => e.toJson()).toList()),
          )
          .timeout(Duration(milliseconds: timeoutMs));

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}
