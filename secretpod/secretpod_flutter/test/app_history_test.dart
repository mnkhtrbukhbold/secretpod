import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretpod_flutter/state/app_history.dart';

void main() {
  for (final dismissing in [false, true]) {
    testWidgets(
      'session reset invalidates a pending ${dismissing ? 'dismissal' : 'guarded traversal'}',
      (
        tester,
      ) async {
        final reports = <Map<dynamic, dynamic>>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.navigation,
          (call) async {
            if (call.method == 'routeInformationUpdated') {
              reports.add(call.arguments as Map);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.navigation,
            null,
          ),
        );
        var depth = 0;
        var pops = 0;
        final traversals = <int>[];
        final history = AppHistory(
          overlayDepth: () => depth,
          popOverlay: () async {
            pops++;
            return true;
          },
          traverse: (delta) {
            traversals.add(delta);
            return true;
          },
        );
        history.addListener(() {});
        addTearDown(history.dispose);
        void report(String uri, int session) {
          history.routerReportsNewRouteInformation(
            RouteInformation(
              uri: Uri.parse(uri),
              state: {
                'workspacePage': 0,
                'overlayDepth': depth,
                'session': session,
              },
            ),
          );
        }

        report('/activity', 0);
        await tester.pump();
        final base = reports.last;
        depth = 1;
        report('/activity', 0);
        await tester.pump();
        final modal = reports.last;
        if (dismissing) {
          depth = 0;
          report('/activity', 0);
          expect(traversals, [-1]);
        } else {
          await history.didPushRouteInformation(
            RouteInformation(
              uri: Uri.parse(base['uri'] as String),
              state: base['state'],
            ),
          );
          expect(traversals, [1]);
        }
        depth = 0;
        report('/secrets', 1);
        await tester.pump();
        expect(reports.last['uri'], '/secrets');
        final completion = dismissing ? base : modal;
        await history.didPushRouteInformation(
          RouteInformation(
            uri: Uri.parse(completion['uri'] as String),
            state: completion['state'],
          ),
        );
        await tester.pump();
        expect(pops, 0);
        expect(history.value.uri.path, '/secrets');
      },
    );
  }
}
