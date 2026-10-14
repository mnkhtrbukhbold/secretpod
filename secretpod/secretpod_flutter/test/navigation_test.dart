import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/main.dart';

import 'package:secretpod_flutter/state/vault_controller.dart';

void main() {
  late VaultController controller;
  final reports = <Map<Object?, Object?>>[];

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
    reports.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.navigation, (call) async {
          if (call.method == 'routeInformationUpdated') {
            reports.add(Map<Object?, Object?>.from(call.arguments as Map));
          }
          return null;
        });
  });
  tearDown(() {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.navigation, null);
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MyApp(controller: controller));
    await tester.pumpAndSettle();
  }

  Future<void> browserRoute(WidgetTester tester, String location) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall(
          'pushRouteInformation',
          {'location': location, 'state': null},
        ),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'screen changes create history and browser replay restores screens',
    (tester) async {
      await open(tester);
      await tester.tap(find.widgetWithText(ListTile, 'Activity'));
      await tester.pumpAndSettle();
      expect(reports.last['uri'], '/activity');
      expect(reports.last['replace'], false);
      await tester.tap(find.widgetWithText(ListTile, 'Members'));
      await tester.pumpAndSettle();
      expect(reports.last['uri'], '/members');
      await browserRoute(tester, '/activity');
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Activity'))
            .selected,
        true,
      );
      await browserRoute(tester, '/members');
      expect(find.text('Invite member'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('account routes restore their previous workspace destination', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ListTile, 'Members'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My invitations'));
    await tester.pumpAndSettle();
    expect(reports.last['uri'], '/invitations');
    await browserRoute(tester, '/settings');
    expect(find.byTooltip('Refresh profile'), findsOneWidget);
    await tester.tap(find.text('Back to workspace'));
    await tester.pumpAndSettle();
    expect(find.text('Invite member'), findsOneWidget);
    expect(reports.last['uri'], '/members');
  });

  testWidgets('initial deep link survives startup', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/settings';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    await open(tester);
    expect(find.byTooltip('Refresh profile'), findsOneWidget);
  });

  testWidgets('unknown routes recover without exposing route diagnostics', (
    tester,
  ) async {
    await open(tester);
    await browserRoute(tester, '/unknown?private=untrusted');
    expect(find.text('Add secret'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('browser navigation respects a dirty secret editor', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Add secret'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Secret name'),
      'Unsaved',
    );
    await browserRoute(tester, '/activity');
    expect(find.text('Discard changes'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'Secrets'))
          .selected,
      true,
    );
  });
}
