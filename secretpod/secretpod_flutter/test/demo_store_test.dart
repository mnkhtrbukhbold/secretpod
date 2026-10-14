import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:secretpod_flutter/demo/demo_store.dart';

Map<String, dynamic> fixture() => {
  'schemaVersion': 1,
  'revision': 0,
  'epoch': 'initial',
  'accountId': 'owner',
  'accounts': <dynamic>[],
  'organizations': <dynamic>[],
  'members': <dynamic>[],
  'secrets': <dynamic>[],
  'invitations': <dynamic>[],
  'activity': <dynamic>[],
  'projects': <String, dynamic>{},
};

void main() {
  test(
    'serialized data survives new store; other browser is isolated',
    () async {
      final backing = MemoryDemoBacking();
      final first = JsonDemoStore(backing, seed: fixture);
      await first.access((s) => s['accountId'] = 'edited', write: true);
      final reopened = JsonDemoStore(backing, seed: fixture);
      expect(await reopened.access((s) => s['accountId']), 'edited');
      expect(
        await MemoryDemoStore(seed: fixture).access((s) => s['accountId']),
        'owner',
      );
    },
  );
  test(
    'failed mutation and storage write both preserve committed state',
    () async {
      final backing = MemoryDemoBacking();
      final store = JsonDemoStore(backing, seed: fixture);
      await store.access((s) => s['accountId']);
      await expectLater(
        store.access((s) {
          s['accountId'] = 'lost';
          throw StateError('invalid operation');
        }, write: true),
        throwsStateError,
      );
      backing.failWrites = true;
      await expectLater(
        store.access((s) => s['accountId'] = 'lost', write: true),
        throwsStateError,
      );
      backing.failWrites = false;
      expect(await store.access((s) => s['accountId']), 'owner');
    },
  );
  test(
    'reset recreates seed with a distinct epoch and removes edits',
    () async {
      final store = MemoryDemoStore(seed: fixture);
      final epoch = await store.access((s) => s['epoch']);
      await store.access((s) => s['secrets'].add({'id': 'new'}), write: true);
      await store.reset();
      expect(await store.access((s) => s['secrets']), isEmpty);
      expect(await store.access((s) => s['epoch']), isNot(epoch));
    },
  );
  test(
    'two stores serialize concurrent increments without lost updates',
    () async {
      final backing = MemoryDemoBacking();
      final a = JsonDemoStore(backing, seed: fixture);
      final b = JsonDemoStore(backing, seed: fixture);
      await Future.wait(
        List.generate(
          40,
          (i) => (i.isEven ? a : b).access(
            (s) => s['count'] = (s['count'] as int? ?? 0) + 1,
            write: true,
          ),
        ),
      );
      expect(await a.access((s) => s['count']), 40);
    },
  );
  test(
    'corrupt or unsupported data is retained until explicit reset',
    () async {
      for (final raw in [
        '{broken',
        jsonEncode({'schemaVersion': 2}),
      ]) {
        final backing = MemoryDemoBacking()..value = raw;
        final store = JsonDemoStore(backing, seed: fixture);
        await expectLater(store.access((s) => s), throwsFormatException);
        expect(backing.value, raw);
        await store.reset();
        expect(await store.access((s) => s['schemaVersion']), 1);
      }
    },
  );
}
