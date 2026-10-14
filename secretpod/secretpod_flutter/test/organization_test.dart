import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/main.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';

void main() {
  late VaultController controller;
  late OrganizationView org;
  late AccountView account;
  var fail = false;
  var renameCalls = 0;
  Completer<http.Response>? pendingRename;
  Completer<http.Response>? pendingOrganizations;

  setUp(() {
    fail = false;
    renameCalls = 0;
    pendingRename = null;
    pendingOrganizations = null;
    org = OrganizationView(
      id: 'org',
      name: 'Engineering',
      role: 'owner',
      createdAt: DateTime.utc(2026),
    );
    account = AccountView(
      id: 'owner',
      name: 'Alex',
      email: 'alex@example.test',
    );
    controller =
        VaultController(
            'http://localhost/',
            api: Client(
              'http://localhost/',
              httpClientOverride: MockClient((request) async {
                final method = request.url.path.split('/').last;
                final args = jsonDecode(request.body) as Map<String, dynamic>;
                Object? result;
                switch (method) {
                  case 'renameOrganization':
                    renameCalls++;
                    expect(args['organizationId'], 'org');
                    if (pendingRename != null) return pendingRename!.future;
                    if (fail) return http.Response('Unavailable', 503);
                    org = org.copyWith(name: (args['name'] as String).trim());
                    result = org.toJson();
                  case 'organizations':
                    if (pendingOrganizations != null) {
                      return pendingOrganizations!.future;
                    }
                    result = [org.toJson()];
                  case 'profile':
                    result = account.toJson();
                  case 'summary':
                    result = WorkspaceSummary(
                      secretCount: 0,
                      memberCount: 1,
                      activityCount: 0,
                      filteredSecretCount: 0,
                      projectCounts: {},
                    ).toJson();
                  case 'logout':
                    result = null;
                  default:
                    result = [];
                }
                return http.Response(
                  jsonEncode(result),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }),
            ),
          )
          ..account = account
          ..organization = org
          ..organizations = [org];
  });
  tearDown(() => controller.dispose());

  Future<void> openRename(WidgetTester tester) async {
    await tester.pumpWidget(MyApp(controller: controller));
    await tester.tap(find.byTooltip('Switch organization'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename organization'));
    await tester.pumpAndSettle();
  }

  testWidgets('owner can edit a prefilled name and see the saved name', (
    tester,
  ) async {
    await openRename(tester);
    final field = find.widgetWithText(TextFormField, 'Organization name');
    expect(tester.widget<TextFormField>(field).controller!.text, 'Engineering');
    await tester.enterText(field, '   ');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(renameCalls, 0);
    expect(find.text('This field is required.'), findsOneWidget);
    await tester.enterText(field, 'Platform');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(controller.organization!.name, 'Platform');
    expect(controller.organizations.single.name, 'Platform');
    expect(find.text('Platform'), findsOneWidget);
    expect(find.text('WORKSPACE  /  PLATFORM'), findsOneWidget);
    expect(find.text('Save changes'), findsNothing);
  });

  for (final role in ['reader', 'editor']) {
    testWidgets('$role has no rename action', (tester) async {
      controller.organization = org.copyWith(role: role);
      await tester.pumpWidget(MyApp(controller: controller));
      await tester.tap(find.byTooltip('Switch organization'));
      await tester.pumpAndSettle();
      expect(find.text('Rename organization'), findsNothing);
    });
  }

  testWidgets('failed rename keeps the original name and allows retry', (
    tester,
  ) async {
    fail = true;
    await openRename(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Organization name'),
      'Platform',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(controller.organization!.name, 'Engineering');
    expect(find.textContaining('Could not reach the vault'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(controller.organization!.name, 'Platform');
  });

  test('older organization refresh cannot undo a confirmed rename', () async {
    pendingOrganizations = Completer<http.Response>();
    final refresh = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    await controller.renameOrganization('org', 'Platform');
    pendingOrganizations!.complete(
      http.Response(
        jsonEncode([org.copyWith(name: 'Engineering').toJson()]),
        200,
      ),
    );
    await refresh;
    expect(controller.organization!.name, 'Platform');
    expect(controller.organizations.single.name, 'Platform');
    expect(controller.loading, isFalse);
    expect(controller.summary, isNotNull);
  });

  test(
    'delayed rename cannot select an old organization or restore logout',
    () async {
      pendingRename = Completer<http.Response>();
      final rename = controller.renameOrganization('org', 'Platform');
      await Future<void>.delayed(Duration.zero);
      controller.organization = org.copyWith(id: 'other', name: 'Other');
      pendingRename!.complete(
        http.Response(jsonEncode(org.copyWith(name: 'Platform').toJson()), 200),
      );
      await rename;
      expect(controller.organization!.name, 'Other');
      expect(controller.organizations.single.name, 'Platform');
      pendingRename = Completer<http.Response>();
      final afterLogout = controller.renameOrganization('org', 'After logout');
      await Future<void>.delayed(Duration.zero);
      await controller.logout();
      pendingRename!.complete(
        http.Response(
          jsonEncode(org.copyWith(name: 'After logout').toJson()),
          200,
        ),
      );
      await afterLogout;
      expect(controller.account, isNull);
      expect(controller.organization, isNull);
      expect(controller.organizations, isEmpty);
    },
  );

  test('queued renames preserve submission order', () async {
    pendingRename = Completer<http.Response>();
    final response = pendingRename!;
    final first = controller.renameOrganization('org', 'First');
    final second = controller.renameOrganization('org', 'Second');
    await Future<void>.delayed(Duration.zero);
    expect(renameCalls, 1);
    pendingRename = null;
    response.complete(
      http.Response(jsonEncode(org.copyWith(name: 'First').toJson()), 200),
    );
    await Future.wait([first, second]);
    expect(controller.organization!.name, 'Second');
    expect(controller.organizations.single.name, 'Second');
  });

  testWidgets('saving blocks duplicate submission and cancellation', (
    tester,
  ) async {
    pendingRename = Completer<http.Response>();
    await openRename(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Organization name'),
      'Platform',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Organization name'),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
          .onPressed,
      isNull,
    );
    pendingRename!.complete(
      http.Response(jsonEncode(org.copyWith(name: 'Platform').toJson()), 200),
    );
    org = org.copyWith(name: 'Platform');
    await tester.pumpAndSettle();
    expect(controller.organization!.name, 'Platform');
    expect(renameCalls, 1);
  });
}
