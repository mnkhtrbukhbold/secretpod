import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretpod_flutter/demo/demo_app.dart';
import 'package:secretpod_flutter/demo/demo_store.dart';

void main() {
  testWidgets(
    'expired sample invitation offers reset instead of a stale link',
    (
      tester,
    ) async {
      final store = MemoryDemoStore();
      await store.access((state) {
        final invite = (state['invitations'] as List).firstWhere(
          (i) => i['id'] == 'demo-invite-009',
        );
        invite['expiresAt'] = DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 1))
            .toIso8601String();
      }, write: true);
      await tester.pumpWidget(DemoApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sample invitation'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No pending sample invitations'),
        findsOneWidget,
      );
      expect(find.text('Copy invitation link'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('corrupt browser data offers reset rather than server advice', (
    tester,
  ) async {
    final backing = MemoryDemoBacking()..value = '{broken';
    await tester.pumpWidget(DemoApp(store: JsonDemoStore(backing)));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Saved demo data cannot be loaded'),
      findsOneWidget,
    );
    expect(find.textContaining('server connection'), findsNothing);
    expect(find.text('Reset demo'), findsOneWidget);
    expect(backing.value, '{broken');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('opens seeded workspace without login; confirms reset', (
    tester,
  ) async {
    final store = MemoryDemoStore();
    await store.access(
      (s) => (s['organizations'] as List).first['name'] = 'Edited organization',
      write: true,
    );
    await tester.pumpWidget(DemoApp(store: store));
    await tester.pumpAndSettle();
    expect(find.textContaining('Changes stay in this browser'), findsOneWidget);
    expect(
      find.text('Edited organization'),
      findsWidgets,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .join(' | '),
    );
    expect(find.text('Sign in'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Sample invitation'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Use this link in My invitations'),
      findsOneWidget,
    );
    expect(find.byType(SelectableText), findsWidgets);
    expect(
      find.text('Copy invitation link'),
      findsOneWidget,
      reason: tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((text) => text.data)
          .join(' | '),
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset demo'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm reset'), findsOneWidget);
    expect(
      await store.access((s) => s['organizations'][0]['name']),
      'Edited organization',
    );
    await tester.tap(find.text('Confirm reset'));
    await tester.pumpAndSettle();
    expect(find.text('Edited organization'), findsNothing);
    expect(
      await store.access((s) => s['organizations'][0]['name']),
      isNot('Edited organization'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
