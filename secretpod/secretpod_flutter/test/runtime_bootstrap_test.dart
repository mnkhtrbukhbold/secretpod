import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretpod_flutter/config/runtime_bootstrap.dart';

void main() {
  testWidgets(
    'failed configuration is visible and Retry starts the app only after success',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        RuntimeBootstrap(
          load: () async {
            if (++attempts == 1) {
              throw const FormatException('sensitive backend details');
            }
            return 'https://vault.example/api/';
          },
          appBuilder: (url) => MaterialApp(home: Text('Connected to $url')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to load application configuration.'),
        findsOneWidget,
      );
      expect(find.textContaining('sensitive backend details'), findsNothing);
      expect(find.textContaining('Connected to'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        find.text('Connected to https://vault.example/api/'),
        findsOneWidget,
      );
      expect(attempts, 2);
    },
  );
}
