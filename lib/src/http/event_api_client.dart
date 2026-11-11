import 'dart:convert';
import 'dart:io' show HttpDate;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/event.dart';

/// Cliente HTTP para enviar eventos para a API CrashLens
class EventApiClient {
  final String baseUrl;
  final int timeoutMs;
  final http.Client _client;

  /// Flag: o plano do workspace atingiu o limite. SDK deve pausar envios.
  bool quotaExceeded = false;

  EventApiClient({
    required this.baseUrl,
    this.timeoutMs = 15000,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Envia um evento para a API
  Future<bool> sendEvent(CrashLensEvent event) async =>
      (await postEvent(event)).isSuccess;

  /// Envia múltiplos eventos em lote
  Future<bool> sendBatch(List<CrashLensEvent> events) async =>
      (await postBatch(events)).isSuccess;

  /// Envia um evento e devolve o resultado detalhado (status, Retry-After, corpo).
  Future<SendResult> postEvent(CrashLensEvent event) => _post(
        '$baseUrl/events',
        event.apiKey,
        jsonEncode(event.toIngestJson()),
      );

  /// Envia um lote e devolve o resultado detalhado.
  /// Com resposta 2xx, [SendResult.itemResults] traz o resultado por item
  /// (`{results:[{index, ok, error?}]}`), quando o servidor o informa.
  Future<SendResult> postBatch(List<CrashLensEvent> events) {
    if (events.isEmpty) return Future.value(const SendResult(200));
    return _post(
      '$baseUrl/events/batch',
      events.first.apiKey,
      jsonEncode(events.map((e) => e.toIngestJson()).toList()),
    );
  }

  Future<SendResult> _post(String url, String apiKey, String body) async {
    try {
      final response = await _client
          .post(Uri.parse(url), headers: _headers(apiKey), body: body)
          .timeout(Duration(milliseconds: timeoutMs));

      final status = response.statusCode;
      // 402 = limite do plano: o SDK deve pausar. 429 é apenas rate limit (backoff).
      if (status == 402) {
        quotaExceeded = true;
        debugPrint('[CrashLens] Limite do plano atingido (402). SDK será pausado.');
      } else {
        quotaExceeded = false;
      }

      return SendResult(
        status,
        retryAfter: _parseRetryAfter(response.headers['retry-after']),
        itemResults: status >= 200 && status < 300
            ? _parseItemResults(response.body)
            : null,
      );
    } catch (e) {
      return const SendResult(0);
    }
  }

  static Duration? _parseRetryAfter(String? value) {
    if (value == null || value.isEmpty) return null;
    final secs = num.tryParse(value.trim());
    if (secs != null) return Duration(seconds: secs.ceil() < 0 ? 0 : secs.ceil());
    try {
      final diff = HttpDate.parse(value).difference(DateTime.now().toUtc());
      return diff.isNegative ? Duration.zero : diff;
    } catch (_) {
      return null;
    }
  }

  static Map<int, BatchItemResult>? _parseItemResults(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['results'] is! List) return null;
      final map = <int, BatchItemResult>{};
      final list = decoded['results'] as List;
      for (var pos = 0; pos < list.length; pos++) {
        final r = list[pos];
        if (r is! Map) continue;
        final index = r['index'] is int ? r['index'] as int : pos;
        map[index] = BatchItemResult(ok: r['ok'] != false, error: r['error']);
      }
      return map;
    } catch (_) {
      return null;
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
    String? deviceModel,
    String? deviceManufacturer,
    String? deviceOs,
    String? deviceOsVersion,
    String? locale,
    String? release,
    Map<String, dynamic>? platformInfo,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/sessions');
      final body = {
        'sessionId': sessionId,
        'startedAt': startedAt,
        'platform': platform,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'deviceId': deviceId,
        'deviceModel': deviceModel,
        'deviceManufacturer': deviceManufacturer,
        'deviceOs': deviceOs,
        'deviceOsVersion': deviceOsVersion,
        'locale': locale,
        'release': release,
        if (platformInfo != null) 'platformInfo': platformInfo,
      };
      final response = await _client
          .post(
            uri,
            headers: _headers(apiKey),
            body: jsonEncode(body),
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

  /// Envia um heartbeat para manter a sessão ativa no backend
  Future<bool> sendHeartbeat({
    required String apiKey,
    required String sessionId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/sessions/$sessionId/heartbeat');
      final response = await _client
          .put(uri, headers: _headers(apiKey))
          .timeout(Duration(milliseconds: timeoutMs));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Map<String, String> _headers(String apiKey) => {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      };

  /// Valida se a API Key é válida chamando o endpoint dedicado de validação
  Future<bool> validateApiKey(String apiKey) async {
    try {
      final uri = Uri.parse('$baseUrl/api-keys/validate');
      final response = await _client
          .post(
            uri,
            headers: _headers(apiKey),
            body: jsonEncode({'apiKey': apiKey}),
          )
          .timeout(Duration(milliseconds: timeoutMs));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['valid'] == true;
      }
      // 429 = rate limit do IP, considera válida para não bloquear
      return true;
    } catch (_) {
      // Timeout ou erro de rede — considera válida para não bloquear offline
      return true;
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Resultado detalhado de uma requisição de envio de eventos.
class SendResult {
  /// Status HTTP, ou 0 em caso de erro de rede/timeout.
  final int statusCode;

  /// Valor do header Retry-After (se enviado).
  final Duration? retryAfter;

  /// Resultado por item de um lote (2xx), quando informado pelo servidor.
  final Map<int, BatchItemResult>? itemResults;

  const SendResult(this.statusCode, {this.retryAfter, this.itemResults});

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// Resultado de um item dentro de um lote.
class BatchItemResult {
  final bool ok;
  final dynamic error;

  const BatchItemResult({required this.ok, this.error});
}
