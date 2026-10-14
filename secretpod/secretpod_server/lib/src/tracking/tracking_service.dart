import 'package:uuid/uuid.dart';
import '../generated/protocol.dart';
import '../organization/access.dart';
import '../storage/vault_store.dart';
import '../paging.dart';
import 'activity_filter.dart';

String recordEvent(
  VaultData data,
  String actor,
  String organizationId,
  String action,
  String target, {
  String? secretId,
  int? version,
  String? details,
  String? project,
}) {
  final account = rows(data, 'accounts').firstWhere((a) => a['id'] == actor);
  final id = const Uuid().v4();
  final projectSnapshot =
      project ??
      (secretId == null
          ? null
          : rows(data, 'secrets')
                    .where(
                      (s) =>
                          s['id'] == secretId &&
                          s['organizationId'] == organizationId,
                    )
                    .firstOrNull?['project']
                as String?);
  rows(data, 'events').add({
    'id': id,
    'organizationId': organizationId,
    'actor': '${account['name']} (${account['email']})',
    'action': action,
    'target': target,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'actorId': actor,
    'secretId': ?secretId,
    'version': ?version,
    'details': ?details,
    'project': ?projectSnapshot,
  });
  return id;
}

class TrackingService {
  TrackingService(this.store);
  final VaultStore store;
  Future<List<AuditView>> list(
    String actor,
    String organizationId, {
    int offset = 0,
    int limit = Pagination.defaultLimit,
    DateTime? from,
    DateTime? until,
    String? project,
    String? action,
    String? user,
  }) => store.read((data) {
    final access = ProjectAccess(data, actor, organizationId);
    final filter = ActivityFilter(
      from: from,
      until: until,
      project: project,
      action: action,
      user: user,
    );
    return Pagination(offset: offset, limit: limit)
        .apply(
          rows(
            data,
            'events',
          ).reversed.where(
            (e) =>
                e['organizationId'] == organizationId &&
                access.canReadEvent(data, e) &&
                filter.matches(e),
          ),
        )
        .map(_view)
        .toList();
  });

  Future<List<AuditView>> forSecret(
    String actor,
    String organizationId,
    String secretId, {
    String? beforeEventId,
    int offset = 0,
    int limit = Pagination.defaultLimit,
  }) async {
    if (store case final VaultQueryStore queries) {
      return (await queries.readSecretActivity(
        actor,
        organizationId,
        secretId,
        beforeEventId: beforeEventId,
        offset: offset,
        limit: limit,
      )).map(_view).toList();
    }
    return store.read((data) {
      final access = ProjectAccess(data, actor, organizationId);
      final paging = Pagination(offset: offset, limit: limit);
      if (beforeEventId != null && offset != 0) {
        throw VaultException(
          message: 'Use either an activity cursor or an offset, not both.',
        );
      }
      if (!rows(data, 'secrets').any(
        (s) => s['id'] == secretId && s['organizationId'] == organizationId,
      )) {
        throw VaultException(message: 'Secret not found.');
      }
      final secret = rows(data, 'secrets').firstWhere(
        (s) => s['id'] == secretId && s['organizationId'] == organizationId,
      );
      access.require(secret['project'] as String);
      final events = rows(data, 'events').reversed
          .where(
            (e) =>
                e['organizationId'] == organizationId &&
                e['secretId'] == secretId &&
                access.canReadEvent(data, e),
          )
          .toList();
      var start = 0;
      if (beforeEventId != null) {
        final index = events.indexWhere((e) => e['id'] == beforeEventId);
        if (index < 0) {
          throw VaultException(
            message: 'Activity page not found. Refresh the history.',
          );
        }
        start = index + 1;
      }
      return paging.apply(events.skip(start)).map(_view).toList();
    });
  }

  Future<void> confirmCopy(
    String actor,
    String organizationId,
    String secretId,
    String eventId,
  ) => store.write((data) {
    requireMembership(data, actor, organizationId);
    final event = rows(data, 'events')
        .where(
          (e) =>
              e['id'] == eventId &&
              e['organizationId'] == organizationId &&
              e['secretId'] == secretId &&
              e['actorId'] == actor &&
              ['copy requested', 'copied'].contains(e['action']),
        )
        .firstOrNull;
    if (event == null) throw VaultException(message: 'Copy request not found.');
    if (!ProjectAccess(data, actor, organizationId).canReadEvent(data, event)) {
      throw VaultException(message: 'Project access denied.');
    }
    // Idempotent acknowledgment by the authenticated app, never a claim that
    // the server can inspect a remote operating system's clipboard.
    event['action'] = 'copied';
  });

  static AuditView _view(Map<String, dynamic> e) => AuditView(
    id: e['id'] as String,
    actor: e['actor'] as String,
    action: e['action'] as String,
    target: e['target'] as String,
    createdAt: DateTime.parse(e['createdAt'] as String),
    secretId: e['secretId'] as String?,
    actorId: e['actorId'] as String?,
    version: e['version'] as int?,
    details: e['details'] as String?,
  );
}
