import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';
import 'package:secretpod_flutter/widgets/secret_activity.dart';

void main() {
  late VaultController controller;
  late List<Map<String, dynamic>> requests;
  var count = 25;
  var fail = false;
  Completer<void>? pending;
  final time = DateTime.utc(2026, 10, 14);

  setUp(() {
    requests = [];
    count = 25;
    fail = false;
    pending = null;
    controller = VaultController(
      'http://localhost/',
      api: Client(
        'http://localhost/',
        httpClientOverride: MockClient((request) async {
          final args = jsonDecode(request.body) as Map<String, dynamic>;
          requests.add(args);
          final cursor = args['beforeEventId'] as String?;
          final start = cursor == null ? 0 : int.parse(cursor.substring(1)) + 1;
          final end = (start + (args['limit'] as int)).clamp(0, count);
          final response = http.Response(
            jsonEncode([
              for (var i = start; i < end; i++)
                AuditView(
                  id: 'e$i',
                  actor: 'Actor $i',
                  action: 'created',
                  target: args['secretId'] as String,
                  createdAt: time,
                ).toJson(),
            ]),
            200,
          );
          await pending?.future;
          return fail ? http.Response('', 503) : response;
        }),
      ),
    );
  });
  tearDown(() => controller.dispose());

  Future<void> open(
    WidgetTester tester, {
    String id = 's1',
    int revision = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SecretActivity(
              controller: controller,
              revision: revision,
              secret: SecretView(
                id: id,
                organizationId: 'org',
                name: id,
                project: 'Payments',
                environment: 'Production',
                kind: 'API key',
                description: '',
                version: 1,
                createdAt: time,
                updatedAt: time,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> click(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, String label) =>
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, label))
          .onPressed !=
      null;

  testWidgets(
    'Next replaces the page and Previous reloads its saved boundary',
    (tester) async {
      await open(tester);
      expect(find.text('Actor 0'), findsOneWidget);
      expect(find.text('Actor 9'), findsOneWidget);
      expect(find.text('Actor 10'), findsNothing);
      expect(find.text('Page 1'), findsOneWidget);
      expect(enabled(tester, 'Previous'), isFalse);
      await click(tester, 'Next');
      expect(find.text('Actor 0'), findsNothing);
      expect(find.text('Actor 10'), findsOneWidget);
      expect(find.text('Actor 19'), findsOneWidget);
      expect(find.text('Actor 20'), findsNothing);
      expect(requests.last['beforeEventId'], 'e9');
      await click(tester, 'Next');
      expect(find.text('Page 3'), findsOneWidget);
      expect(find.text('Actor 20'), findsOneWidget);
      expect(find.text('Actor 24'), findsOneWidget);
      expect(enabled(tester, 'Next'), isFalse);
      await click(tester, 'Previous');
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('Actor 20'), findsNothing);
      expect(find.text('Actor 10'), findsOneWidget);
      expect(requests.last['beforeEventId'], 'e9');
      await click(tester, 'Previous');
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Actor 0'), findsOneWidget);
      expect(requests.last['beforeEventId'], isNull);
    },
  );

  for (final total in [0, 3, 10, 20]) {
    testWidgets('no empty extra page for $total events', (tester) async {
      count = total;
      await open(tester);
      if (total == 20) await click(tester, 'Next');
      expect(enabled(tester, 'Next'), isFalse);
      expect(requests.every((r) => (r['limit'] as int) <= 11), isTrue);
    });
  }

  testWidgets(
    'failed navigation retains its page and Retry targets the failed page',
    (tester) async {
      await open(tester);
      fail = true;
      await click(tester, 'Next');
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Actor 0'), findsOneWidget);
      expect(find.textContaining('Could not load activity'), findsOneWidget);
      fail = false;
      await click(tester, 'Retry');
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('Actor 0'), findsNothing);
      expect(find.text('Actor 10'), findsOneWidget);
      expect(requests.last['beforeEventId'], 'e9');
    },
  );

  testWidgets(
    'refresh resets pagination and narrow enlarged controls remain usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester);
      await click(tester, 'Next');
      await tester.ensureVisible(find.byTooltip('Refresh activity'));
      await tester.tap(find.byTooltip('Refresh activity'));
      await tester.pumpAndSettle();
      expect(find.text('Page 1'), findsOneWidget);
      expect(enabled(tester, 'Previous'), isFalse);
      expect(requests.last['beforeEventId'], isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'busy navigation rejects repeat clicks and ignores an obsolete response',
    (tester) async {
      await open(tester);
      pending = Completer<void>();
      final next = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Next'))
          .onPressed!;
      next();
      next();
      await tester.pump();
      expect(requests, hasLength(2));
      expect(enabled(tester, 'Previous'), isFalse);
      expect(enabled(tester, 'Next'), isFalse);
      final obsolete = pending!;
      pending = null;
      count = 3;
      await open(tester, id: 's2');
      obsolete.complete();
      await tester.pumpAndSettle();
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Actor 2'), findsOneWidget);
      expect(find.text('Actor 10'), findsNothing);
    },
  );
}
