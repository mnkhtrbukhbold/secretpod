import 'package:web/web.dart' as web;
import 'page_size_store.dart';

PageSizeStore createPageSizeStore(String serverUrl) =>
    _BrowserPageSizeStore(serverUrl);

class _BrowserPageSizeStore implements PageSizeStore {
  _BrowserPageSizeStore(this.serverUrl);
  final String serverUrl;
  String _key(String accountId, String list) =>
      'secretpod.pageSize:${Uri.encodeComponent(serverUrl)}:${Uri.encodeComponent(accountId)}:$list';
  @override
  int? read(String accountId, String list) => int.tryParse(
    web.window.localStorage.getItem(_key(accountId, list)) ?? '',
  );
  @override
  void write(String accountId, String list, int size) =>
      web.window.localStorage.setItem(_key(accountId, list), '$size');
}
