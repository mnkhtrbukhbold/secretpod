import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/screens/invitation_dialogs.dart';
import 'package:secretpod_flutter/screens/secret_dialogs.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';
import 'package:secretpod_flutter/widgets/common.dart';
import 'package:secretpod_flutter/widgets/dropdown_field.dart';

void main() {
  late VaultController controller;
  var saves = 0;
  Map<String, dynamic>? saved;
  Completer<http.Response>? pendingSave;
  final secret = SecretView(
    id: 's',
    organizationId: 'o',
    name: 'Service login',
    project: 'Default',
    environment: 'Production',
    kind: 'Username and password',
    description: 'A sample description. ' * 30,
    version: 1,
    createdAt: DateTime.utc(2026, 10, 14),
    updatedAt: DateTime.utc(2026, 10, 14),
  );
  setUp(() {
    saves = 0;
    saved = null;
    pendingSave = null;
    controller =
        VaultController(
            'http://localhost/',
            api: Client(
              'http://localhost/',
              httpClientOverride: MockClient((request) async {
                final method = request.url.path.split('/').last;
                if (method == 'secretActivity') return http.Response('[]', 200);
                if (method == 'create' || method == 'deleteSecret') {
                  return http.Response('Unavailable', 503);
                }
                if (method == 'saveSecret') {
                  saves++;
                  saved = jsonDecode(request.body) as Map<String, dynamic>;
                  return pendingSave?.future ??
                      http.Response(jsonEncode(secret.toJson()), 200);
                }
                throw StateError('Unexpected request: $method');
              }),
            ),
          )
          ..organization = OrganizationView(
            id: 'o',
            name: 'Team',
            role: 'owner',
            createdAt: DateTime.utc(2026),
          );
  });
  tearDown(() => controller.dispose());

  Future<void> open(
    WidgetTester tester,
    Widget dialog, {
    double scale = 1,
    Size viewport = const Size(390, 600),
    double keyboardInset = 0,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => dialog,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('project selection protects changes and saves the selection', (
    tester,
  ) async {
    controller.secrets = [secret.copyWith(project: 'Payments')];
    await open(tester, SecretEditor(controller: controller, secret: secret));
    final project = find.widgetWithText(SecretPodDropdown<String>, 'Project');
    expect(find.widgetWithText(TextFormField, 'Project'), findsNothing);
    await tapVisible(
      tester,
      find.descendant(of: project, matching: find.text('Default')),
    );
    await tapVisible(tester, find.text('Payments'));
    await tapVisible(tester, find.text('Cancel'));
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save secret'));
    expect(saved?['project'], 'Payments');
  });

  testWidgets(
    'project menu preserves existing value and Escape closes menu first',
    (tester) async {
      await open(
        tester,
        SecretEditor(
          controller: controller,
          secret: secret.copyWith(project: 'Legacy'),
        ),
      );
      await tapVisible(tester, find.text('Legacy'));
      expect(find.text('Default'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(SecretEditor), findsOneWidget);
      await tapVisible(tester, find.text('Cancel'));
      expect(find.byType(SecretEditor), findsNothing);
      expect(find.text('Discard changes?'), findsNothing);
    },
  );

  testWidgets('new secrets select Default without entering a project', (
    tester,
  ) async {
    await open(tester, SecretEditor(controller: controller));
    expect(
      find.widgetWithText(SecretPodDropdown<String>, 'Default'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Secret name'),
      'API_TOKEN',
    );
    await tapVisible(tester, find.byKey(const ValueKey('secret-value')));
    await tester.enterText(
      find.byKey(const ValueKey('secret-value')),
      'test-value',
    );
    await tapVisible(tester, find.text('Save secret'));
    expect(saved?['project'], 'Default');
  });

  testWidgets('new project validates a name and selects it for saving', (
    tester,
  ) async {
    await open(tester, SecretEditor(controller: controller, secret: secret));
    await tapVisible(tester, find.text('New project'));
    await tester.tap(find.text('Add project'));
    await tester.pumpAndSettle();
    expect(find.text('This field is required.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Project name'),
      '  Website  ',
    );
    await tester.tap(find.text('Add project'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(SecretPodDropdown<String>, 'Website'),
      findsOneWidget,
    );
    await tapVisible(tester, find.text('Save secret'));
    expect(saved?['project'], 'Website');
  });

  testWidgets(
    'project choices deduplicate names and a reverted selection closes cleanly',
    (tester) async {
      controller.secrets = [
        secret.copyWith(project: 'Payments'),
        secret.copyWith(project: 'payments'),
        secret.copyWith(project: 'default'),
      ];
      await open(tester, SecretEditor(controller: controller, secret: secret));
      await tapVisible(tester, find.text('Default'));
      expect(find.widgetWithText(MenuItemButton, 'Default'), findsOneWidget);
      expect(find.widgetWithText(MenuItemButton, 'Payments'), findsOneWidget);
      expect(find.widgetWithText(MenuItemButton, 'payments'), findsNothing);
      expect(find.widgetWithText(MenuItemButton, 'default'), findsNothing);
      await tapVisible(tester, find.text('Payments'));
      await tapVisible(tester, find.text('Payments'));
      await tapVisible(tester, find.text('Default'));
      await tapVisible(tester, find.text('Cancel'));
      expect(find.byType(SecretEditor), findsNothing);
      expect(find.text('Discard changes?'), findsNothing);
    },
  );

  testWidgets('cancelling a new project keeps the editor unchanged', (
    tester,
  ) async {
    await open(tester, SecretEditor(controller: controller));
    await tapVisible(tester, find.text('New project'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Project name'),
      'Unused',
    );
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(SecretPodDropdown<String>, 'Default'),
      findsOneWidget,
    );
    await tapVisible(tester, find.text('Cancel'));
    expect(find.byType(SecretEditor), findsNothing);
    expect(find.text('Discard changes?'), findsNothing);
  });

  testWidgets('reverting a legacy project preserves its original spelling', (
    tester,
  ) async {
    controller.secrets = [secret.copyWith(project: 'Payments')];
    await open(
      tester,
      SecretEditor(
        controller: controller,
        secret: secret.copyWith(project: 'default'),
      ),
    );
    await tapVisible(tester, find.text('default'));
    await tapVisible(tester, find.text('Payments'));
    await tapVisible(tester, find.text('Payments'));
    expect(find.widgetWithText(MenuItemButton, 'default'), findsOneWidget);
    await tapVisible(tester, find.text('default'));
    await tapVisible(tester, find.text('Cancel'));
    expect(find.byType(SecretEditor), findsNothing);
    expect(find.text('Discard changes?'), findsNothing);
  });

  for (final kind in ['editor', 'details', 'invitation']) {
    testWidgets(
      '$kind header stays visible while its body scrolls at 2x text',
      (tester) async {
        final (dialog, title) = switch (kind) {
          'editor' => (SecretEditor(controller: controller), 'Add a secret'),
          'details' => (
            SecretDetails(controller: controller, secret: secret),
            secret.name,
          ),
          _ => (
            InviteMemberDialog(controller: controller, organizationId: 'o'),
            'Invite a teammate',
          ),
        };
        await open(tester, dialog, scale: 2);
        final titleBefore = tester.getRect(find.text(title));
        final closeBefore = tester.getRect(find.byTooltip('Close'));
        final scroll = find.byType(SingleChildScrollView).first;
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(of: scroll, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        final offsetBefore = position.pixels;
        await tester.drag(scroll, const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(position.pixels, greaterThan(offsetBefore));
        expect(tester.getRect(find.text(title)), titleBefore);
        expect(tester.getRect(find.byTooltip('Close')), closeBefore);
        expect(find.byTooltip('Close').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (viewport, inset) in [
    (const Size(844, 390), 220.0),
    (const Size(390, 600), 300.0),
  ]) {
    testWidgets(
      'header and content fit with keyboard in $viewport at 2x text',
      (tester) async {
        await open(
          tester,
          SecretEditor(controller: controller),
          scale: 2,
          viewport: viewport,
          keyboardInset: inset,
        );
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Close').hitTestable(), findsOneWidget);
        expect(find.text('Save secret').hitTestable(), findsOneWidget);
        expect(find.text('Cancel').hitTestable(), findsOneWidget);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('dialog-body-scroll')))
              .height,
          greaterThanOrEqualTo(40),
        );
        await tapVisible(tester, find.text('Cancel'));
        expect(find.byType(SecretEditor), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.0, 2.0]) {
    for (final kind in ['editor', 'details', 'invitation']) {
      testWidgets(
        '$kind actions stay visible while the body scrolls at ${scale}x text',
        (tester) async {
          final (dialog, labels) = switch (kind) {
            'editor' => (
              SecretEditor(controller: controller),
              ['Cancel', 'Save secret'],
            ),
            'details' => (
              SecretDetails(controller: controller, secret: secret),
              ['Edit secret', 'Delete'],
            ),
            _ => (
              InviteMemberDialog(controller: controller, organizationId: 'o'),
              ['Create invitation', 'Cancel'],
            ),
          };
          await open(tester, dialog, scale: scale);
          final before = [
            for (final label in labels) tester.getRect(find.text(label)),
          ];
          for (final label in labels) {
            expect(find.text(label).hitTestable(), findsOneWidget);
          }
          final scroll = find.byKey(const ValueKey('dialog-body-scroll'));
          await tester.drag(scroll, const Offset(0, -450));
          await tester.pumpAndSettle();
          for (var i = 0; i < labels.length; i++) {
            expect(tester.getRect(find.text(labels[i])), before[i]);
            expect(find.text(labels[i]).hitTestable(), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'the full secret name can be selected and copied from its fixed header',
    (tester) async {
      const name = 'PAYMENTS_PRODUCTION_SERVICE_AUTHENTICATION_API_KEY';
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            if (call.method == 'Clipboard.hasStrings') return {'value': false};
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await open(
        tester,
        SecretDetails(
          controller: controller,
          secret: secret.copyWith(name: name),
        ),
      );
      await tester.longPress(find.text(name));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(copied, name);
    },
  );

  testWidgets('fixed Save reveals the first invalid field', (tester) async {
    await open(tester, SecretEditor(controller: controller));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Secret name'),
      'Service key',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save secret'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a secret value.').hitTestable(), findsOneWidget);
    expect(find.text('Save secret').hitTestable(), findsOneWidget);
    expect(saves, 0);
  });

  for (final kind in ['invitation', 'details']) {
    testWidgets(
      '$kind operation errors are revealed after using fixed actions',
      (tester) async {
        await open(
          tester,
          kind == 'invitation'
              ? InviteMemberDialog(controller: controller, organizationId: 'o')
              : SecretDetails(controller: controller, secret: secret),
        );
        if (kind == 'invitation') {
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Recipient name'),
            'Alex',
          );
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Email address'),
            'alex@example.test',
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Create invitation'));
        } else {
          await tester.tap(find.text('Delete'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete secret'));
        }
        await tester.pumpAndSettle();
        expect(find.byType(ErrorNotice).hitTestable(), findsOneWidget);
        await tester.drag(
          find.byKey(const ValueKey('dialog-body-scroll')),
          const Offset(0, 1500),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ErrorNotice).hitTestable(), findsNothing);
        if (kind == 'invitation') {
          await tester.tap(find.text('Create invitation'));
        } else {
          await tester.tap(find.text('Delete'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete secret'));
        }
        await tester.pumpAndSettle();
        expect(find.byType(ErrorNotice).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'close confirms discarding changes and keep editing preserves input',
    (tester) async {
      await open(tester, SecretEditor(controller: controller));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Secret name'),
        'Unsaved name',
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved name'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.byType(SecretEditor), findsNothing);
      expect(saves, 0);
    },
  );

  for (final exit in ['Cancel', 'Escape', 'Back']) {
    testWidgets('$exit asks before discarding and dismissal keeps the draft', (
      tester,
    ) async {
      await open(tester, SecretEditor(controller: controller));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Secret name'),
        'Unsaved name',
      );
      if (exit == 'Cancel') {
        await tapVisible(tester, find.text('Cancel'));
      } else if (exit == 'Escape') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SecretEditor), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Unsaved name'), findsOneWidget);
      expect(saves, 0);
    });
  }

  testWidgets('untouched and fully reverted forms close without confirmation', (
    tester,
  ) async {
    await open(tester, SecretEditor(controller: controller));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(SecretEditor), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final name = find.widgetWithText(TextFormField, 'Secret name');
    await tester.enterText(name, 'Temporary');
    await tester.enterText(name, '');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SecretEditor), findsNothing);
    expect(find.text('Discard changes?'), findsNothing);
  });

  testWidgets(
    'dropdown Escape closes only the menu and metadata changes are protected',
    (tester) async {
      await open(tester, SecretEditor(controller: controller));
      final environment = find.descendant(
        of: find.widgetWithText(SecretPodDropdown<String>, 'Environment'),
        matching: find.byKey(const ValueKey('dropdown-trigger')),
      );
      await tapVisible(tester, environment);
      await tester.tap(find.widgetWithText(MenuItemButton, 'Production'));
      await tester.pumpAndSettle();
      await tapVisible(tester, environment);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(find.text('Discard changes?'), findsNothing);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(SecretEditor), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Production'), findsOneWidget);
    },
  );

  testWidgets(
    'expiry alone is protected and outside clicks do not close the editor',
    (tester) async {
      await open(tester, SecretEditor(controller: controller));
      await tapVisible(tester, find.text('Set expiry date'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(SecretEditor), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(SecretEditor), findsOneWidget);
    },
  );

  testWidgets(
    'failed saves leave the draft protected and available for retry',
    (tester) async {
      await open(tester, SecretEditor(controller: controller, secret: secret));
      await tester.enterText(
        find.byKey(const ValueKey('secret-username')),
        'new-username',
      );
      pendingSave = Completer<http.Response>();
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('dialog-body-scroll')),
        const Offset(0, 1500),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Save secret'));
      pendingSave!.complete(http.Response('Unavailable', 503));
      await tester.pumpAndSettle();
      expect(find.byType(SecretEditor), findsOneWidget);
      expect(find.byType(ErrorNotice).hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('secret-username')),
            )
            .controller!
            .text,
        'new-username',
      );
      pendingSave = null;
      await tapVisible(tester, find.text('Save secret'));
      expect(find.byType(SecretEditor), findsNothing);
      expect(saves, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'credential edits protect whitespace and block closing during save',
    (tester) async {
      await open(tester, SecretEditor(controller: controller, secret: secret));
      await tester.enterText(
        find.byKey(const ValueKey('secret-value')),
        '  changed  ',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('secret-value')))
            .controller!
            .text,
        '  changed  ',
      );
      pendingSave = Completer<http.Response>();
      await tapVisible(tester, find.text('Save secret'));
      await tester.binding.handlePopRoute();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(SecretEditor), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
      pendingSave!.complete(http.Response(jsonEncode(secret.toJson()), 200));
      await tester.pumpAndSettle();
      expect(find.byType(SecretEditor), findsNothing);
      expect(saves, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
