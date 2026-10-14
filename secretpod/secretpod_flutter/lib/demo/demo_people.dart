part of 'demo_client.dart';

extension _DemoPeople on _DemoState {
  List<Map<String, dynamic>> organizations() =>
      page(
            rows(
              'members',
            ).where((m) => memberId(m) == actor && m['accessDisabled'] != true),
          )
          .map((m) => orgView(organization(m['organizationId'] as String), m))
          .toList();

  Map<String, dynamic> createOrganization() {
    final name = _bounded(text('name'), 'Organization name', max: 80);
    final user = account();
    final organization = OrganizationView(
      id: newId('org'),
      name: name,
      role: 'owner',
      createdAt: DateTime.now().toUtc(),
    ).toJson();
    final member = {
      ...MemberView(
        account: AccountView.fromJson(user),
        role: 'owner',
        canCreateProjects: true,
      ).toJson(),
      'organizationId': organization['id'],
    };
    rows('organizations').add(organization);
    rows('members').add(member);
    (data['projects'] as Map)[organization['id']] = <String>[];
    event(organization['id'] as String, 'created organization', name);
    return orgView(organization, member);
  }

  Map<String, dynamic> renameOrganization() {
    final member = membership(org, owner: true);
    final name = _bounded(text('name'), 'Organization name', max: 80);
    final item = organization(org);
    if (item['name'] != name) {
      final old = item['name'];
      item['name'] = name;
      event(org, 'renamed organization', name, details: 'Previous name: $old');
    }
    return orgView(item, member);
  }

  String createProject() {
    final member = membership(org);
    if (!canCreate(member)) {
      _fail('You do not have permission to create projects.');
    }
    final name = _bounded(text('name'), 'Project', max: 80);
    requireProject(member, name, write: true);
    if (_contains(projectNames(org), name)) {
      _fail('A project with this name already exists.');
    }
    retainProject(org, name);
    event(org, 'created project', name, project: name);
    return name;
  }

  Map<String, dynamic> removableMember() {
    membership(org, owner: true);
    final id = text('accountId');
    final member = rows(
      'members',
    ).where((m) => m['organizationId'] == org && memberId(m) == id).firstOrNull;
    if (member == null) _fail('Member not found.');
    if (id == actor || member['role'] == 'owner') {
      _fail('The organization owner cannot be removed or disabled.');
    }
    return member;
  }

  Map<String, dynamic> updateMemberAccess() {
    final member = removableMember();
    final scopes = normalizedScopes(org, existing: member);
    if (scopes.entries.any(
      (e) => jsonEncode(member[e.key]) != jsonEncode(e.value),
    )) {
      member.addAll(scopes);
      event(
        org,
        'changed member access',
        account(memberId(member))['email'] as String,
        details: 'Role: ${scopes['role']}; project access updated',
      );
    }
    return memberView(member);
  }

  List<Map<String, dynamic>> accessedSecrets() {
    final utcOffset = args['utcOffsetMinutes'] as int? ?? 0;
    if (utcOffset < -720 || utcOffset > 840) _fail('Invalid time zone offset.');
    final localNow = DateTime.now().toUtc().add(Duration(minutes: utcOffset));
    final today = DateTime.utc(localNow.year, localNow.month, localNow.day);
    const actions = {
      'created',
      'updated',
      'rotated',
      'saved',
      'revealed',
      'copy requested',
      'copied',
    };
    final ids = rows('activity')
        .where(
          (e) =>
              e['organizationId'] == org &&
              e['actorId'] == args['accountId'] &&
              actions.contains(e['action']),
        )
        .map((e) => e['secretId'])
        .toSet();
    return rows('secrets')
        .where(
          (s) =>
              s['organizationId'] == org &&
              ids.contains(s['id']) &&
              (s['expiresAt'] == null ||
                  !DateTime.parse(s['expiresAt'] as String).isBefore(today)),
        )
        .toList()
      ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
  }

  Object? changeMember({required bool remove}) {
    final member = removableMember();
    final enabled = !remove && args['enabled'] == true;
    final reviewed = (args['reviewedSecretIds'] as List).cast<String>().toSet();
    final selected = (args['rotateSecretIds'] as List).cast<String>().toSet();
    if (enabled) {
      if (reviewed.isNotEmpty || selected.isNotEmpty) {
        _fail('Re-enabling access does not change rotation flags.');
      }
    } else {
      final secrets = accessedSecrets();
      final current = secrets.map((s) => s['id'] as String).toSet();
      if (current.length != reviewed.length || !current.containsAll(reviewed)) {
        _fail(
          'Secret access changed. Refresh the review before changing this member’s access.',
        );
      }
      if (!current.containsAll(selected)) {
        _fail('Choose secrets from this member’s current access review.');
      }
      for (final secret in secrets.where((s) => selected.contains(s['id']))) {
        rotate(
          secret,
          true,
          details:
              '${remove ? 'Member removed' : 'Member access disabled'}: ${args['accountId']}',
        );
      }
    }
    final user = account(memberId(member));
    if (remove || (member['accessDisabled'] == true) == enabled) {
      if (remove) {
        rows('members').remove(member);
      } else {
        member['accessDisabled'] = !enabled;
      }
      event(
        org,
        remove
            ? 'removed member'
            : enabled
            ? 'enabled member access'
            : 'disabled member access',
        '${user['name']} (${user['email']})',
        details:
            'Account: ${user['id']}; selected for rotation: ${selected.length}',
      );
    }
    return remove ? null : memberView(member);
  }

  bool allowsInvitation(Map<String, dynamic> user, String sender) {
    final policy = user['invitationPolicy'] ?? 'all';
    return policy == 'all' ||
        (policy == 'sameDomain' &&
            (user['email'] as String).split('@').last.toLowerCase() ==
                sender.split('@').last.toLowerCase());
  }

  String invitationStatus(Map<String, dynamic> invite) =>
      invite['status'] == 'pending' &&
          !DateTime.parse(
            invite['expiresAt'] as String,
          ).isAfter(DateTime.now().toUtc())
      ? 'expired'
      : invite['status'] as String;

  Map<String, dynamic> invitationView(Map<String, dynamic> invite) =>
      InvitationView.fromJson({
        ...invite,
        'organizationName':
            rows('organizations')
                .where((o) => o['id'] == invite['organizationId'])
                .firstOrNull?['name'] ??
            invite['organizationName'],
        'status': invitationStatus(invite),
        if (invitationStatus(invite) == 'expired')
          'respondedAt': invite['expiresAt'],
      }).toJson();

  Map<String, dynamic> pendingInvitation(String id) {
    final invite = rows('invitations').where((i) => i['id'] == id).firstOrNull;
    if (invite == null || invitationStatus(invite) != 'pending') {
      _fail('This invitation is no longer pending.');
    }
    return invite;
  }

  Map<String, dynamic> invitationByToken(String token) {
    final invite = rows(
      'invitations',
    ).where((i) => i['token'] == token && token.isNotEmpty).firstOrNull;
    if (invite == null) _fail('Invalid demo invitation link.');
    return pendingInvitation(invite['id'] as String);
  }

  Map<String, dynamic> previewInvitation() {
    final invite = invitationByToken(text('token'));
    final recipient = rows(
      'accounts',
    ).where((a) => a['email'] == invite['recipientEmail']).firstOrNull;
    if (recipient != null &&
        !allowsInvitation(recipient, invite['inviterEmail'] as String)) {
      _fail('Your invitation preferences block this invitation.');
    }
    return invitationView(invite);
  }

  void finishInvitation(
    Map<String, dynamic> invite,
    String status, {
    bool record = true,
  }) {
    invite['status'] = status;
    invite['respondedAt'] = now;
    if (record) {
      event(
        invite['organizationId'] as String,
        'invitation $status',
        invite['recipientEmail'] as String,
        details: 'Invitation ${invite['id']}',
      );
    }
  }

  Map<String, dynamic> createInvitation() {
    membership(org, owner: true);
    final email = _email(text('email'));
    final name = _bounded(text('name'), 'Recipient name', max: 80);
    final scopes = normalizedScopes(org);
    final sender = account();
    final recipient = rows(
      'accounts',
    ).where((a) => a['email'] == email).firstOrNull;
    if (recipient != null) {
      if (!allowsInvitation(recipient, sender['email'] as String)) {
        _fail(
          'This recipient is not accepting invitations from this organization.',
        );
      }
      if (rows('members').any(
        (m) => m['organizationId'] == org && memberId(m) == recipient['id'],
      )) {
        _fail('This person is already a member.');
      }
    }
    final invites = rows('invitations');
    if (invites.any(
      (i) =>
          i['organizationId'] == org &&
          i['recipientEmail'] == email &&
          invitationStatus(i) == 'pending',
    )) {
      _fail('A pending invitation already exists for this email.');
    }
    final time = DateTime.now().toUtc();
    if (invites.any(
      (i) =>
          i['organizationId'] == org &&
          i['recipientEmail'] == email &&
          i['status'] == 'declined' &&
          i['respondedAt'] != null &&
          DateTime.parse(
            i['respondedAt'] as String,
          ).isAfter(time.subtract(const Duration(days: 7))),
    )) {
      _fail(
        'This person declined recently. Wait seven days before inviting them again.',
      );
    }
    if (invites
                .where(
                  (i) =>
                      (i['inviterId'] == actor ||
                          i['inviterEmail'] == sender['email']) &&
                      DateTime.parse(
                        i['createdAt'] as String,
                      ).isAfter(time.subtract(const Duration(hours: 1))),
                )
                .length >=
            20 ||
        invites
                .where(
                  (i) =>
                      i['organizationId'] == org &&
                      invitationStatus(i) == 'pending',
                )
                .length >=
            100) {
      _fail(
        'Invitation limit reached. Try again later or revoke pending invitations.',
      );
    }
    final random = Random.secure();
    final token = base64UrlEncode(
      List.generate(32, (_) => random.nextInt(256)),
    );
    final invite = <String, dynamic>{
      '__className__': 'InvitationView',
      'id': newId('invitation'),
      'organizationId': org,
      'organizationName': organization(org)['name'],
      'inviterId': actor,
      'inviterName': sender['name'],
      'inviterEmail': sender['email'],
      'recipientEmail': email,
      'recipientName': name,
      ...scopes,
      'status': 'pending',
      'createdAt': time.toIso8601String(),
      'expiresAt': time.add(const Duration(days: 7)).toIso8601String(),
      'token': token,
    };
    invites.add(invite);
    event(
      org,
      'invited ${scopes['role']}',
      email,
      details: 'Invitation ${invite['id']}',
    );
    return InvitationCreated(
      invitation: InvitationView.fromJson(invitationView(invite)),
      token: token,
    ).toJson();
  }

  void acceptInvitation() {
    final invite = invitationByToken(text('token'));
    if (invite['id'] != args['id']) {
      _fail('This link belongs to a different invitation.');
    }
    final user = account();
    if (user['email'] != invite['recipientEmail']) {
      _fail('Sign in with the email address this invitation was sent to.');
    }
    if (!allowsInvitation(user, invite['inviterEmail'] as String)) {
      _fail('Your invitation preferences block this invitation.');
    }
    materializeExternalInvitation(invite);
    final inviter =
        invite['inviterId'] as String? ??
        rows('accounts')
                .where((a) => a['email'] == invite['inviterEmail'])
                .firstOrNull?['id']
            as String?;
    if (inviter == null) _fail('The invitation sender no longer has access.');
    final organizationId = invite['organizationId'] as String;
    membership(organizationId, owner: true, accountId: inviter);
    if (rows(
      'members',
    ).any(
      (m) => m['organizationId'] == organizationId && memberId(m) == actor,
    )) {
      _fail('You are already a member of this organization.');
    }
    rows('members').add({
      '__className__': 'MemberView',
      'organizationId': organizationId,
      'account': AccountView.fromJson(user).toJson(),
      'role': invite['role'],
      'accessDisabled': false,
      for (final key in _scopeKeys) key: invite[key],
    });
    finishInvitation(invite, 'accepted');
  }

  void materializeExternalInvitation(Map<String, dynamic> invite) {
    final id = invite['organizationId'] as String;
    if (rows('organizations').any((o) => o['id'] == id)) return;
    // The seed includes an invitation from a fictional external workspace.
    // Joining materializes that workspace locally; it contacts no sender.
    final organizationName = _bounded(
      invite['organizationName'] as String,
      'Organization name',
      max: 80,
    );
    final senderEmail = _email(invite['inviterEmail'] as String);
    var sender = rows(
      'accounts',
    ).where((a) => a['email'] == senderEmail).firstOrNull;
    if (sender == null) {
      sender = AccountView(
        id: newId('account'),
        name: _bounded(invite['inviterName'] as String, 'Name', max: 80),
        email: senderEmail,
        invitationPolicy: 'all',
        themeMode: 'system',
      ).toJson();
      rows('accounts').add(sender);
    }
    invite['inviterId'] = sender['id'];
    rows('organizations').add(
      OrganizationView(
        id: id,
        name: organizationName,
        role: 'owner',
        createdAt: DateTime.now().toUtc(),
      ).toJson(),
    );
    rows('members').add({
      ...MemberView(
        account: AccountView.fromJson(sender),
        role: 'owner',
        canCreateProjects: true,
      ).toJson(),
      'organizationId': id,
    });
    (data['projects'] as Map)[id] = <String>[];
    for (final key in _scopeKeys.take(4)) {
      for (final name in scope(invite, key) ?? <String>[]) {
        retainProject(id, _bounded(name, 'Project', max: 80));
      }
    }
    final scopes = _DemoState(data, {
      'role': invite['role'],
      for (final key in _scopeKeys) key: invite[key],
    }).normalizedScopes(id);
    invite.addAll(scopes);
  }

  void declineInvitation() {
    final invite = pendingInvitation(text('id'));
    if (invite['recipientEmail'] != account()['email']) {
      _fail('Invitation access denied.');
    }
    finishInvitation(invite, 'declined');
  }

  Map<String, dynamic> updatePolicy() {
    final policy = text('policy');
    if (!['all', 'sameDomain', 'none'].contains(policy)) {
      _fail('Choose a valid invitation preference.');
    }
    final user = account();
    user['invitationPolicy'] = policy;
    for (final invite in rows('invitations').where(
      (i) =>
          i['recipientEmail'] == user['email'] &&
          invitationStatus(i) == 'pending',
    )) {
      if (!allowsInvitation(user, invite['inviterEmail'] as String)) {
        finishInvitation(invite, 'blocked');
      }
    }
    return AccountView.fromJson(user).toJson();
  }
}
