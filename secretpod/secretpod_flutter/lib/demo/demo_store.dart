import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'demo_seed.dart';

export 'demo_store_stub.dart'
    if (dart.library.js_interop) 'demo_store_web.dart'
    show createDemoStore;

abstract interface class DemoStore {
  Future<T> access<T>(
    T Function(Map<String, dynamic>) operation, {
    bool write = false,
  });
  Future<void> reset();
  Stream<void> get changes;
  void dispose();
}

/// Backing storage owns serialization between tabs; JSON commits are atomic.
abstract interface class DemoBacking {
  String? read();
  void write(String value);
  Future<T> exclusive<T>(T Function() operation);
  Stream<void> get changes;
  void dispose();
}

class JsonDemoStore implements DemoStore {
  JsonDemoStore(this.backing, {Map<String, dynamic> Function()? seed})
    : _seed = seed ?? createDemoSeed;
  final DemoBacking backing;
  final Map<String, dynamic> Function() _seed;

  Map<String, dynamic> _decode(String raw) {
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value['schemaVersion'] != 1 ||
        value['revision'] is! int ||
        value['epoch'] is! String ||
        value['accountId'] is! String ||
        value['projects'] is! Map ||
        [
          'accounts',
          'organizations',
          'members',
          'secrets',
          'invitations',
          'activity',
        ].any(
          (key) =>
              value[key] is! List || (value[key] as List).any((e) => e is! Map),
        )) {
      throw const FormatException(
        'Saved demo data cannot be loaded. Reset the demo to start again.',
      );
    }
    return value;
  }

  @override
  Future<T> access<T>(
    T Function(Map<String, dynamic>) operation, {
    bool write = false,
  }) => backing.exclusive(() {
    final raw = backing.read();
    // Decoding every operation gives callers isolated snapshots and reads
    // the latest cross-tab commit rather than a stale in-memory cache.
    final state = _decode(raw ?? jsonEncode(_seed()));
    final result = operation(state);
    if (write || raw == null) {
      if (write) state['revision'] = (state['revision'] as int) + 1;
      backing.write(jsonEncode(state));
    }
    return result;
  });

  @override
  Future<void> reset() => backing.exclusive(() {
    final state = _seed();
    // A bit shift by 32 becomes zero in Dart's JavaScript runtime.
    state['epoch'] =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x100000000)}';
    backing.write(jsonEncode(state));
  });
  @override
  Stream<void> get changes => backing.changes;
  @override
  void dispose() => backing.dispose();
}

class MemoryDemoBacking implements DemoBacking {
  String? value;
  bool failWrites = false;
  Future<void> _tail = Future<void>.value();
  @override
  String? read() => value;
  @override
  void write(String next) {
    if (failWrites) throw StateError('Demo changes could not be saved.');
    value = next;
  }

  @override
  Future<T> exclusive<T>(T Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Stream<void> get changes => const Stream.empty();
  @override
  void dispose() {}
}

class MemoryDemoStore extends JsonDemoStore {
  MemoryDemoStore({super.seed}) : super(MemoryDemoBacking());
}
