// Standalone synthetic fixture for browser_navigation_smoke.mjs.
// Build with flutter build web --target test/browser_navigation_fixture.dart
// --output <absolute-fixture-output-directory> --no-web-resources-cdn.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/main.dart';
import 'package:secretpod_flutter/screens/secret_dialogs.dart';
import 'package:secretpod_flutter/screens/workspace_screen.dart';
import 'package:secretpod_flutter/state/session_store_memory.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';
import 'package:web/web.dart' as web;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller =
      VaultController(
          'http://127.0.0.1:1/',
          sessionStore: createSessionStore('fixture'),
        )
        ..account = AccountView(
          id: 'fixture',
          name: 'Fixture',
          email: 'fixture@example.test',
        )
        ..organization = OrganizationView(
          id: 'fixture',
          name: 'Fixture',
          role: 'owner',
          createdAt: DateTime(2026),
        );
  controller.organizations = [controller.organization!];

  List<Element> elements() {
    final result = <Element>[];
    void visit(Element element) {
      result.add(element);
      element.visitChildren(visit);
    }

    final root = WidgetsBinding.instance.rootElement;
    if (root != null) visit(root);
    return result;
  }

  web.window.setProperty(
    'navigationFixture'.toJS,
    ((String action) {
      final all = elements();
      if (action == 'state') {
        final workspace = all
            .map((e) => e.widget)
            .whereType<WorkspaceScreen>()
            .firstOrNull;
        return jsonEncode({
          'page': workspace?.page,
          'editor': all.any((e) => e.widget is SecretEditor),
          'confirmation': all.any(
            (e) =>
                e.widget is Text &&
                (e.widget as Text).data == 'Discard changes?',
          ),
          'draft': all
              .map((e) => e.widget)
              .whereType<TextField>()
              .where((w) => w.decoration?.labelText == 'Secret name')
              .firstOrNull
              ?.controller
              ?.text,
        });
      }
      if (action == 'edit') {
        final workspace = all.firstWhere((e) => e.widget is WorkspaceScreen);
        showDialog<void>(
          context: workspace,
          barrierDismissible: false,
          builder: (_) => SecretEditor(controller: controller),
        );
      } else if (action == 'draft') {
        all
                .map((e) => e.widget)
                .whereType<TextField>()
                .firstWhere((w) => w.decoration?.labelText == 'Secret name')
                .controller!
                .text =
            'Unsaved fixture';
      } else if (action == 'close') {
        all
            .map((e) => e.widget)
            .whereType<IconButton>()
            .lastWhere((w) => w.tooltip == 'Close')
            .onPressed!();
      } else if (action == 'Keep editing' || action == 'Discard changes') {
        all
            .map((e) => e.widget)
            .whereType<ButtonStyleButton>()
            .lastWhere(
              (w) => w.child is Text && (w.child as Text).data == action,
            )
            .onPressed!();
      } else {
        final workspace = all
            .map((e) => e.widget)
            .whereType<WorkspaceScreen>()
            .first;
        workspace.onNavigate(int.parse(action));
      }
      return '{}';
    }).toJS,
  );
  runApp(MyApp(controller: controller));
}
