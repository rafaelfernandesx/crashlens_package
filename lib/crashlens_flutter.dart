/// CrashLens SDK - Mini Sentry para Flutter
///
/// Captura automaticamente erros, exceções, logs e informações do dispositivo,
/// enviando tudo para a API CrashLens.
library crashlens_flutter;

export 'src/crashlens.dart';
export 'src/crashlens_options.dart';
export 'src/session_tracker.dart';
export 'src/navigator_observer.dart';
export 'src/dio_interceptor.dart';
export 'src/http/http_interceptor.dart';
export 'src/models/event.dart';
export 'src/models/user.dart';
export 'src/models/breadcrumb.dart';
export 'src/models/device_info.dart';
export 'src/enums/event_severity.dart';
export 'src/enums/breadcrumb_type.dart';
export 'src/handlers/error_handler.dart';
export 'src/handlers/flutter_error_handler.dart';
export 'src/handlers/platform_dispatcher_handler.dart';
export 'src/http/event_api_client.dart';
export 'src/queue/event_queue.dart';
