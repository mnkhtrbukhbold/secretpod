import 'package:uuid/uuid.dart';
import '../crypto/crypto_service.dart';
import '../generated/protocol.dart';
import '../organization/access.dart';
import '../storage/vault_store.dart';
import '../tracking/tracking_service.dart';
import '../tracking/activity_filter.dart';
import '../validation.dart';
import '../paging.dart';
import 'rotation.dart';
import 'secret_access_limiter.dart';

class VaultService {
  VaultService(this.store, this.crypto, {SecretAccessLimiter? accessLimiter})
    : _accessLimiter = accessLimiter ?? SecretAccessLimiter();
  final VaultStore store;
  final CryptoService crypto;
  final SecretAccessLimiter _accessLimiter;

  // Legacy projects existed only through secrets. Retain their identity when
  // the last secret moves or is deleted so existing writers can use them again.
  static void _retainProject(
    VaultData data,
    String organizationId,
    String name,
  ) {
    if (name.toLowerCase() == 'default') return;
    final projects = rows(data, 'projects');
    if (!projects.any(
      (p) =>
          p['organizationId'] == organizationId &&
          (p['name'] as String).toLowerCase() == name.toLowerCase(),
    )) {
      projects.add({'organizationId': organizationId, 'name': name});
    }
  }

  Future<String> createProject(
    String actor,
    String organizationId,
    String name,
  ) => store.write((data) {
    final access = ProjectAccess(data, actor, organizationId);
    if (!access.canCreateProjects) {
      throw VaultException(
        message: 'You do not have permission to create projects.',
      );
    }
    final canonicalName = bounded(name, 'Project', max: 80);
    access.require(canonicalName, write: true);
    final normalized = canonicalName.toLowerCase();
    if (normalized == 'default' ||
        rows(data, 'projects').any(
          (project) =>
              project['organizationId'] == organizationId &&
              (project['name'] as String).toLowerCase() == normalized,
        ) ||
        rows(data, 'secrets').any(
          (secret) =>
              secret['organizationId'] == organizationId &&
              (secret['project'] as String).toLowerCase() == normalized,
        )) {
      throw VaultException(message: 'A project with this name already exists.');
    }
    rows(data, 'projects').add({
      'organizationId': organizationId,
      'name': canonicalName,
    });
    recordEvent(
      data,
      actor,
      organizationId,
      'created project',
      canonicalName,
      project: canonicalName,
    );
    return canonicalName;
  });

  static bool _matches(
    Map<String, dynamic> s,
    String query,
    String? project,
    String? environment,
  ) =>
      (project == null ||
          (s['project'] as String).toLowerCase() == project.toLowerCase()) &&
      (environment == null || s['environment'] == environment) &&
      '${s['name']} ${s['project']} ${s['kind']} ${s['description']}'
          .toLowerCase()
          .contains(query.toLowerCase());

  Future<List<SecretView>> list(
    String actor,
    String organizationId, {
    int offset = 0,
    int limit = Pagination.defaultLimit,
    String query = '',
    String? project,
    String? environment,
  }) => store.read((data) {
    final access = ProjectAccess(data, actor, organizationId);
    final paging = Pagination(offset: offset, limit: limit);
    final matches =
        rows(data, 'secrets')
            .where(
              (s) =>
                  s['organizationId'] == organizationId &&
                  access.canRead(s['project'] as String) &&
                  _matches(s, query, project, environment),
            )
            .toList()
          ..sort((a, b) {
            final time = DateTime.parse(
              b['updatedAt'] as String,
            ).compareTo(DateTime.parse(a['updatedAt'] as String));
            return time != 0
                ? time
                : (a['id'] as String).compareTo(b['id'] as String);
          });
    return paging.apply(matches).map(view).toList();
  });

  Future<WorkspaceSummary> summary(
    String actor,
    String organizationId, {
    String query = '',
    String? project,
    String? environment,
    DateTime? activityFrom,
    DateTime? activityUntil,
    String? activityProject,
    String? activityAction,
    String? activityUser,
  }) => store.read((data) {
    final access = ProjectAccess(data, actor, organizationId);
    final activityFilter = ActivityFilter(
      from: activityFrom,
      until: activityUntil,
      project: activityProject,
      action: activityAction,
      user: activityUser,
    );
    final events =
        rows(
              data,
              'events',
            )
            .where(
              (e) =>
                  e['organizationId'] == organizationId &&
                  access.canReadEvent(data, e),
            )
            .toList();
    final activityProjects = <String, String>{};
    final activityUsers = <String, String>{};
    for (final event in events) {
      final project = event['project'] as String?;
      if (project != null) {
        activityProjects.putIfAbsent(project.toLowerCase(), () => project);
      }
    }
    // Member choices use current identities, including members without events.
    // Legacy actor text cannot establish identity and must not create duplicates.
    final memberIds = rows(data, 'members')
        .where((m) => m['organizationId'] == organizationId)
        .map((m) => m['accountId'])
        .toSet();
    for (final account in rows(
      data,
      'accounts',
    ).where((a) => memberIds.contains(a['id']))) {
      activityUsers['id:${account['id']}'] =
          '${account['name']} (${account['email']})';
    }
    final secrets =
        rows(
              data,
              'secrets',
            )
            .where(
              (s) =>
                  s['organizationId'] == organizationId &&
                  access.canRead(s['project'] as String),
            )
            .toList();
    final names = <String, String>{
      if (access.canRead('Default')) 'default': 'Default',
    };
    final counts = <String, int>{if (access.canRead('Default')) 'Default': 0};
    for (final project in rows(data, 'projects').where(
      (project) =>
          project['organizationId'] == organizationId &&
          access.canRead(project['name'] as String),
    )) {
      final raw = project['name'] as String;
      final name = names.putIfAbsent(raw.toLowerCase(), () => raw);
      counts.putIfAbsent(name, () => 0);
    }
    for (final secret in secrets) {
      final raw = secret['project'] as String;
      final name = names.putIfAbsent(raw.toLowerCase(), () => raw);
      counts[name] = (counts[name] ?? 0) + 1;
    }
    for (final name in counts.keys) {
      activityProjects.putIfAbsent(name.toLowerCase(), () => name);
    }
    return WorkspaceSummary(
      secretCount: secrets.length,
      filteredSecretCount: secrets
          .where((s) => _matches(s, query, project, environment))
          .length,
      memberCount: rows(
        data,
        'members',
      ).where((m) => m['organizationId'] == organizationId).length,
      activityCount: events.length,
      projectCounts: counts,
      filteredActivityCount: events.where(activityFilter.matches).length,
      activityProjects: activityProjects.values.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
      activityActions: events.map((e) => e['action'] as String).toSet().toList()
        ..sort(),
      activityUsers: activityUsers,
    );
  });

  Future<SecretView> save(
    String actor,
    String organizationId, {
    String? id,
    required String name,
    required String? value,
    required String project,
    required String environment,
    required String kind,
    required String description,
    String? username,
    String? url,
    DateTime? expiresAt,
    bool replaceMetadata = true,
  }) {
    name = bounded(name, 'Secret name');
    project = bounded(project, 'Project', max: 80);
    description = bounded(description, 'Description', max: 1000, empty: true);
    if (!['Development', 'Staging', 'Production'].contains(environment)) {
      throw VaultException(message: 'Choose a valid environment.');
    }
    if (![
      'API key',
      'Environment variable',
      'Password',
      'Username and password',
      'Certificate',
      'Other',
    ].contains(kind)) {
      throw VaultException(message: 'Choose a valid secret type.');
    }
    if (value != null && (value.isEmpty || value.length > 65536)) {
      throw VaultException(message: 'Secret value must be 1–65536 characters.');
    }
    if (username != null &&
        (username.trim().isEmpty || username.length > 320)) {
      throw VaultException(
        message: 'Username must be 1–320 characters and cannot be blank.',
      );
    }
    url = url?.trim();
    if (url != null && url.isEmpty) url = null;
    if (url != null) {
      final uri = Uri.tryParse(url);
      if (url.length > 2048 ||
          uri == null ||
          !['https', 'http'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          RegExp(r'\s').hasMatch(url)) {
        throw VaultException(
          message:
              'Enter an http:// or https:// URL without embedded credentials.',
        );
      }
    }
    // Calendar date, serialized at UTC midnight to avoid timezone date shifts.
    if (expiresAt != null) {
      if (expiresAt.year < 1900 || expiresAt.year > 9999) {
        throw VaultException(
          message: 'Choose an expiry date between 1900 and 9999.',
        );
      }
      expiresAt = DateTime.utc(expiresAt.year, expiresAt.month, expiresAt.day);
    }
    return store.write((data) async {
      requireMembership(data, actor, organizationId, write: true);
      final secrets = rows(data, 'secrets');
      final previous = id == null ? null : _find(data, organizationId, id);
      final access = ProjectAccess(data, actor, organizationId);
      access.require(project, write: true);
      final projectExists =
          project.toLowerCase() == 'default' ||
          // Existing selected grants can outlive pre-upgrade implicit projects.
          (access.writeProjects?.any(
                (p) => p.toLowerCase() == project.toLowerCase(),
              ) ??
              false) ||
          rows(data, 'projects').any(
            (p) =>
                p['organizationId'] == organizationId &&
                (p['name'] as String).toLowerCase() == project.toLowerCase(),
          ) ||
          secrets.any(
            (s) =>
                s['organizationId'] == organizationId &&
                (s['project'] as String).toLowerCase() == project.toLowerCase(),
          );
      if (!projectExists && !access.canCreateProjects) {
        throw VaultException(
          message: 'You do not have permission to create projects.',
        );
      }
      if (previous != null) {
        access.require(previous['project'] as String, write: true);
        _retainProject(data, organizationId, previous['project'] as String);
      }
      _retainProject(data, organizationId, project);
      if (previous == null && value == null) {
        throw VaultException(message: 'Enter a secret value.');
      }
      if (secrets.any(
        (s) =>
            s['organizationId'] == organizationId &&
            s['id'] != id &&
            (s['name'] as String).toLowerCase() == name.toLowerCase() &&
            (s['project'] as String).toLowerCase() == project.toLowerCase() &&
            s['environment'] == environment,
      )) {
        throw VaultException(
          message:
              'A secret with this name already exists in this project and environment.',
        );
      }
      final secretId = id ?? const Uuid().v4();
      final valueChanged =
          previous == null ||
          (value != null &&
              !CryptoService.constantTimeEquals(
                value,
                await crypto.decrypt(
                  previous['ciphertext'] as String,
                  '$organizationId:$secretId',
                ),
              ));
      final oldUsername = previous?['usernameCiphertext'] as String?;
      String? usernameCiphertext;
      var usernameChanged = false;
      if (kind == 'Username and password') {
        if (username == null && oldUsername == null) {
          throw VaultException(
            message: 'Enter a username for this secret type.',
          );
        }
        usernameChanged =
            username != null &&
            (oldUsername == null ||
                !CryptoService.constantTimeEquals(
                  username,
                  await crypto.decrypt(
                    oldUsername,
                    '$organizationId:$secretId:username',
                  ),
                ));
        usernameCiphertext = usernameChanged
            ? await crypto.encrypt(
                username,
                '$organizationId:$secretId:username',
              )
            : oldUsername;
      } else {
        if (username != null) {
          throw VaultException(
            message:
                'Username is only available for the username and password type.',
          );
        }
        usernameChanged = oldUsername != null;
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final storedUrl = replaceMetadata ? url : previous?['url'] as String?;
      final storedExpiry = replaceMetadata
          ? expiresAt?.toIso8601String()
          : previous?['expiresAt'] as String?;
      final secret = <String, dynamic>{
        'id': secretId,
        'organizationId': organizationId,
        'name': name,
        'project': project,
        'environment': environment,
        'kind': kind,
        'description': description,
        'ciphertext': valueChanged
            ? await crypto.encrypt(value!, '$organizationId:$secretId')
            : previous['ciphertext'],
        'usernameCiphertext': ?usernameCiphertext,
        'url': ?storedUrl,
        'expiresAt': ?storedExpiry,
        if (previous?['needsRotation'] != null)
          'needsRotation': valueChanged ? 0 : previous['needsRotation'],
        'version': ((previous?['version'] as int?) ?? 0) + 1,
        'createdAt': previous?['createdAt'] ?? now,
        'updatedAt': now,
      };
      if (previous != null) secrets.remove(previous);
      secrets.add(secret);
      final changedFields = [
        if (valueChanged) 'value',
        if (usernameChanged) 'username',
        if (valueChanged && previous?['needsRotation'] == 1) 'rotation status',
        if (previous != null)
          for (final field in [
            'name',
            'project',
            'environment',
            'kind',
            'description',
            'url',
            'expiresAt',
          ])
            if (previous[field] != secret[field])
              field == 'kind'
                  ? 'type'
                  : field == 'expiresAt'
                  ? 'expiry date'
                  : field,
      ];
      recordEvent(
        data,
        actor,
        organizationId,
        previous == null
            ? 'created'
            : changedFields.isEmpty
            ? 'saved'
            : valueChanged || usernameChanged
            ? 'rotated'
            : 'updated',
        name,
        secretId: secretId,
        version: secret['version'] as int,
        details: previous == null
            ? null
            : changedFields.isEmpty
            ? 'Saved without changes'
            : 'Changed: ${changedFields.join(', ')}',
      );
      return view(secret);
    });
  }

  Future<String> reveal(String actor, String organizationId, String id) async {
    _accessLimiter.consume(actor);
    return store.write((data) async {
      requireMembership(data, actor, organizationId);
      final secret = _find(data, organizationId, id);
      ProjectAccess(
        data,
        actor,
        organizationId,
      ).require(secret['project'] as String);
      final value = await crypto.decrypt(
        // Authorization precedes decryption and audit recording.
        secret['ciphertext'] as String,
        '$organizationId:$id',
      );
      recordEvent(
        data,
        actor,
        organizationId,
        'revealed',
        secret['name'] as String,
        secretId: id,
        version: secret['version'] as int,
      );
      return value;
    });
  }

  Future<SecretFields> revealFields(
    String actor,
    String organizationId,
    String id,
  ) async {
    _accessLimiter.consume(actor);
    return store.write((data) async {
      requireMembership(data, actor, organizationId);
      final secret = _find(data, organizationId, id);
      ProjectAccess(
        data,
        actor,
        organizationId,
      ).require(secret['project'] as String);
      final username = secret['usernameCiphertext'] as String?;
      final result = SecretFields(
        value: await crypto.decrypt(
          secret['ciphertext'] as String,
          '$organizationId:$id',
        ),
        username: username == null
            ? null
            : await crypto.decrypt(username, '$organizationId:$id:username'),
      );
      recordEvent(
        data,
        actor,
        organizationId,
        'revealed',
        secret['name'] as String,
        secretId: id,
        version: secret['version'] as int,
        details: username == null
            ? 'Field: value'
            : 'Fields: username, password',
      );
      return result;
    });
  }

  Future<SecretCopy> copy(
    String actor,
    String organizationId,
    String id, {
    String? field,
  }) async {
    _accessLimiter.consume(actor);
    return store.write((data) async {
      requireMembership(data, actor, organizationId);
      final secret = _find(data, organizationId, id);
      ProjectAccess(
        data,
        actor,
        organizationId,
      ).require(secret['project'] as String);
      final selected = field ?? 'value';
      if (!['value', 'username'].contains(selected)) {
        throw VaultException(message: 'Choose a valid secret field.');
      }
      final ciphertext =
          secret[selected == 'username' ? 'usernameCiphertext' : 'ciphertext']
              as String?;
      if (ciphertext == null) {
        throw VaultException(message: 'This secret has no username.');
      }
      final value = await crypto.decrypt(
        ciphertext,
        selected == 'username'
            ? '$organizationId:$id:username'
            : '$organizationId:$id',
      );
      final eventId = recordEvent(
        data,
        actor,
        organizationId,
        'copy requested',
        secret['name'] as String,
        secretId: id,
        version: secret['version'] as int,
        details:
            'Field: ${selected == 'value' && secret['kind'] == 'Username and password' ? 'password' : selected}',
      );
      return SecretCopy(eventId: eventId, value: value);
    });
  }

  Future<void> delete(String actor, String organizationId, String id) =>
      store.write((data) {
        requireMembership(data, actor, organizationId, write: true);
        final secret = _find(data, organizationId, id);
        ProjectAccess(
          data,
          actor,
          organizationId,
        ).require(secret['project'] as String, write: true);
        _retainProject(data, organizationId, secret['project'] as String);
        recordEvent(
          data,
          actor,
          organizationId,
          'deleted',
          secret['name'] as String,
          secretId: id,
          version: secret['version'] as int,
        );
        rows(data, 'secrets').remove(secret);
      });

  Future<SecretView> setRotationRequired(
    String actor,
    String organizationId,
    String id,
    bool required,
  ) => store.write((data) {
    requireMembership(data, actor, organizationId, write: true);
    final secret = _find(data, organizationId, id);
    ProjectAccess(
      data,
      actor,
      organizationId,
    ).require(secret['project'] as String, write: true);
    markSecretRotation(data, actor, secret, required);
    return view(secret);
  });

  Map<String, dynamic> _find(VaultData data, String organizationId, String id) {
    final secret = rows(data, 'secrets')
        .where((s) => s['id'] == id && s['organizationId'] == organizationId)
        .firstOrNull;
    if (secret == null) throw VaultException(message: 'Secret not found.');
    return secret;
  }

  static SecretView view(Map<String, dynamic> s) => SecretView(
    id: s['id'] as String,
    organizationId: s['organizationId'] as String,
    name: s['name'] as String,
    project: s['project'] as String,
    environment: s['environment'] as String,
    kind: s['kind'] as String,
    description: s['description'] as String,
    version: s['version'] as int,
    createdAt: DateTime.parse(s['createdAt'] as String),
    updatedAt: DateTime.parse(s['updatedAt'] as String),
    needsRotation: s['needsRotation'] == 1,
    url: s['url'] as String?,
    expiresAt: s['expiresAt'] == null
        ? null
        : DateTime.parse(s['expiresAt'] as String),
  );
}
