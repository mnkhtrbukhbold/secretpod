import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/demo/demo_seed.dart';
import 'package:secretpod_flutter/state/invitation_link.dart';

void main() {
  final now = DateTime.utc(2026, 10, 14, 12, 30);

  Map<String, dynamic> persistedSeed() =>
      jsonDecode(jsonEncode(createDemoSeed(now: now))) as Map<String, dynamic>;

  List<Map<String, dynamic>> rows(Map<String, dynamic> seed, String key) =>
      (seed[key] as List).cast<Map<String, dynamic>>();

  test('seed survives persistence and deserializes into every app model', () {
    final seed = persistedSeed();
    expect(seed['schemaVersion'], 1);
    expect(seed['revision'], 0);
    expect(
      seed['epoch'],
      isA<String>().having((s) => s.length, 'length', greaterThan(10)),
    );
    final accounts = rows(seed, 'accounts').map(AccountView.fromJson).toList();
    final organizations = rows(
      seed,
      'organizations',
    ).map(OrganizationView.fromJson).toList();
    final members = rows(seed, 'members').map(MemberView.fromJson).toList();
    final secrets = rows(seed, 'secrets').map(SecretView.fromJson).toList();
    final invitations = rows(
      seed,
      'invitations',
    ).map(InvitationView.fromJson).toList();
    final activity = rows(seed, 'activity').map(AuditView.fromJson).toList();

    expect(accounts.length, inInclusiveRange(5, 6));
    expect(organizations, hasLength(2));
    expect(members.length, greaterThanOrEqualTo(6));
    expect(secrets.length, greaterThanOrEqualTo(30));
    expect(invitations.length, greaterThanOrEqualTo(6));
    expect(activity.length, greaterThanOrEqualTo(60));
    expect(accounts.map((a) => a.id), contains(seed['accountId']));
    for (final organization in organizations) {
      expect(
        rows(seed, 'members').any(
          (row) =>
              row['organizationId'] == organization.id &&
              row['account']['id'] == seed['accountId'] &&
              row['role'] == 'owner',
        ),
        isTrue,
      );
    }
  });

  test('members, projects and secret activity retain valid references', () {
    final seed = persistedSeed();
    final accounts = {for (final a in rows(seed, 'accounts')) a['id']: a};
    final organizations = {
      for (final o in rows(seed, 'organizations')) o['id']: o,
    };
    final secrets = {for (final s in rows(seed, 'secrets')) s['id']: s};
    final projects = seed['projects'] as Map<String, dynamic>;
    expect(accounts.length, rows(seed, 'accounts').length);
    expect(secrets.length, rows(seed, 'secrets').length);
    expect(projects.keys.toSet(), organizations.keys.toSet());
    for (final member in rows(seed, 'members')) {
      expect(accounts[member['account']['id']], member['account']);
      expect(organizations, contains(member['organizationId']));
      for (final field in [
        'readProjects',
        'writeProjects',
        'deniedReadProjects',
        'deniedWriteProjects',
      ]) {
        for (final project in (member[field] as List? ?? [])) {
          expect(projects[member['organizationId']], contains(project));
        }
      }
      if (member['writeProjects'] != null && member['readProjects'] != null) {
        expect(
          member['readProjects'],
          containsAll(member['writeProjects'] as List),
        );
      }
      if (member['canCreateProjects'] == true) {
        expect(member['readProjects'], isNull);
        expect(member['writeProjects'], isNull);
      }
    }
    for (final secret in secrets.values) {
      expect(organizations, contains(secret['organizationId']));
      expect(projects[secret['organizationId']], contains(secret['project']));
      final events = rows(
        seed,
        'activity',
      ).where((e) => e['secretId'] == secret['id']).toList();
      expect(
        events.any((e) => e['action'] == 'created' && e['version'] == 1),
        isTrue,
      );
      expect(events.any((e) => e['version'] == secret['version']), isTrue);
    }
    for (final event in rows(seed, 'activity')) {
      expect(accounts, contains(event['actorId']));
      expect(organizations, contains(event['organizationId']));
      expect(
        rows(seed, 'members').any(
          (member) =>
              member['organizationId'] == event['organizationId'] &&
              member['account']['id'] == event['actorId'],
        ),
        isTrue,
      );
      if (event['secretId'] != null) {
        final secret = secrets[event['secretId']];
        expect(secret, isNotNull);
        expect(event['organizationId'], secret!['organizationId']);
        expect(event['project'], secret['project']);
        expect(event['target'], secret['name']);
        expect(event['version'], lessThanOrEqualTo(secret['version'] as int));
        expect(
          event['details'] ?? '',
          isNot(contains(secret['value'] as String)),
        );
      }
    }
  });

  test(
    'demo content exercises type, environment, access and invitation states',
    () {
      final seed = persistedSeed();
      final secrets = rows(seed, 'secrets');
      expect(secrets.map((s) => s['kind']).toSet(), {
        'API key',
        'Environment variable',
        'Password',
        'Username and password',
        'Certificate',
        'Other',
      });
      expect(secrets.map((s) => s['environment']).toSet(), {
        'Development',
        'Staging',
        'Production',
      });
      expect(secrets.map((s) => s['name']).toSet().length, secrets.length);
      expect(secrets.any((s) => s['needsRotation'] == true), isTrue);
      expect(secrets.any((s) => s['needsRotation'] == false), isTrue);
      expect(secrets.any((s) => (s['value'] as String).contains('\n')), isTrue);
      expect(secrets.any((s) => s['expiresAt'] == null), isTrue);
      expect(
        secrets.any(
          (s) =>
              s['expiresAt'] != null &&
              DateTime.parse(s['expiresAt'] as String).isBefore(now),
        ),
        isTrue,
      );
      expect(
        secrets.any(
          (s) =>
              s['expiresAt'] != null &&
              DateTime.parse(s['expiresAt'] as String).isAfter(now),
        ),
        isTrue,
      );
      for (final secret in secrets) {
        expect(secret['value'], contains('DEMO'));
        if (secret['kind'] == 'Username and password') {
          expect(secret['username'], isNotEmpty);
        }
        if (secret['kind'] == 'Certificate') {
          expect(secret['value'], contains('NOT A VALID CERTIFICATE'));
        }
        if (secret['url'] != null) {
          expect(
            Uri.parse(secret['url'] as String).host,
            endsWith('example.com'),
          );
        }
      }
      final members = rows(seed, 'members');
      expect(members.map((m) => m['role']).toSet(), {
        'owner',
        'editor',
        'reader',
      });
      expect(
        members.any(
          (m) =>
              m['readProjects'] is List &&
              (m['readProjects'] as List).isNotEmpty,
        ),
        isTrue,
      );
      expect(
        members.any(
          (m) =>
              m['deniedReadProjects'] is List &&
              (m['deniedReadProjects'] as List).isNotEmpty,
        ),
        isTrue,
      );
      expect(
        rows(seed, 'activity').map((e) => e['actorId']).toSet().length,
        greaterThanOrEqualTo(4),
      );

      final invitations = rows(
        seed,
        'invitations',
      ).map(InvitationView.fromJson).toList();
      final owner = rows(
        seed,
        'accounts',
      ).singleWhere((a) => a['id'] == seed['accountId']);
      final outgoing = invitations.where(
        (i) => i.inviterEmail == owner['email'],
      );
      expect(
        outgoing.map((i) => i.status).toSet(),
        containsAll(['pending', 'declined', 'expired', 'accepted', 'revoked']),
      );
      final incoming = invitations
          .where(
            (i) => i.recipientEmail == owner['email'] && i.status == 'pending',
          )
          .toList();
      expect(incoming, isNotEmpty);
      for (final invitation in incoming) {
        expect(
          rows(seed, 'organizations').map((o) => o['id']),
          isNot(contains(invitation.organizationId)),
        );
        expect(
          rows(seed, 'members').any(
            (m) =>
                m['organizationId'] == invitation.organizationId &&
                m['account']['id'] == seed['accountId'],
          ),
          isFalse,
        );
      }
      expect(
        rows(seed, 'invitations').map((i) => i['token']).toSet().length,
        invitations.length,
      );
      for (final invitation in invitations.where(
        (i) => i.status == 'accepted',
      )) {
        expect(
          members.any(
            (m) =>
                m['organizationId'] == invitation.organizationId &&
                m['account']['email'] == invitation.recipientEmail,
          ),
          isTrue,
        );
      }
    },
  );

  test('dates stay coherent and move relative to first seed creation', () {
    final seed = persistedSeed();
    final events = rows(seed, 'activity').map(AuditView.fromJson).toList();
    for (var i = 0; i < events.length; i++) {
      expect(events[i].createdAt.isAfter(now), isFalse);
      if (i > 0) {
        expect(events[i].createdAt.isBefore(events[i - 1].createdAt), isFalse);
      }
    }
    for (final secret in rows(seed, 'secrets').map(SecretView.fromJson)) {
      expect(secret.createdAt.isAfter(secret.updatedAt), isFalse);
      expect(secret.updatedAt.isAfter(now), isFalse);
      final created = events.singleWhere(
        (e) => e.secretId == secret.id && e.action == 'created',
      );
      expect(created.createdAt, secret.createdAt);
      if (secret.expiresAt != null) expect(secret.expiresAt!.hour, 0);
    }
    for (final invitation in rows(
      seed,
      'invitations',
    ).map(InvitationView.fromJson)) {
      expect(invitation.createdAt.isBefore(invitation.expiresAt), isTrue);
      if (invitation.status == 'pending') {
        expect(invitation.expiresAt.isAfter(now), isTrue);
      }
      if (invitation.status == 'expired') {
        expect(invitation.expiresAt.isBefore(now), isTrue);
      }
      if (invitation.respondedAt != null) {
        expect(invitation.respondedAt!.isAfter(invitation.createdAt), isTrue);
        expect(invitation.respondedAt!.isAfter(now), isFalse);
      }
    }
    final futureSeed = createDemoSeed(now: now.add(const Duration(days: 40)));
    final futureFirst = SecretView.fromJson(rows(futureSeed, 'secrets').first);
    final originalFirst = SecretView.fromJson(rows(seed, 'secrets').first);
    expect(futureFirst.id, originalFirst.id);
    expect(
      futureFirst.createdAt.difference(originalFirst.createdAt),
      const Duration(days: 40),
    );
  });

  test('seeded invitation tokens can open the normal invitation screen', () {
    final seed = persistedSeed();
    for (final invitation in rows(seed, 'invitations')) {
      final token = invitation['token'] as String;
      expect(invitationTokenFromLink(token), token);
      expect(invitationTokenFromLink(invitationLink(token)), token);
    }
  });

  test('reset gets a unique generation and independent mutable data', () {
    final first = createDemoSeed(now: now);
    final second = createDemoSeed(now: now);
    expect(first['epoch'], isNot(second['epoch']));
    final original = jsonEncode(second);
    rows(first, 'accounts').first['name'] = 'Visitor edit';
    rows(first, 'members').first['account']['name'] = 'Membership edit';
    rows(first, 'secrets').first['value'] = 'Visitor value';
    (first['projects'] as Map).values.first.add('Visitor project');
    rows(first, 'invitations').clear();
    rows(first, 'activity').clear();
    expect(jsonEncode(second), original);
    expect(
      rows(first, 'accounts')[1]['name'],
      rows(second, 'accounts')[1]['name'],
    );
  });
}
