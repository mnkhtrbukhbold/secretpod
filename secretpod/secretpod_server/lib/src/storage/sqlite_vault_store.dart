import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:synchronized/synchronized.dart';
import 'sqlite_schema.dart';
import 'sqlite_session.dart';
import 'secret_activity_query.dart';
import 'vault_store.dart';

typedef VaultValidator = Future<void> Function(VaultData data);

class SqliteVaultStore implements VaultStore, VaultQueryStore {
  SqliteVaultStore._(this._path, this._lockFile, this._session);
  static const _schemaVersion = 11;
  static const _applicationId = 0x53504f44; // SPOD
  static final _openPaths = <String>{};
  final String _path;
  final RandomAccessFile _lockFile;
  final VaultDatabaseSession _session;
  final _mutex = Lock();
  bool _closed = false;
  Database get _db => _session.db;

  static Future<SqliteVaultStore> open(
    Directory directory, {
    required VaultValidator validate,
  }) async {
    await directory.create(recursive: true);
    final path = await directory.resolveSymbolicLinks();
    if (!_openPaths.add(path)) throw StateError('This vault is already open.');
    RandomAccessFile? lockFile;
    VaultDatabaseSession? session;
    try {
      // Same lock as the old adapter: migration cannot race a JSON writer.
      lockFile = await File('$path/vault.lock').open(mode: FileMode.append);
      await lockFile.lock(FileLock.exclusive);
      session = await VaultDatabaseSession.open('$path/vault.sqlite');
      final store = SqliteVaultStore._(path, lockFile, session);
      await store._initialize(validate);
      return store;
    } catch (_) {
      try {
        await session?.close();
      } finally {
        await lockFile?.close();
        _openPaths.remove(path);
      }
      rethrow;
    }
  }

  Future<void> _initialize(VaultValidator validate) => _db.transaction((
    tx,
  ) async {
    final version =
        (await _db.unsafeQuery(
              'PRAGMA user_version',
              transaction: tx,
            )).first.first
            as int;
    if (version == 0) {
      final existing = await _db.unsafeQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
        transaction: tx,
      );
      if (existing.isNotEmpty) {
        throw StateError('Unrecognized existing SQLite database.');
      }
      final legacy = File('$_path/vault.json');
      VaultData initial = emptyVault();
      if (await legacy.exists()) {
        try {
          final decoded = jsonDecode(await legacy.readAsString());
          if (decoded is! Map<String, dynamic>) throw const FormatException();
          initial = decoded;
        } on FormatException {
          throw StateError(
            'Invalid legacy vault JSON. Original file was retained.',
          );
        }
      }
      initial.putIfAbsent('invitations', () => <Map<String, dynamic>>[]);
      initial.putIfAbsent('projects', () => <Map<String, dynamic>>[]);
      validateVaultShape(initial);
      await validate(initial);
      await _db.unsafeExecute(
        'CREATE TABLE vault_metadata ("key" TEXT PRIMARY KEY NOT NULL, "value" TEXT NOT NULL)',
        transaction: tx,
      );
      for (final table in vaultTables) {
        await _db.unsafeExecute(table.createSql, transaction: tx);
      }
      for (final index in vaultIndexes) {
        await _db.unsafeExecute(index, transaction: tx);
      }
      await _persist(emptyVault(), initial, tx);
      // These markers commit atomically with the complete import, never before it.
      await _db.unsafeExecute(
        'PRAGMA application_id = $_applicationId',
        transaction: tx,
      );
      await _db.unsafeExecute(
        'PRAGMA user_version = $_schemaVersion',
        transaction: tx,
      );
    } else {
      final applicationId = (await _db.unsafeQuery(
        'PRAGMA application_id',
        transaction: tx,
      )).first.first;
      if ((version < 1 || version > _schemaVersion) ||
          applicationId != _applicationId) {
        throw StateError('Unsupported SQLite vault format.');
      }
      if (version == 1) {
        // Old events have only a display name. Never guess their secret/actor ID.
        for (final column in [
          'secretId TEXT',
          'actorId TEXT',
          'version INTEGER',
          'details TEXT',
        ]) {
          await _db.unsafeExecute(
            'ALTER TABLE vault_events ADD COLUMN $column',
            transaction: tx,
          );
        }
        await _db.unsafeExecute(vaultIndexes[4], transaction: tx);
      }
      if (version < 3) {
        for (final column in [
          'usernameCiphertext TEXT',
          'url TEXT',
          'expiresAt TEXT',
        ]) {
          await _db.unsafeExecute(
            'ALTER TABLE vault_secrets ADD COLUMN $column',
            transaction: tx,
          );
        }
      }
      if (version < 4) {
        await _db.unsafeExecute(
          'ALTER TABLE vault_accounts ADD COLUMN invitationPolicy TEXT',
          transaction: tx,
        );
        await _db.unsafeExecute(
          vaultTables
              .singleWhere((table) => table.collection == 'invitations')
              .createSql,
          transaction: tx,
        );
        for (final index in vaultIndexes.skip(5)) {
          await _db.unsafeExecute(index, transaction: tx);
        }
      }
      if (version < 5) {
        await _db.unsafeExecute(
          'ALTER TABLE vault_accounts ADD COLUMN themeMode TEXT',
          transaction: tx,
        );
      }
      if (version < 6) {
        await _db.unsafeExecute(
          'ALTER TABLE vault_secrets ADD COLUMN needsRotation INTEGER',
          transaction: tx,
        );
      }
      if (version < 7) {
        await _db.unsafeExecute(
          'ALTER TABLE vault_events ADD COLUMN project TEXT',
          transaction: tx,
        );
      }
      if (version < 8) {
        await _db.unsafeExecute(
          vaultTables
              .singleWhere((table) => table.collection == 'projects')
              .createSql,
          transaction: tx,
        );
      }
      if (version < 9) {
        // Before v4 the invitations table is created above with current columns.
        for (final table in ['members', if (version >= 4) 'invitations']) {
          for (final column in ['readProjects', 'writeProjects']) {
            await _db.unsafeExecute(
              'ALTER TABLE vault_$table ADD COLUMN $column TEXT',
              transaction: tx,
            );
          }
        }
      }
      if (version < 10) {
        await _db.unsafeExecute(
          'ALTER TABLE vault_members ADD COLUMN accessDisabled INTEGER',
          transaction: tx,
        );
      }
      if (version < 11) {
        for (final table in ['members', if (version >= 4) 'invitations']) {
          for (final column in [
            'deniedReadProjects TEXT',
            'deniedWriteProjects TEXT',
            'canCreateProjects INTEGER',
          ]) {
            await _db.unsafeExecute(
              'ALTER TABLE vault_$table ADD COLUMN $column',
              transaction: tx,
            );
          }
        }
      }
      final data = await _load(tx);
      validateVaultShape(data);
      await validate(data);
      if (version != _schemaVersion) {
        await _db.unsafeExecute(
          'PRAGMA user_version = $_schemaVersion',
          transaction: tx,
        );
      }
    }
  });

  Future<VaultData> _load(Transaction tx) async {
    final data = <String, dynamic>{};
    final metadata = await _db.unsafeQuery(
      'SELECT "key", "value" FROM vault_metadata',
      transaction: tx,
    );
    for (final row in metadata) {
      data[row[0] as String] = jsonDecode(row[1] as String);
    }
    for (final table in vaultTables) {
      final result = await _db.unsafeQuery(
        'SELECT ${table.columns.keys.map((key) => '"$key"').join(', ')} FROM "${table.name}" ORDER BY "_order"',
        transaction: tx,
      );
      data[table.collection] = result
          .map(
            (row) => row.toColumnMap()
              ..removeWhere(
                (key, value) =>
                    value == null && table.columns[key]!.endsWith('?'),
              ),
          )
          .toList();
    }
    return data;
  }

  Future<void> _persist(
    VaultData before,
    VaultData after,
    Transaction tx,
  ) async {
    validateVaultShape(after);
    // Remove children first; add parents first. Every change uses one transaction.
    for (final table in vaultTables.reversed) {
      final remaining = rows(
        after,
        table.collection,
      ).map(table.identity).toSet();
      for (final row in rows(before, table.collection)) {
        if (!remaining.contains(table.identity(row))) {
          await _db.unsafeExecute(
            'DELETE FROM "${table.name}" WHERE ${table.primaryKey.map((key) => '"$key" = @$key').join(' AND ')}',
            parameters: QueryParameters.named({
              for (final key in table.primaryKey) key: row[key],
            }),
            transaction: tx,
          );
        }
      }
    }
    for (final table in vaultTables) {
      final previous = rows(before, table.collection);
      final oldRows = {
        for (var i = 0; i < previous.length; i++)
          table.identity(previous[i]): {...previous[i], '_order': i},
      };
      final next = rows(after, table.collection);
      for (var i = 0; i < next.length; i++) {
        final row = {
          for (final key in table.columns.keys) key: next[i][key],
          '_order': i,
        };
        final old = oldRows[table.identity(next[i])];
        if (old != null && row.keys.every((key) => old[key] == row[key])) {
          continue;
        }
        final columns = [...table.columns.keys, '_order'];
        await _db.unsafeExecute(
          'INSERT INTO "${table.name}" (${columns.map((key) => '"$key"').join(', ')}) '
          'VALUES (${columns.map((key) => '@$key').join(', ')}) '
          'ON CONFLICT (${table.primaryKey.map((key) => '"$key"').join(', ')}) DO UPDATE SET '
          '${columns.where((key) => !table.primaryKey.contains(key)).map((key) => '"$key" = excluded."$key"').join(', ')}',
          parameters: QueryParameters.named(row),
          transaction: tx,
        );
      }
    }
    final collections = vaultTables.map((table) => table.collection).toSet();
    for (final key in before.keys.where(
      (key) => !collections.contains(key) && !after.containsKey(key),
    )) {
      await _db.unsafeExecute(
        'DELETE FROM vault_metadata WHERE "key" = @key',
        parameters: QueryParameters.named({'key': key}),
        transaction: tx,
      );
    }
    // Include scalar metadata on initial creation, even if unchanged from defaults.
    for (final key in after.keys.where((key) => !collections.contains(key))) {
      await _db.unsafeExecute(
        'INSERT INTO vault_metadata ("key", "value") VALUES (@key, @value) '
        'ON CONFLICT ("key") DO UPDATE SET "value" = excluded."value"',
        parameters: QueryParameters.named({
          'key': key,
          'value': jsonEncode(after[key]),
        }),
        transaction: tx,
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> readSession(
    String digest,
  ) => _mutex.synchronized(() async {
    if (_closed) throw StateError('Vault is closed.');
    final result = await _db.unsafeQuery(
      'SELECT "accountId", "expiresAt" FROM vault_sessions WHERE "digest" = @digest LIMIT 1',
      parameters: QueryParameters.named({'digest': digest}),
    );
    return result.isEmpty ? null : result.single.toColumnMap();
  });

  @override
  Future<List<Map<String, dynamic>>> readSecretActivity(
    String actor,
    String organizationId,
    String secretId, {
    String? beforeEventId,
    required int offset,
    required int limit,
  }) => _mutex.synchronized(() async {
    if (_closed) throw StateError('Vault is closed.');
    return _db.transaction(
      (tx) => SecretActivityQuery(_db, tx).read(
        actor,
        organizationId,
        secretId,
        beforeEventId: beforeEventId,
        offset: offset,
        limit: limit,
      ),
    );
  });

  @override
  Future<T> read<T>(T Function(VaultData data) operation) =>
      _mutex.synchronized(() async {
        if (_closed) throw StateError('Vault is closed.');
        return _db.transaction((tx) async => operation(await _load(tx)));
      });

  @override
  Future<T> write<T>(FutureOr<T> Function(VaultData data) operation) =>
      _mutex.synchronized(() async {
        if (_closed) throw StateError('Vault is closed.');
        return _db.transaction((tx) async {
          final before = await _load(tx);
          final after = jsonDecode(jsonEncode(before)) as VaultData;
          final result = await operation(after);
          await _persist(before, after, tx);
          return result;
        });
      });

  @override
  Future<void> close() => _mutex.synchronized(() async {
    if (_closed) return;
    _closed = true;
    try {
      await _session.close();
    } finally {
      await _lockFile.close();
      _openPaths.remove(_path);
    }
  });
}
