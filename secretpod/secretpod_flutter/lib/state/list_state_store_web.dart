import 'package:web/web.dart' as web;
import 'list_state_store.dart';

ListStateStore createListStateStore(String serverUrl) =>
    _BrowserListStateStore(serverUrl);

class _BrowserListStateStore implements ListStateStore {
  _BrowserListStateStore(this.serverUrl);
  final String serverUrl;
  String _key(String accountId, String key) =>
      'secretpod.listState:${Uri.encodeComponent(serverUrl)}:${Uri.encodeComponent(accountId)}:$key';
  @override
  String? read(String accountId, String key) =>
      web.window.localStorage.getItem(_key(accountId, key));
  @override
  void write(String accountId, String key, String value) =>
      web.window.localStorage.setItem(_key(accountId, key), value);
}
