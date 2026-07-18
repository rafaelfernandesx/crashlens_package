import 'package:flutter/material.dart';
import '../crashlens_flutter.dart';

/// Observer que captura automaticamente a navegação entre rotas Flutter.
/// Gera breadcrumbs automáticos para cada navegação.
///
/// Uso:
/// ```dart
/// MaterialApp(
///   navigatorObservers: [CrashLensNavigatorObserver()],
///   ...
/// )
/// ```
class CrashLensNavigatorObserver extends NavigatorObserver {
  String? _currentRoute;
  final Map<String, DateTime> _routeTimestamps = {};

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logNavigation('push', route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logNavigation('pop', previousRoute, route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _logNavigation('replace', newRoute, oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _logNavigation('remove', route, previousRoute);
  }

  void _logNavigation(String type, Route<dynamic>? route, Route<dynamic>? previousRoute) {
    final routeName = route?.settings.name ?? route?.runtimeType.toString() ?? 'unknown';
    final previousName = previousRoute?.settings.name ?? previousRoute?.runtimeType.toString() ?? 'none';

    final now = DateTime.now();
    final timeOnPrevious = _currentRoute != null
        ? now.difference(_routeTimestamps[_currentRoute] ?? now).inSeconds
        : null;

    _routeTimestamps[routeName] = now;
    _currentRoute = routeName;

    try {
      CrashLens.addBreadcrumb(Breadcrumb(
        type: BreadcrumbType.navigation,
        category: 'navigation',
        message: '$previousName → $routeName',
        data: {
          'from': previousName,
          'to': routeName,
          'type': type,
          'time_on_previous': timeOnPrevious,
        },
      ));
    } catch (_) {
      // CrashLens pode não estar inicializado ainda
    }
  }
}
