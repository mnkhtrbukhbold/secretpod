import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/main.dart';
import 'package:secretpod_flutter/screens/secret_dialogs.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';

void main() {
  late VaultController controller;
  late OrganizationView org;
  late AccountView account;
  var fail = false;
  var createCalls = 0;
  Completer<http.Response>? pendingCreate;
  Completer<http.Response>? pendingSummary;
  late Map<String, int> counts;

  http.Response response(Object? value) => http.Response(
    jsonEncode(value),
    200,
    headers: {'content-type': 'application/json'},
  );
  WorkspaceSummary summary() => WorkspaceSummary(
    secretCount: 2,
    filteredSecretCount: 0,
    memberCount: 1,
    activityCount: 0,
    projectCounts: Map.of(counts),
  );

  setUp(() async {
    fail = false;
    createCalls = 0;
    pendingCreate = null;
    pendingSummary = null;
    counts = {'Default': 0, 'Payments': 2};
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
                switch (method) {
                  case 'createProject':
                    createCalls++;
                    expect(args['organizationId'], 'org');
                    if (pendingCreate != null) return pendingCreate!.future;
                    if (fail) return http.Response('Unavailable', 503);
                    final name = (args['name'] as String).trim();
                    counts[name] = 0;
                    return response(name);
                  case 'summary':
                    if (pendingSummary != null) return pendingSummary!.future;
                    return response(summary().toJson());
                  case 'organizations':
                    return response([org.toJson()]);
                  case 'profile':
                    return response(account.toJson());
                  case 'logout':
                    return response(null);
                  default:
                    return response([]);
                }
              }),
            ),
          )
          ..account = account
          ..organization = org
          ..organizations = [org]
          ..summary = summary();
    controller.auth.token = 'project-test-session';
    await controller.refresh();
  });
  tearDown(() => controller.dispose());

  Future<void> openPicker(WidgetTester tester) async {
    await tester.pumpWidget(MyApp(controller: controller));
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
  }

  Future<void> openCreate(WidgetTester tester) async {
    await openPicker(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Create project'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'selection adds a project filter and clear preserves other filters',
    (tester) async {
      controller.secretQuery = 'api';
      controller.secretEnvironment = 'Production';
      await openPicker(tester);
      await tester.tap(find.widgetWithText(ListTile, 'Payments'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(controller.secretProject, 'Payments');
      expect(controller.secretQuery, 'api');
      expect(controller.secretEnvironment, 'Production');
      expect(find.text('Project: Payments'), findsOneWidget);
      await tester.ensureVisible(find.text('Project: Payments'));
      await tester.tap(find.text('Project: Payments'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Payments'))
            .selected,
        isTrue,
      );
      await tester.tap(find.widgetWithText(ListTile, 'All projects'));
      await tester.pumpAndSettle();
      expect(controller.secretProject, isNull);
      expect(controller.secretQuery, 'api');
      expect(controller.secretEnvironment, 'Production');
      await tester.ensureVisible(find.text('All projects'));
      await tester.tap(find.text('All projects'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Payments'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Clear project filter'));
      await tester.tap(find.byTooltip('Clear project filter'));
      await tester.pumpAndSettle();
      expect(controller.secretProject, isNull);
      expect(controller.secretQuery, 'api');
      expect(controller.secretEnvironment, 'Production');
    },
  );

  testWidgets('create validates names and applies the persisted project', (
    tester,
  ) async {
    await openCreate(tester);
    final field = find.widgetWithText(TextFormField, 'Project name');
    await tester.enterText(field, '  ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('This field is required.'), findsOneWidget);
    await tester.enterText(field, ' pAyMeNtS ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(
      find.text('A project with this name already exists.'),
      findsOneWidget,
    );
    expect(createCalls, 0);
    await tester.enterText(field, ' Platform ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(createCalls, 1);
    expect(controller.secretProject, 'Platform');
    expect(controller.projects, contains('Platform'));
    expect(find.byType(Dialog), findsNothing);
    await controller.refresh();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Project: Platform'));
    await tester.tap(find.text('Project: Platform'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Platform'), findsOneWidget);
    expect(controller.projectCount('Platform'), 0);
  });

  testWidgets('failed creation allows retry without publishing a project', (
    tester,
  ) async {
    fail = true;
    await openCreate(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Project name'),
      'Platform',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not reach the vault'), findsOneWidget);
    expect(controller.projects, isNot(contains('Platform')));
    fail = false;
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(controller.secretProject, 'Platform');
  });

  for (final role in ['reader', 'editor']) {
    testWidgets('$role project creation visibility matches role', (
      tester,
    ) async {
      controller.organization = org.copyWith(role: role);
      await openPicker(tester);
      expect(
        find.widgetWithText(FilledButton, 'Create project'),
        role == 'reader' ? findsNothing : findsOneWidget,
      );
    });
  }

  test('an old refresh cannot erase a confirmed empty project', () async {
    pendingSummary = Completer<http.Response>();
    final old = summary();
    final refresh = controller.refresh();
    while (!controller.loading) {
      await Future<void>.delayed(Duration.zero);
    }
    await controller.createProject('org', 'Platform');
    pendingSummary!.complete(response(old.toJson()));
    await refresh;
    expect(controller.projects, contains('Platform'));
    expect(controller.projectCount('Platform'), 0);
  });

  testWidgets('scoped editor can select projects but cannot create them', (
    tester,
  ) async {
    controller.organization = org.copyWith(
      role: 'editor',
      readProjects: ['Payments'],
      writeProjects: ['Payments'],
    );
    await openPicker(tester);
    expect(find.widgetWithText(FilledButton, 'Create project'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Payments'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Default'), findsNothing);
  });

  test('cached creations respect later changes to read permissions', () async {
    await controller.createProject('org', 'Platform');
    controller.organization = org.copyWith(
      role: 'editor',
      readProjects: ['Payments'],
      writeProjects: ['Payments'],
    );
    expect(controller.projects, ['Payments']);
    controller.organization = org.copyWith(
      role: 'editor',
      writeProjects: ['Payments'],
    );
    expect(controller.canCreateProject, isFalse);
    expect(controller.projects, contains('Platform'));
    controller.organization = org.copyWith(role: 'reader', readProjects: []);
    expect(controller.projects, isEmpty);
  });

  test(
    'late project responses stay scoped to organization and session',
    () async {
      pendingCreate = Completer<http.Response>();
      final create = controller.createProject('org', 'Platform');
      await Future<void>.delayed(Duration.zero);
      controller.organization = org.copyWith(id: 'other');
      controller.summary = null;
      pendingCreate!.complete(response('Platform'));
      await create;
      expect(controller.projects, isNot(contains('Platform')));
      controller.organization = org;
      expect(controller.projects, contains('Platform'));
      pendingCreate = Completer<http.Response>();
      final afterLogout = controller.createProject('org', 'Late');
      await Future<void>.delayed(Duration.zero);
      await controller.logout();
      pendingCreate!.complete(response('Late'));
      await afterLogout;
      controller.organization = org;
      expect(controller.projects, isNot(contains('Late')));
      expect(controller.projects, isNot(contains('Platform')));
    },
  );

  testWidgets(
    'new secret inherits project without marking untouched form dirty',
    (tester) async {
      controller.secretProject = 'payments';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => SecretEditor(controller: controller),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Payments'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    },
  );
}
