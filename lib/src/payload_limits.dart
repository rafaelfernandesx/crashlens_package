import 'dart:convert';

/// Limites de payload aplicados no SDK antes do envio (espelham o SDK JS).
class PayloadLimits {
  PayloadLimits._();

  static const int message = 8 * 1024;
  static const int stackTrace = 64 * 1024;
  static const int breadcrumbs = 50;
  static const int breadcrumbData = 2 * 1024;

  /// extra / tags / context (serializados).
  static const int blob = 32 * 1024;

  /// Tamanho máximo (bytes serializados) de um lote.
  static const int batchBytes = 512 * 1024;

  static const String _suffix = '…[truncated]';

  static String truncate(String value, int max) {
    if (value.length <= max) return value;
    return value.substring(0, max - _suffix.length) + _suffix;
  }

  /// Se o mapa serializado passar de [max], devolve um marcador com prévia.
  static Map<String, dynamic> capMap(Map<String, dynamic> value, int max) {
    try {
      final json = jsonEncode(value);
      if (json.length <= max) return value;
      return {
        '_truncated': true,
        'preview': truncate(json, max < 1024 ? max : 1024),
      };
    } catch (_) {
      return {'_truncated': true};
    }
  }
}
