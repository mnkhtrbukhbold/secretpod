part of 'demo_client.dart';

extension _DemoVault on _DemoState {
  Map<String, dynamic> findSecret(String id, {bool write = false}) {
    final member = membership(org, write: write);
    final secret = rows(
      'secrets',
    ).where((s) => s['id'] == id && s['organizationId'] == org).firstOrNull;
    if (secret == null) _fail('Secret not found.');
    requireProject(member, secret['project'] as String, write: write);
    return secret;
  }

  List<Map<String, dynamic>> visibleSecrets() {
    final member = membership(org);
    return rows('secrets')
        .where(
          (s) =>
              s['organizationId'] == org &&
              canRead(member, s['project'] as String),
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
  }

  bool matchesSecret(Map<String, dynamic> secret) =>
      (args['project'] == null ||
          (secret['project'] as String).toLowerCase() ==
              text('project').toLowerCase()) &&
      (args['environment'] == null ||
          secret['environment'] == args['environment']) &&
      '${secret['name']} ${secret['project']} ${secret['kind']} ${secret['description']}'
          .toLowerCase()
          .contains((args['query'] as String? ?? '').toLowerCase());

  bool canReadEvent(Map<String, dynamic> member, Map<String, dynamic> item) {
    if (readsAll(member)) return true;
    final project = item['project'] as String?;
    if (project == null || !canRead(member, project)) return false;
    final secret = rows('secrets')
        .where(
          (s) =>
              s['id'] == item['secretId'] &&
              s['organizationId'] == item['organizationId'],
        )
        .firstOrNull;
    return secret == null || canRead(member, secret['project'] as String);
  }

  List<Map<String, dynamic>> visibleEvents() {
    final member = membership(org);
    return rows('activity').reversed
        .where((e) => e['organizationId'] == org && canReadEvent(member, e))
        .toList();
  }

  Iterable<Map<String, dynamic>> filteredEvents(
    Iterable<Map<String, dynamic>> items, {
    bool summary = false,
  }) {
    final from = args[summary ? 'activityFrom' : 'from'] as String?;
    final until = args[summary ? 'activityUntil' : 'until'] as String?;
    final start = from == null ? null : DateTime.parse(from);
    final end = until == null ? null : DateTime.parse(until);
    if (start != null && end != null && !start.isBefore(end)) {
      _fail('Choose a valid activity date range.');
    }
    final project = args[summary ? 'activityProject' : 'project'] as String?;
    final action = args[summary ? 'activityAction' : 'action'] as String?;
    final user = args[summary ? 'activityUser' : 'user'] as String?;
    return items.where((e) {
      final time = DateTime.parse(e['createdAt'] as String);
      final key = e['actorId'] != null
          ? 'id:${e['actorId']}'
          : 'legacy:${e['actor']}';
      return (start == null || !time.isBefore(start)) &&
          (end == null || time.isBefore(end)) &&
          (project == null ||
              (e['project'] as String?)?.toLowerCase() ==
                  project.toLowerCase()) &&
          (action == null || e['action'] == action) &&
          (user == null || key == user);
    });
  }

  Map<String, dynamic> summary() {
    final member = membership(org);
    final secrets = visibleSecrets();
    final events = visibleEvents();
    final names = <String, String>{
      for (final name in projectNames(org).where((p) => canRead(member, p)))
        name.toLowerCase(): name,
    };
    final counts = <String, int>{for (final name in names.values) name: 0};
    for (final secret in secrets) {
      final name = names[(secret['project'] as String).toLowerCase()]!;
      counts[name] = counts[name]! + 1;
    }
    final activityProjects = {...names};
    for (final event in events) {
      final project = event['project'] as String?;
      if (project != null) {
        activityProjects.putIfAbsent(project.toLowerCase(), () => project);
      }
    }
    final members = rows(
      'members',
    ).where((m) => m['organizationId'] == org).toList();
    final users = <String, String>{};
    for (final member in members) {
      final user = account(memberId(member));
      users['id:${user['id']}'] = '${user['name']} (${user['email']})';
    }
    return WorkspaceSummary(
      secretCount: secrets.length,
      filteredSecretCount: secrets.where(matchesSecret).length,
      memberCount: members.length,
      activityCount: events.length,
      projectCounts: counts,
      filteredActivityCount: filteredEvents(events, summary: true).length,
      activityProjects: activityProjects.values.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
      activityActions: events.map((e) => e['action'] as String).toSet().toList()
        ..sort(),
      activityUsers: users,
    ).toJson();
  }

  Map<String, dynamic> saveSecret() {
    final member = membership(org, write: true);
    final name = _bounded(text('name'), 'Secret name');
    final project = _bounded(text('project'), 'Project', max: 80);
    final description = _bounded(
      text('description'),
      'Description',
      max: 1000,
      empty: true,
    );
    final environment = text('environment');
    final kind = text('kind');
    if (!['Development', 'Staging', 'Production'].contains(environment)) {
      _fail('Choose a valid environment.');
    }
    if (![
      'API key',
      'Environment variable',
      'Password',
      'Username and password',
      'Certificate',
      'Other',
    ].contains(kind)) {
      _fail('Choose a valid secret type.');
    }
    final value = args['value'] as String?;
    final username = args['username'] as String?;
    if (value != null && (value.isEmpty || value.length > 65536)) {
      _fail('Secret value must be 1–65536 characters.');
    }
    if (username != null &&
        (username.trim().isEmpty || username.length > 320)) {
      _fail('Username must be 1–320 characters and cannot be blank.');
    }
    var url = (args['url'] as String?)?.trim();
    if (url != null && url.isEmpty) url = null;
    if (url != null) {
      final uri = Uri.tryParse(url);
      if (url.length > 2048 ||
          uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          RegExp(r'\s').hasMatch(url)) {
        _fail('Enter an http:// or https:// URL without embedded credentials.');
      }
    }
    final rawExpiry = args['expiresAt'] as String?;
    DateTime? expiry = rawExpiry == null ? null : DateTime.parse(rawExpiry);
    if (expiry != null) {
      if (expiry.year < 1900 || expiry.year > 9999) {
        _fail('Choose an expiry date between 1900 and 9999.');
      }
      expiry = DateTime.utc(expiry.year, expiry.month, expiry.day);
    }
    final id = args['id'] as String?;
    final previous = id == null ? null : findSecret(id, write: true);
    requireProject(member, project, write: true);
    final exists =
        _contains(projectNames(org), project) ||
        _contains(scope(member, 'writeProjects') ?? [], project);
    if (!exists && !canCreate(member)) {
      _fail('You do not have permission to create projects.');
    }
    if (previous == null && value == null) _fail('Enter a secret value.');
    if (rows('secrets').any(
      (s) =>
          s['organizationId'] == org &&
          s['id'] != id &&
          (s['name'] as String).toLowerCase() == name.toLowerCase() &&
          (s['project'] as String).toLowerCase() == project.toLowerCase() &&
          s['environment'] == environment,
    )) {
      _fail(
        'A secret with this name already exists in this project and environment.',
      );
    }
    String? storedUsername;
    if (kind == 'Username and password') {
      storedUsername = username ?? previous?['username'] as String?;
      if (storedUsername == null) {
        _fail('Enter a username for this secret type.');
      }
    } else if (username != null) {
      _fail('Username is only available for the username and password type.');
    }
    final valueChanged =
        previous == null || (value != null && value != previous['value']);
    final usernameChanged = storedUsername != previous?['username'];
    final replaceMetadata =
        args['replaceMetadata'] as bool? ??
        (args['url'] != null || args['expiresAt'] != null);
    final storedUrl = replaceMetadata ? url : previous?['url'] as String?;
    final storedExpiry = replaceMetadata
        ? expiry?.toIso8601String()
        : previous?['expiresAt'] as String?;
    final timestamp = now;
    final secret = <String, dynamic>{
      '__className__': 'SecretView',
      'id': id ?? newId('secret'),
      'organizationId': org,
      'name': name,
      'project': project,
      'environment': environment,
      'kind': kind,
      'description': description,
      'value': value ?? previous?['value'],
      'username': storedUsername,
      'url': storedUrl,
      'expiresAt': storedExpiry,
      'needsRotation': !valueChanged && previous['needsRotation'] == true,
      'version': (previous?['version'] as int? ?? 0) + 1,
      'createdAt': previous?['createdAt'] ?? timestamp,
      'updatedAt': timestamp,
    };
    final changedFields = <String>[
      if (valueChanged) 'value',
      if (usernameChanged) 'username',
      if (valueChanged && previous?['needsRotation'] == true) 'rotation status',
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
    if (previous != null) {
      retainProject(org, previous['project'] as String);
      rows('secrets').remove(previous);
    }
    retainProject(org, project);
    rows('secrets').add(secret);
    event(
      org,
      previous == null
          ? 'created'
          : changedFields.isEmpty
          ? 'saved'
          : valueChanged || usernameChanged
          ? 'rotated'
          : 'updated',
      name,
      secret: secret,
      details: previous == null
          ? null
          : changedFields.isEmpty
          ? 'Saved without changes'
          : 'Changed: ${changedFields.join(', ')}',
    );
    return secretView(secret);
  }

  Object reveal({required bool fields}) {
    final secret = findSecret(text('id'));
    event(
      org,
      'revealed',
      secret['name'] as String,
      secret: secret,
      details: fields
          ? secret['username'] == null
                ? 'Field: value'
                : 'Fields: username, password'
          : null,
    );
    return fields
        ? SecretFields(
            value: secret['value'] as String,
            username: secret['username'] as String?,
          ).toJson()
        : secret['value'] as String;
  }

  Map<String, dynamic> copySecret() {
    final secret = findSecret(text('id'));
    final field = args['field'] as String? ?? 'value';
    if (!['value', 'username'].contains(field)) {
      _fail('Choose a valid secret field.');
    }
    final value = secret[field] as String?;
    if (value == null) _fail('This secret has no username.');
    final eventId = event(
      org,
      'copy requested',
      secret['name'] as String,
      secret: secret,
      details:
          'Field: ${field == 'value' && secret['kind'] == 'Username and password' ? 'password' : field}',
    );
    return SecretCopy(eventId: eventId, value: value).toJson();
  }

  void confirmCopy() {
    final member = membership(org);
    final item = rows('activity')
        .where(
          (e) =>
              e['id'] == args['eventId'] &&
              e['organizationId'] == org &&
              e['secretId'] == args['secretId'] &&
              e['actorId'] == actor &&
              ['copy requested', 'copied'].contains(e['action']),
        )
        .firstOrNull;
    if (item == null) _fail('Copy request not found.');
    if (!canReadEvent(member, item)) _fail('Project access denied.');
    item['action'] = 'copied';
  }

  void deleteSecret() {
    final secret = findSecret(text('id'), write: true);
    retainProject(org, secret['project'] as String);
    event(org, 'deleted', secret['name'] as String, secret: secret);
    rows('secrets').remove(secret);
  }

  void rotate(Map<String, dynamic> secret, bool required, {String? details}) {
    if ((secret['needsRotation'] == true) == required) return;
    secret['needsRotation'] = required;
    secret['updatedAt'] = now;
    event(
      secret['organizationId'] as String,
      required ? 'marked needs rotating' : 'cleared rotation flag',
      secret['name'] as String,
      secret: secret,
      details: details,
    );
  }

  List<Map<String, dynamic>> secretActivity() {
    final id = text('secretId');
    findSecret(id);
    var items = visibleEvents().where((e) => e['secretId'] == id).toList();
    final cursor = args['beforeEventId'] as String?;
    if (cursor != null) {
      if ((args['offset'] as int? ?? 0) != 0) {
        _fail('Use either an activity cursor or an offset, not both.');
      }
      final index = items.indexWhere((e) => e['id'] == cursor);
      if (index < 0) _fail('Activity page not found. Refresh the history.');
      items = items.skip(index + 1).toList();
    }
    return page(items).map((e) => AuditView.fromJson(e).toJson()).toList();
  }
}
