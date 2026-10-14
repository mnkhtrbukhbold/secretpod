import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'session_store.dart';

SessionStore createSessionStore(String serverUrl) =>
    _BrowserSessionStore(serverUrl);

class _BrowserSessionStore implements SessionStore {
  _BrowserSessionStore(String serverUrl)
    : _key = 'secretpod.session:$serverUrl';
  final String _key;
  late final JSFunction _listener = ((web.Event event) {
    final change = event as web.StorageEvent;
    if (change.storageArea == web.window.localStorage &&
        (change.key == _key || change.key == null)) {
      _changes.add(null);
    }
  }).toJS;
  late final _changes = StreamController<void>.broadcast(
    onListen: () => web.window.addEventListener('storage', _listener),
    onCancel: () => web.window.removeEventListener('storage', _listener),
  );
  @override
  Stream<void> get changes => _changes.stream;

  void _discardLegacyTabToken() {
    // Never import a stale tab-only token after another tab has signed out.
    try {
      web.window.sessionStorage.removeItem(_key);
    } catch (_) {}
  }

  @override
  String? read() {
    _discardLegacyTabToken();
    return web.window.localStorage.getItem(_key);
  }

  @override
  void write(String? token) {
    if (token == null) {
      web.window.localStorage.removeItem(_key);
    } else {
      web.window.localStorage.setItem(_key, token);
    }
    _discardLegacyTabToken();
  }
}
