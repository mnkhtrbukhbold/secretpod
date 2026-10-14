import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/screens/invitation_dialogs.dart';
import 'package:secretpod_flutter/screens/workspace_screen.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';
import 'package:secretpod_flutter/widgets/member_access_fields.dart';

void main() {
  testWidgets('selected projects grant only checked reads and writes', (
    tester,
  ) async {
    MemberAccess? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MemberAccessFields(
              initialValue: const MemberAccess(
                role: 'editor',
                readProjects: [],
                writeProjects: [],
                canCreateProjects: false,
              ),
              projects: const ['Alpha', 'Beta', 'Gamma'],
              onChanged: (value) => result = value,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('access-read-Alpha')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('access-write-Alpha')),
    );
    await tester.tap(find.byKey(const ValueKey('access-write-Alpha')));
    expect(result!.readProjects, ['Alpha']);
    expect(result!.writeProjects, ['Alpha']);
    expect(result!.canCreateProjects, isFalse);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('access-write-Beta')),
          )
          .onChanged,
      isNull,
    );
  });

  testWidgets(
    'project choices stay visible and creator conversion preserves restrictions',
    (tester) async {
      MemberAccess? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MemberAccessFields(
                initialValue: const MemberAccess(
                  role: 'editor',
                  readProjects: ['Alpha'],
                  writeProjects: ['Alpha'],
                ),
                projects: const ['Alpha', 'Beta', 'Gamma'],
                onChanged: (value) => result = value,
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('access-read-Alpha')), findsOneWidget);
      expect(find.byKey(const ValueKey('access-write-Beta')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('access-create-projects')));
      await tester.pumpAndSettle();
      final dynamic changed = result;
      expect(changed.canCreateProjects, isTrue);
      expect(changed.readProjects, isNull);
      expect(changed.writeProjects, isNull);
      expect(changed.deniedReadProjects, ['Beta', 'Gamma']);
      expect(changed.deniedWriteProjects, ['Beta', 'Gamma']);
      expect(find.byKey(const ValueKey('access-read-Alpha')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('access-read-Beta')),
      );
      await tester.tap(find.byKey(const ValueKey('access-read-Beta')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('access-write-Beta')),
      );
      await tester.tap(find.byKey(const ValueKey('access-write-Beta')));
      final dynamic updated = result;
      expect(updated.deniedReadProjects, ['Gamma']);
      expect(updated.deniedWriteProjects, ['Gamma']);
    },
  );

  late VaultController controller;
  Map<String, dynamic>? submitted;
  Completer<void>? gate;
  bool fail = false;
  final owner = AccountView(
    id: 'owner',
    name: 'Owner',
    email: 'owner@example.test',
  );
  final member = MemberView(
    account: AccountView(
      id: 'member',
      name: 'Alex',
      email: 'alex@example.test',
    ),
    role: 'reader',
  );
  setUp(() {
    submitted = null;
    gate = null;
    fail = false;
    controller =
        VaultController(
            'http://localhost/',
            api: Client(
              'http://localhost/',
              httpClientOverride: MockClient((request) async {
                if (request.url.path.endsWith('/updateMemberAccess')) {
                  submitted = jsonDecode(request.body) as Map<String, dynamic>;
                  await gate?.future;
                  if (fail) return http.Response('Unavailable', 503);
                  return http.Response(
                    jsonEncode({
                      ...member.toJson(),
                      'role': submitted!['role'],
                      'readProjects': submitted!['readProjects'],
                      'writeProjects': submitted!['writeProjects'],
                      'deniedReadProjects': submitted!['deniedReadProjects'],
                      'deniedWriteProjects': submitted!['deniedWriteProjects'],
                      'canCreateProjects': submitted!['canCreateProjects'],
                    }),
                    200,
                  );
                }
                return http.Response('[]', 200);
              }),
            ),
          )
          ..account = owner
          ..organization = OrganizationView(
            id: 'org',
            name: 'Team',
            role: 'owner',
            createdAt: DateTime.utc(2026),
          )
          ..members = [MemberView(account: owner, role: 'owner'), member]
          ..summary = WorkspaceSummary(
            secretCount: 0,
            filteredSecretCount: 0,
            memberCount: 2,
            activityCount: 0,
            projectCounts: {'Default': 0, 'Alpha': 0, 'Beta': 0},
          );
    controller.organizations = [controller.organization!];
  });
  tearDown(() => controller.dispose());
  test(
    'creator exclusions restrict controls while allowing future projects',
    () {
      controller.organization = controller.organization!.copyWith(
        role: 'editor',
        canCreateProjects: true,
        deniedReadProjects: ['Alpha'],
        deniedWriteProjects: ['Alpha', 'Beta'],
      );
      expect(controller.projects, ['Default', 'Beta']);
      expect(controller.canReadProject('ALPHA'), isFalse);
      expect(controller.canWriteProject('beta'), isFalse);
      expect(controller.canCreateProject, isTrue);
      expect(controller.canReadProject('Future'), isTrue);
      expect(controller.canWriteProject('Future'), isTrue);
      controller.organization = controller.organization!.copyWith(
        canCreateProjects: false,
      );
      expect(controller.canCreateProject, isFalse);
    },
  );
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(
          controller: controller,
          page: 2,
          lastWorkspacePage: 2,
          onNavigate: (_) {},
        ),
      ),
    );
    await tester.ensureVisible(find.byTooltip('Edit access for Alex'));
    await tester.tap(find.byTooltip('Edit access for Alex'));
    await tester.pumpAndSettle();
  }

  testWidgets('invitation exposes read all and project-scoped grants', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InviteMemberDialog(
            controller: controller,
            organizationId: 'org',
          ),
        ),
      ),
    );
    expect(find.text('All projects, with exclusions'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('owner changes role and keeps read all with selected writes', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Reader · view and copy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editor · manage secrets').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('access-write-mode-true')),
    );
    await tester.tap(find.byKey(const ValueKey('access-write-mode-true')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selected projects only').last);
    await tester.pumpAndSettle();
    for (final project in ['Beta', 'Default']) {
      await tester.ensureVisible(find.byKey(ValueKey('access-write-$project')));
      await tester.tap(find.byKey(ValueKey('access-write-$project')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Save access'));
    await tester.pumpAndSettle();
    expect(submitted!['role'], 'editor');
    expect(submitted!['readProjects'], isNull);
    expect(submitted!['writeProjects'], ['Alpha']);
    expect(submitted!['canCreateProjects'], isFalse);
  });

  testWidgets('failure keeps edit dialog and selections for retry', (
    tester,
  ) async {
    await open(tester);
    fail = true;
    await tester.tap(find.text('Save access'));
    await tester.pumpAndSettle();
    expect(find.text('Save access'), findsOneWidget);
    expect(
      find.text(
        'Could not reach the vault. Check the server connection and try again.',
      ),
      findsOneWidget,
    );
    fail = false;
    await tester.tap(find.text('Save access'));
    await tester.pumpAndSettle();
    expect(find.text('Save access'), findsNothing);
  });

  test('delayed member update cannot overwrite another session', () async {
    gate = Completer<void>();
    final dynamic c = controller;
    final operation = c.updateMemberAccess(
      'org',
      'member',
      'editor',
      readProjects: null,
      writeProjects: <String>['Alpha'],
    );
    while (submitted == null) {
      await Future<void>.delayed(Duration.zero);
    }
    controller.account = member.account;
    controller.auth.token = 'other-session';
    gate!.complete();
    await operation;
    expect(controller.members.last.role, 'reader');
  });

  testWidgets('non-owner has no edit access actions', (tester) async {
    controller.organization = controller.organization!.copyWith(role: 'editor');
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(
          controller: controller,
          page: 2,
          lastWorkspacePage: 2,
          onNavigate: (_) {},
        ),
      ),
    );
    expect(find.byTooltip('Edit access for Alex'), findsNothing);
  });

  testWidgets(
    'compact enlarged-text editor keeps actions reachable and blocks duplicate saves',
    (tester) async {
      tester.view.physicalSize = const Size(320, 680);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('access-read-Alpha')),
      );
      await tester.tap(find.byKey(const ValueKey('access-read-Alpha')));
      expect(tester.getRect(find.text('Save access')).bottom, lessThan(680));
      gate = Completer<void>();
      await tester.tap(find.text('Save access'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      gate!.complete();
      await tester.pumpAndSettle();
      expect(submitted!['readProjects'], isNull);
      expect(submitted!['deniedReadProjects'], ['Alpha']);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'project-specific controls restrict writes without reducing read-all visibility',
    () {
      controller.organization = controller.organization!.copyWith(
        role: 'editor',
        writeProjects: ['Alpha'],
      );
      expect(controller.projects, ['Default', 'Alpha', 'Beta']);
      expect(controller.writableProjects, ['Alpha']);
      expect(controller.canWriteProject('alpha'), isTrue);
      expect(controller.canWriteProject('Beta'), isFalse);
      expect(controller.canCreateProject, isFalse);
      controller.organization = controller.organization!.copyWith(
        writeProjects: [],
      );
      expect(controller.canEdit, isFalse);
      controller.organization = controller.organization!.copyWith(
        role: 'reader',
        readProjects: ['Beta'],
      );
      expect(controller.projects, ['Beta']);
    },
  );
}
