import '../models/event.dart';

/// Interface para handlers de erro
abstract class ErrorHandler {
  /// Captura um erro e retorna um evento CrashLens
  CrashLensEvent? captureError(
    dynamic error,
    StackTrace? stackTrace, {
    bool handled = true,
    String? context,
    Map<String, dynamic>? tags,
    Map<String, dynamic>? extra,
  });
}
