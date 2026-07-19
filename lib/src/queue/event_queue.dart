import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/event.dart';
import '../http/event_api_client.dart';

/// Fila de eventos com suporte a retry e armazenamento offline
class EventQueue {
  final EventApiClient _apiClient;
  final int maxRetries;
  final List<_QueuedEvent> _queue = [];
  Timer? _flushTimer;
  bool _isFlushing = false;
  bool _paused = false;

  /// Callback chamado após um lote ser enviado com sucesso.
  final void Function(List<CrashLensEvent> sentEvents)? onBatchSent;

  /// Callback chamado quando o limite do plano é excedido (402/429).
  final VoidCallback? onQuotaExceeded;

  EventQueue({
    required EventApiClient apiClient,
    this.maxRetries = 3,
    this.onBatchSent,
    this.onQuotaExceeded,
  }) : _apiClient = apiClient;

  /// Adiciona um evento à fila
  void enqueue(CrashLensEvent event) {
    _queue.add(_QueuedEvent(event: event));
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

  /// Envia todos os eventos pendentes
  Future<void> flush() async {
    if (_paused) return;
    if (_isFlushing || _queue.isEmpty) return;
    _isFlushing = true;

    final batch = List<_QueuedEvent>.from(_queue);
    _queue.clear();

    try {
      final events = batch.map((e) => e.event).toList();
      final success = await _apiClient.sendBatch(events);

      // Se a API sinalizou limite excedido, pausa e notifica
      if (_apiClient.quotaExceeded) {
        _paused = true;
        stopAutoFlush();
        onQuotaExceeded?.call();
        return;
      }

      if (!success) {
        // Re-adiciona eventos que falharam com retry
        for (final queued in batch) {
          queued.retryCount++;
          if (queued.retryCount < maxRetries) {
            _queue.add(queued);
          }
        }
      } else {
        // Notifica que o lote foi enviado com sucesso
        onBatchSent?.call(events);
      }
    } catch (e) {
      // Em caso de erro, re-adiciona tudo
      for (final queued in batch) {
        queued.retryCount++;
        if (queued.retryCount < maxRetries) {
          _queue.add(queued);
        }
      }
    } finally {
      _isFlushing = false;
    }
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
  int retryCount;

  _QueuedEvent({
    required this.event,
  }) : retryCount = 0;
}
