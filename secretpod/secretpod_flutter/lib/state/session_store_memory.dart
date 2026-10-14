import 'session_store.dart';

SessionStore createSessionStore(String serverUrl) => _MemorySessionStore();

class _MemorySessionStore implements SessionStore {
  String? _token;
  @override
  Stream<void> get changes => const Stream<void>.empty();
  @override
  String? read() => _token;
  @override
  void write(String? token) => _token = token;
}
