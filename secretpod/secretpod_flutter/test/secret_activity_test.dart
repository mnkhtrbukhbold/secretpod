import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/screens/secret_dialogs.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';

void main() {
  late VaultController controller;
  final time = DateTime.utc(2026, 10, 13, 12, 34, 56);
  final secret = SecretView(
    id: 's1',
    organizationId: 'org',
    name: 'API_KEY',
    project: 'Payments',
    environment: 'Production',
    kind: 'API key',
    description: '',
    version: 1,
    createdAt: time,
    updatedAt: time,
  );
  final steps = <String>[];
  var clipboardFails = false, confirmationFails = false, historyFails = false;
  var copied = false, requested = false;
  var confirmations = 0;
  var historyRequests = 0;
  var historyCount = 1;
  setUp(() {
    steps.clear();
    clipboardFails = confirmationFails = historyFails = copied = requested =
        false;
    confirmations = 0;
    historyRequests = 0;
    historyCount = 1;
    final client = Client(
      'http://localhost/',
      httpClientOverride: MockClient((request) async {
        final args = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.endsWith('/secretActivity')) {
          historyRequests++;
          expect(args['organizationId'], 'org');
          expect(args['secretId'], 's1');
          expect(args['limit'], 10);
          if (historyFails) return http.Response('', 503);
          return http.Response(
            jsonEncode([
              if (requested)
                AuditView(
                  id: 'copy1',
                  actor: 'Reader (reader@example.com)',
                  actorId: 'reader',
                  secretId: 's1',
                  version: 2,
                  action: copied ? 'copied' : 'copy requested',
                  target: 'API_KEY',
                  createdAt: time,
                ).toJson(),
              for (var index = 0; index < historyCount; index++)
                AuditView(
                  id: 'edit$index',
                  actor: 'Alex (alex@example.com)',
                  actorId: 'alex',
                  secretId: 's1',
                  version: 2,
                  action: 'rotated',
                  target: 'API_KEY',
                  details: 'Changed: value, name',
                  createdAt: time,
                ).toJson(),
            ]),
            200,
          );
        }
        if (request.url.path.endsWith('/copySecret')) {
          expect(args['id'], 's1');
          expect(args['organizationId'], 'org');
          steps.add('request');
          requested = true;
          return http.Response(
            jsonEncode(
              SecretCopy(eventId: 'copy1', value: 'current-value-v2').toJson(),
            ),
            200,
          );
        }
        if (request.url.path.endsWith('/confirmCopy')) {
          expect(args['eventId'], 'copy1');
          expect(args['secretId'], 's1');
          expect(args['organizationId'], 'org');
          steps.add('confirm');
          confirmations++;
          if (confirmationFails) return http.Response('', 503);
          copied = true;
          return http.Response('null', 200);
        }
        throw StateError('Unexpected test request: ${request.url.path}');
      }),
    );
    controller = VaultController('http://localhost/', api: client)
      ..organization = OrganizationView(
        id: 'org',
        name: 'Team',
        role: 'reader',
        createdAt: time,
      );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            steps.add('clipboard');
            if (clipboardFails) throw PlatformException(code: 'denied');
            expect((call.arguments as Map)['text'], 'current-value-v2');
          }
          return null;
        });
  });
  tearDown(() {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SecretDetails(controller: controller, secret: secret),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> activity(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(Tab, 'Activity'));
    await tester.pumpAndSettle();
  }

  testWidgets('details open first and activity loads only in its tab', (
    tester,
  ) async {
    await open(tester);
    expect(find.widgetWithText(Tab, 'Details'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Copy'), findsOneWidget);
    expect(find.text('Alex (alex@example.com)'), findsNothing);
    expect(historyRequests, 0);
    await activity(tester);
    expect(historyRequests, 1);
    expect(find.text('Alex (alex@example.com)'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Copy'), findsNothing);
    await tester.tap(find.widgetWithText(Tab, 'Details'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Copy'), findsOneWidget);
    expect(find.text('Alex (alex@example.com)'), findsNothing);
  });

  testWidgets(
    'activity tabs stay accessible while history scrolls at 2x text',
    (tester) async {
      historyCount = 12;
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SecretDetails(controller: controller, secret: secret),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await activity(tester);
      final tabs = tester.getRect(find.byType(TabBar));
      final title = tester.getRect(find.text('API_KEY'));
      await tester.drag(
        find.byKey(const ValueKey('dialog-body-scroll')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(TabBar)), tabs);
      expect(tester.getRect(find.text('API_KEY')), title);
      await tester.tap(find.widgetWithText(Tab, 'Details'));
      await tester.pumpAndSettle();
      expect(find.text('SECRET VALUE').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'secret details show actor, changed fields, version and time on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      expect(find.text('Activity'), findsOneWidget);
      await activity(tester);
      expect(find.text('Alex (alex@example.com)'), findsOneWidget);
      expect(find.textContaining('Changed: value, name'), findsOneWidget);
      expect(find.textContaining('Version 2'), findsOneWidget);
      expect(find.textContaining('2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'copy records request, writes latest value, then confirms and refreshes history',
    (tester) async {
      await open(tester);
      await activity(tester);
      expect(find.text('Reader (reader@example.com)'), findsNothing);
      await tester.tap(find.widgetWithText(Tab, 'Details'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Copy'));
      await tester.pumpAndSettle();
      expect(steps, ['request', 'clipboard', 'confirm']);
      await activity(tester);
      expect(find.text('Reader (reader@example.com)'), findsOneWidget);
      expect(find.text('Copied'), findsWidgets);
      expect(find.text('current-value-v2'), findsNothing);
    },
  );

  testWidgets('clipboard failure leaves a request and never confirms a copy', (
    tester,
  ) async {
    clipboardFails = true;
    await open(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Copy'));
    await tester.pumpAndSettle();
    expect(steps, ['request', 'clipboard']);
    expect(confirmations, 0);
    expect(find.text('Copied'), findsNothing);
    expect(find.textContaining('Clipboard access failed'), findsOneWidget);
    await activity(tester);
    expect(find.text('Copy requested'), findsOneWidget);
  });

  testWidgets(
    'lost confirmation is reported and retried without copying again',
    (tester) async {
      confirmationFails = true;
      await open(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Copy'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('confirmation could not be saved'),
        findsOneWidget,
      );
      confirmationFails = false;
      await tester.ensureVisible(find.text('Retry confirmation'));
      await tester.tap(find.text('Retry confirmation'));
      await tester.pumpAndSettle();
      expect(steps, ['request', 'clipboard', 'confirm', 'confirm']);
      expect(find.text('Retry confirmation'), findsNothing);
      expect(find.text('Copied'), findsWidgets);
    },
  );

  testWidgets(
    'history connection failure has an explicit retry instead of empty history',
    (tester) async {
      historyFails = true;
      await open(tester);
      await activity(tester);
      expect(find.textContaining('Could not load activity'), findsOneWidget);
      historyFails = false;
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Alex (alex@example.com)'), findsOneWidget);
      expect(find.textContaining('Could not load activity'), findsNothing);
    },
  );
}
