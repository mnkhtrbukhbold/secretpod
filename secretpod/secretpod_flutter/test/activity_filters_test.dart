import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretpod_flutter/screens/workspace_screen.dart';
import 'package:secretpod_flutter/widgets/secret_activity.dart';
import 'package:secretpod_flutter/theme/app_theme.dart';
import 'package:secretpod_flutter/widgets/dropdown_field.dart';
import 'package:secretpod_flutter/widgets/activity_filters.dart';
import 'paging_controller_test.dart' show PagingFixture;

void main() {
  testWidgets('action options use recorded actions with formatted labels', (
    tester,
  ) async {
    final fixture = PagingFixture();
    addTearDown(fixture.controller.dispose);
    await fixture.controller.refresh();
    fixture.controller.summary = fixture.controller.summary!.copyWith(
      activityActions: [
        'invited reader',
        'invitation revoked',
        'added reader',
        'created organization',
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActivityFilters(controller: fixture.controller)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('activity-filter-Action')));
    await tester.pumpAndSettle();
    expect(find.text('Invited reader'), findsOneWidget);
    expect(find.text('Invitation revoked'), findsOneWidget);
    expect(find.text('Added reader'), findsOneWidget);
    expect(find.text('Created organization'), findsOneWidget);
    expect(find.text('Deleted'), findsNothing);
    expect(activityLabel('invitation revoked'), 'Invitation revoked');
  });

  testWidgets('projects include current projects and member label is clear', (
    tester,
  ) async {
    final fixture = PagingFixture();
    addTearDown(fixture.controller.dispose);
    await fixture.controller.refresh();
    fixture.controller.summary = fixture.controller.summary!.copyWith(
      projectCounts: {'Payments': 2, 'Empty project': 0},
      activityProjects: [],
      activityUsers: {
        'id:a': 'Alex (alex@example.test)',
        'id:b': 'Blair (blair@example.test)',
      },
    );
    fixture.controller.activityProject = 'payments';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActivityFilters(controller: fixture.controller)),
      ),
    );
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('All members'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('activity-filter-Project')));
    await tester.pumpAndSettle();
    expect(find.text('Payments'), findsNWidgets(2));
    expect(find.text('Empty project'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('activity-filter-Project')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activity-filter-Members')));
    await tester.pumpAndSettle();
    expect(find.text('Alex (alex@example.test)'), findsOneWidget);
    expect(find.text('Blair (blair@example.test)'), findsOneWidget);
  });

  for (final size in [const Size(1400, 1000), const Size(390, 844)]) {
    testWidgets('date range dialog stays within a bounded surface at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = PagingFixture();
      addTearDown(fixture.controller.dispose);
      await fixture.controller.refresh();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActivityFilters(controller: fixture.controller),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('activity-date-range')));
      await tester.pumpAndSettle();
      final surface = tester.getRect(find.byType(Dialog));
      expect(surface.width, lessThanOrEqualTo(560));
      expect(surface.height, lessThanOrEqualTo(680));
      expect(surface.left, greaterThan(0));
      expect(surface.top, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  }

  test(
    'activity filters reset their page and reach summary and rows together',
    () async {
      final fixture = PagingFixture();
      final c = fixture.controller;
      addTearDown(c.dispose);
      await c.refresh();
      await c.changePage(1, 3);
      final start = DateTime.utc(2026, 10, 1), end = DateTime.utc(2026, 11, 1);
      await c.filterActivity(
        from: start,
        until: end,
        project: 'Payments',
        action: 'revealed',
        user: 'id:a',
      );
      expect(c.pages[1], 0);
      final summary = fixture.requests.lastWhere(
        (r) => r['method'] == 'summary',
      );
      final rows = fixture.requests.lastWhere((r) => r['method'] == 'activity');
      expect(summary['activityProject'], rows['project']);
      expect(summary['activityAction'], rows['action']);
      expect(summary['activityUser'], rows['user']);
      expect(summary['activityFrom'], start.toIso8601String());
      expect(rows['until'], end.toIso8601String());
      expect(rows['offset'], 0);
      await c.selectOrganization(fixture.organizations[1]);
      expect(c.hasActivityFilters, isFalse);
      await c.selectOrganization(fixture.organizations[0]);
      expect(c.activityProject, 'Payments');
      expect(c.activityFrom, start);
      await c.filterActivity();
      expect(c.hasActivityFilters, isFalse);
      expect(
        fixture.requests.lastWhere((r) => r['method'] == 'activity')['project'],
        isNull,
      );
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'action badges share semantic icon colors in ${dark ? 'dark' : 'light'} theme',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: secretPodTheme(dark ? Brightness.dark : Brightness.light),
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    for (final action in [
                      'revealed',
                      'deleted',
                      'updated',
                      'created',
                    ])
                      Row(
                        children: [
                          Icon(
                            activityIcon(action),
                            color: activityColors(context, action).foreground,
                          ),
                          ActivityBadge(action),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        for (final action in ['revealed', 'deleted', 'updated', 'created']) {
          final icon = tester.widget<Icon>(find.byIcon(activityIcon(action)));
          final label = tester.widget<Text>(find.text(activityLabel(action)));
          expect(label.style!.color, icon.color);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('activity exposes filters and reset with narrow enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = PagingFixture();
    addTearDown(fixture.controller.dispose);
    await fixture.controller.refresh();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ListenableBuilder(
          listenable: fixture.controller,
          builder: (context, _) => WorkspaceScreen(
            controller: fixture.controller,
            page: 1,
            lastWorkspacePage: 1,
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Date range'), findsOneWidget);
    expect(find.text('All projects'), findsOneWidget);
    expect(find.text('All actions'), findsOneWidget);
    expect(find.text('All members'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('action selection requests a new page and clear resets it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = PagingFixture();
    addTearDown(fixture.controller.dispose);
    await fixture.controller.refresh();
    fixture.controller.summary = fixture.controller.summary!.copyWith(
      activityActions: ['revealed'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: fixture.controller,
          builder: (context, _) => WorkspaceScreen(
            controller: fixture.controller,
            page: 1,
            lastWorkspacePage: 1,
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    final action = find.byKey(const ValueKey('activity-filter-Action'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SecretPodMenuItem, 'Revealed'));
    await tester.pumpAndSettle();
    expect(fixture.controller.activityAction, 'revealed');
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(fixture.controller.hasActivityFilters, isFalse);
    await tester.tap(find.byKey(const ValueKey('activity-date-range')));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
