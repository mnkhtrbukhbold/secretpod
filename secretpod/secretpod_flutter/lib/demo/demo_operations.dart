part of 'demo_client.dart';

Never _fail(String message) => throw VaultException(message: message);

String _bounded(
  String value,
  String label, {
  int max = 120,
  bool empty = false,
}) {
  final trimmed = value.trim();
  if ((!empty && trimmed.isEmpty) || trimmed.length > max) {
    _fail('$label must be ${empty ? 0 : 1}–$max characters.');
  }
  return trimmed;
}

String _email(String value) {
  final email = _bounded(value, 'Email', max: 254).toLowerCase();
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    _fail('Enter a valid email address.');
  }
  return email;
}

bool _contains(Iterable<String> values, String value) =>
    values.any((item) => item.toLowerCase() == value.toLowerCase());

const _scopeKeys = [
  'readProjects',
  'writeProjects',
  'deniedReadProjects',
  'deniedWriteProjects',
  'canCreateProjects',
];

class _DemoState {
  _DemoState(this.data, this.args);
  final Map<String, dynamic> data;
  final Map<String, dynamic> args;

  List<Map<String, dynamic>> rows(String key) =>
      (data[key] as List).cast<Map<String, dynamic>>();
  String get actor => data['accountId'] as String;
  String get org => args['organizationId'] as String;
  String text(String key) => args[key] as String;
  String get now => DateTime.now().toUtc().toIso8601String();
  String newId(String kind) {
    final sequence = (data['nextId'] as int? ?? 0) + 1;
    data['nextId'] = sequence;
    return 'demo-$kind-${DateTime.now().microsecondsSinceEpoch}-$sequence-${Random.secure().nextInt(1 << 30)}';
  }

  Map<String, dynamic> account([String? id]) =>
      rows('accounts').where((a) => a['id'] == (id ?? actor)).firstOrNull ??
      (throw VaultException(
        message: 'Demo account not found. Reset the demo.',
      ));
  String memberId(Map<String, dynamic> member) =>
      (member['account'] as Map)['id'] as String;
  Map<String, dynamic> organization(String id) =>
      rows('organizations').where((o) => o['id'] == id).firstOrNull ??
      (throw VaultException(message: 'Organization not found.'));
  Map<String, dynamic> membership(
    String id, {
    bool owner = false,
    bool write = false,
    String? accountId,
  }) {
    final member = rows('members')
        .where(
          (m) =>
              m['organizationId'] == id && memberId(m) == (accountId ?? actor),
        )
        .firstOrNull;
    if (member == null || member['accessDisabled'] == true) {
      _fail('Organization access denied.');
    }
    if (!['owner', 'editor', 'reader'].contains(member['role']) ||
        (owner && member['role'] != 'owner') ||
        (write && member['role'] == 'reader')) {
      _fail('Your role does not allow this action.');
    }
    return member;
  }

  List<String>? scope(Map<String, dynamic> member, String key) {
    final value = member[key];
    if (value == null) return null;
    return value is List && value.every((e) => e is String)
        ? value.cast<String>()
        : <String>[];
  }

  bool validScope(Map<String, dynamic> member, String key) =>
      member[key] == null ||
      (member[key] is List && (member[key] as List).every((e) => e is String));
  bool canRead(Map<String, dynamic> member, String project) =>
      member['role'] == 'owner' ||
      (validScope(member, 'deniedReadProjects') &&
          !_contains(scope(member, 'deniedReadProjects') ?? [], project) &&
          (member['readProjects'] == null ||
              _contains(scope(member, 'readProjects')!, project)));
  bool canWrite(Map<String, dynamic> member, String project) =>
      member['role'] == 'owner' ||
      (member['role'] == 'editor' &&
          canRead(member, project) &&
          validScope(member, 'deniedWriteProjects') &&
          !_contains(scope(member, 'deniedWriteProjects') ?? [], project) &&
          (member['writeProjects'] == null ||
              _contains(scope(member, 'writeProjects')!, project)));
  bool canCreate(Map<String, dynamic> member) =>
      member['role'] == 'owner' ||
      (member['role'] == 'editor' &&
          member['canCreateProjects'] != false &&
          member['readProjects'] == null &&
          member['writeProjects'] == null &&
          validScope(member, 'deniedReadProjects') &&
          validScope(member, 'deniedWriteProjects'));
  bool readsAll(Map<String, dynamic> member) =>
      member['role'] == 'owner' ||
      (member['readProjects'] == null &&
          validScope(member, 'deniedReadProjects') &&
          (scope(member, 'deniedReadProjects') ?? []).isEmpty);
  void requireProject(
    Map<String, dynamic> member,
    String project, {
    bool write = false,
  }) {
    if (!(write ? canWrite(member, project) : canRead(member, project))) {
      _fail('Project access denied.');
    }
  }

  List<String> projectNames(String id) {
    final names = <String, String>{'default': 'Default'};
    for (final name
        in ((data['projects'] as Map)[id] as List? ?? []).cast<String>()) {
      names.putIfAbsent(name.toLowerCase(), () => name);
    }
    for (final secret in rows(
      'secrets',
    ).where((s) => s['organizationId'] == id)) {
      final name = secret['project'] as String;
      names.putIfAbsent(name.toLowerCase(), () => name);
    }
    return names.values.toList();
  }

  void retainProject(String id, String name) {
    if (name.toLowerCase() == 'default') return;
    final projects =
        ((data['projects'] as Map).putIfAbsent(id, () => <String>[]) as List);
    if (!_contains(projects.cast<String>(), name)) projects.add(name);
  }

  Map<String, dynamic> normalizedScopes(
    String id, {
    Map<String, dynamic>? existing,
  }) {
    final role = text('role');
    if (!['reader', 'editor'].contains(role)) _fail('Choose reader or editor.');
    final names = {
      for (final name in projectNames(id)) name.toLowerCase(): name,
    };
    if (existing != null) {
      for (final key in _scopeKeys.take(4)) {
        for (final name in scope(existing, key) ?? <String>[]) {
          names.putIfAbsent(name.toLowerCase(), () => name);
        }
      }
    }
    List<String>? normalize(String key) {
      if (args[key] == null) return null;
      final normalized = <String>{};
      for (final value in (args[key] as List).cast<String>()) {
        final name = names[value.trim().toLowerCase()];
        if (name == null) _fail('Choose an existing project.');
        normalized.add(name);
      }
      return normalized.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }

    final read = normalize('readProjects');
    final write = normalize('writeProjects');
    final deniedRead = normalize('deniedReadProjects') ?? <String>[];
    final deniedWrite = normalize('deniedWriteProjects') ?? <String>[];
    final create =
        args['canCreateProjects'] as bool? ??
        (role == 'editor' && read == null && write == null);
    if ((read != null && deniedRead.isNotEmpty) ||
        (write != null && deniedWrite.isNotEmpty)) {
      _fail('Use selected projects or exclusions for each permission.');
    }
    if (create && (role != 'editor' || read != null || write != null)) {
      _fail(
        'Project creators must use all projects with exclusions for read and write access.',
      );
    }
    if (role == 'reader' &&
        ((write != null && write.isNotEmpty) || deniedWrite.isNotEmpty)) {
      _fail('Readers cannot have write access.');
    }
    if (role == 'editor' &&
        ((read != null &&
                (write == null || write.any((p) => !read.contains(p)))) ||
            (write != null && write.any(deniedRead.contains)))) {
      _fail('Write access requires read access to the same projects.');
    }
    if (role == 'editor' && write == null) {
      deniedWrite.addAll(deniedRead.where((p) => !deniedWrite.contains(p)));
      deniedWrite.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    return {
      'role': role,
      'readProjects': read,
      'writeProjects': role == 'reader' ? <String>[] : write,
      'deniedReadProjects': deniedRead,
      'deniedWriteProjects': role == 'reader' ? <String>[] : deniedWrite,
      'canCreateProjects': create,
    };
  }

  List<T> page<T>(Iterable<T> values) {
    final offset = args['offset'] as int? ?? 0;
    final limit = args['limit'] as int? ?? 10;
    if (offset < 0 || offset > 2147483647 || limit < 1 || limit > 100) {
      _fail('Use a non-negative offset and a page size from 1 to 100.');
    }
    return values.skip(offset).take(limit).toList();
  }

  Map<String, dynamic> memberView(Map<String, dynamic> member) =>
      MemberView.fromJson({
        ...member,
        'account': account(memberId(member)),
        'canCreateProjects': canCreate(member),
      }).toJson();
  Map<String, dynamic> orgView(
    Map<String, dynamic> organization,
    Map<String, dynamic> member,
  ) => OrganizationView.fromJson({
    ...organization,
    'role': member['role'],
    for (final key in _scopeKeys) key: member[key],
    'canCreateProjects': canCreate(member),
  }).toJson();
  Map<String, dynamic> secretView(Map<String, dynamic> secret) =>
      SecretView.fromJson(secret).toJson();

  String event(
    String id,
    String action,
    String target, {
    Map<String, dynamic>? secret,
    String? details,
    String? project,
  }) {
    final user = account();
    final eventId = newId('event');
    rows('activity').add({
      ...AuditView(
        id: eventId,
        actor: '${user['name']} (${user['email']})',
        actorId: actor,
        action: action,
        target: target,
        createdAt: DateTime.now().toUtc(),
        secretId: secret?['id'] as String?,
        version: secret?['version'] as int?,
        details: details,
      ).toJson(),
      'organizationId': id,
      'project': project ?? secret?['project'],
    });
    return eventId;
  }

  Object? dispatch(String route) {
    switch (route) {
      case 'account/login':
        return AuthResult(
          token: 'demo-session',
          account: AccountView.fromJson(account()),
        ).toJson();
      case 'vault/logout':
        return null;
      case 'account/register':
      case 'account/registerFromInvitation':
      case 'profile/updateEmail':
      case 'profile/changePassword':
        _fail(
          'Account registration and credential changes are unavailable in this demo.',
        );
      case 'vault/addMember':
        _fail(
          'Direct member addition is disabled. Create a demo invitation and wait for acceptance.',
        );
      case 'invitation/profile':
        return AccountView.fromJson(account()).toJson();
      case 'profile/updateName':
        account()['name'] = _bounded(text('name'), 'Name', max: 80);
        return AccountView.fromJson(account()).toJson();
      case 'profile/updateTheme':
        if (!['system', 'light', 'dark'].contains(args['themeMode'])) {
          _fail('Choose System, Light, or Dark appearance.');
        }
        account()['themeMode'] = text('themeMode');
        return AccountView.fromJson(account()).toJson();
      case 'invitation/updatePolicy':
        return updatePolicy();
      case 'vault/organizations':
        return organizations();
      case 'vault/createOrganization':
        return createOrganization();
      case 'vault/renameOrganization':
        return renameOrganization();
      case 'vault/createProject':
        return createProject();
      case 'vault/members':
        membership(org);
        return page(
          rows('members').where((m) => m['organizationId'] == org),
        ).map(memberView).toList();
      case 'vault/updateMemberAccess':
        return updateMemberAccess();
      case 'vault/memberRemovalSecrets':
        removableMember();
        return page(accessedSecrets()).map(secretView).toList();
      case 'vault/setMemberEnabled':
        return changeMember(remove: false);
      case 'vault/removeMember':
        return changeMember(remove: true);
      case 'vault/listSecrets':
        return page(
          visibleSecrets().where(matchesSecret),
        ).map(secretView).toList();
      case 'vault/summary':
        return summary();
      case 'vault/saveSecret':
        return saveSecret();
      case 'vault/revealSecret':
        return reveal(fields: false);
      case 'vault/revealSecretFields':
        return reveal(fields: true);
      case 'vault/copySecret':
        return copySecret();
      case 'vault/confirmCopy':
        confirmCopy();
        return null;
      case 'vault/deleteSecret':
        deleteSecret();
        return null;
      case 'vault/setSecretRotationRequired':
        final secret = findSecret(text('id'), write: true);
        rotate(secret, args['required'] as bool);
        return secretView(secret);
      case 'vault/activity':
        return page(
          filteredEvents(visibleEvents()),
        ).map((e) => AuditView.fromJson(e).toJson()).toList();
      case 'vault/secretActivity':
        return secretActivity();
      case 'invitation/create':
        return createInvitation();
      case 'invitation/inbox':
        return page(
          rows(
            'invitations',
          ).reversed.where((i) => i['recipientEmail'] == account()['email']),
        ).map(invitationView).toList();
      case 'invitation/outgoing':
        membership(org, owner: true);
        return page(
          rows('invitations').reversed.where((i) => i['organizationId'] == org),
        ).map(invitationView).toList();
      case 'account/previewInvitation':
        return previewInvitation();
      case 'invitation/accept':
        acceptInvitation();
        return null;
      case 'invitation/decline':
        declineInvitation();
        return null;
      case 'invitation/revoke':
        membership(org, owner: true);
        final invite = pendingInvitation(text('id'));
        if (invite['organizationId'] != org) _fail('Invitation access denied.');
        finishInvitation(invite, 'revoked');
        return null;
      case 'account/declineInvitation':
        finishInvitation(
          invitationByToken(text('token')),
          'declined',
          record: false,
        );
        return null;
      default:
        _fail('This API operation is unavailable in the demo.');
    }
  }
}
