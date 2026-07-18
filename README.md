# 🐛 CrashLens Flutter SDK

SDK Flutter para captura de erros e eventos do **CrashLens** — uma alternativa open-source ao Sentry.

## 📦 Instalação

```yaml
# pubspec.yaml
dependencies:
  crashlens_flutter:
    git: https://github.com/rafaelfernandesx/crashlens_package.git
```

## 🚀 Inicialização

```dart
import 'package:crashlens_flutter/crashlens_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CrashLens.init(
    options: CrashLensOptions(
      apiKey: 'chave_do_ambiente',
      baseUrl: 'https://apicrashlens.laziv.com/api',
      environment: 'production',
      enableFlutterErrorCapture: true,
      enablePlatformDispatcherCapture: true,
      enableZoneCapture: true,
      sendInDebug: true,  // enviar eventos em debug
    ),
  );

  runApp(MyApp());
}
```

---

## 📖 API Completa

### `CrashLens.init()`

```dart
await CrashLens.init(
  options: CrashLensOptions(
    // Obrigatório
    apiKey: '...',                      // Chave do ambiente (criado no painel)

    // Conexão
    baseUrl: 'https://apicrashlens.laziv.com/api', // URL do backend

    // Identificação
    environment: 'production',            // Nome do ambiente
    user: CrashLensUser(                  // Usuário atual
      id: 'user-123',
      name: 'João',
      email: 'joao@email.com',
    ),
    tags: {'app_version': '1.0.0'},       // Tags globais

    // Handlers automáticos
    enableFlutterErrorCapture: true,      // Capturar FlutterError
    enablePlatformDispatcherCapture: true, // Capturar exceções não tratadas
    enableZoneCapture: true,              // Capturar via runZonedGuarded
    enableAutoBreadcrumbs: true,          // Breadcrumbs automáticos

    // Comportamento
    sampleRate: 1.0,                      // 0.0 a 1.0 (% de eventos enviados)
    sendInDebug: false,                   // Enviar em modo debug
    flushIntervalSeconds: 5,              // Intervalo de envio
    maxBreadcrumbs: 100,                  // Máx. breadcrumbs armazenados
    httpTimeoutMs: 15000,                 // Timeout HTTP
    maxRetries: 3,                        // Tentativas de reenvio
    beforeSend: (event) {                 // Callback antes do envio
      return event;                       // retorne null para descartar
    },
  ),
);
```

---

### Captura de Erros

#### `captureException()` — Capturar exceção manualmente

```dart
try {
  await api.call();
} catch (e, s) {
  CrashLens.captureException(e, s,
    handled: true,
    context: 'HomeScreen.fetchData',
    tags: {'source': 'api'},
    extra: {'status_code': 500},
  );
}
```

#### `captureMessage()` — Enviar log/mensagem

```dart
CrashLens.captureMessage(
  'Usuário fez login',
  severity: EventSeverity.info,
  tags: {'action': 'login'},
);
```

#### `captureEvent()` — Evento personalizado

```dart
CrashLens.captureEvent(
  message: 'Pagamento processado',
  severity: EventSeverity.info,
  exceptionType: 'PaymentError',
  context: 'CheckoutScreen',
  tags: {'method': 'credit_card'},
  extra: {'amount': 150.00, 'installments': 3},
);
```

---

### Usuário (como SentryUser)

```dart
// Definir usuário (enviado com todos os eventos subsequentes)
CrashLens.setUser(CrashLensUser(
  id: 'user_456',
  name: 'João Silva',
  email: 'joao@email.com',
  username: 'joaosilva',
  ipAddress: '192.168.1.1',
  data: {'plano': 'premium'},
));
```

---

### Tags Globais (como Sentry.configureScope)

```dart
// Adicionar tag
CrashLens.setTag('shorebird_patch_number', '42');

// Remover tag
CrashLens.removeTag('shorebird_patch_number');
```

---

### Breadcrumbs

```dart
CrashLens.addBreadcrumb(Breadcrumb(
  message: 'Navegou para tela de checkout',
  type: BreadcrumbType.navigation,
  category: 'navigation',
  data: {'from': '/home', 'to': '/checkout'},
));
```

Tipos disponíveis: `navigation`, `http`, `user`, `ui`, `system`, `debug`, `error`

---

### `beforeSend` — Modificar ou descartar eventos

```dart
beforeSend: (event) {
  // Verificar pelo tipo do erro (runtime)
  if (event.error is DioException) {
    final dio = event.error as DioException;
    return event.copyWith(
      extra: {
        'status': dio.response?.statusCode,
        'method': dio.requestOptions.method,
      },
    );
  }

  // Descartar eventos específicos
  if (event.exceptionType == 'NotFoundError') {
    return null; // descarta
  }

  return event; // mantém como está
},
```

---

### Utilitários

```dart
// Forçar envio imediato
await CrashLens.flush();

// Verificar status
final ok = CrashLens.instance.isInitialized;
final pending = CrashLens.instance.pendingEvents;

// Encerrar SDK
await CrashLens.close();
```

---

## 📋 Opções Completas (`CrashLensOptions`)

| Parâmetro | Tipo | Padrão | Descrição |
|-----------|------|--------|-----------|
| `apiKey` | `String` | **obrigatório** | Chave do ambiente |
| `baseUrl` | `String` | `https://apicrashlens.laziv.com/api` | URL do backend |
| `environment` | `String` | `production` | Nome do ambiente |
| `release` | `String?` | `null` | Versão do app |
| `flushIntervalSeconds` | `int` | `5` | Intervalo de envio (s) |
| `maxBreadcrumbs` | `int` | `100` | Máx. breadcrumbs |
| `enableFlutterErrorCapture` | `bool` | `true` | Capturar FlutterError |
| `enablePlatformDispatcherCapture` | `bool` | `true` | Capturar exceções nativas |
| `enableZoneCapture` | `bool` | `true` | Capturar via Zones |
| `enableAutoBreadcrumbs` | `bool` | `true` | Breadcrumbs automáticos |
| `sampleRate` | `double` | `1.0` | Taxa de amostragem |
| `sendInDebug` | `bool` | `false` | Enviar em debug |
| `user` | `CrashLensUser?` | `null` | Usuário atual |
| `tags` | `Map<String, dynamic>?` | `null` | Tags globais |
| `httpTimeoutMs` | `int` | `15000` | Timeout HTTP |
| `maxRetries` | `int` | `3` | Tentativas de reenvio |
| `beforeSend` | `CrashLensEvent? Function(CrashLensEvent)?` | `null` | Callback de modificação |

---

## 🧪 Exemplo Completo

```dart
import 'package:crashlens_flutter/crashlens_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CrashLens.init(
    options: CrashLensOptions(
      apiKey: 'd2367497-59c2-43e6-805f-c48cb874b67a',
      baseUrl: 'https://apicrashlens.laziv.com/api',
      environment: 'development',
      user: CrashLensUser(id: 'user-123', email: 'test@test.com'),
      tags: {'app': 'CrashLens Demo'},
      enableFlutterErrorCapture: true,
      enablePlatformDispatcherCapture: true,
      enableZoneCapture: true,
      sendInDebug: true,
      beforeSend: (event) {
        if (event.error is DioException) {
          return event.copyWith(
            severity: EventSeverity.warning,
            extra: {'dio': true},
          );
        }
        return event;
      },
    ),
  );

  // Enviar mensagem
  CrashLens.captureMessage('App iniciado', severity: EventSeverity.info);

  runApp(MyApp());
}
```

---

## 🔄 Fluxo de Captura

```
Erro → SDK detecta (automático ou manual)
  → Cria CrashLensEvent com todos os dados
  → beforeSend (se configurado) — modifica ou descarta
  → Calcula fingerprint SHA-256 (excluindo timestamp)
  → Adiciona à fila de envio
  → Envia a cada 5s (ou no flush manual)
  → Backend recebe e agrupa por fingerprint
```

---

## 📄 Licença

MIT
