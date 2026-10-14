import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretpod_flutter/screens/workspace_screen.dart';
import 'package:secretpod_flutter/screens/invitations_screen.dart';
import 'package:secretpod_flutter/widgets/dropdown_field.dart';
import 'package:secretpod_flutter/widgets/list_table.dart';
import 'paging_controller_test.dart' show PagingFixture;

void main() {
  testWidgets('sent search and status filter all pages together', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = PagingFixture();
    final c = fixture.controller;
    addTearDown(c.dispose);
    await c.refresh();
    c.sentInvitations = [
      for (var i = 0; i < 31; i++)
        c.sentInvitations[i].copyWith(
          recipientName: i == 30 ? 'Morgan' : 'Person $i',
          recipientEmail: 'person$i@company.test',
          status: i >= 20 ? 'revoked' : 'pending',
        ),
    ];
    Widget screen(Key key) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OutgoingInvitations(key: key, controller: c),
        ),
      ),
    );
    await tester.pumpWidget(screen(const ValueKey('first')));
    await tester.ensureVisible(find.byTooltip('Next page'));
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    final search = find.byType(TextField);
    await tester.ensureVisible(search);
    await tester.enterText(search, ' MORGAN ');
    await tester.pumpAndSettle();
    expect(find.byType(InvitationTile), findsOneWidget);
    expect(find.text('Morgan'), findsOneWidget);
    expect(find.text('Page 1 of 1'), findsOneWidget);
    await tester.tap(find.byType(SecretPodDropdown<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pending'));
    await tester.pumpAndSettle();
    expect(find.text('No matching invitations'), findsOneWidget);
    expect(find.byType(InvitationTile), findsNothing);
    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    expect(find.byType(InvitationTile), findsNWidgets(10));
    await tester.enterText(search, '@COMPANY.TEST');
    await tester.tap(find.byType(SecretPodDropdown<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoked'));
    await tester.pumpAndSettle();
    expect(find.byType(InvitationTile), findsNWidgets(10));
    expect(find.text('Page 1 of 2'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Next page'));
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.byType(InvitationTile), findsOneWidget);
    expect(find.text('Morgan'), findsOneWidget);
    await tester.pumpWidget(screen(const ValueKey('reopened')));
    await tester.pumpAndSettle();
    expect(find.byType(InvitationTile), findsOneWidget);
    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(c.sentInvitations, hasLength(31));
    expect(tester.takeException(), isNull);
  });

  for (final page in [1, 2, 3, 4]) {
    testWidgets('list $page fits mobile with enlarged text', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
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
          home: page <= 2
              ? WorkspaceScreen(
                  controller: fixture.controller,
                  page: page,
                  lastWorkspacePage: page,
                  onNavigate: (_) {},
                )
              : Scaffold(
                  body: SingleChildScrollView(
                    child: page == 3
                        ? InvitationsScreen(
                            controller: fixture.controller,
                            onOpenSettings: () {},
                          )
                        : OutgoingInvitations(controller: fixture.controller),
                  ),
                ),
        ),
      );
      expect(find.byType(ListTableHeader), findsNothing);
      expect(find.byType(ListTableRow), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'invitation page size is independent and survives screen recreation',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = PagingFixture();
      addTearDown(fixture.controller.dispose);
      await fixture.controller.refresh();
      Widget screen(Key key) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InvitationsScreen(
              key: key,
              controller: fixture.controller,
              onOpenSettings: () {},
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen(const ValueKey('first')));
      expect(find.byType(InvitationTile), findsNWidgets(10));
      final selector = find.byType(SecretPodDropdown<int>);
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('25'));
      await tester.pumpAndSettle();
      expect(find.byType(InvitationTile), findsNWidgets(25));
      await tester.pumpWidget(screen(const ValueKey('recreated')));
      await tester.pumpAndSettle();
      expect(find.byType(InvitationTile), findsNWidgets(25));
      expect(fixture.controller.preferredPageSize('sent-invitations'), 10);
      expect(fixture.controller.pageSizes, [10, 10, 10]);
      await tester.ensureVisible(find.byTooltip('Next page'));
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      expect(find.byType(InvitationTile), findsNWidgets(6));
      expect(find.text('Page 2 of 2'), findsOneWidget);
      await tester.pumpWidget(screen(const ValueKey('reopened-on-page-two')));
      await tester.pumpAndSettle();
      expect(find.text('Page 2 of 2'), findsOneWidget);
      expect(find.byType(InvitationTile), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    },
  );

  for (final page in [1, 2]) {
    testWidgets('workspace list $page has table columns on desktop', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = PagingFixture();
      addTearDown(fixture.controller.dispose);
      await fixture.controller.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScreen(
            controller: fixture.controller,
            page: page,
            lastWorkspacePage: page,
            onNavigate: (_) {},
          ),
        ),
      );
      for (final label
          in page == 1
              ? ['ACTOR', 'ACTION', 'TARGET', 'TIME']
              : ['NAME', 'EMAIL', 'ROLE', 'ACTIONS']) {
        expect(find.text(label), findsWidgets);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final outgoing in [false, true]) {
    testWidgets(
      '${outgoing ? 'sent' : 'received'} invitations have table columns',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = PagingFixture();
        addTearDown(fixture.controller.dispose);
        await fixture.controller.refresh();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: outgoing
                    ? OutgoingInvitations(controller: fixture.controller)
                    : InvitationsScreen(
                        controller: fixture.controller,
                        onOpenSettings: () {},
                      ),
              ),
            ),
          ),
        );
        for (final label in [
          if (outgoing) ...['NAME', 'EMAIL'] else 'ORGANIZATION',
          'ROLE',
          'STATUS',
          'ACTIONS',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
