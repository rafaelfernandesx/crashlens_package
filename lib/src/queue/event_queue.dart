import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/event.dart';
import '../http/event_api_client.dart';
import '../payload_limits.dart';

/// Fila de eventos com envio em lote, retry com backoff e armazenamento offline.
///
/// - Lotes limitados por quantidade ([maxBatchSize]) e por bytes ([maxBatchBytes]).
/// - Falhas transitórias (rede/5xx) são repetidas com backoff exponencial; o evento
///   só é abandonado após muitas tentativas ou muito tempo (continua persistido
///   pelo SDK e é reenviado na próxima execução).
/// - 400/413/422: evento descartado imediatamente (nunca será aceito).
/// - 429: backoff (respeita Retry-After), sem pausar o SDK.
/// - 402: pausa (limite do plano).
class EventQueue {
  final EventApiClient _apiClient;

  /// Número de tentativas "rápidas". O evento só é abandonado na memória após
  /// `max(maxRetries, 10)` tentativas ou [maxEventAge].
  final int maxRetries;
  final int maxBatchSize;
  final int maxBatchBytes;

  /// Máximo de eventos em memória; ao estourar, descarta os mais antigos
  /// (que continuam persistidos pelo SDK).
  final int maxQueueSize;
  final Duration maxEventAge;
  final List<_QueuedEvent> _queue = [];
  final DateTime Function() _clock;
  Timer? _flushTimer;
  bool _isFlushing = false;
  bool _paused = false;
  bool _requeued = false;
  DateTime? _backoffUntil;
  int _rateLimitLevel = 0;

  static const _minAttempts = 10;
  static const _baseBackoff = Duration(seconds: 5);
  static const _maxBackoff = Duration(minutes: 5);
  static const _maxRetryAfter = Duration(minutes: 5);
  static const _dropStatus = [400, 413, 422];

  /// Callback chamado após um lote ser enviado com sucesso.
  final void Function(List<CrashLensEvent> sentEvents)? onBatchSent;

  /// Callback chamado quando o limite do plano é excedido (402).
  final VoidCallback? onQuotaExceeded;

  /// Callback chamado com eventos descartados de vez pela fila (400/413/422 ou
  /// erro por item não repetível). Esses eventos não devem mais ser reenviados.
  final void Function(List<CrashLensEvent> droppedEvents)? onEventsDropped;

  EventQueue({
    required EventApiClient apiClient,
    this.maxRetries = 3,
    this.maxBatchSize = 25,
    this.maxBatchBytes = PayloadLimits.batchBytes,
    this.maxQueueSize = 100,
    this.maxEventAge = const Duration(hours: 24),
    this.onBatchSent,
    this.onQuotaExceeded,
    this.onEventsDropped,
    DateTime Function()? clock,
  })  : _apiClient = apiClient,
        _clock = clock ?? DateTime.now;

  /// Adiciona um evento à fila
  void enqueue(CrashLensEvent event) {
    var bytes = 0;
    try {
      bytes = utf8.encode(jsonEncode(event.toIngestJson())).length;
    } catch (_) {
      return; // não serializável
    }
    _queue.add(_QueuedEvent(event: event, bytes: bytes));
    if (_queue.length > maxQueueSize) {
      _queue.removeRange(0, _queue.length - maxQueueSize);
    }
    _startFlushTimer();
  }

  /// Inicia o timer de envio periódico
  void startAutoFlush({Duration interval = const Duration(seconds: 5)}) {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(interval, (_) => flush());
  }

  /// Para o timer de envio
  void stopAutoFlush() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  /// Envia os eventos pendentes (em lotes)
  Future<void> flush() async {
    if (_paused) return;
    if (_isFlushing || _queue.isEmpty) return;
    if (_inBackoff) return;
    _isFlushing = true;

    try {
      while (!_paused && !_inBackoff) {
        final batch = _takeBatch();
        if (batch.isEmpty) break;
        _requeued = false;
        await _processBatch(batch);
        if (_requeued) break; // tenta de novo só no próximo ciclo
      }
    } catch (e) {
      debugPrint('[CrashLens] Erro ao enviar eventos: $e');
    } finally {
      _isFlushing = false;
    }
  }

  bool get _inBackoff =>
      _backoffUntil != null && _clock().isBefore(_backoffUntil!);

  /// Retira da fila um lote elegível, limitado por quantidade e por bytes.
  List<_QueuedEvent> _takeBatch() {
    final now = _clock();
    final batch = <_QueuedEvent>[];
    var bytes = 0;
    for (final q in List<_QueuedEvent>.from(_queue)) {
      if (batch.length >= maxBatchSize) break;
      final next = q.nextAttemptAt;
      if (next != null && now.isBefore(next)) continue;
      if (batch.isNotEmpty && bytes + q.bytes > maxBatchBytes) break;
      bytes += q.bytes;
      batch.add(q);
      _queue.remove(q);
    }
    return batch;
  }

  Future<void> _processBatch(List<_QueuedEvent> batch) async {
    final res = await _apiClient.postBatch(batch.map((q) => q.event).toList());

    if (res.isSuccess) {
      _rateLimitLevel = 0;
      _handleBatchSuccess(batch, res);
      return;
    }

    if (_handleGlobalFailure(res)) {
      _requeue(batch);
      return;
    }

    if (_dropStatus.contains(res.statusCode)) {
      if (batch.length == 1) {
        _drop(batch);
      } else {
        // Algum item do lote é inválido: isola reenviando um a um.
        await _sendIndividually(batch);
      }
      return;
    }

    // Falha transitória (rede/5xx): backoff e nova tentativa depois.
    _retryLater(batch);
  }

  void _handleBatchSuccess(List<_QueuedEvent> batch, SendResult res) {
    final results = res.itemResults;
    if (results == null) {
      onBatchSent?.call(batch.map((q) => q.event).toList());
      return;
    }
    final delivered = <CrashLensEvent>[];
    final retry = <_QueuedEvent>[];
    final dropped = <_QueuedEvent>[];
    for (var i = 0; i < batch.length; i++) {
      final r = results[i];
      if (r == null || r.ok) {
        delivered.add(batch[i].event);
      } else if (_isRetryableItemError(r.error)) {
        retry.add(batch[i]);
      } else {
        dropped.add(batch[i]);
      }
    }
    if (delivered.isNotEmpty) onBatchSent?.call(delivered);
    _drop(dropped);
    _retryLater(retry);
  }

  Future<void> _sendIndividually(List<_QueuedEvent> batch) async {
    final delivered = <CrashLensEvent>[];
    final retry = <_QueuedEvent>[];
    final dropped = <_QueuedEvent>[];
    for (var i = 0; i < batch.length; i++) {
      final item = batch[i];
      final res = await _apiClient.postEvent(item.event);
      if (res.isSuccess) {
        delivered.add(item.event);
      } else if (_handleGlobalFailure(res)) {
        // 402/429: este e os restantes voltam sem consumir tentativa
        _requeue(batch.sublist(i));
        break;
      } else if (_dropStatus.contains(res.statusCode)) {
        dropped.add(item);
      } else {
        retry.add(item);
      }
    }
    if (delivered.isNotEmpty) onBatchSent?.call(delivered);
    _drop(dropped);
    _retryLater(retry);
  }

  /// 402 → pausa; 429 → backoff (Retry-After ou exponencial). true se tratado.
  bool _handleGlobalFailure(SendResult res) {
    if (res.statusCode == 402) {
      _paused = true;
      stopAutoFlush();
      onQuotaExceeded?.call();
      return true;
    }
    if (res.statusCode == 429) {
      final retryAfter = res.retryAfter;
      final delay = retryAfter != null
          ? (retryAfter > _maxRetryAfter ? _maxRetryAfter : retryAfter)
          : _exponential(_rateLimitLevel);
      _rateLimitLevel++;
      _backoffUntil = _clock().add(delay);
      return true;
    }
    return false;
  }

  Duration _exponential(int attempt) {
    final ms = _baseBackoff.inMilliseconds * pow(2, min(attempt, 10)).toInt();
    return Duration(milliseconds: min(ms, _maxBackoff.inMilliseconds));
  }

  /// Marca falha transitória: incrementa tentativas, agenda o próximo envio com
  /// backoff e devolve à fila (ou abandona após muitas tentativas / muito tempo).
  void _retryLater(List<_QueuedEvent> items) {
    final keep = <_QueuedEvent>[];
    final now = _clock();
    for (final q in items) {
      q.attempts++;
      final tooOld = now.difference(q.event.timestamp) > maxEventAge;
      if (q.attempts >= max(maxRetries, _minAttempts) || tooOld) {
        // Abandona na memória; continua persistido e é reenviado na próxima execução.
        continue;
      }
      q.nextAttemptAt = now.add(_exponential(q.attempts - 1));
      keep.add(q);
    }
    _requeue(keep);
  }

  void _requeue(List<_QueuedEvent> items) {
    if (items.isEmpty) return;
    _requeued = true;
    _queue.insertAll(0, items);
    if (_queue.length > maxQueueSize) {
      _queue.removeRange(0, _queue.length - maxQueueSize);
    }
  }

  void _drop(List<_QueuedEvent> items) {
    if (items.isEmpty) return;
    onEventsDropped?.call(items.map((q) => q.event).toList());
  }

  /// Erros por item só são repetidos se parecerem transitórios.
  bool _isRetryableItemError(dynamic error) {
    int? status;
    if (error is int) {
      status = error;
    } else if (error is Map) {
      final s = error['status'] ?? error['statusCode'];
      if (s is int) status = s;
    }
    if (status != null) return status >= 500 || status == 429 || status == 408;
    if (error is String) {
      return RegExp(r'internal|server|timeout|unavailable|temporar|rate',
              caseSensitive: false)
          .hasMatch(error);
    }
    return false;
  }

  void _startFlushTimer() {
    _flushTimer ??= Timer(const Duration(seconds: 2), () => flush());
  }

  int get pendingCount => _queue.length;

  /// Pausa o envio de eventos (limite de plano excedido, etc.)
  void pause() {
    _paused = true;
    stopAutoFlush();
  }

  /// Resume o envio de eventos
  void resume() {
    _paused = false;
    if (_flushTimer == null && _queue.isNotEmpty) {
      _startFlushTimer();
    }
  }

  void dispose() {
    stopAutoFlush();
    _apiClient.dispose();
  }
}

class _QueuedEvent {
  final CrashLensEvent event;
  final int bytes;
  int attempts;
  DateTime? nextAttemptAt;

  _QueuedEvent({
    required this.event,
    this.bytes = 0,
  }) : attempts = 0;
}
