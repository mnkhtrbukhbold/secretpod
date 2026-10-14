import 'page_size_store.dart';

PageSizeStore createPageSizeStore(String serverUrl) => MemoryPageSizeStore();

class MemoryPageSizeStore implements PageSizeStore {
  final _sizes = <(String, String), int>{};
  @override
  int? read(String accountId, String list) => _sizes[(accountId, list)];
  @override
  void write(String accountId, String list, int size) {
    _sizes[(accountId, list)] = size;
  }
}
