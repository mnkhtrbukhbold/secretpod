import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';
import 'package:secretpod_flutter/main.dart';
import 'package:secretpod_flutter/widgets/dropdown_field.dart';
import 'package:secretpod_flutter/widgets/pagination_controls.dart';
import 'paging_controller_test.dart' show PagingFixture;

void main() {
  testWidgets('failed page size change restores the displayed selector', (
    tester,
  ) async {
    final fixture = PagingFixture();
    final controller = fixture.controller;
    addTearDown(controller.dispose);
    await controller.refresh();
    await tester.pumpWidget(MyApp(controller: controller));
    final selector = find.byType(SecretPodDropdown<int>);
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    fixture.fail = true;
    await tester.tap(find.text('50'));
    await tester.pumpAndSettle();
    expect(controller.pageSizes[0], 10);
    expect(
      find.descendant(of: selector, matching: find.text('10')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: selector, matching: find.text('50')),
      findsNothing,
    );
  });

  testWidgets('recreated workspace shows active server filters', (
    tester,
  ) async {
    final fixture = PagingFixture();
    final controller = fixture.controller;
    addTearDown(controller.dispose);
    await controller.refresh();
    await controller.filterSecrets(
      query: 'Secret 60',
      project: 'Other',
      environment: 'Production',
    );
    await tester.pumpWidget(
      MyApp(key: const ValueKey('recreated'), controller: controller),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Secret 60',
    );
    expect(find.text('Project: Other'), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Production'))
          .selected,
      isTrue,
    );
    expect(find.text('No matching secrets'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'Secret 60',
      ),
      findsOneWidget,
    );
  });

  for (final width in [260.0, 390.0]) {
    testWidgets('pagination fits width $width at enlarged text size', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 844),
              textScaler: const TextScaler.linear(2),
            ),
            child: Scaffold(
              body: PaginationControls(
                page: 0,
                pageSize: 10,
                total: 1000,
                onPage: (_) {},
                onPageSize: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(find.byTooltip('Next page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Secrets displays 10 rows and supports the next page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final account = AccountView(id: 'a', name: 'Alex', email: 'a@example.test');
    final org = OrganizationView(
      id: 'o',
      name: 'Team',
      role: 'owner',
      createdAt: DateTime.utc(2026),
    );
    final secrets = List.generate(
      30,
      (i) => SecretView(
        id: 's$i',
        organizationId: 'o',
        name: 'SECRET_$i',
        project: 'Default',
        environment: 'Production',
        kind: 'API key',
        description: '',
        version: 1,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    final requests = <Map<String, dynamic>>[];
    final controller = VaultController(
      'http://localhost:8080/',
      api: Client(
        'http://localhost:8080/',
        httpClientOverride: MockClient((request) async {
          final args = jsonDecode(request.body) as Map<String, dynamic>;
          final method = request.url.pathSegments.last;
          Object result = [];
          switch (method) {
            case 'profile':
              result = account.toJson();
            case 'organizations':
              result = [org.toJson()];
            case 'summary':
              result = {
                '__className__': 'WorkspaceSummary',
                'secretCount': 30,
                'filteredSecretCount': 30,
                'memberCount': 0,
                'activityCount': 0,
                'projectCounts': {'Default': 30},
              };
            case 'listSecrets':
              requests.add(args);
              result = secrets
                  .skip(args['offset'] as int? ?? 0)
                  .take(args['limit'] as int? ?? 10)
                  .map((s) => s.toJson())
                  .toList();
          }
          return http.Response(jsonEncode(result), 200);
        }),
      ),
    )..account = account;
    controller.auth.token = 'test-session';
    addTearDown(controller.dispose);
    await controller.refresh();
    await tester.pumpWidget(MyApp(controller: controller));
    expect(find.text('SECRET_0'), findsOneWidget);
    expect(find.text('SECRET_10'), findsNothing);
    expect(find.text('Page 1 of 3'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Next page'));
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('SECRET_10'), findsOneWidget);
    expect(find.text('SECRET_0'), findsNothing);
    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(requests.last['offset'], 10);
    expect(requests.last['limit'], 10);
    final selector = find.byType(SecretPodDropdown<int>);
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();
    expect(requests.last['limit'], 25);
    expect(find.text('Page 1 of 2'), findsOneWidget);
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();
    expect(requests.last['limit'], 10);
    expect(find.text('Page 1 of 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
