import 'dart:convert';
import 'package:dio/dio.dart';
import '../crashlens_flutter.dart';

/// Interceptor do Dio que captura automaticamente requisições HTTP.
/// Gera breadcrumbs e, em caso de erro, anexa informações ao evento.
///
/// Uso:
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(CrashLensDioInterceptor());
/// ```
class CrashLensDioInterceptor extends Interceptor {
  /// Headers a serem sanitizados (mostrados com ***)
  final List<String> sanitizeHeaders;

  /// Chaves do body a serem sanitizadas (mostradas com ***)
  final List<String> sanitizeBodyKeys;

  CrashLensDioInterceptor({
    this.sanitizeHeaders = const ['Authorization', 'Cookie', 'Set-Cookie'],
    this.sanitizeBodyKeys = const ['password', 'token', 'accessToken', 'refreshToken', 'creditCard', 'cvv'],
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final startTime = DateTime.now();
    options.extra['_crashlens_start_time'] = startTime;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logRequest(response.requestOptions, response.statusCode, null);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logRequest(err.requestOptions, err.response?.statusCode, err);
    handler.next(err);
  }

  void _logRequest(RequestOptions options, int? statusCode, DioException? error) {
    final startTime = options.extra['_crashlens_start_time'] as DateTime?;
    final duration = startTime != null
        ? DateTime.now().difference(startTime).inMilliseconds
        : null;

    try {
      CrashLens.addBreadcrumb(Breadcrumb(
        type: BreadcrumbType.http,
        category: 'http',
        message: '${options.method} ${options.uri} → $statusCode${error != null ? ' (erro)' : ''}',
        data: {
          'method': options.method,
          'url': options.uri.toString(),
          'status_code': statusCode,
          'duration_ms': duration,
          'request_body': _sanitizeBodyToJson(options.data),
          'response_body': _safeResponseBody(error?.response?.data),
          'error': error?.message,
        },
      ));

      if (error != null) {
        // Adiciona informações detalhadas via evento personalizado
        CrashLens.captureEvent(
          message: '${options.method} ${options.uri} → HTTP $statusCode',
          severity: statusCode != null && statusCode >= 500
              ? EventSeverity.error
              : EventSeverity.warning,
          exceptionType: 'DioException',
          context: 'HTTP Request',
          tags: {
            'http_method': options.method,
            'http_url': options.uri.toString(),
            'http_status': statusCode?.toString(),
          },
          extra: {
            'duration_ms': duration,
            'query_params': jsonEncode(_sanitizeMap(options.queryParameters)),
            'request_headers': jsonEncode(_sanitizeHeaders(options.headers)),
            'request_body': _sanitizeBodyToJson(options.data),
            'response_body': _safeResponseBody(error.response?.data),
          },
        );
      }
    } catch (_) {}
  }

  Map<String, String> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = <String, String>{};
    headers.forEach((key, value) {
      sanitized[key] = sanitizeHeaders.contains(key) ? '***' : '${value ?? ''}';
    });
    return sanitized;
  }

  String? _sanitizeBodyToJson(dynamic data) {
    if (data == null) return null;
    try {
      if (data is Map) {
        final sanitized = Map<String, dynamic>.from(data);
        for (final key in sanitizeBodyKeys) {
          if (sanitized.containsKey(key)) sanitized[key] = '***';
        }
        return jsonEncode(sanitized);
      }
      if (data is List) {
        return jsonEncode(data);
      }
      if (data is String) {
        try {
          final parsed = jsonDecode(data);
          if (parsed is Map) {
            final sanitized = Map<String, dynamic>.from(parsed);
            for (final key in sanitizeBodyKeys) {
              if (sanitized.containsKey(key)) sanitized[key] = '***';
            }
            return jsonEncode(sanitized);
          }
        } catch (_) {}
        return data;
      }
      return data.toString();
    } catch (_) {
      return data?.toString();
    }
  }

  String? _safeResponseBody(dynamic data) {
    if (data == null) return null;
    try {
      if (data is Map || data is List) return jsonEncode(data);
      return data.toString();
    } catch (_) {
      return data?.toString();
    }
  }

  Map<String, String> _sanitizeMap(Map<String, dynamic> map) {
    if (map.isEmpty) return {};
    return map.map((k, v) => MapEntry(k, '$v'));
  }
}
