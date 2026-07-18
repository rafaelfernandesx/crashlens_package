/// Tipo de breadcrumb
enum BreadcrumbType {
  navigation('navigation'),
  http('http'),
  gesture('gesture'),
  lifecycle('lifecycle'),
  error('error'),
  debug('debug'),
  custom('custom');

  final String value;
  const BreadcrumbType(this.value);

  static BreadcrumbType fromString(String value) {
    return BreadcrumbType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BreadcrumbType.custom,
    );
  }
}
