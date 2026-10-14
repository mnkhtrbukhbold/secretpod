import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/screens/workspace_screen.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';
import 'package:secretpod_flutter/main.dart';
import 'package:secretpod_flutter/screens/secret_dialogs.dart';

void main() {
  late VaultController controller;
  late List<SecretView> exposed;
  Map<String, dynamic>? submitted;
  Map<String, dynamic>? accessSubmitted;
  bool failPreview = false;
  bool denyAfterOverview = false;
  Completer<void>? removalGate;
  final owner = MemberView(
    account: AccountView(
      id: 'owner',
      name: 'Owner',
      email: 'owner@example.com',
    ),
    role: 'owner',
  );
  final member = MemberView(
    account: AccountView(id: 'member', name: 'Alex', email: 'alex@example.com'),
    role: 'editor',
  );
  SecretView secret(String id, String kind) => SecretView(
    id: id,
    organizationId: 'org',
    name: 'Secret $id',
    project: 'Payments',
    environment: 'Production',
    kind: kind,
    description: '',
    version: 1,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  setUp(() {
    submitted = null;
    accessSubmitted = null;
    failPreview = false;
    denyAfterOverview = false;
    removalGate = null;
    exposed = [secret('one', 'API key'), secret('two', 'Password')];
    controller =
        VaultController(
            'http://localhost/',
            api: Client(
              'http://localhost/',
              httpClientOverride: MockClient((request) async {
                final method = request.url.path.split('/').last;
                final args = jsonDecode(request.body) as Map<String, dynamic>;
                switch (method) {
                  case 'organizations':
                    return http.Response(
                      jsonEncode(
                        accessSubmitted == null && !denyAfterOverview
                            ? []
                            : controller.organizations
                                  .map((o) => o.toJson())
                                  .toList(),
                      ),
                      200,
                    );
                  case 'members':
                    return http.Response(
                      jsonEncode(
                        controller.members.map((m) => m.toJson()).toList(),
                      ),
                      200,
                    );
                  case 'summary':
                    if (denyAfterOverview) {
                      return http.Response(
                        Protocol().encodeWithType(
                          VaultException(
                            message: 'Organization access denied.',
                          ),
                        ),
                        500,
                      );
                    }
                    return http.Response(
                      jsonEncode(
                        WorkspaceSummary(
                          secretCount: 0,
                          filteredSecretCount: 0,
                          memberCount: 2,
                          activityCount: 0,
                          projectCounts: {},
                        ).toJson(),
                      ),
                      200,
                    );
                  case 'profile':
                    return http.Response(
                      jsonEncode(controller.account!.toJson()),
                      200,
                    );
                  case 'setMemberEnabled':
                    accessSubmitted = args;
                    await removalGate?.future;
                    return http.Response(
                      jsonEncode(
                        member.toJson()
                          ..['accessDisabled'] = !(args['enabled'] as bool),
                      ),
                      200,
                    );
                  case 'memberRemovalSecrets':
                    if (failPreview) return http.Response('Unavailable', 503);
                    final offset = args['offset'] as int? ?? 0;
                    final limit = args['limit'] as int? ?? 25;
                    return http.Response(
                      jsonEncode(
                        exposed
                            .skip(offset)
                            .take(limit)
                            .map((s) => s.toJson())
                            .toList(),
                      ),
                      200,
                    );
                  case 'removeMember':
                    submitted = args;
                    await removalGate?.future;
                    return http.Response('null', 200);
                  default:
                    return http.Response('[]', 200);
                }
              }),
            ),
          )
          ..account = owner.account
          ..organization = OrganizationView(
            id: 'org',
            name: 'Team',
            role: 'owner',
            createdAt: DateTime.utc(2026),
          )
          ..members = [owner, member];
    controller.organizations = [controller.organization!];
  });
  tearDown(() => controller.dispose());

  testWidgets(
    'owner can disable after secret review without removing membership',
    (tester) async {
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
      await tester.ensureVisible(find.byTooltip('Disable access for Alex'));
      await tester.tap(find.byTooltip('Disable access for Alex'));
      await tester.pumpAndSettle();
      expect(find.text('Disable access?'), findsOneWidget);
      expect(find.text('Secret one'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('rotate-two')));
      await tester.tap(find.byKey(const ValueKey('rotate-two')));
      await tester.tap(find.widgetWithText(FilledButton, 'Disable access'));
      await tester.pumpAndSettle();
      expect(accessSubmitted!['enabled'], false);
      expect(accessSubmitted!['rotateSecretIds'], ['one']);
      expect(submitted, isNull);
      expect(
        controller.members
            .firstWhere((m) => m.account.id == 'member')
            .toJson()['accessDisabled'],
        true,
      );
      expect(controller.members, hasLength(2));
    },
  );

  testWidgets(
    'disabled member stays visible and owner can reenable preserved access',
    (tester) async {
      controller.members = [
        owner,
        MemberView.fromJson(member.toJson()..['accessDisabled'] = true),
      ];
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
      expect(find.text('Access disabled'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Enable access for Alex'));
      await tester.tap(find.byTooltip('Enable access for Alex'));
      await tester.pumpAndSettle();
      expect(find.text('Enable access?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Enable access'));
      await tester.pumpAndSettle();
      expect(accessSubmitted!['enabled'], true);
      expect(accessSubmitted!['rotateSecretIds'], isEmpty);
      expect(
        controller.members
            .firstWhere((m) => m.account.id == 'member')
            .toJson()['accessDisabled'],
        false,
      );
    },
  );

  testWidgets(
    'losing organization access closes open secret details on refresh',
    (tester) async {
      controller.account = member.account;
      controller.organization = controller.organization!.copyWith(
        role: 'reader',
      );
      controller.organizations = [controller.organization!];
      controller.secrets = exposed;
      await tester.pumpWidget(MyApp(controller: controller));
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(WorkspaceScreen)),
          builder: (_) =>
              SecretDetails(controller: controller, secret: exposed.first),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SecretDetails), findsOneWidget);
      await controller.refresh();
      await tester.pumpAndSettle();
      expect(controller.organization, isNull);
      expect(controller.secrets, isEmpty);
      expect(find.byType(SecretDetails), findsNothing);
      expect(find.text('Team'), findsNothing);
    },
  );

  test(
    'delayed disable never updates a different account or organization',
    () async {
      removalGate = Completer<void>();
      final operation = controller.setMemberEnabled(
        'org',
        'member',
        false,
        ['one'],
        ['one'],
      );
      while (accessSubmitted == null) {
        await Future<void>.delayed(Duration.zero);
      }
      controller.account = member.account;
      controller.auth.token = 'new-session';
      controller.members = [member];
      controller.secrets = exposed;
      removalGate!.complete();
      await operation;
      expect(controller.members.single.accessDisabled, isFalse);
      expect(controller.secrets.any((s) => s.needsRotation), isFalse);
    },
  );

  testWidgets(
    'access denied after overview clears cached organization and open secrets',
    (tester) async {
      denyAfterOverview = true;
      controller.account = member.account;
      controller.organization = controller.organization!.copyWith(
        role: 'reader',
      );
      controller.organizations = [controller.organization!];
      controller.secrets = exposed;
      await tester.pumpWidget(MyApp(controller: controller));
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(WorkspaceScreen)),
          builder: (_) =>
              SecretDetails(controller: controller, secret: exposed.first),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SecretDetails), findsOneWidget);
      await controller.refresh();
      await tester.pumpAndSettle();
      expect(controller.organization, isNull);
      expect(controller.organizations, isEmpty);
      expect(controller.error, 'Organization access denied.');
      expect(controller.secrets, isEmpty);
      expect(controller.members, isEmpty);
      expect(find.byType(SecretDetails), findsNothing);
      expect(find.text('Team'), findsNothing);
    },
  );

  test(
    'delayed removal does not decrement an already refreshed member count',
    () async {
      controller.summary = WorkspaceSummary(
        secretCount: 0,
        filteredSecretCount: 0,
        memberCount: 2,
        activityCount: 0,
        projectCounts: {},
      );
      removalGate = Completer<void>();
      final operation = controller.removeMember('org', 'member', [], []);
      while (submitted == null) {
        await Future<void>.delayed(Duration.zero);
      }
      // An authoritative refresh completed after removal committed on the server,
      // before the removal HTTP response arrived.
      controller.members = [owner];
      controller.summary = controller.summary!.copyWith(memberCount: 1);
      removalGate!.complete();
      await operation;
      expect(controller.memberCount, 1);
      expect(controller.members.map((m) => m.account.id), ['owner']);
    },
  );

  test(
    'delayed removal never updates a different account or organization',
    () async {
      removalGate = Completer<void>();
      final operation = controller.removeMember('org', 'member', [], []);
      while (submitted == null) {
        await Future<void>.delayed(Duration.zero);
      }
      controller.account = member.account;
      controller.auth.token = 'new-session';
      controller.members = [member];
      removalGate!.complete();
      await operation;
      expect(controller.members.map((m) => m.account.id), ['member']);
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
    await tester.ensureVisible(find.byTooltip('Remove Alex'));
    await tester.ensureVisible(find.byTooltip('Remove Alex'));
    await tester.tap(find.byTooltip('Remove Alex'));
    await tester.pumpAndSettle();
  }

  testWidgets('owner reviews kinds and chooses which secrets to mark', (
    tester,
  ) async {
    await open(tester);
    expect(find.byTooltip('Remove Owner'), findsNothing);
    expect(find.text('Secret one'), findsOneWidget);
    expect(find.text('Secret two'), findsOneWidget);
    expect(find.textContaining('API key'), findsWidgets);
    expect(find.textContaining('Password'), findsWidgets);
    await tester.ensureVisible(find.byKey(const ValueKey('rotate-two')));
    await tester.tap(find.byKey(const ValueKey('rotate-two')));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove member'));
    await tester.pumpAndSettle();
    expect(submitted!['accountId'], 'member');
    expect(submitted!['reviewedSecretIds'], unorderedEquals(['one', 'two']));
    expect(submitted!['rotateSecretIds'], ['one']);
    expect(find.text('Remove member?'), findsNothing);
  });

  testWidgets('failed preview disables removal and permits retry', (
    tester,
  ) async {
    failPreview = true;
    await open(tester);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Remove member'),
          )
          .onPressed,
      isNull,
    );
    expect(submitted, isNull);
    failPreview = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Secret one'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Remove member'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('empty exposure and cancel are usable without marking', (
    tester,
  ) async {
    exposed = [];
    await open(tester);
    expect(
      find.text(
        'No unexpired secrets found in this member’s recorded activity.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(submitted, isNull);
  });

  testWidgets('busy removal cannot be dismissed or submitted twice', (
    tester,
  ) async {
    removalGate = Completer<void>();
    await open(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove member'));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Removing…'))
          .onPressed,
      isNull,
    );
    removalGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Remove member?'), findsNothing);
  });

  testWidgets(
    'long review is complete and scrolls with fixed actions on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      exposed = List.generate(
        101,
        (i) => secret('$i', 'Username and password'),
      );
      await open(tester);
      final action = find.widgetWithText(FilledButton, 'Remove member');
      final before = tester.getTopLeft(action);
      await tester.drag(
        find.byKey(const ValueKey('dialog-body-scroll')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(action), before);
      expect(tester.takeException(), isNull);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(submitted!['reviewedSecretIds'], hasLength(101));
      expect(submitted!['rotateSecretIds'], hasLength(101));
    },
  );

  testWidgets('editors cannot see member removal controls', (tester) async {
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
    expect(find.byTooltip('Remove Alex'), findsNothing);
    expect(find.byTooltip('Disable access for Alex'), findsNothing);
    expect(find.byTooltip('Enable access for Alex'), findsNothing);
  });
}
