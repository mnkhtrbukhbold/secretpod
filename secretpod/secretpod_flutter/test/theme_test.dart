import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/main.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';
import 'package:secretpod_flutter/widgets/dropdown_field.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1400, 1000)]) {
    testWidgets('system theme switches without losing form input at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final platform = tester.binding.platformDispatcher;
      platform.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(platform.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      final email = find.widgetWithText(TextFormField, 'Email address');
      await tester.enterText(email, 'theme@example.com');

      ThemeData theme() => Theme.of(tester.element(email));
      expect(theme().brightness, Brightness.light);
      expect(
        theme().scaffoldBackgroundColor.computeLuminance(),
        greaterThan(.8),
      );

      platform.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(theme().brightness, Brightness.dark);
      expect(theme().scaffoldBackgroundColor.computeLuminance(), lessThan(.05));
      expect(find.text('theme@example.com'), findsOneWidget);
      expect(tester.takeException(), isNull);

      platform.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(theme().brightness, Brightness.light);
      expect(
        theme().scaffoldBackgroundColor.computeLuminance(),
        greaterThan(.8),
      );
      expect(find.text('theme@example.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'system change updates an open menu and preserves the secret draft',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      final platform = tester.binding.platformDispatcher;
      platform.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(platform.clearPlatformBrightnessTestValue);
      final controller = VaultController('http://localhost:8080/')
        ..account = AccountView(
          id: 'a',
          name: 'Alex',
          email: 'alex@example.com',
        )
        ..organization = OrganizationView(
          id: 'o',
          name: 'Engineering',
          role: 'owner',
          createdAt: DateTime(2026, 10, 14),
        );
      controller.organizations = [controller.organization!];
      addTearDown(controller.dispose);
      await tester.pumpWidget(MyApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add secret'));
      await tester.pumpAndSettle();
      final name = find.widgetWithText(TextFormField, 'Secret name');
      await tester.enterText(name, 'Unsaved draft');
      await tester.tap(
        find.widgetWithText(SecretPodDropdown<String>, 'Environment'),
      );
      await tester.pumpAndSettle();

      final option = find.widgetWithText(MenuItemButton, 'Staging');
      Color menuBackground() => tester
          .widget<Material>(
            find
                .ancestor(
                  of: option,
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      expect(option, findsOneWidget);
      expect(menuBackground().computeLuminance(), lessThan(.1));

      platform.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(option, findsOneWidget);
      expect(menuBackground().computeLuminance(), greaterThan(.8));
      expect(find.text('Unsaved draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
