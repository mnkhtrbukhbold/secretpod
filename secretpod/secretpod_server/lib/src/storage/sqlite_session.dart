import 'package:serverpod_database/serverpod_database.dart' hide Protocol;
import 'package:serverpod_shared/serverpod_shared.dart';
import '../generated/protocol.dart' show Protocol;

/// Module-owned session using the same SQLite provider as Serverpod's server.
class VaultDatabaseSession implements DatabaseSession {
  VaultDatabaseSession._(this._pool) {
    _database = DatabaseConstructor.create(session: this, poolManager: _pool);
  }
  final DatabasePoolManager _pool;
  late final Database _database;

  static Future<VaultDatabaseSession> open(String path) async {
    final pool = DatabaseProvider.forDialect(
      DatabaseDialect.sqlite,
    ).createPoolManager(Protocol(), null, SqliteDatabaseConfig(filePath: path));
    try {
      await pool.started;
      final session = VaultDatabaseSession._(pool);
      await session.db.unsafeExecute('PRAGMA synchronous = FULL');
      return session;
    } catch (_) {
      await pool.stop();
      rethrow;
    }
  }

  @override
  Database get db => _database;
  @override
  Transaction? get transaction => null;
  // Query logging is disabled so bound sensitive values never enter logs.
  @override
  LogQueryFunction? get logQuery => null;
  @override
  LogWarningFunction? get logWarning => null;
  Future<void> close() => _pool.stop();
}
