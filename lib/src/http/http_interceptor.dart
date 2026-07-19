import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../../crashlens_flutter.dart';

/// Interceptor para o pacote `http` que captura automaticamente requisições HTTP.
/// Gera breadcrumbs e, em caso de erro, anexa informações ao evento.
///
/// Substitui o `http.Client` padrão por uma versão que captura dados:
/// ```dart
/// final client = CrashLensHttpClient(http.Client());
/// final response = await client.get(Uri.parse('https://api.exemplo.com/data'));
/// ```
class CrashLensHttpClient extends http.BaseClient {
  final http.Client _inner;

  /// Headers a serem sanitizados (mostrados com ***)
  final List<String> sanitizeHeaders;

  /// Chaves do body a serem sanitizadas (mostradas com ***)
  final List<String> sanitizeBodyKeys;

  /// Tamanho máximo do body capturado (bytes). Excedente será truncado.
  final int maxBodySize;

  CrashLensHttpClient(
    this._inner, {
    this.sanitizeHeaders = const ['Authorization', 'Cookie', 'Set-Cookie'],
    this.sanitizeBodyKeys = const ['password', 'token', 'accessToken', 'refreshToken', 'creditCard', 'cvv'],
    this.maxBodySize = 4096,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final startTime = DateTime.now();

    // Extrai o body da requisição
    final requestBody = _extractRequestBody(request);

    try {
      final response = await _inner.send(request);
      final duration = DateTime.now().difference(startTime).inMilliseconds;

      // Lê o body da resposta sem quebrar o stream para o caller
      final responseBytes = await response.stream.toBytes();
      final responseBody = _truncateBytes(responseBytes);

      _logRequest(
        method: request.method,
        url: request.url.toString(),
        statusCode: response.statusCode,
        durationMs: duration,
        requestHeaders: request.headers,
        requestBody: requestBody,
        responseBody: responseBody,
        responseHeaders: response.headers,
        errorMessage: null,
      );

      // Retorna uma nova response com o stream reconstruído
      return http.StreamedResponse(
        Stream.value(responseBytes).asBroadcastStream(),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (err) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;

      _logRequest(
        method: request.method,
        url: request.url.toString(),
        statusCode: null,
        durationMs: duration,
        requestHeaders: request.headers,
        requestBody: requestBody,
        responseBody: null,
        responseHeaders: null,
        errorMessage: err.toString(),
      );

      rethrow;
    }
  }

  /// Tenta extrair o body de um [http.BaseRequest].
  /// Funciona com [http.Request] (tem `body`/`bodyBytes`).
  /// Para streams, retorna null.
  String? _extractRequestBody(http.BaseRequest request) {
    try {
      if (request is http.Request) {
        if (request.body.isNotEmpty) {
          return request.body;
        }
        if (request.bodyBytes.isNotEmpty) {
          return _truncateBytes(request.bodyBytes);
        }
      }
      // StreamingRequest — não tenta ler o stream
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Converte bytes para string truncada no [maxBodySize].
  String? _truncateBytes(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    try {
      final text = utf8.decode(bytes);
      if (text.length > maxBodySize) {
        return '${text.substring(0, maxBodySize)}... [truncado]';
      }
      return text;
    } catch (_) {
      return '[${bytes.length} bytes binários]';
    }
  }

  void _logRequest({
    required String method,
    required String url,
    int? statusCode,
    int? durationMs,
    Map<String, String>? requestHeaders,
    String? requestBody,
    String? responseBody,
    Map<String, String>? responseHeaders,
    String? errorMessage,
  }) {
    try {
      // Sempre gera breadcrumb
      CrashLens.addBreadcrumb(Breadcrumb(
        type: BreadcrumbType.http,
        category: 'http',
        message: '$method $url → ${statusCode ?? 'erro'}',
        data: {
          'method': method,
          'url': url,
          'status_code': statusCode,
          'duration_ms': durationMs,
          'request_body': _sanitizeJsonBody(requestBody),
          'response_body': _sanitizeJsonBody(responseBody),
          'error': errorMessage,
        },
      ));

      // Em caso de erro (status >= 400 ou exception), gera evento
      final isError = errorMessage != null || (statusCode != null && statusCode >= 400);
      if (isError) {
        CrashLens.captureEvent(
          message: '$method $url → HTTP ${statusCode ?? "erro"}',
          severity: (statusCode != null && statusCode >= 500) || errorMessage != null
              ? EventSeverity.error
              : EventSeverity.warning,
          exceptionType: errorMessage != null ? 'HttpException' : 'HttpError',
          context: 'HTTP Request',
          tags: {
            'http_method': method,
            'http_url': url,
            'http_status': statusCode?.toString(),
          },
          extra: {
            'duration_ms': durationMs,
            'request_headers': _sanitizeHeaders(requestHeaders),
            'request_body': _sanitizeJsonBody(requestBody),
            'response_headers': _sanitizeHeaders(responseHeaders),
            'response_body': _sanitizeJsonBody(responseBody),
            'error': errorMessage,
          },
        );
      }
    } catch (_) {}
  }

  /// Sanitiza um body JSON, escondendo chaves sensíveis.
  String? _sanitizeJsonBody(String? body) {
    if (body == null || body.isEmpty) return body;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final sanitized = Map<String, dynamic>.from(decoded);
        for (final key in sanitizeBodyKeys) {
          if (sanitized.containsKey(key)) sanitized[key] = '***';
        }
        return jsonEncode(sanitized);
      }
      return body;
    } catch (_) {
      return body;
    }
  }

  Map<String, String> _sanitizeHeaders(Map<String, String>? headers) {
    if (headers == null) return {};
    final sanitized = <String, String>{};
    headers.forEach((key, value) {
      sanitized[key] = sanitizeHeaders.contains(key) ? '***' : value;
    });
    return sanitized;
  }

  @override
  void close() {
    _inner.close();
  }
}

/// Extensão para criar o client interceptado facilmente
extension CrashLensHttpExtension on http.Client {
  /// Retorna um [CrashLensHttpClient] que captura automaticamente
  /// as requisições como breadcrumbs e eventos de erro.
  CrashLensHttpClient get withCrashLens => CrashLensHttpClient(this);
}
