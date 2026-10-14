import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/demo/demo_client.dart';
import 'package:secretpod_flutter/demo/demo_seed.dart';
import 'package:secretpod_flutter/demo/demo_store.dart';
import 'package:secretpod_flutter/state/invitation_link.dart';

void main() {
  late MemoryDemoStore store;
  late DemoClient transport;
  late Client client;

  setUp(() {
    store = MemoryDemoStore(seed: _fixture);
    transport = DemoClient(store);
    client = Client('https://demo.invalid/', httpClientOverride: transport);
  });

  test(
    'generated client filters and pages metadata without revealing values',
    () async {
      final page = await client.vault.listSecrets(
        'org',
        project: 'WEB',
        offset: 1,
        limit: 1,
      );
      expect(page.map((s) => s.id), ['web-old']);
      final summary = await client.vault.summary('org', project: 'WEB');
      expect(summary.secretCount, 3);
      expect(summary.filteredSecretCount, 2);
      expect(summary.projectCounts, {'Default': 0, 'Web': 2, 'Ops': 1});
      final response = await transport.post(
        Uri.parse('https://demo.invalid/vault/listSecrets'),
        body: jsonEncode({'organizationId': 'org'}),
      );
      expect(response.body, isNot(contains('SYNTHETIC-SECRET')));
      expect(
        await client.vault.listSecrets('org', query: 'certificate'),
        hasLength(1),
      );
      await expectLater(
        client.vault.listSecrets('org', limit: 101),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        client.vault.listSecrets('missing'),
        throwsA(isA<VaultException>()),
      );
    },
  );

  test(
    'save preserves exact credentials and metadata until explicit replacement',
    () async {
      final created = await client.vault.saveSecret(
        'org',
        null,
        ' Database ',
        ' exact\npassword ',
        'Web',
        'Development',
        'Username and password',
        ' Demo ',
        username: ' demo user ',
        url: 'https://example.invalid/db',
        expiresAt: DateTime.utc(2030, 1, 2),
        replaceMetadata: true,
      );
      final fields = await client.vault.revealSecretFields('org', created.id);
      expect(fields.value, ' exact\npassword ');
      expect(fields.username, ' demo user ');
      expect(created.name, 'Database');
      final edited = await client.vault.saveSecret(
        'org',
        created.id,
        'Database renamed',
        null,
        'Web',
        'Development',
        'Username and password',
        '',
      );
      expect(edited.version, 2);
      expect(edited.url, 'https://example.invalid/db');
      expect(edited.expiresAt, DateTime.utc(2030, 1, 2));
      final converted = await client.vault.saveSecret(
        'org',
        created.id,
        'Database renamed',
        null,
        'Web',
        'Development',
        'Password',
        '',
        replaceMetadata: true,
      );
      expect(converted.url, isNull);
      expect(converted.expiresAt, isNull);
      expect(
        (await client.vault.revealSecretFields('org', created.id)).username,
        isNull,
      );
      final events = await client.vault.secretActivity('org', created.id, null);
      expect(
        events.any((e) => e.action == 'updated' && e.details!.contains('name')),
        isTrue,
      );
      expect(
        jsonEncode(events.map((e) => e.toJson()).toList()),
        isNot(contains('exact\npassword')),
      );
      await client.vault.deleteSecret('org', created.id);
      expect(
        (await client.vault.activity('org', action: 'deleted')).single.secretId,
        created.id,
      );
      await expectLater(
        client.vault.revealSecret('org', created.id),
        throwsA(isA<VaultException>()),
      );
    },
  );

  test(
    'copy is requested before confirmation and acknowledgment is idempotent',
    () async {
      final copy = await client.vault.copySecret('org', 'web-new');
      expect(copy.value, 'SYNTHETIC-SECRET-web-new');
      expect(
        (await client.vault.secretActivity(
          'org',
          'web-new',
          null,
        )).first.action,
        'copy requested',
      );
      await expectLater(
        client.vault.confirmCopy('org', 'web-old', copy.eventId),
        throwsA(isA<VaultException>()),
      );
      await client.vault.confirmCopy('org', 'web-new', copy.eventId);
      await client.vault.confirmCopy('org', 'web-new', copy.eventId);
      final events = await client.vault.secretActivity('org', 'web-new', null);
      expect(events.where((e) => e.id == copy.eventId).single.action, 'copied');
      await expectLater(
        client.vault.copySecret('org', 'web-new', field: 'username'),
        throwsA(isA<VaultException>()),
      );
    },
  );

  test(
    'invalid saves roll back and duplicate identity uses case-insensitive matching',
    () async {
      final before = await client.vault.summary('org');
      await expectLater(
        client.vault.saveSecret(
          'org',
          null,
          'Bad',
          'value',
          'New project',
          'Production',
          'Username and password',
          '',
        ),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        client.vault.saveSecret(
          'org',
          null,
          'WEB-NEW',
          'value',
          'web',
          'Production',
          'API key',
          '',
        ),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        client.vault.saveSecret(
          'org',
          null,
          'Bad URL',
          'value',
          'Web',
          'Production',
          'API key',
          '',
          url: 'https://user:password@example.invalid',
        ),
        throwsA(isA<VaultException>()),
      );
      final after = await client.vault.summary('org');
      expect(after.secretCount, before.secretCount);
      expect(after.activityCount, before.activityCount);
      expect(after.projectCounts.containsKey('New project'), isFalse);
    },
  );

  test(
    'rotation flags survive metadata saves and clear after value rotation',
    () async {
      expect(
        (await client.vault.setSecretRotationRequired(
          'org',
          'web-new',
          true,
        )).needsRotation,
        isTrue,
      );
      final unchanged = await client.vault.saveSecret(
        'org',
        'web-new',
        'web-new',
        null,
        'Web',
        'Production',
        'API key',
        'changed',
      );
      expect(unchanged.needsRotation, isTrue);
      final rotated = await client.vault.saveSecret(
        'org',
        'web-new',
        'web-new',
        'replacement',
        'Web',
        'Production',
        'API key',
        'changed',
      );
      expect(rotated.needsRotation, isFalse);
      expect(rotated.version, 3);
    },
  );

  test(
    'organization and project changes persist and duplicate projects fail',
    () async {
      final org = await client.vault.createOrganization(' New team ');
      expect(org.name, 'New team');
      expect(org.role, 'owner');
      expect((await client.vault.members(org.id)).single.account.id, 'owner');
      expect(await client.vault.createProject(org.id, ' Mobile '), 'Mobile');
      await expectLater(
        client.vault.createProject(org.id, 'mobile'),
        throwsA(isA<VaultException>()),
      );
      await client.vault.renameOrganization(org.id, 'Renamed team');
      final reopened = Client(
        'https://demo.invalid/',
        httpClientOverride: DemoClient(store),
      );
      expect((await reopened.vault.organizations()).last.name, 'Renamed team');
      expect((await reopened.vault.summary(org.id)).projectCounts, {
        'Default': 0,
        'Mobile': 0,
      });
    },
  );

  test(
    'member review protects owner and marks only reviewed accessed secrets',
    () async {
      await expectLater(
        client.vault.updateMemberAccess('org', 'owner', 'reader'),
        throwsA(isA<VaultException>()),
      );
      final member = await client.vault.updateMemberAccess(
        'org',
        'editor',
        'editor',
        readProjects: ['web'],
        writeProjects: ['Web'],
        canCreateProjects: false,
      );
      expect(member.readProjects, ['Web']);
      await expectLater(
        client.vault.updateMemberAccess(
          'org',
          'editor',
          'editor',
          readProjects: ['Web'],
          writeProjects: ['Ops'],
          canCreateProjects: false,
        ),
        throwsA(isA<VaultException>()),
      );
      expect(
        (await client.vault.memberRemovalSecrets(
          'org',
          'editor',
        )).map((s) => s.id),
        ['web-new'],
      );
      await expectLater(
        client.vault.setMemberEnabled('org', 'editor', false, [], []),
        throwsA(isA<VaultException>()),
      );
      final disabled = await client.vault.setMemberEnabled(
        'org',
        'editor',
        false,
        ['web-new'],
        ['web-new'],
      );
      expect(disabled.accessDisabled, isTrue);
      expect(
        (await client.vault.listSecrets(
          'org',
        )).firstWhere((s) => s.id == 'web-new').needsRotation,
        isTrue,
      );
      expect(
        (await client.vault.setMemberEnabled(
          'org',
          'editor',
          true,
          [],
          [],
        )).accessDisabled,
        isFalse,
      );
      await client.vault.removeMember('org', 'editor', ['web-new'], []);
      expect((await client.vault.members('org')).map((m) => m.account.id), [
        'owner',
      ]);
    },
  );

  test(
    'scopes filter metadata and history before pagination and reject moves',
    () async {
      await store.access((data) {
        data['accountId'] = 'editor';
        final member = (data['members'] as List).last as Map;
        member['readProjects'] = ['Web'];
        member['writeProjects'] = ['Web'];
        member['canCreateProjects'] = false;
      }, write: true);
      expect((await client.vault.listSecrets('org')).length, 2);
      expect((await client.vault.summary('org')).projectCounts, {'Web': 2});
      await expectLater(
        client.vault.revealSecret('org', 'ops'),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        client.vault.saveSecret(
          'org',
          'web-new',
          'web-new',
          null,
          'Ops',
          'Production',
          'API key',
          '',
        ),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        client.vault.createProject('org', 'Mobile'),
        throwsA(isA<VaultException>()),
      );
      expect((await client.vault.activity('org')).map((e) => e.id), [
        'access-web',
      ]);
    },
  );

  test('activity dates, filters and cursors match summary counts', () async {
    final events = await client.vault.activity(
      'org',
      project: 'web',
      user: 'id:editor',
      from: DateTime.utc(2026, 1, 1),
      until: DateTime.utc(2026, 2, 1),
    );
    expect(events.map((e) => e.id), ['access-web']);
    final summary = await client.vault.summary(
      'org',
      activityProject: 'WEB',
      activityUser: 'id:editor',
    );
    expect(summary.filteredActivityCount, 1);
    expect(
      summary.activityUsers?['id:editor'],
      'Editor (editor@example.invalid)',
    );
    await client.vault.revealSecret('org', 'web-new');
    final first = await client.vault.secretActivity(
      'org',
      'web-new',
      null,
      limit: 1,
    );
    final next = await client.vault.secretActivity(
      'org',
      'web-new',
      first.single.id,
      limit: 1,
    );
    expect(next.single.id, 'access-web');
    await expectLater(
      client.vault.activity(
        'org',
        from: DateTime.utc(2026, 2),
        until: DateTime.utc(2026, 1),
      ),
      throwsA(isA<VaultException>()),
    );
  });

  test(
    'invitations can be issued, previewed, revoked and accepted locally',
    () async {
      final created = await client.invitation.create(
        'org',
        'new@example.invalid',
        'New person',
        'reader',
        readProjects: ['Web'],
      );
      expect(
        invitationTokenFromLink(
          'https://demo.invalid/#invite=${created.token}',
        ),
        created.token,
      );
      expect(
        (await client.account.previewInvitation(created.token)).id,
        created.invitation.id,
      );
      expect(
        (await client.invitation.outgoing('org')).first.id,
        created.invitation.id,
      );
      await client.invitation.revoke('org', created.invitation.id);
      await expectLater(
        client.account.previewInvitation(created.token),
        throwsA(isA<VaultException>()),
      );
      expect((await client.invitation.inbox()).single.id, 'incoming');
      await expectLater(
        client.invitation.accept('incoming', 'wrong'),
        throwsA(isA<VaultException>()),
      );
      await client.invitation.accept('incoming', 'demo-incoming-token');
      expect((await client.vault.organizations()).map((o) => o.id), [
        'org',
        'other-org',
      ]);
      expect((await client.invitation.inbox()).single.status, 'accepted');
      await expectLater(
        client.invitation.accept('incoming', 'demo-incoming-token'),
        throwsA(isA<VaultException>()),
      );
    },
  );

  test(
    'profile changes are local and credential operations explicitly fail',
    () async {
      expect(
        (await client.profile.updateName(' Demo owner ')).name,
        'Demo owner',
      );
      expect((await client.profile.updateTheme('dark')).themeMode, 'dark');
      expect(
        (await client.invitation.updatePolicy('none')).invitationPolicy,
        'none',
      );
      expect((await client.invitation.inbox()).single.status, 'blocked');
      await expectLater(
        client.profile.updateName(' '),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        client.profile.updateTheme('invalid'),
        throwsA(isA<VaultException>()),
      );
      for (final request in [
        () => client.profile.updateEmail(
          'private password',
          'new@example.invalid',
        ),
        () => client.profile.changePassword('private password', 'new password'),
        () => client.account.register(
          'new@example.invalid',
          'private password',
          'New',
        ),
      ]) {
        await expectLater(
          request(),
          throwsA(
            isA<VaultException>().having(
              (e) => e.message,
              'message',
              contains('demo'),
            ),
          ),
        );
      }
      await client.vault.logout();
      final login = await client.account.login(
        'ignored@example.invalid',
        'private password',
      );
      expect(login.account.id, 'owner');
      expect(login.token, 'demo-session');
      expect(
        await store.access((data) => jsonEncode(data)),
        isNot(contains('private password')),
      );
    },
  );

  test('a reset invalidates writes from an already opened client', () async {
    await client.vault.organizations();
    await store.reset();
    await expectLater(
      client.vault.saveSecret(
        'org',
        null,
        'Stale edit',
        'value',
        'Web',
        'Production',
        'API key',
        '',
      ),
      throwsA(
        isA<VaultException>().having(
          (e) => e.message,
          'message',
          contains('reset'),
        ),
      ),
    );
    final fresh = Client(
      'https://demo.invalid/',
      httpClientOverride: DemoClient(store),
    );
    expect((await fresh.vault.summary('org')).secretCount, 3);
  });

  test(
    'exclusion scopes constrain future projects and malformed denials fail closed',
    () async {
      final member = await client.vault.updateMemberAccess(
        'org',
        'editor',
        'editor',
        deniedReadProjects: ['Ops'],
        canCreateProjects: true,
      );
      expect(member.deniedWriteProjects, ['Ops']);
      await store.access((data) => data['accountId'] = 'editor', write: true);
      expect(await client.vault.createProject('org', 'Mobile'), 'Mobile');
      final saved = await client.vault.saveSecret(
        'org',
        null,
        'Mobile key',
        'synthetic',
        'Mobile',
        'Development',
        'API key',
        '',
      );
      expect(saved.project, 'Mobile');
      await expectLater(
        client.vault.revealSecret('org', 'ops'),
        throwsA(isA<VaultException>()),
      );
      await store.access(
        (data) =>
            ((data['members'] as List).last as Map)['deniedReadProjects'] =
                'malformed',
        write: true,
      );
      expect(await client.vault.listSecrets('org'), isEmpty);
      await expectLater(
        client.vault.createProject('org', 'Forbidden'),
        throwsA(isA<VaultException>()),
      );
    },
  );

  test(
    'invitation decline and policy checks cannot add or bypass membership',
    () async {
      await client.invitation.decline('incoming');
      expect((await client.invitation.inbox()).single.status, 'declined');
      expect((await client.vault.organizations()).map((o) => o.id), ['org']);
      final created = await client.invitation.create(
        'org',
        'new@example.invalid',
        'New',
        'reader',
      );
      await client.account.declineInvitation(created.token);
      expect(
        (await client.invitation.outgoing('org')).single.status,
        'declined',
      );
      await expectLater(
        client.vault.addMember('org', 'new@example.invalid', 'reader'),
        throwsA(isA<VaultException>()),
      );
      await expectLater(
        client.account.registerFromInvitation(created.token, 'New', 'password'),
        throwsA(isA<VaultException>()),
      );
    },
  );

  test(
    'unknown routes and non-POST requests never fall back to the network',
    () async {
      final unknown = await transport.post(
        Uri.parse('https://unreachable.invalid/vault/notImplemented'),
        body: '{}',
      );
      expect(unknown.statusCode, 500);
      expect(unknown.body, contains('demo'));
      final method = await transport.send(
        http.Request(
          'GET',
          Uri.parse('https://unreachable.invalid/vault/organizations'),
        ),
      );
      expect(method.statusCode, 500);
    },
  );

  test(
    'failed initial storage commit does not pin an unsaved reset generation',
    () async {
      final backing = store.backing as MemoryDemoBacking;
      backing.failWrites = true;
      await expectLater(
        client.vault.createOrganization('Unsaved'),
        throwsA(isA<VaultException>()),
      );
      backing.failWrites = false;
      final saved = await client.vault.createOrganization('Saved');
      expect(saved.name, 'Saved');
      expect((await client.vault.organizations()).map((o) => o.name), [
        'org',
        'Saved',
      ]);
    },
  );

  test(
    'full synthetic seed loads every workspace and accepts its external invitation',
    () async {
      final seededStore = MemoryDemoStore(seed: () => createDemoSeed());
      final seeded = Client(
        'https://demo.invalid/',
        httpClientOverride: DemoClient(seededStore),
      );
      expect((await seeded.invitation.profile()).id, 'demo-account-owner');
      final organizations = await seeded.vault.organizations();
      expect(organizations, hasLength(2));
      for (final org in organizations) {
        final summary = await seeded.vault.summary(org.id);
        expect(
          (await seeded.vault.listSecrets(org.id, limit: 100)),
          hasLength(summary.secretCount),
        );
        expect(await seeded.vault.members(org.id), isNotEmpty);
        expect(await seeded.vault.activity(org.id), isNotEmpty);
        expect(await seeded.invitation.outgoing(org.id), isNotEmpty);
      }
      final incoming = (await seeded.invitation.inbox()).single;
      expect(incoming.organizationName, 'Harbor Design Partners');
      final token = await seededStore.access(
        (data) =>
            ((data['invitations'] as List).singleWhere(
                      (i) => i['id'] == incoming.id,
                    )
                    as Map)['token']
                as String,
      );
      expect(invitationTokenFromLink(token), token);
      expect((await seeded.account.previewInvitation(token)).id, incoming.id);
      await seeded.invitation.accept(incoming.id, token);
      final joined = (await seeded.vault.organizations()).last;
      expect(joined.id, incoming.organizationId);
      expect(joined.role, 'editor');
      expect((await seeded.vault.summary(joined.id)).projectCounts, {
        'Joint Launch': 0,
      });
      expect((await seeded.vault.members(joined.id)).map((m) => m.role), [
        'owner',
        'editor',
      ]);
    },
  );
}

Map<String, dynamic> _fixture() {
  Map<String, dynamic> account(String id, String name) => AccountView(
    id: id,
    name: name,
    email: '$id@example.invalid',
    invitationPolicy: 'all',
    themeMode: 'system',
  ).toJson();
  final owner = account('owner', 'Owner');
  final editor = account('editor', 'Editor');
  final inviter = account('inviter', 'Inviter');
  final now = DateTime.utc(2026, 1, 2);
  Map<String, dynamic> secret(
    String id,
    String project,
    int day, {
    String kind = 'API key',
  }) => {
    ...SecretView(
      id: id,
      organizationId: 'org',
      name: id,
      project: project,
      environment: 'Production',
      kind: kind,
      description: '',
      version: 1,
      createdAt: now,
      updatedAt: DateTime.utc(2026, 1, day),
    ).toJson(),
    'value': 'SYNTHETIC-SECRET-$id',
  };
  return {
    'schemaVersion': 1,
    'revision': 0,
    'epoch': DateTime.now().microsecondsSinceEpoch.toString(),
    'accountId': 'owner',
    'accounts': [owner, editor, inviter],
    'organizations': [
      for (final id in ['org', 'other-org'])
        OrganizationView(
          id: id,
          name: id,
          role: 'owner',
          createdAt: now,
        ).toJson(),
    ],
    'members': [
      {
        ...MemberView(
          account: AccountView.fromJson(owner),
          role: 'owner',
        ).toJson(),
        'organizationId': 'org',
      },
      {
        ...MemberView(
          account: AccountView.fromJson(inviter),
          role: 'owner',
        ).toJson(),
        'organizationId': 'other-org',
      },
      {
        ...MemberView(
          account: AccountView.fromJson(editor),
          role: 'editor',
        ).toJson(),
        'organizationId': 'org',
      },
    ],
    'secrets': [
      secret('web-old', 'Web', 2),
      secret('web-new', 'Web', 3),
      secret('ops', 'Ops', 4, kind: 'Certificate'),
    ],
    'activity': [
      {
        ...AuditView(
          id: 'legacy',
          actor: 'Owner',
          action: 'created organization',
          target: 'org',
          createdAt: now,
        ).toJson(),
        'organizationId': 'org',
      },
      {
        ...AuditView(
          id: 'access-web',
          actor: 'Editor (editor@example.invalid)',
          actorId: 'editor',
          action: 'revealed',
          target: 'web-new',
          secretId: 'web-new',
          version: 1,
          createdAt: now,
        ).toJson(),
        'organizationId': 'org',
        'project': 'Web',
      },
    ],
    'projects': {
      'org': ['Web', 'Ops'],
      'other-org': [],
    },
    'invitations': [
      {
        ...InvitationView(
          id: 'incoming',
          organizationId: 'other-org',
          organizationName: 'other-org',
          inviterName: 'Inviter',
          inviterEmail: 'inviter@example.invalid',
          recipientEmail: 'owner@example.invalid',
          recipientName: 'Owner',
          role: 'reader',
          status: 'pending',
          createdAt: now,
          expiresAt: DateTime.utc(2099),
        ).toJson(),
        'token': 'demo-incoming-token',
      },
    ],
  };
}
