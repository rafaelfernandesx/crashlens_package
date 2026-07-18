import 'package:flutter/foundation.dart';
import '../enums/event_severity.dart';
import '../models/event.dart';

/// Handler para captura de exceções não tratadas via PlatformDispatcher
class PlatformDispatcherHandler {
  void install(void Function(CrashLensEvent) onEvent) {
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      final event = CrashLensEvent(
        apiKey: '',
        message: error.toString(),
        severity: EventSeverity.fatal,
        exceptionType: error.runtimeType.toString(),
        exceptionMessage: error.toString(),
        stackTrace: stack.toString(),
        timestamp: DateTime.now(),
        handled: false,
        context: 'PlatformDispatcher.onError',
        error: error,
      );
      onEvent(event);
      return true; // não propaga o erro
    };
  }

  void uninstall() {
    PlatformDispatcher.instance.onError = null;
  }
}
