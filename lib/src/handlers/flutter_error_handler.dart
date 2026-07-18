import 'package:flutter/foundation.dart';
import '../models/event.dart';
import '../enums/event_severity.dart';
import 'error_handler.dart';

/// Handler para captura de erros do Flutter (FlutterError.onError)
class FlutterErrorHandler extends ErrorHandler {
  ErrorHandler? _previousHandler;

  @override
  CrashLensEvent? captureError(
    dynamic error,
    StackTrace? stackTrace, {
    bool handled = true,
    String? context,
    Map<String, dynamic>? tags,
    Map<String, dynamic>? extra,
  }) {
    return CrashLensEvent(
      apiKey: '', // será preenchido pelo CrashLens._capture
      message: error is FlutterError ? error.message : error.toString(),
      severity: EventSeverity.fatal,
      exceptionType: error.runtimeType.toString(),
      exceptionMessage: error.toString(),
      stackTrace: stackTrace?.toString(),
      timestamp: DateTime.now(),
      handled: handled,
      context: context ?? 'FlutterError.onError',
      tags: tags,
      extra: extra,
      error: error,
    );
  }

  /// Instala o handler no FlutterError.onError
  void install(void Function(CrashLensEvent) onEvent) {
    FlutterError.onError = (FlutterErrorDetails details) {
      final event = captureError(
        details.exception,
        details.stack,
        handled: details.silent,
      );
      if (event != null) {
        onEvent(event);
      }
    };
  }

  /// Remove o handler
  void uninstall() {
    FlutterError.onError = _previousHandler as void Function(FlutterErrorDetails)?;
  }
}
