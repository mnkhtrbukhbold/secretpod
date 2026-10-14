import 'dart:async';
import 'dart:convert';
import 'package:secretpod_server/src/crypto/crypto_service.dart';
import 'package:secretpod_server/src/storage/sqlite_schema.dart';
import 'package:secretpod_server/src/storage/vault_store.dart';
import 'package:secretpod_server/src/vault/vault_service.dart';
import 'package:test/test.dart';

class _Store implements VaultStore {
  final data = emptyVault();
  @override
  Future<T> read<T>(T Function(VaultData) operation) async => operation(data);
  @override
  Future<T> write<T>(FutureOr<T> Function(VaultData) operation) async =>
      operation(data);
  @override
  Future<void> close() async {}
}

void main() {
  test(
    'options include current projects and each member once without activity',
    () async {
      final store = _Store();
      rows(store.data, 'accounts').addAll([
        {'id': 'owner', 'name': 'Current name', 'email': 'owner@example.test'},
        {'id': 'reader', 'name': 'New member', 'email': 'reader@example.test'},
        {
          'id': 'outsider',
          'name': 'Other organization',
          'email': 'other@example.test',
        },
      ]);
      rows(store.data, 'members').addAll([
        {'organizationId': 'org', 'accountId': 'owner', 'role': 'owner'},
        {
          'organizationId': 'org',
          'accountId': 'reader',
          'role': 'reader',
          'readProjects': '["Payments"]',
        },
        {'organizationId': 'other', 'accountId': 'outsider', 'role': 'owner'},
      ]);
      rows(store.data, 'projects').addAll([
        {'id': 'p1', 'organizationId': 'org', 'name': 'Payments'},
        {'id': 'p2', 'organizationId': 'org', 'name': 'Empty project'},
        {'id': 'p3', 'organizationId': 'other', 'name': 'Private project'},
      ]);
      rows(store.data, 'events').addAll([
        {
          'id': 'legacy',
          'organizationId': 'org',
          'actor': 'Old name (owner@example.test)',
          'action': 'created organization',
          'target': 'Team',
          'createdAt': '2026-10-14T00:00:00Z',
        },
        {
          'id': 'linked',
          'organizationId': 'org',
          'actorId': 'owner',
          'actor': 'Old name (owner@example.test)',
          'action': 'invited reader',
          'target': 'reader@example.test',
          'createdAt': '2026-10-14T01:00:00Z',
        },
      ]);
      final vault = VaultService(
        store,
        CryptoService(base64Encode(List.filled(32, 17))),
      );
      final summary = await vault.summary('owner', 'org');
      expect(summary.activityProjects, [
        'Default',
        'Empty project',
        'Payments',
      ]);
      expect(summary.activityUsers, {
        'id:owner': 'Current name (owner@example.test)',
        'id:reader': 'New member (reader@example.test)',
      });
      expect(summary.activityActions, [
        'created organization',
        'invited reader',
      ]);
      expect(rows(store.data, 'events').first.containsKey('actorId'), isFalse);
      final restricted = await vault.summary('reader', 'org');
      expect(restricted.activityProjects, ['Payments']);
    },
  );
}
