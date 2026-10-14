import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/main.dart';
import 'package:secretpod_flutter/screens/auth_screen.dart';
import 'package:secretpod_flutter/screens/secret_dialogs.dart';
import 'package:secretpod_flutter/screens/workspace_screen.dart';
import 'package:secretpod_flutter/state/session_store.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';

// Separate tab views share durable storage; events reach only other tabs,
// matching the browser storage-event boundary.
class SharedBrowser {
  String? token;
  final tabs = <BrowserTabStore>[];
  BrowserTabStore openTab() {
    final tab = BrowserTabStore(this);
    tabs.add(tab);
    return tab;
  }

  void update(BrowserTabStore source, String? value) {
    if (token == value) return;
    token = value;
    for (final tab in tabs.where((tab) => tab != source)) {
      tab.events.add(null);
    }
  }
}

class BrowserTabStore implements SessionStore {
  BrowserTabStore(this.browser);
  final SharedBrowser browser;
  final events = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => events.stream;
  @override
  String? read() => browser.token;
  @override
  void write(String? token) => browser.update(this, token);
}

void main() {
  final browser = SharedBrowser();
  final controllers = <VaultController>[];
  final account = AccountView(
    id: 'alex',
    name: 'Alex',
    email: 'alex@example.com',
  );
  Completer<void>? oldProfileGate, createOrganizationGate;
  var rejectOldProfile = false;
  VaultController tab({BrowserTabStore? storage}) {
    final api = Client(
      'http://localhost:8080/',
      httpClientOverride: MockClient((request) async {
        final token = request.headers['authorization'];
        final method = request.url.path.split('/').last;
        if (method == 'createOrganization') {
          await createOrganizationGate?.future;
          return http.Response(
            jsonEncode(
              OrganizationView(
                id: 'old-org',
                name: 'Old organization',
                role: 'owner',
                createdAt: DateTime.utc(2026),
              ).toJson(),
            ),
            200,
          );
        }
        if (method == 'profile' && token == 'Bearer old-token') {
          await oldProfileGate?.future;
          if (rejectOldProfile) return http.Response('', 401);
        }
        if (method == 'profile') {
          return http.Response(jsonEncode(account.toJson()), 200);
        }
        return http.Response(method == 'logout' ? 'null' : '[]', 200);
      }),
    );
    final controller = VaultController(
      'http://localhost:8080/',
      api: api,
      sessionStore: storage ?? browser.openTab(),
    );
    controllers.add(controller);
    return controller;
  }

  Future<void> settleEvents() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() {
    browser.token = null;
    oldProfileGate = null;
    createOrganizationGate = null;
    rejectOldProfile = false;
  });
  tearDown(() async {
    for (final controller in controllers) {
      controller.dispose();
    }
    controllers.clear();
    for (final storage in browser.tabs) {
      await storage.events.close();
    }
    browser.tabs.clear();
  });

  test(
    'sign-in and logout synchronize with another already-open tab',
    () async {
      final first = tab(), second = tab();
      await first.useAuthentication(
        AuthResult(token: 'old-token', account: account),
      );
      await settleEvents();
      expect(second.account?.id, 'alex');
      expect(second.auth.token, 'old-token');
      await first.logout();
      await settleEvents();
      expect(second.account, isNull);
      expect(second.auth.token, isNull);
      expect(browser.token, isNull);
    },
  );

  test(
    'a new browser session restores the durable token after all old tabs close',
    () async {
      final first = tab();
      await first.useAuthentication(
        AuthResult(token: 'old-token', account: account),
      );
      first.dispose();
      controllers.remove(first);
      final reopened = tab();
      await reopened.restoreSession();
      expect(reopened.account?.id, 'alex');
      expect(reopened.auth.token, 'old-token');
    },
  );

  test('logout in another tab cancels pending restoration', () async {
    final first = tab();
    await first.useAuthentication(
      AuthResult(token: 'old-token', account: account),
    );
    oldProfileGate = Completer<void>();
    final second = tab();
    final restore = second.restoreSession();
    await first.logout();
    await settleEvents();
    oldProfileGate!.complete();
    await restore;
    expect(second.account, isNull);
    expect(second.auth.token, isNull);
  });

  test('a delayed refresh cannot interrupt session restoration', () async {
    browser.token = 'old-token';
    oldProfileGate = Completer<void>();
    final controller = tab();
    final restore = controller.restoreSession();
    final refresh = controller.refresh();
    oldProfileGate!.complete();
    await Future.wait([restore, refresh]);
    expect(controller.restoringSession, isFalse);
    expect(controller.account?.id, 'alex');
  });

  test(
    'a late organization creation response cannot restore logged-out state',
    () async {
      final first = tab(), second = tab();
      await first.useAuthentication(
        AuthResult(token: 'old-token', account: account),
      );
      await settleEvents();
      createOrganizationGate = Completer<void>();
      final creation = second.createOrganization('Old organization');
      await first.logout();
      await settleEvents();
      createOrganizationGate!.complete();
      await creation;
      expect(second.account, isNull);
      expect(second.organization, isNull);
    },
  );

  test('server expiry detected in one tab signs the other tab out', () async {
    final first = tab(), second = tab();
    await first.useAuthentication(
      AuthResult(token: 'old-token', account: account),
    );
    await settleEvents();
    rejectOldProfile = true;
    await first.refresh();
    await settleEvents();
    expect(browser.token, isNull);
    expect(first.account, isNull);
    expect(second.account, isNull);
    expect(second.auth.token, isNull);
  });

  test(
    'a stale unauthorized response cannot erase a newer shared token',
    () async {
      browser.token = 'old-token';
      final second = tab();
      oldProfileGate = Completer<void>();
      rejectOldProfile = true;
      final restore = second.restoreSession();
      // A concurrent tab has committed its new token; its storage event can lag.
      browser.token = 'new-token';
      oldProfileGate!.complete();
      await restore;
      await settleEvents();
      expect(browser.token, 'new-token');
      expect(second.auth.token, 'new-token');
      expect(second.account?.id, 'alex');
    },
  );

  testWidgets('remote logout closes open dialogs before showing sign in', (
    tester,
  ) async {
    final first = tab(), second = tab();
    await first.useAuthentication(
      AuthResult(token: 'old-token', account: account),
    );
    await second.restoreSession();
    await tester.pumpWidget(MyApp(controller: second));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(WorkspaceScreen));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) =>
            const AlertDialog(content: Text('Revealed secret fixture')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Revealed secret fixture'), findsOneWidget);
    await first.logout();
    await tester.pumpAndSettle();
    expect(find.text('Revealed secret fixture'), findsNothing);
    expect(find.byType(AuthScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'remote logout disposes an unsaved secret and its discard confirmation',
    (tester) async {
      final first = tab(), second = tab();
      await first.useAuthentication(
        AuthResult(token: 'old-token', account: account),
      );
      await second.restoreSession();
      await tester.pumpWidget(MyApp(controller: second));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(WorkspaceScreen));
      unawaited(
        showDialog<bool>(
          context: context,
          builder: (_) => SecretEditor(controller: second),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Secret name'),
        'Unsaved fixture',
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await first.logout();
      await tester.pumpAndSettle();
      expect(find.byType(SecretEditor), findsNothing);
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Unsaved fixture'), findsNothing);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
