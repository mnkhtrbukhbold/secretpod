import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/screens/secret_dialogs.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';
import 'package:secretpod_flutter/widgets/common.dart';

void main() {
  late VaultController controller;
  final now = DateTime.utc(2026, 10, 14);
  final secret = SecretView(
    id: 's',
    organizationId: 'o',
    name: 'Service login',
    project: 'Default',
    environment: 'Production',
    kind: 'Username and password',
    description: '',
    version: 1,
    createdAt: now,
    updatedAt: now,
    url: 'https://example.com/login',
    expiresAt: DateTime.utc(2020, 1, 2),
  );
  Map<String, dynamic>? saved;
  final copied = <String>[];
  final steps = <String>[];
  setUp(() {
    saved = null;
    copied.clear();
    steps.clear();
    final client = Client(
      'http://localhost/',
      httpClientOverride: MockClient((request) async {
        final args = jsonDecode(request.body) as Map<String, dynamic>;
        final method = request.url.path.split('/').last;
        switch (method) {
          case 'saveSecret':
            saved = args;
            return http.Response(jsonEncode(secret.toJson()), 200);
          case 'secretActivity':
            return http.Response('[]', 200);
          case 'revealSecretFields':
            return http.Response(
              jsonEncode(
                SecretFields(
                  value: 'test-password',
                  username: 'test-username',
                ).toJson(),
              ),
              200,
            );
          case 'copySecret':
            final field = args['field'] as String;
            steps.add('request:$field');
            return http.Response(
              jsonEncode(
                SecretCopy(
                  eventId: field,
                  value: field == 'username'
                      ? 'test-username'
                      : 'test-password',
                ).toJson(),
              ),
              200,
            );
          case 'confirmCopy':
            steps.add('confirm:${args['eventId']}');
            return http.Response('null', 200);
        }
        throw StateError('Unexpected request: $method');
      }),
    );
    controller = VaultController('http://localhost/', api: client)
      ..organization = OrganizationView(
        id: 'o',
        name: 'Team',
        role: 'owner',
        createdAt: now,
      );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
            steps.add('clipboard');
          }
          return null;
        });
  });
  tearDown(() {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  Future<void> editor(WidgetTester tester, {SecretView? existing}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    SecretEditor(controller: controller, secret: existing),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'create credential with URL and expiry preserves password whitespace',
    (tester) async {
      await editor(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Secret name'),
        'Service login',
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('dropdown-trigger')).last,
      );
      await tapVisible(
        tester,
        find.widgetWithText(MenuItemButton, 'Username and password'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('secret-username')),
        'test-username',
      );
      final password = find.byKey(const ValueKey('secret-value'));
      await tester.enterText(password, '  test-password  ');
      expect(
        tester.widget<TextFormField>(password).controller!.text,
        '  test-password  ',
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: password,
                matching: find.byType(EditableText),
              ),
            )
            .obscureText,
        isTrue,
      );
      await tester.enterText(
        find.byKey(const ValueKey('secret-url')),
        'https://example.com/login',
      );
      await tapVisible(tester, find.text('Set expiry date'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Save secret'));
      expect(saved!['kind'], 'Username and password');
      expect(saved!['username'], 'test-username');
      expect(saved!['value'], '  test-password  ');
      expect(saved!['url'], 'https://example.com/login');
      final expiry = DateTime.parse(saved!['expiresAt'] as String);
      final today = DateTime.now();
      expect(expiry, DateTime.utc(today.year, today.month, today.day));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing metadata keeps credentials and clears optional fields on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await editor(tester, existing: secret);
      await tester.enterText(find.byKey(const ValueKey('secret-url')), '');
      await tapVisible(tester, find.byTooltip('Remove expiry date'));
      expect(find.text('Never expires'), findsOneWidget);
      await tapVisible(tester, find.text('Save secret'));
      expect(saved!['value'], isNull);
      expect(saved!['username'], isNull);
      expect(saved!['expiresAt'], isNull);
      expect(saved!['replaceMetadata'], isTrue);
      expect(saved!['url'], '');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'converting credential type explains removal of the saved username',
    (tester) async {
      await editor(tester, existing: secret);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('dropdown-trigger')).last,
      );
      await tapVisible(tester, find.widgetWithText(MenuItemButton, 'Password'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('will remove the saved username'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'credentials reveal together, hide after thirty seconds and copy separately',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecretDetails(controller: controller, secret: secret),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('test-username'), findsNothing);
      expect(find.text('test-password'), findsNothing);
      expect(find.text('https://example.com/login'), findsOneWidget);
      expect(find.text('Expired 2020-01-02'), findsOneWidget);
      await tapVisible(tester, find.text('Copy username'));
      await tapVisible(tester, find.text('Copy password'));
      expect(copied, ['test-username', 'test-password']);
      expect(steps, [
        'request:username',
        'clipboard',
        'confirm:username',
        'request:value',
        'clipboard',
        'confirm:value',
      ]);
      expect(find.text('test-password'), findsNothing);
      await tapVisible(tester, find.text('Reveal credentials'));
      expect(find.text('test-username'), findsOneWidget);
      expect(find.text('test-password'), findsOneWidget);
      await tester.tap(find.widgetWithText(Tab, 'Activity'));
      await tester.pumpAndSettle();
      expect(find.text('test-username'), findsNothing);
      expect(find.text('test-password'), findsNothing);
      await tester.pump(const Duration(seconds: 31));
      await tester.tap(find.widgetWithText(Tab, 'Details'));
      await tester.pumpAndSettle();
      expect(find.text('test-username'), findsNothing);
      expect(find.text('test-password'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('expiry treats the chosen calendar day as valid through that day', () {
    expect(
      secretExpired(
        DateTime.utc(2026, 10, 14),
        now: DateTime(2026, 10, 14, 23, 59),
      ),
      isFalse,
    );
    expect(
      secretExpired(DateTime.utc(2026, 10, 14), now: DateTime(2026, 10, 15)),
      isTrue,
    );
    expect(expiryLabel(null), 'Never expires');
  });
}
