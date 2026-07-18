import 'dart:async';
import '../models/event.dart';
import '../http/event_api_client.dart';

/// Fila de eventos com suporte a retry e armazenamento offline
class EventQueue {
  final EventApiClient _apiClient;
  final int maxRetries;
  final List<_QueuedEvent> _queue = [];
  Timer? _flushTimer;
  bool _isFlushing = false;

  EventQueue({
    required EventApiClient apiClient,
    this.maxRetries = 3,
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
    if (_isFlushing || _queue.isEmpty) return;
    _isFlushing = true;

    final batch = List<_QueuedEvent>.from(_queue);
    _queue.clear();

    try {
      final events = batch.map((e) => e.event).toList();
      final success = await _apiClient.sendBatch(events);

      if (!success) {
        // Re-adiciona eventos que falharam com retry
        for (final queued in batch) {
          queued.retryCount++;
          if (queued.retryCount < maxRetries) {
            _queue.add(queued);
          }
        }
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
