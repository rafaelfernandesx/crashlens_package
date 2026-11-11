import 'dart:convert';

import 'package:crashlens_flutter/crashlens_flutter.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

CrashLensEvent _event(String message, {String? eventId, int size = 0}) =>
    CrashLensEvent(
      apiKey: 'k',
      message: message,
      eventId: eventId ?? message,
      timestamp: DateTime(2030, 1, 1),
      extra: size > 0 ? {'blob': 'x' * size} : null,
    );

void main() {
  group('options', () {
    test('environment tem padrão e pode ser definido', () {
      expect(CrashLensOptions(apiKey: 'k').environment, 'development');
      expect(
          CrashLensOptions(apiKey: 'k', environment: 'staging').environment,
          'staging');
    });
  });

  group('payload', () {
    test('envia environment, eventId e omite fingerprint não definido', () {
      final e = CrashLensEvent(
          apiKey: 'k', message: 'm', eventId: 'id-1', environment: 'production');
      final json = e.toIngestJson();
      expect(json['environment'], 'production');
      expect(json['eventId'], 'id-1');
      expect(json.containsKey('fingerprint'), isFalse);
    });

    test('trunca message, stack, breadcrumbs, extra e tags', () {
      final e = CrashLensEvent(
        apiKey: 'k',
        message: 'm' * 20000,
        stackTrace: 's' * 200000,
        extra: {'big': 'x' * 100000},
        tags: {'t': 'y' * 100000},
        breadcrumbs: List.generate(
            80, (i) => Breadcrumb(message: 'b$i', data: {'blob': 'z' * 10000})),
      );
      final json = e.toIngestJson();
      expect((json['message'] as String).length, lessThanOrEqualTo(8 * 1024));
      expect(
          (json['stackTrace'] as String).length, lessThanOrEqualTo(64 * 1024));
      expect(jsonEncode(json['extra']).length, lessThan(32 * 1024 + 100));
      expect(jsonEncode(json['tags']).length, lessThan(32 * 1024 + 100));
      final crumbs = json['breadcrumbs'] as List;
      expect(crumbs.length, 50);
      expect((crumbs.last as Map)['message'], 'b79');
      expect(jsonEncode((crumbs.first as Map)['data']).length,
          lessThan(2 * 1024 + 100));
    });
  });

  group('EventQueue', () {
    late List<List<String>> batches;
    late List<String> singles;
    var now = DateTime(2030, 1, 1);

    EventQueue build(
      http.Response Function(http.Request req) handler, {
      void Function(List<CrashLensEvent>)? onDropped,
      VoidCallback? onQuota,
      void Function(List<CrashLensEvent>)? onSent,
      int maxBatchSize = 25,
      int maxBatchBytes = 512 * 1024,
    }) {
      batches = [];
      singles = [];
      now = DateTime(2030, 1, 1);
      final client = MockClient((req) async {
        final body = jsonDecode(req.body);
        if (body is List) {
          batches.add(body.map((e) => e['message'] as String).toList());
        } else {
          singles.add(body['message'] as String);
        }
        return handler(req);
      });
      return EventQueue(
        apiClient: EventApiClient(baseUrl: 'https://x/api', client: client),
        clock: () => now,
        onEventsDropped: onDropped,
        onQuotaExceeded: onQuota,
        onBatchSent: onSent,
        maxBatchSize: maxBatchSize,
        maxBatchBytes: maxBatchBytes,
      );
    }

    test('limita o lote por quantidade', () async {
      final q = build((_) => http.Response('', 201), maxBatchSize: 2);
      for (var i = 0; i < 5; i++) {
        q.enqueue(_event('e$i'));
      }
      await q.flush();
      expect(batches.map((b) => b.length), [2, 2, 1]);
      expect(q.pendingCount, 0);
    });

    test('limita o lote por bytes', () async {
      final q = build((_) => http.Response('', 201), maxBatchBytes: 3000);
      for (var i = 0; i < 4; i++) {
        q.enqueue(_event('e$i', size: 1500));
      }
      await q.flush();
      expect(batches.length, greaterThan(1));
      expect(batches.expand((b) => b).length, 4);
    });

    test('falha transitória mantém o evento com backoff (não descarta)',
        () async {
      final q = build((_) => http.Response('', 503));
      q.enqueue(_event('a'));
      for (var i = 0; i < 5; i++) {
        await q.flush();
        now = now.add(const Duration(minutes: 10));
      }
      expect(q.pendingCount, 1);
      expect(batches.length, 5);
    });

    test('413 descarta imediatamente e notifica', () async {
      final dropped = <String>[];
      final q = build((_) => http.Response('', 413),
          onDropped: (e) => dropped.addAll(e.map((x) => x.message)));
      q.enqueue(_event('big'));
      await q.flush();
      expect(q.pendingCount, 0);
      expect(dropped, ['big']);
    });

    test('falha do lote 400 isola o evento inválido', () async {
      final dropped = <String>[];
      final sent = <String>[];
      final q = build(
        (req) {
          final body = jsonDecode(req.body);
          if (body is List) return http.Response('', 400);
          return body['message'] == 'bad'
              ? http.Response('', 400)
              : http.Response('', 201);
        },
        onDropped: (e) => dropped.addAll(e.map((x) => x.message)),
        onSent: (e) => sent.addAll(e.map((x) => x.message)),
      );
      for (final m in ['a', 'bad', 'c']) {
        q.enqueue(_event(m));
      }
      await q.flush();
      expect(dropped, ['bad']);
      expect(sent, ['a', 'c']);
      expect(q.pendingCount, 0);
    });

    test('429 respeita Retry-After sem pausar', () async {
      var quota = false;
      var first = true;
      final q = build((_) {
        if (first) {
          first = false;
          return http.Response('', 429, headers: {'retry-after': '30'});
        }
        return http.Response('', 201);
      }, onQuota: () => quota = true);
      q.enqueue(_event('a'));
      await q.flush();
      expect(quota, isFalse);
      expect(q.pendingCount, 1);
      await q.flush(); // ainda em backoff
      expect(batches.length, 1);
      now = now.add(const Duration(seconds: 31));
      await q.flush();
      expect(batches.length, 2);
      expect(q.pendingCount, 0);
    });

    test('402 pausa e notifica', () async {
      var quota = false;
      final q = build((_) => http.Response('', 402), onQuota: () => quota = true);
      q.enqueue(_event('a'));
      await q.flush();
      expect(quota, isTrue);
      await q.flush();
      expect(batches.length, 1);
      expect(q.pendingCount, 1);
    });

    test('resultados por item: remove ok e descarta erros do cliente', () async {
      final sent = <String>[];
      final dropped = <String>[];
      final q = build(
        (_) => http.Response(
          jsonEncode({
            'results': [
              {'index': 0, 'ok': true},
              {'index': 1, 'ok': false, 'error': 'validation failed'},
              {
                'index': 2,
                'ok': false,
                'error': {'status': 503}
              },
            ]
          }),
          200,
        ),
        onSent: (e) => sent.addAll(e.map((x) => x.message)),
        onDropped: (e) => dropped.addAll(e.map((x) => x.message)),
      );
      for (final m in ['a', 'b', 'c']) {
        q.enqueue(_event(m));
      }
      await q.flush();
      expect(sent, ['a']);
      expect(dropped, ['b']);
      expect(q.pendingCount, 1);
    });
  });
}
