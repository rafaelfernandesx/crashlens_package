import 'package:flutter_test/flutter_test.dart';
import 'package:crashlens_flutter/crashlens_flutter.dart';

void main() {
  group('CrashLensUser', () {
    test('deve criar usuário com id e email', () {
      final user = CrashLensUser(
        id: 'user-123',
        email: 'test@test.com',
        name: 'Test User',
      );

      expect(user.id, 'user-123');
      expect(user.email, 'test@test.com');
      expect(user.name, 'Test User');
    });

    test('deve serializar para JSON', () {
      final user = CrashLensUser(
        id: 'user-123',
        username: 'testuser',
        email: 'test@test.com',
        ipAddress: '192.168.1.1',
        name: 'Test User',
      );

      final json = user.toJson();
      expect(json['id'], 'user-123');
      expect(json['username'], 'testuser');
      expect(json['email'], 'test@test.com');
      expect(json['ip_address'], '192.168.1.1');
      expect(json['name'], 'Test User');
    });

    test('deve restaurar de JSON', () {
      final json = {
        'id': 'user-456',
        'username': 'johndoe',
        'email': 'john@test.com',
      };

      final user = CrashLensUser.fromJson(json);
      expect(user.id, 'user-456');
      expect(user.username, 'johndoe');
      expect(user.email, 'john@test.com');
    });
  });

  group('EventSeverity', () {
    test('deve ter todos os valores', () {
      expect(EventSeverity.debug.value, 'debug');
      expect(EventSeverity.info.value, 'info');
      expect(EventSeverity.warning.value, 'warning');
      expect(EventSeverity.error.value, 'error');
      expect(EventSeverity.fatal.value, 'fatal');
    });

    test('deve restaurar de string', () {
      expect(EventSeverity.fromString('debug'), EventSeverity.debug);
      expect(EventSeverity.fromString('info'), EventSeverity.info);
      expect(EventSeverity.fromString('warning'), EventSeverity.warning);
      expect(EventSeverity.fromString('error'), EventSeverity.error);
      expect(EventSeverity.fromString('fatal'), EventSeverity.fatal);
      expect(EventSeverity.fromString('unknown'), EventSeverity.info);
    });
  });

  group('BreadcrumbType', () {
    test('deve ter todos os valores', () {
      expect(BreadcrumbType.navigation.value, 'navigation');
      expect(BreadcrumbType.http.value, 'http');
      expect(BreadcrumbType.gesture.value, 'gesture');
      expect(BreadcrumbType.lifecycle.value, 'lifecycle');
      expect(BreadcrumbType.error.value, 'error');
      expect(BreadcrumbType.debug.value, 'debug');
      expect(BreadcrumbType.custom.value, 'custom');
    });

    test('deve restaurar de string', () {
      expect(BreadcrumbType.fromString('navigation'), BreadcrumbType.navigation);
      expect(BreadcrumbType.fromString('http'), BreadcrumbType.http);
      expect(BreadcrumbType.fromString('unknown'), BreadcrumbType.custom);
    });
  });

  group('Breadcrumb', () {
    test('deve criar breadcrumb com valores mínimos', () {
      final breadcrumb = Breadcrumb(
        message: 'Test breadcrumb',
        type: BreadcrumbType.custom,
      );

      expect(breadcrumb.message, 'Test breadcrumb');
      expect(breadcrumb.type, BreadcrumbType.custom);
      expect(breadcrumb.category, isNull);
    });

    test('deve criar breadcrumb com todos os campos', () {
      final breadcrumb = Breadcrumb(
        message: 'Navigation occurred',
        type: BreadcrumbType.navigation,
        category: 'navigation',
        data: {'from': '/home', 'to': '/checkout'},
      );

      expect(breadcrumb.message, 'Navigation occurred');
      expect(breadcrumb.type, BreadcrumbType.navigation);
      expect(breadcrumb.category, 'navigation');
      expect(breadcrumb.data!['from'], '/home');
      expect(breadcrumb.data!['to'], '/checkout');
    });

    test('deve serializar para JSON', () {
      final breadcrumb = Breadcrumb(
        message: 'Test',
        type: BreadcrumbType.gesture,
        category: 'ui',
        data: {'action': 'click'},
      );

      final json = breadcrumb.toJson();
      expect(json['message'], 'Test');
      expect(json['type'], 'gesture');
      expect(json['category'], 'ui');
      expect(json['data']['action'], 'click');
      expect(json['timestamp'], isNotNull);
    });

    test('deve restaurar de JSON', () {
      final json = {
        'message': 'HTTP request',
        'type': 'http',
        'category': 'network',
        'data': {'status': 200},
        'timestamp': '2024-01-01T00:00:00.000',
      };

      final breadcrumb = Breadcrumb.fromJson(json);
      expect(breadcrumb.message, 'HTTP request');
      expect(breadcrumb.type, BreadcrumbType.http);
      expect(breadcrumb.category, 'network');
      expect(breadcrumb.data!['status'], 200);
    });
  });

  group('DeviceInfoData', () {
    test('deve criar com valores básicos', () {
      final info = DeviceInfoData(
        deviceName: 'Test Device',
        deviceModel: 'Pixel 6',
        deviceOs: 'android',
        osVersion: '14',
      );

      expect(info.deviceName, 'Test Device');
      expect(info.deviceModel, 'Pixel 6');
      expect(info.deviceOs, 'android');
      expect(info.osVersion, '14');
    });

    test('deve serializar para JSON', () {
      final info = DeviceInfoData(
        deviceName: 'Test',
        deviceOs: 'ios',
        osVersion: '17.0',
        appVersion: '1.0.0',
        buildNumber: '1',
      );

      final json = info.toJson();
      expect(json['deviceName'], 'Test');
      expect(json['deviceOs'], 'ios');
      expect(json['osVersion'], '17.0');
      expect(json['appVersion'], '1.0.0');
      expect(json['buildNumber'], '1');
    });

    test('deve restaurar de JSON', () {
      final json = {
        'deviceName': 'My Phone',
        'deviceModel': 'iPhone 15',
        'deviceOs': 'ios',
        'osVersion': '17.2',
        'isPhysicalDevice': true,
      };

      final info = DeviceInfoData.fromJson(json);
      expect(info.deviceName, 'My Phone');
      expect(info.deviceModel, 'iPhone 15');
      expect(info.deviceOs, 'ios');
      expect(info.osVersion, '17.2');
      expect(info.isPhysicalDevice, isTrue);
    });
  });

  group('CrashLensOptions', () {
    test('deve criar com valores padrão', () {
      final options = CrashLensOptions(
        apiKey: 'test-key',
      );

      expect(options.apiKey, 'test-key');
      expect(options.baseUrl, 'https://apicrashlens.laziv.com/api');
      expect(options.flushIntervalSeconds, 5);
      expect(options.maxBreadcrumbs, 100);
      expect(options.enableFlutterErrorCapture, isTrue);
      expect(options.enablePlatformDispatcherCapture, isTrue);
      expect(options.enableZoneCapture, isTrue);
      expect(options.enableAutoBreadcrumbs, isTrue);
      expect(options.sampleRate, 1.0);
      expect(options.sendInDebug, isFalse);
      expect(options.httpTimeoutMs, 15000);
      expect(options.maxRetries, 3);
      expect(options.captureLocally, isFalse);
      expect(options.beforeSend, isNull);
    });

    test('deve aceitar valores personalizados', () {
      final options = CrashLensOptions(
        apiKey: 'custom-key',
        baseUrl: 'https://custom.api.com',
        flushIntervalSeconds: 10,
        sampleRate: 0.5,
        sendInDebug: true,
        captureLocally: true,
      );

      expect(options.apiKey, 'custom-key');
      expect(options.baseUrl, 'https://custom.api.com');
      expect(options.flushIntervalSeconds, 10);
      expect(options.sampleRate, 0.5);
      expect(options.sendInDebug, isTrue);
      expect(options.captureLocally, isTrue);
    });
  });

  group('CrashLensEvent', () {
    test('deve criar evento com valores básicos', () {
      final event = CrashLensEvent(
        apiKey: 'test-key',
        message: 'Test error',
      );

      expect(event.apiKey, 'test-key');
      expect(event.message, 'Test error');
      expect(event.severity, EventSeverity.error);
      expect(event.handled, isTrue);
      expect(event.timestamp, isNotNull);
    });

    test('deve criar evento personalizado', () {
      final event = CrashLensEvent(
        apiKey: 'test-key',
        message: 'Custom event',
        severity: EventSeverity.warning,
        exceptionType: 'MyException',
        context: 'TestContext',
        handled: false,
      );

      expect(event.severity, EventSeverity.warning);
      expect(event.exceptionType, 'MyException');
      expect(event.context, 'TestContext');
      expect(event.handled, isFalse);
    });

    test('deve copiar com copyWith', () {
      final event = CrashLensEvent(
        apiKey: 'test-key',
        message: 'Original',
      );

      final copied = event.copyWith(
        message: 'Modified',
        severity: EventSeverity.fatal,
      );

      expect(copied.message, 'Modified');
      expect(copied.severity, EventSeverity.fatal);
      expect(copied.apiKey, 'test-key');
    });

    test('deve serializar para JSON', () {
      final event = CrashLensEvent(
        apiKey: 'test-key',
        message: 'Test event',
        severity: EventSeverity.error,
        exceptionType: 'Exception',
        handled: true,
      );

      final json = event.toJson();
      expect(json['apiKey'], 'test-key');
      expect(json['message'], 'Test event');
      expect(json['severity'], 'error');
      expect(json['exceptionType'], 'Exception');
      expect(json['handled'], isTrue);
    });
  });
}
