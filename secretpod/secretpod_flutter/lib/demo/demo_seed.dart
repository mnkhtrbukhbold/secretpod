import 'dart:math';

import 'package:secretpod_client/secretpod_client.dart';

/// A new browser playground. Every value is fictional and intentionally unusable.
///
/// Call only when initializing or resetting storage: dates are relative to that
/// moment, while record IDs remain stable for navigation and audit references.
Map<String, dynamic> createDemoSeed({DateTime? now}) {
  final timestamp = (now ?? DateTime.now()).toUtc();
  final today = DateTime.utc(timestamp.year, timestamp.month, timestamp.day);
  final accounts = [
    AccountView(
      id: 'demo-account-owner',
      name: 'Maya Chen',
      email: 'maya.chen@example.com',
      invitationPolicy: 'all',
      themeMode: 'system',
    ),
    AccountView(
      id: 'demo-account-theo',
      name: 'Theo Grant',
      email: 'theo.grant@example.com',
      invitationPolicy: 'sameDomain',
      themeMode: 'system',
    ),
    AccountView(
      id: 'demo-account-leila',
      name: 'Leila Haddad',
      email: 'leila.haddad@example.com',
      invitationPolicy: 'all',
      themeMode: 'system',
    ),
    AccountView(
      id: 'demo-account-owen',
      name: 'Owen Brooks',
      email: 'owen.brooks@example.com',
      invitationPolicy: 'sameDomain',
      themeMode: 'system',
    ),
    AccountView(
      id: 'demo-account-sofia',
      name: 'Sofia Rossi',
      email: 'sofia.rossi@example.com',
      invitationPolicy: 'all',
      themeMode: 'system',
    ),
    AccountView(
      id: 'demo-account-felix',
      name: 'Felix Okafor',
      email: 'felix.okafor@example.com',
      invitationPolicy: 'all',
      themeMode: 'system',
    ),
  ];
  final owner = accounts[0];
  const northstar = 'demo-org-northstar';
  const labs = 'demo-org-labs';
  final organizations = [
    OrganizationView(
      id: northstar,
      name: 'Northstar Cloud',
      role: 'owner',
      createdAt: timestamp.subtract(const Duration(days: 180)),
      canCreateProjects: true,
    ),
    OrganizationView(
      id: labs,
      name: 'Northstar Research',
      role: 'owner',
      createdAt: timestamp.subtract(const Duration(days: 120)),
      canCreateProjects: true,
    ),
  ];
  final projects = <String, List<String>>{
    northstar: [
      'Platform',
      'Customer Portal',
      'Commerce',
      'Analytics',
      'Finance',
      'Mobile',
    ],
    labs: ['Model Gateway', 'Evaluation', 'Prototype'],
  };

  Map<String, dynamic> member(
    String organizationId,
    int accountIndex,
    String role, {
    List<String>? read,
    List<String>? write,
    List<String>? denyRead,
    List<String>? denyWrite,
    bool createProjects = false,
  }) => {
    ...MemberView(
      account: accounts[accountIndex],
      role: role,
      readProjects: read,
      writeProjects: write,
      deniedReadProjects: denyRead,
      deniedWriteProjects: denyWrite,
      canCreateProjects: createProjects,
    ).toJson(),
    'organizationId': organizationId,
  };

  final members = [
    member(northstar, 0, 'owner', createProjects: true),
    member(
      northstar,
      1,
      'editor',
      denyRead: ['Finance'],
      denyWrite: ['Finance', 'Commerce'],
      createProjects: true,
    ),
    member(
      northstar,
      2,
      'editor',
      read: ['Customer Portal', 'Commerce'],
      write: ['Customer Portal', 'Commerce'],
    ),
    member(
      northstar,
      3,
      'reader',
      read: ['Platform', 'Customer Portal'],
      write: [],
    ),
    member(northstar, 4, 'reader', read: ['Analytics'], write: []),
    member(northstar, 5, 'reader', read: ['Analytics'], write: []),
    member(labs, 0, 'owner', createProjects: true),
    member(
      labs,
      1,
      'editor',
      read: ['Model Gateway'],
      write: ['Model Gateway'],
    ),
    member(
      labs,
      4,
      'editor',
      denyRead: ['Prototype'],
      denyWrite: ['Prototype'],
      createProjects: true,
    ),
    member(labs, 5, 'reader', read: ['Evaluation'], write: []),
  ];
  final secrets = <Map<String, dynamic>>[];
  final activity = <Map<String, dynamic>>[];

  void event({
    required String organizationId,
    required AccountView actor,
    required String action,
    required String target,
    required DateTime at,
    String? secretId,
    String? project,
    int? version,
    String? details,
  }) {
    activity.add({
      ...AuditView(
        id: 'demo-event-${(activity.length + 1).toString().padLeft(3, '0')}',
        actor: '${actor.name} (${actor.email})',
        actorId: actor.id,
        action: action,
        target: target,
        createdAt: at,
        secretId: secretId,
        version: version,
        details: details,
      ).toJson(),
      'organizationId': organizationId,
      'project': ?project,
    });
  }

  for (final entry in {
    northstar: _cloudSecrets,
    labs: _researchSecrets,
  }.entries) {
    for (final spec in entry.value) {
      final index = secrets.length;
      final id = 'demo-secret-${(index + 1).toString().padLeft(3, '0')}';
      final version = 1 + index % 4;
      final createdAt = timestamp.subtract(
        Duration(days: 78 - index, hours: index % 6),
      );
      final updatedAt = version == 1
          ? createdAt
          : timestamp.subtract(Duration(days: 21 - index % 17));
      final secret = SecretView(
        id: id,
        organizationId: entry.key,
        name: spec.name,
        project: spec.project,
        environment: spec.environment,
        kind: spec.kind,
        description:
            '${spec.purpose} Fictional demo data; this value cannot authenticate to a service.',
        version: version,
        createdAt: createdAt,
        updatedAt: updatedAt,
        url:
            'https://${spec.project.toLowerCase().replaceAll(' ', '-')}.example.com',
        expiresAt: spec.expiryDays == null
            ? null
            : today.add(Duration(days: spec.expiryDays!)),
        needsRotation: spec.rotate,
      );
      final slug = spec.name.toUpperCase().replaceAll(
        RegExp('[^A-Z0-9]+'),
        '_',
      );
      final value =
          spec.value ??
          switch (spec.kind) {
            'Certificate' =>
              '-----BEGIN CERTIFICATE-----\nDEMO: NOT A VALID CERTIFICATE\n$slug\nThis is display-only sample text, not cryptographic material.\n-----END CERTIFICATE-----',
            'Environment variable' =>
              'DEMO_MODE=true\nSERVICE_NAME=$slug\nSERVICE_URL=https://sandbox.example.com\nCREDENTIAL=DEMO_ONLY_NO_ACCESS',
            'Password' ||
            'Username and password' => 'DEMO_ONLY_${slug}_not-a-real-password!',
            _ => 'DEMO_ONLY_${slug}_NO_ACCESS',
          };
      secrets.add({
        ...secret.toJson(),
        'value': value,
        if (spec.kind == 'Username and password')
          'username': spec.username ?? 'demo-service@example.com',
      });
      final author = entry.key == labs
          ? (spec.project == 'Prototype' ? owner : accounts[4])
          : switch (spec.project) {
              'Finance' => owner,
              'Customer Portal' || 'Commerce' => accounts[2],
              _ => accounts[1],
            };
      final reader = entry.key == labs
          ? switch (spec.project) {
              'Evaluation' => accounts[5],
              'Model Gateway' => accounts[1],
              _ => owner,
            }
          : switch (spec.project) {
              'Platform' || 'Customer Portal' => accounts[3],
              'Analytics' => accounts[5],
              _ => author,
            };
      event(
        organizationId: entry.key,
        actor: author,
        action: 'created',
        target: secret.name,
        at: createdAt,
        secretId: id,
        project: spec.project,
        version: 1,
        details: 'Initial version created.',
      );
      for (var revision = 2; revision <= version; revision++) {
        final at = createdAt.add(
          Duration(
            microseconds:
                updatedAt.difference(createdAt).inMicroseconds *
                (revision - 1) ~/
                (version - 1),
          ),
        );
        event(
          organizationId: entry.key,
          actor: author,
          action: revision.isEven ? 'rotated' : 'updated',
          target: secret.name,
          at: at,
          secretId: id,
          project: spec.project,
          version: revision,
          details: revision.isEven
              ? 'Changed fields: value. Previous version: ${revision - 1}.'
              : 'Changed fields: description, url. Previous version: ${revision - 1}.',
        );
      }
      final accessedAt = timestamp.subtract(
        Duration(hours: 72 - index, minutes: index),
      );
      event(
        organizationId: entry.key,
        actor: reader,
        action: 'revealed',
        target: secret.name,
        at: accessedAt,
        secretId: id,
        project: spec.project,
        version: version,
        details: spec.kind == 'Username and password'
            ? 'Revealed username and password.'
            : 'Revealed secret value.',
      );
      if (index % 3 == 0) {
        event(
          organizationId: entry.key,
          actor: reader,
          action: 'copied',
          target: secret.name,
          at: accessedAt.add(const Duration(minutes: 2)),
          secretId: id,
          project: spec.project,
          version: version,
          details: 'Clipboard completion acknowledged.',
        );
      }
      if (spec.rotate) {
        event(
          organizationId: entry.key,
          actor: author,
          action: 'marked needs rotating',
          target: secret.name,
          at: timestamp.subtract(Duration(hours: 12, minutes: index)),
          secretId: id,
          project: spec.project,
          version: version,
          details: 'Scheduled credential review.',
        );
      }
    }
  }

  Map<String, dynamic> invitation({
    required String id,
    required String organizationId,
    required String organizationName,
    required String recipientName,
    required String recipientEmail,
    required String role,
    required String status,
    required int createdDaysAgo,
    required int expiresInDays,
    int? respondedDaysAgo,
    String? inviterName,
    String? inviterEmail,
    List<String>? read,
    List<String>? write,
  }) => {
    ...InvitationView(
      id: id,
      organizationId: organizationId,
      organizationName: organizationName,
      inviterName: inviterName ?? owner.name,
      inviterEmail: inviterEmail ?? owner.email,
      recipientEmail: recipientEmail,
      recipientName: recipientName,
      role: role,
      status: status,
      createdAt: timestamp.subtract(Duration(days: createdDaysAgo)),
      expiresAt: timestamp.add(Duration(days: expiresInDays)),
      respondedAt: respondedDaysAgo == null
          ? null
          : timestamp.subtract(Duration(days: respondedDaysAgo)),
      readProjects: read,
      writeProjects: write,
      canCreateProjects: false,
    ).toJson(),
    'token': '${'DEMO_ONLY_INVITATION_$id'.padRight(43, '_')}=',
  };

  final invitations = [
    invitation(
      id: 'demo-invite-001',
      organizationId: northstar,
      organizationName: 'Northstar Cloud',
      recipientName: 'Amara Silva',
      recipientEmail: 'amara.silva@example.com',
      role: 'editor',
      status: 'pending',
      createdDaysAgo: 2,
      expiresInDays: 5,
      read: ['Customer Portal'],
      write: ['Customer Portal'],
    ),
    invitation(
      id: 'demo-invite-002',
      organizationId: northstar,
      organizationName: 'Northstar Cloud',
      recipientName: 'Noah Kim',
      recipientEmail: 'noah.kim@example.com',
      role: 'reader',
      status: 'pending',
      createdDaysAgo: 1,
      expiresInDays: 6,
      read: ['Analytics'],
      write: [],
    ),
    invitation(
      id: 'demo-invite-003',
      organizationId: northstar,
      organizationName: 'Northstar Cloud',
      recipientName: 'Iris Patel',
      recipientEmail: 'iris.patel@example.com',
      role: 'reader',
      status: 'declined',
      createdDaysAgo: 12,
      expiresInDays: -5,
      respondedDaysAgo: 10,
      read: ['Customer Portal'],
      write: [],
    ),
    invitation(
      id: 'demo-invite-004',
      organizationId: northstar,
      organizationName: 'Northstar Cloud',
      recipientName: 'Alex Morgan',
      recipientEmail: 'alex.morgan@example.com',
      role: 'editor',
      status: 'expired',
      createdDaysAgo: 15,
      expiresInDays: -8,
      read: ['Mobile'],
      write: ['Mobile'],
    ),
    invitation(
      id: 'demo-invite-005',
      organizationId: northstar,
      organizationName: 'Northstar Cloud',
      recipientName: accounts[3].name,
      recipientEmail: accounts[3].email,
      role: 'reader',
      status: 'accepted',
      createdDaysAgo: 100,
      expiresInDays: -93,
      respondedDaysAgo: 98,
      read: ['Platform', 'Customer Portal'],
      write: [],
    ),
    invitation(
      id: 'demo-invite-006',
      organizationId: northstar,
      organizationName: 'Northstar Cloud',
      recipientName: 'Robin Ellis',
      recipientEmail: 'robin.ellis@example.com',
      role: 'editor',
      status: 'revoked',
      createdDaysAgo: 6,
      expiresInDays: 1,
      respondedDaysAgo: 4,
      read: ['Commerce'],
      write: ['Commerce'],
    ),
    invitation(
      id: 'demo-invite-007',
      organizationId: labs,
      organizationName: 'Northstar Research',
      recipientName: 'Samira Bell',
      recipientEmail: 'samira.bell@example.com',
      role: 'reader',
      status: 'pending',
      createdDaysAgo: 3,
      expiresInDays: 4,
      read: ['Evaluation'],
      write: [],
    ),
    invitation(
      id: 'demo-invite-008',
      organizationId: labs,
      organizationName: 'Northstar Research',
      recipientName: accounts[5].name,
      recipientEmail: accounts[5].email,
      role: 'reader',
      status: 'accepted',
      createdDaysAgo: 90,
      expiresInDays: -83,
      respondedDaysAgo: 88,
      read: ['Evaluation'],
      write: [],
    ),
    invitation(
      id: 'demo-invite-009',
      organizationId: 'demo-org-harbor',
      organizationName: 'Harbor Design Partners',
      recipientName: owner.name,
      recipientEmail: owner.email,
      role: 'editor',
      status: 'pending',
      createdDaysAgo: 1,
      expiresInDays: 6,
      inviterName: 'Avery Stone',
      inviterEmail: 'avery.stone@harbor.example.com',
      read: ['Joint Launch'],
      write: ['Joint Launch'],
    ),
  ];
  for (final row in invitations.where(
    (i) => i['inviterEmail'] == owner.email,
  )) {
    final invite = InvitationView.fromJson(row);
    event(
      organizationId: invite.organizationId,
      actor: owner,
      action: 'invited member',
      target: invite.recipientEmail,
      at: invite.createdAt,
      details: 'Invitation ${invite.id}; role: ${invite.role}.',
    );
    if (invite.respondedAt != null && invite.status == 'revoked') {
      event(
        organizationId: invite.organizationId,
        actor: owner,
        action: 'revoked invitation',
        target: invite.recipientEmail,
        at: invite.respondedAt!,
        details: 'Invitation ${invite.id}.',
      );
    }
    if (invite.respondedAt != null && invite.status == 'accepted') {
      event(
        organizationId: invite.organizationId,
        actor: accounts.singleWhere((a) => a.email == invite.recipientEmail),
        action: 'accepted invitation',
        target: invite.organizationName,
        at: invite.respondedAt!,
        details: 'Invitation ${invite.id}.',
      );
    }
  }
  activity.sort(
    (a, b) => (a['createdAt'] as String).compareTo(b['createdAt'] as String),
  );

  return {
    'schemaVersion': 1,
    'revision': 0,
    'epoch':
        'demo-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x100000000).toRadixString(16)}',
    'accountId': owner.id,
    'accounts': accounts.map((account) => account.toJson()).toList(),
    'organizations': organizations
        .map((organization) => organization.toJson())
        .toList(),
    'members': members,
    'secrets': secrets,
    'invitations': invitations,
    'activity': activity,
    'projects': projects,
  };
}

class _SecretSpec {
  const _SecretSpec(
    this.name,
    this.project,
    this.environment,
    this.kind,
    this.purpose, {
    this.username,
    this.value,
    this.expiryDays,
    this.rotate = false,
  });

  final String name;
  final String project;
  final String environment;
  final String kind;
  final String purpose;
  final String? username;
  final String? value;
  final int? expiryDays;
  final bool rotate;
}

const _cloudSecrets = [
  _SecretSpec(
    'Observability ingest key',
    'Platform',
    'Production',
    'API key',
    'Connects the sample telemetry pipeline.',
    expiryDays: 7,
    rotate: true,
  ),
  _SecretSpec(
    'PostgreSQL service account',
    'Platform',
    'Production',
    'Username and password',
    'Application database account for the fictional core service.',
    username: 'demo_platform_service',
    expiryDays: 45,
  ),
  _SecretSpec(
    'Service runtime configuration',
    'Platform',
    'Staging',
    'Environment variable',
    'Multiline configuration used in deployment rehearsals.',
  ),
  _SecretSpec(
    'Build agent recovery password',
    'Platform',
    'Development',
    'Password',
    'Recovery credential for disposable build agents.',
    rotate: true,
  ),
  _SecretSpec(
    'Internal gateway certificate',
    'Platform',
    'Production',
    'Certificate',
    'Nonfunctional certificate sample for the internal gateway.',
    expiryDays: -3,
    rotate: true,
  ),
  _SecretSpec(
    'Container registry deploy token',
    'Platform',
    'Staging',
    'API key',
    'Example deployment credential for container publishing.',
    expiryDays: 28,
  ),
  _SecretSpec(
    'Identity sandbox client',
    'Customer Portal',
    'Development',
    'API key',
    'Fictional identity client for local sign-in flows.',
  ),
  _SecretSpec(
    'Customer portal runtime',
    'Customer Portal',
    'Production',
    'Environment variable',
    'Sample customer portal environment settings.',
  ),
  _SecretSpec(
    'CMS publishing account',
    'Customer Portal',
    'Staging',
    'Username and password',
    'Example content publishing service account.',
    username: 'demo_publisher@example.com',
    expiryDays: 60,
  ),
  _SecretSpec(
    'Transactional email key',
    'Customer Portal',
    'Production',
    'API key',
    'Placeholder for receipt and account email delivery.',
    expiryDays: 2,
    rotate: true,
  ),
  _SecretSpec(
    'Webhook signature shared secret',
    'Customer Portal',
    'Staging',
    'Other',
    'Demonstrates a shared webhook verification value.',
  ),
  _SecretSpec(
    'Checkout test gateway key',
    'Commerce',
    'Staging',
    'API key',
    'Payment rehearsal credential; no real payment processor is connected.',
    expiryDays: 90,
  ),
  _SecretSpec(
    'Order database credentials',
    'Commerce',
    'Production',
    'Username and password',
    'Fictional order service database login.',
    username: 'demo_orders_service',
    expiryDays: 30,
  ),
  _SecretSpec(
    'Tax calculation sandbox token',
    'Commerce',
    'Development',
    'API key',
    'Sample regional tax integration token.',
  ),
  _SecretSpec(
    'Settlement archive passphrase',
    'Commerce',
    'Production',
    'Password',
    'Example passphrase for a fictional settlement archive.',
    expiryDays: -1,
    rotate: true,
  ),
  _SecretSpec(
    'Checkout feature flags',
    'Commerce',
    'Development',
    'Environment variable',
    'Multiline settings for checkout experiments.',
    value:
        'DEMO_MODE=true\nCHECKOUT_V2=true\nPAYMENT_PROVIDER=DEMO_ONLY\nCALLBACK_URL=https://checkout.example.com/callback',
  ),
  _SecretSpec(
    'Warehouse reporting reader',
    'Analytics',
    'Production',
    'Username and password',
    'Read-only reporting login for the sample warehouse.',
    username: 'demo_reporting_reader',
    expiryDays: 21,
  ),
  _SecretSpec(
    'Metrics export key',
    'Analytics',
    'Staging',
    'API key',
    'Example key for a scheduled metrics export.',
  ),
  _SecretSpec(
    'Pipeline destination settings',
    'Analytics',
    'Development',
    'Environment variable',
    'Demonstrates a multiline ingestion destination.',
  ),
  _SecretSpec(
    'Analytics recovery notes',
    'Analytics',
    'Production',
    'Other',
    'Sample recovery instructions stored as a multiline secret.',
    value:
        'DEMO RECOVERY NOTES\n1. Open https://analytics.example.com/recovery\n2. Use the fictional workspace Northstar Cloud.\n3. Recovery code: DEMO_ONLY_NOT_VALID',
  ),
  _SecretSpec(
    'Invoice processing account',
    'Finance',
    'Production',
    'Username and password',
    'Restricted finance service account example.',
    username: 'demo_invoice_service',
    expiryDays: 14,
  ),
  _SecretSpec(
    'Finance export archive password',
    'Finance',
    'Production',
    'Password',
    'Restricted finance archive example.',
    rotate: true,
  ),
  _SecretSpec(
    'Billing connector test token',
    'Finance',
    'Staging',
    'API key',
    'Test connector for the fictional billing system.',
  ),
  _SecretSpec(
    'Push notification sandbox key',
    'Mobile',
    'Development',
    'API key',
    'Push notification integration placeholder.',
    expiryDays: 120,
  ),
  _SecretSpec(
    'App signing recovery notes',
    'Mobile',
    'Staging',
    'Other',
    'Sample mobile signing checklist.',
    value:
        'DEMO SIGNING CHECKLIST\nApplication: com.example.northstar.demo\nRecovery phrase: DEMO ONLY - NEVER VALID\nPortal: https://mobile.example.com/signing',
  ),
  _SecretSpec(
    'Mobile development certificate',
    'Mobile',
    'Development',
    'Certificate',
    'Nonfunctional certificate sample for development signing.',
    expiryDays: 180,
  ),
];

const _researchSecrets = [
  _SecretSpec(
    'Model router sandbox key',
    'Model Gateway',
    'Staging',
    'API key',
    'Fictional token for model routing experiments.',
    expiryDays: 10,
  ),
  _SecretSpec(
    'Experiment queue worker',
    'Model Gateway',
    'Development',
    'Username and password',
    'Example queue worker credentials.',
    username: 'demo_experiment_worker',
  ),
  _SecretSpec(
    'Model gateway limits',
    'Model Gateway',
    'Production',
    'Environment variable',
    'Example runtime limits for a fictional research gateway.',
  ),
  _SecretSpec(
    'Evaluation signing secret',
    'Model Gateway',
    'Staging',
    'Other',
    'Sample integrity value for evaluation requests.',
    rotate: true,
  ),
  _SecretSpec(
    'Scoring service token',
    'Evaluation',
    'Staging',
    'API key',
    'Placeholder token for synthetic benchmark scoring.',
    expiryDays: 5,
  ),
  _SecretSpec(
    'Benchmark artifact store',
    'Evaluation',
    'Production',
    'Username and password',
    'Example service login for benchmark artifacts.',
    username: 'demo_benchmark_reader',
    expiryDays: 60,
  ),
  _SecretSpec(
    'Evaluation dataset manifest',
    'Evaluation',
    'Development',
    'Environment variable',
    'Multiline manifest referencing only synthetic datasets.',
    value:
        'DEMO_DATASET=synthetic-support-v3\nSOURCE=https://datasets.example.com/synthetic\nACCESS_TOKEN=DEMO_ONLY_NO_ACCESS\nRECORD_LIMIT=1000',
  ),
  _SecretSpec(
    'Evaluation bundle password',
    'Evaluation',
    'Staging',
    'Password',
    'Example password for a synthetic evaluation bundle.',
  ),
  _SecretSpec(
    'Prototype maps API key',
    'Prototype',
    'Development',
    'API key',
    'Restricted prototype integration placeholder.',
    expiryDays: -7,
    rotate: true,
  ),
  _SecretSpec(
    'Prototype local certificate',
    'Prototype',
    'Development',
    'Certificate',
    'Nonfunctional certificate for the restricted prototype.',
    expiryDays: 365,
  ),
];
