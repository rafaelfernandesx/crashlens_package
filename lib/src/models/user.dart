/// Descreve o usuário atual associado ao aplicativo.
///
/// Similar ao [SentryUser](https://develop.sentry.dev/sdk/event-payloads/user/).
/// Use ao menos [id] para o CrashLens conseguir agrupar usuários afetados.
///
/// Uso:
/// ```dart
/// CrashLens.setUser(CrashLensUser(id: '123', email: 'user@email.com'));
/// ```
class CrashLensUser {
  /// Identificador único do usuário
  final String? id;

  /// Nome de usuário
  final String? username;

  /// Email do usuário
  final String? email;

  /// Endereço IP do usuário
  final String? ipAddress;

  /// Nome legível do usuário
  final String? name;

  /// Dados extras do usuário
  final Map<String, dynamic>? data;

  CrashLensUser({
    this.id,
    this.username,
    this.email,
    this.ipAddress,
    this.name,
    this.data,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (username != null) 'username': username,
        if (email != null) 'email': email,
        if (ipAddress != null) 'ip_address': ipAddress,
        if (name != null) 'name': name,
        if (data != null && data!.isNotEmpty) 'data': data,
      };

  factory CrashLensUser.fromJson(Map<String, dynamic> json) => CrashLensUser(
        id: json['id'] as String?,
        username: json['username'] as String?,
        email: json['email'] as String?,
        ipAddress: json['ip_address'] as String?,
        name: json['name'] as String?,
        data: json['data'] as Map<String, dynamic>?,
      );
}
