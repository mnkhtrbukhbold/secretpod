import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'demo_store.dart';

DemoStore createDemoStore() => JsonDemoStore(_BrowserDemoBacking());

class _BrowserDemoBacking implements DemoBacking {
  static const key = 'secretpod.demo.database.v1';
  final _changes = StreamController<void>.broadcast();
  late final JSFunction _listener = ((web.Event event) {
    final change = event as web.StorageEvent;
    if (change.storageArea == web.window.localStorage &&
        (change.key == key || change.key == null)) {
      _changes.add(null);
    }
  }).toJS;
  _BrowserDemoBacking() {
    web.window.addEventListener('storage', _listener);
  }
  @override
  String? read() {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      throw StateError(
        'This browser could not read demo storage. Allow site storage and try again.',
      );
    }
  }

  @override
  void write(String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {
      throw StateError(
        'This browser could not save the demo. Allow site storage or reset the demo to free space.',
      );
    }
  }

  @override
  Future<T> exclusive<T>(T Function() operation) async {
    late T result;
    Object? failure;
    StackTrace? failureStack;
    try {
      await web.window.navigator.locks
          .request(
            key,
            ((web.Lock? _) {
              try {
                result = operation();
              } catch (error, stack) {
                failure = error;
                failureStack = stack;
              }
              return null;
            }).toJS,
          )
          .toDart;
    } catch (_) {
      throw StateError(
        'The demo needs browser storage and Web Locks. Use a current browser over HTTPS or localhost.',
      );
    }
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
    return result;
  }

  @override
  Stream<void> get changes => _changes.stream;
  @override
  void dispose() {
    web.window.removeEventListener('storage', _listener);
    _changes.close();
  }
}
