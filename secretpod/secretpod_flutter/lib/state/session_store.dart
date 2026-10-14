export 'session_store_memory.dart'
    if (dart.library.js_interop) 'session_store_web.dart'
    show createSessionStore;

/// Stores only the opaque session token. Account and vault data stay in memory.
abstract interface class SessionStore {
  /// Changes committed by another tab; consumers re-read the latest value.
  Stream<void> get changes;
  String? read();
  void write(String? token);
}
