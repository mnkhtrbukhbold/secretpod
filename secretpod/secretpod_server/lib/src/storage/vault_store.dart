import 'dart:async';

typedef VaultData = Map<String, dynamic>;

/// Persistence boundary: isolated snapshots and atomic writes with audit events.
abstract interface class VaultStore {
  Future<T> read<T>(T Function(VaultData data) operation);
  Future<T> write<T>(FutureOr<T> Function(VaultData data) operation);
  Future<void> close();
}

List<Map<String, dynamic>> rows(VaultData data, String key) =>
    (data[key] as List).cast<Map<String, dynamic>>();
