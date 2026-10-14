import 'dart:async';

typedef VaultData = Map<String, dynamic>;

/// Persistence boundary: isolated snapshots and atomic writes with audit events.
abstract interface class VaultStore {
  Future<T> read<T>(T Function(VaultData data) operation);
  Future<T> write<T>(FutureOr<T> Function(VaultData data) operation);
  Future<void> close();
}

/// Targeted reads supported by persistent stores without loading a vault snapshot.
/// Snapshot-only adapters can continue to use the service's in-memory path.
abstract interface class VaultQueryStore {
  Future<Map<String, dynamic>?> readSession(String digest);
  Future<List<Map<String, dynamic>>> readSecretActivity(
    String actor,
    String organizationId,
    String secretId, {
    String? beforeEventId,
    required int offset,
    required int limit,
  });
}

List<Map<String, dynamic>> rows(VaultData data, String key) =>
    (data[key] as List).cast<Map<String, dynamic>>();
