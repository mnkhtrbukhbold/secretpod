import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';
import 'package:secretpod_flutter/main.dart';
import 'package:secretpod_flutter/screens/workspace_screen.dart';

void main() {
  testWidgets('startup restores the account from an existing session token', (
    tester,
  ) async {
    final api = Client(
      'http://localhost:8080/',
      httpClientOverride: MockClient((request) async {
        if (request.headers['authorization'] != 'Bearer restored-session') {
          return http.Response('', 401);
        }
        if (request.url.path.endsWith('/profile')) {
          return http.Response(
            jsonEncode(
              AccountView(
                id: 'a',
                name: 'Alex',
                email: 'alex@example.com',
              ).toJson(),
            ),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );
    final controller = VaultController('http://localhost:8080/', api: api);
    // Page reload discards the account; startup must validate the session and
    // reload the profile before presenting the workspace.
    controller.auth.token = 'restored-session';
    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(controller.account?.email, 'alex@example.com');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  for (final status in [401, 503]) {
    test(
      'logout clears local credentials when the server returns $status',
      () async {
        final api = Client(
          'http://localhost:8080/',
          httpClientOverride: MockClient(
            (_) async => http.Response('', status),
          ),
        );
        final controller = VaultController('http://localhost:8080/', api: api)
          ..account = AccountView(
            id: 'a',
            name: 'Alex',
            email: 'alex@example.com',
          );
        controller.auth.token = 'expired-test-token';
        try {
          await controller.logout();
        } catch (_) {
          /* Network errors may still be reported. */
        }
        expect(controller.account, isNull);
        expect(controller.auth.token, isNull);
        expect(controller.secrets, isEmpty);
        controller.dispose();
      },
    );
  }
}
