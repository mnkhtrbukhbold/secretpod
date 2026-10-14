import 'list_state_store.dart';

ListStateStore createListStateStore(String serverUrl) => MemoryListStateStore();

class MemoryListStateStore implements ListStateStore {
  final _values = <(String, String), String>{};
  @override
  String? read(String accountId, String key) => _values[(accountId, key)];
  @override
  void write(String accountId, String key, String value) {
    _values[(accountId, key)] = value;
  }
}
