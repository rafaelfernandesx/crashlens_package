import '../enums/breadcrumb_type.dart';

/// Breadcrumb — evento de rastreamento que leva a um erro
class Breadcrumb {
  final String message;
  final BreadcrumbType type;
  final String? category;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  Breadcrumb({
    required this.message,
    this.type = BreadcrumbType.custom,
    this.category,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'message': message,
        'type': type.value,
        'category': category,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Breadcrumb.fromJson(Map<String, dynamic> json) => Breadcrumb(
        message: json['message'] as String,
        type: BreadcrumbType.fromString(json['type'] as String? ?? 'custom'),
        category: json['category'] as String?,
        data: json['data'] as Map<String, dynamic>?,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : null,
      );
}
