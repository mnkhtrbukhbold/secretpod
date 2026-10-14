import 'package:flutter_test/flutter_test.dart';
import 'package:secretpod_flutter/state/list_state_store_memory.dart';
import 'paging_controller_test.dart' show PagingFixture;

void main() {
  test(
    'activity filters and page restore before requests after app reload',
    () async {
      final store = MemoryListStateStore();
      final first = PagingFixture(listStateStore: store);
      final from = DateTime.utc(2026, 1, 1);
      final until = DateTime.utc(2026, 2, 1);
      await first.controller.refresh();
      await first.controller.filterActivity(
        from: from,
        until: until,
        project: 'Default',
        action: 'created',
        user: 'id:a',
      );
      await first.controller.changePage(1, 2);
      first.controller.dispose();
      final second = PagingFixture(listStateStore: store);
      addTearDown(second.controller.dispose);
      await second.controller.refresh();
      expect(second.controller.pages[1], 2);
      expect(second.controller.activityFrom, from);
      expect(second.controller.activityUntil, until);
      expect(second.controller.activityProject, 'Default');
      expect(second.controller.activityAction, 'created');
      expect(second.controller.activityUser, 'id:a');
      final request = second.requests.firstWhere(
        (r) => r['method'] == 'activity',
      );
      expect(request['offset'], 20);
      expect(request['from'], from.toIso8601String());
      expect(request['until'], until.toIso8601String());
      expect(request['project'], 'Default');
      expect(request['action'], 'created');
      expect(request['user'], 'id:a');
      await second.controller.filterActivity();
      final third = PagingFixture(listStateStore: store);
      addTearDown(third.controller.dispose);
      await third.controller.refresh();
      expect(third.controller.pages[1], 0);
      expect(third.controller.hasActivityFilters, isFalse);
    },
  );
}
