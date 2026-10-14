import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/main.dart';
import 'package:secretpod_flutter/screens/auth_screen.dart';
import 'package:secretpod_flutter/screens/workspace_screen.dart';
import 'package:secretpod_flutter/state/session_store.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';

class TestSessionStore implements SessionStore {
  String? token;
  bool unavailable = false;
  bool writeUnavailable = false;
  @override
  Stream<void> get changes => const Stream<void>.empty();
  @override
  String? read() {
    if (unavailable) throw StateError('Storage unavailable');
    return token;
  }

  @override
  void write(String? value) {
    if (unavailable || writeUnavailable) {
      throw StateError('Storage unavailable');
    }
    token = value;
  }
}

void main() {
  const sessionToken = 'test-session-token';
  final account = AccountView(
    id: 'account',
    name: 'Alex',
    email: 'alex@example.com',
  );
  late TestSessionStore store;
  int status = 200;
  String? logoutHeader;
  Completer<void>? profileGate, logoutGate;
  final controllers = <VaultController>[];

  VaultController createController() {
    final api = Client(
      'http://localhost:8080/',
      httpClientOverride: MockClient((request) async {
        final method = request.url.path.split('/').last;
        if (method == 'logout') logoutHeader = request.headers['authorization'];
        if (method == 'login') {
          return http.Response(
            jsonEncode(
              AuthResult(token: sessionToken, account: account).toJson(),
            ),
            200,
          );
        }
        if (method == 'profile') await profileGate?.future;
        if (method == 'logout') await logoutGate?.future;
        if (status != 200) return http.Response('', status);
        if (![
          'Bearer $sessionToken',
          'Bearer new-session',
        ].contains(request.headers['authorization'])) {
          return http.Response('', 401);
        }
        return http.Response(
          method == 'profile'
              ? jsonEncode(account.toJson())
              : method == 'logout'
              ? 'null'
              : '[]',
          200,
        );
      }),
    );
    final controller = VaultController(
      'http://localhost:8080/',
      api: api,
      sessionStore: store,
    );
    controllers.add(controller);
    return controller;
  }

  setUp(() {
    store = TestSessionStore();
    status = 200;
    logoutHeader = null;
    profileGate = logoutGate = null;
  });
  tearDown(() {
    for (final controller in controllers) {
      controller.dispose();
    }
    controllers.clear();
  });

  testWidgets(
    'login survives recreating the app and controller with tab storage',
    (tester) async {
      final original = createController();
      await original.authenticate(
        email: account.email,
        password: 'test-password',
      );
      expect(store.token, sessionToken);
      final reloaded = createController();
      await tester.pumpWidget(MyApp(controller: reloaded));
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceScreen), findsOneWidget);
      expect(reloaded.account?.id, 'account');
      expect(find.byType(AuthScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'startup waits for server validation before showing account screens',
    (tester) async {
      store.token = sessionToken;
      profileGate = Completer<void>();
      final controller = createController();
      await tester.pumpWidget(MyApp(controller: controller));
      expect(find.byType(AuthScreen), findsNothing);
      expect(find.byType(WorkspaceScreen), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      profileGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('expired or revoked session is removed and returns to sign in', (
    tester,
  ) async {
    store.token = sessionToken;
    status = 401;
    final controller = createController();
    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(store.token, isNull);
    expect(controller.auth.token, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offline restoration retains the session and can retry', (
    tester,
  ) async {
    store.token = sessionToken;
    status = 503;
    final controller = createController();
    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();
    expect(store.token, sessionToken);
    expect(find.byType(AuthScreen), findsNothing);
    expect(find.byType(WorkspaceScreen), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    status = 200;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('logout clears stored session before the server response', () async {
    final controller = createController();
    await controller.authenticate(
      email: account.email,
      password: 'test-password',
    );
    logoutGate = Completer<void>();
    final logout = controller.logout();
    await Future<void>.delayed(Duration.zero);
    expect(store.token, isNull);
    expect(controller.account, isNull);
    expect(controller.auth.token, isNull);
    status = 503;
    logoutGate!.complete();
    await expectLater(logout, throwsA(isA<ServerpodClientException>()));
    expect(controller.account, isNull);
    expect(controller.auth.token, isNull);
  });

  test('logout prevents an in-flight restore from signing back in', () async {
    store.token = sessionToken;
    profileGate = Completer<void>();
    final controller = createController();
    final restoring = controller.restoreSession();
    await controller.logout();
    expect(logoutHeader, 'Bearer test-session-token');
    profileGate!.complete();
    await restoring;
    expect(controller.account, isNull);
    expect(controller.auth.token, isNull);
    expect(store.token, isNull);
  });

  test('completing an old logout does not clear a newer login', () async {
    final controller = createController();
    await controller.authenticate(
      email: account.email,
      password: 'test-password',
    );
    logoutGate = Completer<void>();
    final logout = controller.logout();
    await Future<void>.delayed(Duration.zero);
    expect(logoutHeader, 'Bearer test-session-token');
    await controller.useAuthentication(
      AuthResult(token: 'new-session', account: account),
    );
    logoutGate!.complete();
    await logout;
    expect(store.token, 'new-session');
    expect(controller.auth.token, 'new-session');
  });

  test(
    'a rejected refresh clears persisted authentication and account data',
    () async {
      final controller = createController();
      await controller.authenticate(
        email: account.email,
        password: 'test-password',
      );
      status = 401;
      await controller.refresh();
      expect(store.token, isNull);
      expect(controller.account, isNull);
      expect(controller.auth.token, isNull);
      expect(controller.organizations, isEmpty);
    },
  );

  test(
    'unavailable browser storage permits login with an explicit notice',
    () async {
      store.unavailable = true;
      final controller = createController();
      await controller.authenticate(
        email: account.email,
        password: 'test-password',
      );
      expect(controller.account?.id, 'account');
      expect(controller.sessionStorageWarning, isNotNull);
    },
  );

  test(
    'a failed storage write does not sign out the in-memory session on resume',
    () async {
      store.writeUnavailable = true;
      final controller = createController();
      await controller.authenticate(
        email: account.email,
        password: 'test-password',
      );
      await controller.synchronizeSession();
      expect(controller.account?.id, 'account');
      expect(controller.auth.token, sessionToken);
      expect(controller.sessionStorageWarning, isNotNull);
    },
  );
}
