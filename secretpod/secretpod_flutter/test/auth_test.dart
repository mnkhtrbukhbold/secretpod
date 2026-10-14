import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/main.dart';
import 'package:secretpod_flutter/screens/auth_screen.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';

void main() {
  testWidgets(
    'failed login cooldown covers clicks and Enter without changing password bytes',
    (tester) async {
      var requests = 0;
      final response = Completer<http.Response>();
      final client = Client(
        'http://localhost/',
        httpClientOverride: MockClient((request) async {
          requests++;
          expect(
            (jsonDecode(request.body) as Map)['password'],
            ' exact password ',
          );
          return response.future;
        }),
      );
      final controller = VaultController('http://localhost/', api: client);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(home: AuthScreen(controller: controller)),
      );
      await tester.enterText(find.byType(TextFormField).first, 'a@example.com');
      await tester.enterText(
        find.byType(TextFormField).last,
        ' exact password ',
      );
      final submit = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Sign in'))
          .onPressed!;
      submit();
      submit();
      await tester.pump();
      expect(requests, 1);
      response.complete(http.Response('', 503));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(requests, 1);
      await tester.pump(const Duration(seconds: 2));
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('oversized login fields are rejected locally', (tester) async {
    var requests = 0;
    final client = Client(
      'http://localhost/',
      httpClientOverride: MockClient((_) async {
        requests++;
        return http.Response('', 503);
      }),
    );
    final controller = VaultController('http://localhost/', api: client);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(controller: controller)),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      '${'a' * 250}@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'p' * 257);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.text('Use at most 254 characters.'), findsOneWidget);
    expect(find.text('Use at most 256 characters.'), findsOneWidget);
  });
  testWidgets('empty login is validated without sending a request', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Sign in').last);
    await tester.pump();
    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });
  testWidgets('authentication fits a 390px mobile screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    expect(find.text('SecretPod'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
