/// Severidade do evento capturado
enum EventSeverity {
  debug('debug'),
  info('info'),
  warning('warning'),
  error('error'),
  fatal('fatal');

  final String value;
  const EventSeverity(this.value);

  static EventSeverity fromString(String value) {
    return EventSeverity.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EventSeverity.info,
    );
  }
}
