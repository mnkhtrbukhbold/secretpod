import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/main.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';
import 'package:secretpod_flutter/screens/projects_dialog.dart';
import 'package:secretpod_flutter/theme/app_theme.dart';

void main() {
  late VaultController controller;
  setUp(() {
    controller = VaultController('http://localhost:8080/')
      ..account = AccountView(id: 'a', name: 'Alex', email: 'alex@example.com')
      ..organization = OrganizationView(
        id: 'o',
        name: 'Engineering',
        role: 'owner',
        createdAt: DateTime(2026, 10, 13),
      );
    controller.organizations = [controller.organization!];
    controller.secrets = [
      SecretView(
        id: 's1',
        organizationId: 'o',
        name: 'STRIPE_API_KEY',
        project: 'Payments',
        environment: 'Production',
        kind: 'API key',
        description: '',
        version: 1,
        createdAt: DateTime(2026, 10, 13),
        updatedAt: DateTime(2026, 10, 13),
      ),
      SecretView(
        id: 's2',
        organizationId: 'o',
        name: 'DATABASE_URL',
        project: 'Website',
        environment: 'Development',
        kind: 'Environment variable',
        description: '',
        version: 1,
        createdAt: DateTime(2026, 10, 13),
        updatedAt: DateTime(2026, 10, 13),
      ),
    ];
  });
  tearDown(() => controller.dispose());
  testWidgets('projects count visible secrets missing from an older summary', (
    tester,
  ) async {
    controller.summary = WorkspaceSummary(
      secretCount: 12,
      filteredSecretCount: 12,
      memberCount: 1,
      activityCount: 0,
      projectCounts: {'payments': 12},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectsDialog(controller: controller, organizationId: 'o'),
      ),
    );
    await tester.scrollUntilVisible(find.text('Website'), 200);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Website'),
        matching: find.text('1 secret'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'payments'),
        matching: find.text('12 secrets'),
      ),
      findsOneWidget,
    );
  });
  testWidgets('large project lists build rows as they enter the viewport', (
    tester,
  ) async {
    controller.secrets = [];
    controller.summary = WorkspaceSummary(
      secretCount: 1000,
      filteredSecretCount: 1000,
      memberCount: 1,
      activityCount: 0,
      projectCounts: {
        for (var i = 0; i < 1000; i++)
          'Project ${i.toString().padLeft(4, '0')}': 1,
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectsDialog(controller: controller, organizationId: 'o'),
      ),
    );
    expect(find.byType(ListTile).evaluate().length, lessThan(30));
    await tester.scrollUntilVisible(find.text('Project 0020'), 500);
    expect(find.text('Project 0020'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [260.0, 390.0, 1400.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'projects remain usable at $width in $brightness with enlarged text',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          controller.summary = WorkspaceSummary(
            secretCount: 42,
            filteredSecretCount: 1,
            memberCount: 1,
            activityCount: 0,
            projectCounts: {
              'Payments': 31,
              'A long project name for the infrastructure team': 11,
            },
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: secretPodTheme(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: ProjectsDialog(controller: controller, organizationId: 'o'),
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text('11 secrets'), 200);
          expect(find.text('11 secrets'), findsOneWidget);
          await tester.scrollUntilVisible(find.text('31 secrets'), 200);
          expect(find.text('31 secrets'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Payments'));
          expect(tester.takeException(), isNull);
          expect(
            tester.getRect(find.text('Payments')).right,
            lessThanOrEqualTo(width),
          );
        },
      );
    }
  }
  testWidgets('empty workspace includes the Default project', (tester) async {
    controller.secrets = [];
    await tester.pumpWidget(MyApp(controller: controller));
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.text('Default'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Default'), findsOneWidget);
    await tester.tap(find.text('Default'));
    await tester.pumpAndSettle();
    expect(find.text('Project: Default'), findsOneWidget);
  });
  testWidgets('summary cards open projects and members and reset filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MyApp(controller: controller));
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    await tester.tap(find.text('Total secrets'));
    await tester.pumpAndSettle();
    expect(find.text('STRIPE_API_KEY'), findsOneWidget);
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Payments'));
    await tester.pumpAndSettle();
    expect(find.text('STRIPE_API_KEY'), findsOneWidget);
    expect(find.text('DATABASE_URL'), findsNothing);
    await tester.tap(find.text('Team members'));
    await tester.pumpAndSettle();
    expect(find.text('Invite member'), findsOneWidget);
  });
  for (final width in [260.0, 390.0]) {
    testWidgets('account menu keeps a gap from narrow screen edges at $width', (
      tester,
    ) async {
      controller.secrets = [];
      controller.organization = null;
      controller.organizations = [];
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MyApp(controller: controller));
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      final panel = find
          .ancestor(
            of: find.text('alex@example.com'),
            matching: find.byType(Material),
          )
          .first;
      expect(tester.getTopLeft(panel).dx, greaterThanOrEqualTo(20));
      expect(tester.getTopRight(panel).dx, lessThanOrEqualTo(width - 12));
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [390.0, 1400.0]) {
    testWidgets('empty vault states are centered at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MyApp(controller: controller));
      await tester.enterText(find.byType(TextField), 'Testing');
      await tester.pump();

      void expectCentered(Finder finder) {
        expect(
          tester.getCenter(finder).dx,
          closeTo(tester.getCenter(find.byType(TextField)).dx, 0.5),
        );
      }

      expectCentered(find.byIcon(Icons.search_off));
      expectCentered(find.text('No matching secrets'));
      expectCentered(
        find.text('Try another search or choose a different environment.'),
      );
      controller.secrets = [];
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expectCentered(find.text('Your vault starts here'));
      expectCentered(
        find.widgetWithText(OutlinedButton, 'Add your first secret'),
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('search and environment filter narrow actual secret rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MyApp(controller: controller));
    expect(find.text('STRIPE_API_KEY'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Payments');
    await tester.pump();
    expect(find.text('STRIPE_API_KEY'), findsOneWidget);
    expect(find.text('DATABASE_URL'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Development'));
    await tester.pump();
    expect(find.text('STRIPE_API_KEY'), findsNothing);
    expect(find.text('DATABASE_URL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('mobile workspace and add-secret dialog fit without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MyApp(controller: controller));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Add secret'));
    await tester.pumpAndSettle();
    expect(find.text('Add a secret'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('reader cannot see editing actions', (tester) async {
    controller.organization!.role = 'reader';
    await tester.pumpWidget(MyApp(controller: controller));
    expect(find.text('Add secret'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('certificate editor preserves pasted line breaks', (
    tester,
  ) async {
    await tester.pumpWidget(MyApp(controller: controller));
    await tester.tap(find.text('Add secret'));
    await tester.pumpAndSettle();
    final field = find.widgetWithText(TextFormField, 'Secret value');
    await tester.ensureVisible(field);
    await tester.enterText(
      field,
      '-----BEGIN KEY-----\nline2\n-----END KEY-----',
    );
    await tester.pump();
    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(
      editable.controller.text,
      '-----BEGIN KEY-----\nline2\n-----END KEY-----',
    );
  });
}
