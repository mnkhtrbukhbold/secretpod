import 'dart:io';
import 'src/crypto/crypto_service.dart';
import 'src/deployment/runtime_config.dart';
import 'src/deployment/runtime_routes.dart';
import 'src/generated/serverpod.dart';
import 'src/services.dart';

Future<void> run(List<String> args) async {
  final pod = await createServer(args);
  try {
    await pod.start();
  } catch (_) {
    await VaultServices.instance.close();
    rethrow;
  }
}

/// Constructs the server; listeners are opened only by [Serverpod.start].
Future<Serverpod> createServer(
  List<String> args, {
  Map<String, String>? environment,
}) async {
  final env = environment ?? Platform.environment;
  final key = await loadMasterKey(env);
  var runtime = RuntimeConfig.fromEnvironment(env);
  final pod = Serverpod(
    args,
    configOverride: (config) {
      final api = config.apiServer;
      runtime = RuntimeConfig.fromEnvironment(
        env,
        developmentApiUrl: Uri(
          scheme: api.publicScheme,
          host: api.publicHost,
          port: api.publicPort,
          path: '/',
        ).toString(),
      );
      if (config.runMode == 'production') runtime.validateProduction();
      final origin = runtime.publicOrigin;
      if (origin == null) return config;
      final public = Uri.parse(origin);
      return config.copyWith(
        allowedOrigins: [origin],
        apiServer: ServerConfig(
          port: api.port,
          publicHost: public.host,
          publicPort: public.port,
          publicScheme: public.scheme,
        ),
        webServer: config.webServer == null
            ? null
            : ServerConfig(
                port: config.webServer!.port,
                publicHost: public.host,
                publicPort: public.port,
                publicScheme: public.scheme,
              ),
      );
    },
    httpResponseHeaders: Headers.build((headers) {
      headers.accessControlAllowOrigin = runtime.publicOrigin == null
          ? const AccessControlAllowOriginHeader.wildcard()
          : AccessControlAllowOriginHeader.origin(
              origin: Origin.parse(runtime.publicOrigin!),
            );
      headers.accessControlAllowMethods =
          AccessControlAllowMethodsHeader.methods([Method.post]);
      headers['Cache-Control'] = ['no-store'];
      headers['X-Content-Type-Options'] = ['nosniff'];
    }),
    authenticationHandler: (session, token) async {
      final user = await VaultServices.instance.accounts.authenticate(token);
      return user == null
          ? null
          : AuthenticationInfo(
              user,
              {},
              authId: CryptoService.tokenDigest(token),
            );
    },
  );
  if (runtime.publicOrigin != null) {
    pod.server.addMiddleware(
      (next) => (request) {
        final origins = request.headers['origin'];
        if (origins != null &&
            (origins.length != 1 || origins.single != runtime.publicOrigin)) {
          return Response.forbidden(
            body: Body.fromString('Request origin not allowed.'),
          );
        }
        return next(request);
      },
    );
  }
  VaultServices.instance = await VaultServices.open(
    Directory(env['SECRETPOD_DATA_DIR'] ?? env['PODVAULT_DATA_DIR'] ?? 'data'),
    key,
  );
  pod.webServer.addRoute(RuntimeConfigRoute(runtime), '/app-config.json');
  pod.webServer.addRoute(HealthRoute(VaultServices.instance), '/healthz');
  final app = Directory('web/app');
  if (app.existsSync()) pod.webServer.addRoute(FlutterRoute(app), '/');
  return pod;
}
