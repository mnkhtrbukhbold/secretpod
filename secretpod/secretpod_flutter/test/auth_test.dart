import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretpod_flutter/main.dart';

void main() {
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
