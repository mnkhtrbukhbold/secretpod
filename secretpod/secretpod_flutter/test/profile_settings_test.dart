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
  late Map<String, dynamic> profile;
  final calls = <String, Map<String, dynamic>>{};
  var fail = false;
  var failureStatus = 503;
  Completer<http.Response>? themeResponse;
  Completer<void>? themeStarted;
  Completer<http.Response>? profileResponse;
  Completer<void>? profileStarted;
  final workspaceResponses = <String, Object>{};
  setUp(() {
    calls.clear();
    workspaceResponses.clear();
    fail = false;
    failureStatus = 503;
    themeResponse = null;
    themeStarted = null;
    profileResponse = null;
    profileStarted = null;
    profile = AccountView(
      id: 'a',
      name: 'Alex',
      email: 'alex@example.com',
      invitationPolicy: 'all',
    ).toJson();
    controller = VaultController(
      'http://localhost/',
      api: Client(
        'http://localhost/',
        httpClientOverride: MockClient((request) async {
          final method = request.url.path.split('/').last;
          final args = jsonDecode(request.body) as Map<String, dynamic>;
          calls[method] = args;
          if (method == 'updateTheme' && themeResponse != null) {
            themeStarted?.complete();
            return themeResponse!.future;
          }
          if (method == 'profile' && profileResponse != null) {
            profileStarted?.complete();
            return profileResponse!.future;
          }
          if (fail) return http.Response('', failureStatus);
          if (method == 'summary') {
            return http.Response(
              jsonEncode(
                WorkspaceSummary(
                  secretCount:
                      (workspaceResponses['listSecrets'] as List?)?.length ?? 0,
                  filteredSecretCount:
                      (workspaceResponses['listSecrets'] as List?)?.length ?? 0,
                  memberCount:
                      (workspaceResponses['members'] as List?)?.length ?? 0,
                  activityCount:
                      (workspaceResponses['activity'] as List?)?.length ?? 0,
                  projectCounts: {'Default': 0},
                ).toJson(),
              ),
              200,
            );
          }
          if (workspaceResponses.containsKey(method)) {
            return http.Response(jsonEncode(workspaceResponses[method]), 200);
          }
          switch (method) {
            case 'updateTheme':
              profile['themeMode'] = args['themeMode'];
            case 'updateName':
              profile['name'] = args['name'];
            case 'updateEmail':
              profile['email'] = args['email'];
            case 'updatePolicy':
              profile['invitationPolicy'] = args['policy'];
            case 'changePassword':
            case 'logout':
              return http.Response('null', 200);
            case 'profile':
              break;
            default:
              return http.Response('[]', 200);
          }
          return http.Response(jsonEncode(profile), 200);
        }),
      ),
    )..account = AccountView.fromJson(profile);
    controller.auth.token = 'fixture-session';
  });
  tearDown(() => controller.dispose());

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, {double width = 1200}) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MyApp(controller: controller));
    await tap(tester, find.byTooltip('Account'));
    await tap(tester, find.text('Profile settings'));
  }

  testWidgets(
    'profile settings works without an organization and saves theme override',
    (tester) async {
      final platform = tester.binding.platformDispatcher;
      platform.platformBrightnessTestValue = Brightness.light;
      addTearDown(platform.clearPlatformBrightnessTestValue);
      await open(tester, width: 390);
      expect(find.text('Profile settings'), findsOneWidget);
      expect(find.text('alex@example.com'), findsOneWidget);
      expect(find.text('Who can invite you?'), findsOneWidget);
      await tap(tester, find.text('System').first);
      await tap(tester, find.widgetWithText(MenuItemButton, 'Dark'));
      expect(calls['updateTheme'], {'themeMode': 'dark'});
      expect(
        Theme.of(tester.element(find.text('Profile settings'))).brightness,
        Brightness.dark,
      );
      await tap(tester, find.text('Dark').first);
      await tap(tester, find.widgetWithText(MenuItemButton, 'System'));
      expect(
        Theme.of(tester.element(find.text('Profile settings'))).brightness,
        Brightness.light,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('display name and email actions send validated profile changes', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      'Alex Updated',
    );
    await tap(tester, find.text('Save profile'));
    expect(calls['updateName'], {'name': 'Alex Updated'});
    expect(controller.account!.name, 'Alex Updated');
    await tap(tester, find.text('Change email'));
    await tap(tester, find.text('Save email'));
    expect(calls.containsKey('updateEmail'), isFalse);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New email address'),
      'updated@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      'current-password',
    );
    await tap(tester, find.text('Save email'));
    expect(calls['updateEmail'], {
      'currentPassword': 'current-password',
      'email': 'updated@example.com',
    });
    expect(controller.account!.email, 'updated@example.com');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'password confirmation blocks mismatch and clears the completed dialog',
    (tester) async {
      await open(tester, width: 390);
      await tap(tester, find.text('Change password'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current password'),
        'current-password',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'new-password-123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'different-password',
      );
      await tap(tester, find.text('Save password'));
      expect(calls.containsKey('changePassword'), isFalse);
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'new-password-123',
      );
      await tap(tester, find.text('Save password'));
      expect(calls['changePassword'], {
        'currentPassword': 'current-password',
        'newPassword': 'new-password-123',
      });
      expect(
        find.widgetWithText(TextFormField, 'Current password'),
        findsNothing,
      );
      expect(
        find.text('Password changed. Other sessions have been signed out.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed theme save retains the active theme and reports failure',
    (tester) async {
      final platform = tester.binding.platformDispatcher;
      platform.platformBrightnessTestValue = Brightness.light;
      addTearDown(platform.clearPlatformBrightnessTestValue);
      await open(tester);
      fail = true;
      await tap(tester, find.text('System').first);
      await tap(tester, find.widgetWithText(MenuItemButton, 'Dark'));
      expect(
        Theme.of(tester.element(find.text('Profile settings'))).brightness,
        Brightness.light,
      );
      expect(find.textContaining('Could not reach the vault'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
    },
  );

  test('late theme response cannot restore a signed-out account', () async {
    themeResponse = Completer<http.Response>();
    themeStarted = Completer<void>();
    final save = controller.updateTheme('dark');
    await themeStarted!.future;
    await controller.logout();
    themeResponse!.complete(
      http.Response(jsonEncode({...profile, 'themeMode': 'dark'}), 200),
    );
    await save;
    expect(controller.account, isNull);
    expect(controller.auth.token, isNull);
  });

  test(
    'concurrent theme and invitation saves preserve both confirmed fields',
    () async {
      themeResponse = Completer<http.Response>();
      themeStarted = Completer<void>();
      final oldProfile = Map<String, dynamic>.from(profile);
      final save = controller.updateTheme('dark');
      await themeStarted!.future;
      final policySave = controller.updateInvitationPolicy('none');
      themeResponse!.complete(
        http.Response(jsonEncode({...oldProfile, 'themeMode': 'dark'}), 200),
      );
      await save;
      await policySave;
      expect(controller.account!.themeMode, 'dark');
      expect(controller.account!.invitationPolicy, 'none');
    },
  );

  for (final action in ['profile', 'password']) {
    test(
      'expired $action request prevents an older refresh restoring account',
      () async {
        profileResponse = Completer<http.Response>();
        profileStarted = Completer<void>();
        final staleProfile = jsonEncode(profile);
        final refresh = controller.refresh();
        await profileStarted!.future;
        fail = true;
        failureStatus = 401;
        await expectLater(
          action == 'profile'
              ? controller.updateName('Updated')
              : controller.changePassword(
                  'current-password',
                  'new-password-123',
                ),
          throwsA(isA<ServerpodClientUnauthorized>()),
        );
        expect(controller.account, isNull);
        profileResponse!.complete(http.Response(staleProfile, 200));
        await refresh;
        expect(controller.account, isNull);
        expect(controller.auth.token, isNull);
      },
    );
  }

  test(
    'overlapping theme saves persist and display the latest choice',
    () async {
      themeResponse = Completer<http.Response>();
      themeStarted = Completer<void>();
      final firstResponse = themeResponse!;
      final darkSave = controller.updateTheme('dark');
      await themeStarted!.future;
      themeResponse = null;
      final lightSave = controller.updateTheme('light');
      await Future<void>.delayed(Duration.zero);
      firstResponse.complete(
        http.Response(jsonEncode({...profile, 'themeMode': 'dark'}), 200),
      );
      await Future.wait([darkSave, lightSave]);
      expect(profile['themeMode'], 'light');
      expect(controller.account!.themeMode, 'light');
    },
  );

  test(
    'profile save preserves a pending organization refresh and its data',
    () async {
      final org = OrganizationView(
        id: 'next',
        name: 'Next team',
        role: 'reader',
        createdAt: DateTime.utc(2026),
      );
      final secret = SecretView(
        id: 'secret',
        organizationId: org.id,
        name: 'Fixture key',
        project: 'Default',
        environment: 'Development',
        kind: 'API key',
        description: '',
        version: 1,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      workspaceResponses['organizations'] = [org.toJson()];
      workspaceResponses['listSecrets'] = [secret.toJson()];
      themeResponse = Completer<http.Response>();
      themeStarted = Completer<void>();
      final save = controller.updateTheme('dark');
      await themeStarted!.future;
      profileResponse = Completer<http.Response>();
      profileStarted = Completer<void>();
      final refresh = controller.selectOrganization(org);
      await profileStarted!.future;
      themeResponse!.complete(
        http.Response(jsonEncode({...profile, 'themeMode': 'dark'}), 200),
      );
      await save;
      profileResponse!.complete(http.Response(jsonEncode(profile), 200));
      await refresh;
      expect(controller.secrets.map((s) => s.id), ['secret']);
      expect(controller.account!.themeMode, 'dark');
      expect(controller.loading, isFalse);
    },
  );

  testWidgets(
    'sign out disposes password inputs and resets appearance to System',
    (tester) async {
      final platform = tester.binding.platformDispatcher;
      platform.platformBrightnessTestValue = Brightness.light;
      addTearDown(platform.clearPlatformBrightnessTestValue);
      controller.account = controller.account!.copyWith(themeMode: 'dark');
      await open(tester);
      expect(
        Theme.of(tester.element(find.text('Profile settings'))).brightness,
        Brightness.dark,
      );
      await tap(tester, find.text('Change password'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current password'),
        'transient-current-password',
      );
      await controller.logout();
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Current password'),
        findsNothing,
      );
      expect(find.text('transient-current-password'), findsNothing);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('Welcome back'))).brightness,
        Brightness.light,
      );
    },
  );
}
