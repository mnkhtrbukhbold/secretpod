import 'package:serverpod_database/serverpod_database.dart';
import '../generated/protocol.dart' show VaultException;
import '../organization/access.dart';
import '../paging.dart';
import 'sqlite_schema.dart';

/// Authorization and page selection share one database transaction. Event
/// payloads are selected only after access, cursor and page bounds are applied.
class SecretActivityQuery {
  SecretActivityQuery(this.database, this.transaction);
  final Database database;
  final Transaction transaction;

  Future<List<Map<String, dynamic>>> _query(
    String sql,
    Map<String, dynamic> parameters,
  ) async => (await database.unsafeQuery(
    sql,
    parameters: QueryParameters.named(parameters),
    transaction: transaction,
  )).map((row) => row.toColumnMap()).toList();

  Future<List<Map<String, dynamic>>> read(
    String actor,
    String organizationId,
    String secretId, {
    String? beforeEventId,
    required int offset,
    required int limit,
  }) async {
    final parameters = <String, dynamic>{
      'actor': actor,
      'organizationId': organizationId,
      'secretId': secretId,
    };
    final members = await _query(
      'SELECT * FROM vault_members WHERE "organizationId" = @organizationId '
      'AND "accountId" = @actor LIMIT 1',
      parameters,
    );
    final access = ProjectAccess({'members': members}, actor, organizationId);
    Pagination(offset: offset, limit: limit);
    if (beforeEventId != null && offset != 0) {
      throw VaultException(
        message: 'Use either an activity cursor or an offset, not both.',
      );
    }
    final secrets = await _query(
      'SELECT "project" FROM vault_secrets WHERE "organizationId" = @organizationId '
      'AND "id" = @secretId LIMIT 1',
      parameters,
    );
    if (secrets.isEmpty) throw VaultException(message: 'Secret not found.');
    access.require(secrets.single['project'] as String);

    var predicate =
        '"organizationId" = @organizationId AND "secretId" = @secretId';
    bool canReadProject(Map<String, dynamic> event) =>
        access.readAll ||
        (event['project'] != null &&
            access.canRead(event['project'] as String));
    if (beforeEventId != null) {
      parameters['cursor'] = beforeEventId;
      final cursor = await _query(
        'SELECT "_order", "project" FROM vault_events WHERE $predicate AND "id" = @cursor LIMIT 1',
        parameters,
      );
      if (cursor.isEmpty || !canReadProject(cursor.single)) {
        throw VaultException(
          message: 'Activity page not found. Refresh the history.',
        );
      }
      parameters['beforeOrder'] = cursor.single['_order'];
      predicate += ' AND "_order" < @beforeOrder';
    }
    parameters.addAll({'limit': limit, 'offset': offset});
    if (!access.readAll) {
      // SQLite LOWER/NOCASE only fold ASCII. Walk bounded metadata batches
      // using the shared Dart policy, stopping as soon as this page is full.
      // Offset counts authorized events only; denied rows never consume a slot.
      final ids = <String>[];
      var remainingOffset = offset;
      var scanPredicate = predicate;
      while (ids.length < limit) {
        final batch = await _query(
          'SELECT "id", "project", "_order" FROM vault_events '
          'WHERE $scanPredicate ORDER BY "_order" DESC LIMIT @limit',
          parameters,
        );
        for (final event in batch) {
          if (!canReadProject(event)) continue;
          if (remainingOffset > 0) {
            remainingOffset--;
          } else {
            ids.add(event['id'] as String);
            if (ids.length == limit) break;
          }
        }
        if (ids.length == limit || batch.length < limit) break;
        parameters['scanBefore'] = batch.last['_order'];
        scanPredicate = '$predicate AND "_order" < @scanBefore';
      }
      if (ids.isEmpty) return [];
      final placeholders = <String>[];
      for (var i = 0; i < ids.length; i++) {
        parameters['event$i'] = ids[i];
        placeholders.add('@event$i');
      }
      predicate += ' AND "id" IN (${placeholders.join(', ')})';
      parameters['offset'] = 0;
    }
    final columns = vaultTables
        .singleWhere((table) => table.collection == 'events')
        .columns
        .keys;
    return _query(
      'SELECT ${columns.map((column) => '"$column"').join(', ')} FROM vault_events '
      'WHERE $predicate ORDER BY "_order" DESC LIMIT @limit OFFSET @offset',
      parameters,
    );
  }
}
