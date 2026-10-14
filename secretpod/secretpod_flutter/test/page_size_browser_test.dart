@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:secretpod_flutter/state/page_size_store.dart';
import 'package:secretpod_flutter/state/pagination.dart';

void main() {
  test(
    'browser storage survives recreation and isolates servers and accounts',
    () {
      final server =
          'http://preferences-test-${DateTime.now().microsecondsSinceEpoch}/';
      final original = createPageSizeStore(server);
      for (var index = 0; index < PaginationSettings.lists.length; index++) {
        original.write(
          'synthetic-account',
          PaginationSettings.lists[index],
          PaginationSettings.pageSizes[index % 4],
        );
      }
      final reloaded = createPageSizeStore(server);
      for (var index = 0; index < PaginationSettings.lists.length; index++) {
        final list = PaginationSettings.lists[index];
        expect(
          reloaded.read('synthetic-account', list),
          PaginationSettings.pageSizes[index % 4],
        );
        expect(reloaded.read('another-account', list), isNull);
        expect(
          createPageSizeStore('$server/other').read('synthetic-account', list),
          isNull,
        );
      }
    },
  );
}
