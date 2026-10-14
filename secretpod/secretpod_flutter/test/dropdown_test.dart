import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretpod_flutter/widgets/dropdown_field.dart';

void main() {
  Widget sample({
    String value = 'reader',
    ValueChanged<String?>? onChanged,
    Key? fieldKey,
  }) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 280,
          child: SecretPodDropdown<String>(
            key: fieldKey,
            initialValue: value,
            decoration: const InputDecoration(labelText: 'Access'),
            items: const [
              DropdownMenuItem(value: 'reader', child: Text('Reader')),
              DropdownMenuItem(value: 'editor', child: Text('Editor')),
              DropdownMenuItem(
                value: 'disabled',
                enabled: false,
                child: Text('Unavailable'),
              ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );

  testWidgets('anchored options select once, mark current value and close', (
    tester,
  ) async {
    final changes = <String?>[];
    await tester.pumpWidget(sample(onChanged: changes.add));
    await tester.tap(find.byType(SecretPodDropdown<String>));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNWidgets(3));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    final trigger = find.byKey(const ValueKey('dropdown-trigger'));
    expect(
      tester.getTopLeft(find.byType(MenuItemButton).first).dy,
      greaterThan(tester.getBottomLeft(trigger).dy),
    );
    expect(
      tester.getSize(find.byType(MenuItemButton).first).width,
      closeTo(tester.getSize(trigger).width - 8, 1),
    );
    await tester.tap(find.widgetWithText(MenuItemButton, 'Editor'));
    await tester.pumpAndSettle();
    expect(changes, ['editor']);
    expect(find.byType(MenuItemButton), findsNothing);
    expect(find.text('Editor'), findsOneWidget);
  });

  testWidgets(
    'keyboard selection, escape and outside click dismiss correctly',
    (tester) async {
      final changes = <String?>[];
      await tester.pumpWidget(sample(onChanged: changes.add));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNWidgets(3));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(changes, ['editor']);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      await tester.tap(find.byKey(const ValueKey('dropdown-trigger')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(changes, ['editor']);
    },
  );

  testWidgets(
    'external values and disabled state are respected while menu is open',
    (tester) async {
      final changes = <String?>[];
      await tester.pumpWidget(sample(onChanged: changes.add));
      await tester.tap(find.byType(SecretPodDropdown<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Unavailable'));
      expect(changes, isEmpty);
      await tester.pumpWidget(sample(value: 'editor'));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(find.text('Editor'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('dropdown-trigger')));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('removing either anchor disposes its open menu', (tester) async {
    final samples = [
      sample(onChanged: (_) {}),
      MaterialApp(
        home: Scaffold(
          body: SecretPodMenu(
            children: [
              SecretPodMenuItem(onPressed: () {}, child: const Text('Action')),
            ],
            builder: (context, toggle, focus) => TextButton(
              focusNode: focus,
              onPressed: toggle,
              child: const Text('Account'),
            ),
          ),
        ),
      ),
    ];
    for (final widget in samples) {
      await tester.pumpWidget(widget);
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsWidgets);
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
