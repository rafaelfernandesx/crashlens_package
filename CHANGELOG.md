## 0.4.2

- Feito downgrade de algumas dependencias

## 0.4.1

- Adicionado suporte a `CrashLensHttpClient` para o pacote `http`
- Adicionado callback `onBatchSent` e `onQuotaExceeded` na `EventQueue`
- Melhorias no gerenciamento de sessão com `endSession()`, `sessionId` e `markSessionCrashed()`
- Adicionado `CrashLens.flush()` para envio forçado de eventos
- Adicionado suporte a erros locais com `captureLocally`, `localErrors`, `deleteLocalError()`, `clearLocalErrors()`
- Adicionado `CrashLens.setUser()`, `setTag()` e `removeTag()`
- Adicionado `beforeSend` callback para modificar/descartar eventos
- Sistema de fingerprint SHA-256 para agrupamento inteligente de eventos
- Pausa automática do SDK quando o plano atinge o limite (HTTP 402/429)
- Sanitização de headers e body nos interceptors Dio e http
- Extensão `withCrashLens` para `http.Client`

## 0.4.0

- Suporte completo a sessões com rastreamento de crash-free rate
- Interceptor Dio (`CrashLensDioInterceptor`) com sanitização de dados sensíveis
- `CrashLensNavigatorObserver` para captura automática de navegação
- Coleta de informações do dispositivo (Android, iOS, Windows, macOS, Linux)
- Fila de eventos com retry e persistência offline via SharedPreferences
- Validação de API Key na inicialização
- Suporte a tags globais e informações do usuário

## 0.3.0

- Captura automática de FlutterError via `FlutterError.onError`
- Captura de exceções não tratadas via `PlatformDispatcher.onError`
- Captura de erros de zona via `runZonedGuarded`
- Métodos `captureException()`, `captureMessage()` e `captureEvent()`
- Sistema de breadcrumbs com tipos: navigation, http, gesture, lifecycle, error, debug, custom
- Envio em lote com intervalo configurável

## 0.2.0

- Primeira versão funcional do SDK
- Inicialização via `CrashLens.init()` com `CrashLensOptions`
- Envio de eventos para a API CrashLens
- Coleta básica de informações do dispositivo

## 0.1.0

- Versão inicial
