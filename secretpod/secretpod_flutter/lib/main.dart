import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'config/runtime_bootstrap.dart';
import 'config/runtime_config.dart';
import 'config/runtime_fetch.dart';
import 'screens/invitation_landing.dart';
import 'state/app_router.dart';
import 'state/app_history.dart';
import 'screens/auth_screen.dart';
import 'screens/workspace_screen.dart';
import 'state/vault_controller.dart';
import 'widgets/common.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    RuntimeBootstrap(
      load: () => resolveApiUrl(
        baseUri: Uri.base,
        isWeb: kIsWeb,
        isDebug: kDebugMode,
        configuredUrl: const String.fromEnvironment('SERVER_URL'),
        fetch: fetchRuntimeConfig,
      ),
      appBuilder: (apiUrl) => MyApp(serverUrl: apiUrl),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.controller, this.serverUrl});
  final VaultController? controller;
  final String? serverUrl;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final controller =
      widget.controller ?? VaultController(widget.serverUrl ?? _serverUrl());
  late final _router = AppRouter(homeBuilder: _home);
  late final _history = AppHistory(
    overlayDepth: () => _router.overlayDepth,
    popOverlay: _router.popRoute,
  );
  String? _displayedSession;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _displayedSession = controller.auth.token;
    controller.addListener(_sessionChanged);
    controller.restoreSession();
  }

  void _sessionChanged() {
    if (_displayedSession == controller.auth.token) return;
    final hadSession = _displayedSession != null;
    _displayedSession = controller.auth.token;
    // Dispose dialogs and their revealed values when a different tab signs out
    // or switches accounts. Do not use a token as a widget/debug key.
    if (hadSession) {
      _router.resetSession(signedOut: controller.auth.token == null);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) controller.synchronizeSession();
  }

  String _serverUrl() {
    const configured = String.fromEnvironment('SERVER_URL');
    if (configured.isNotEmpty) {
      return configured.endsWith('/') ? configured : '$configured/';
    }
    final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
    return '${Uri(scheme: Uri.base.scheme == 'https' ? 'https' : 'http', host: host, port: 8080)}/';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_sessionChanged);
    _router.dispose();
    _history.dispose();
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (_, _) => MaterialApp.router(
      title: 'SecretPod · Team secrets',
      routerDelegate: _router,
      routeInformationParser: const AppRouteParser(),
      routeInformationProvider: _history,
      debugShowCheckedModeBanner: false,
      themeMode: switch (controller.account?.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      theme: secretPodTheme(Brightness.light),
      darkTheme: secretPodTheme(Brightness.dark),
    ),
  );

  Widget _home(BuildContext context) =>
      controller.restoringSession || controller.sessionRestoreError != null
      ? _sessionRestoration()
      : _router.invitationToken != null
      ? InvitationLanding(
          key: ValueKey(_router.invitationToken),
          controller: controller,
          token: _router.invitationToken!,
          initialSignIn: _router.invitationPreferSignIn,
          onClose: _router.closeInvitation,
        )
      : controller.account == null
      ? AuthScreen(controller: controller)
      : WorkspaceScreen(
          controller: controller,
          page: _router.page,
          lastWorkspacePage: _router.workspacePage,
          onNavigate: _router.navigate,
        );

  Widget _sessionRestoration() => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Brand(large: true),
              const SizedBox(height: 28),
              if (controller.restoringSession) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Restoring your session…'),
              ] else ...[
                ErrorNotice(
                  controller.sessionRestoreError!,
                  onRetry: controller.restoreSession,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    try {
                      await controller.logout();
                    } catch (_) {
                      // Local sign-out is completed even if revocation is offline.
                    }
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
