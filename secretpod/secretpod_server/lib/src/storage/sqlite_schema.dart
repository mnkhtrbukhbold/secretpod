import 'vault_store.dart';

/// Only these static identifiers are interpolated into SQL. Values are bound.
class VaultTable {
  const VaultTable(
    this.collection,
    this.columns,
    this.primaryKey, {
    this.constraints = const [],
  });
  final String collection;
  final Map<String, String> columns;
  final List<String> primaryKey;
  final List<String> constraints;
  String get name => 'vault_$collection';
  String get createSql =>
      'CREATE TABLE "$name" ('
      '${columns.entries.map((e) => '"${e.key}" ${e.value.replaceAll('?', '')}${e.value.endsWith('?') ? '' : ' NOT NULL'}').join(', ')}, '
      '"_order" INTEGER NOT NULL, '
      'PRIMARY KEY (${primaryKey.map((key) => '"$key"').join(', ')})'
      '${constraints.map((constraint) => ', $constraint').join()})';
  String identity(Map<String, dynamic> row) => primaryKey
      .map((key) => '${(row[key] as String).length}:${row[key]}')
      .join();
}

const vaultTables = [
  VaultTable(
    'accounts',
    {
      'id': 'TEXT',
      'email': 'TEXT',
      'name': 'TEXT',
      'salt': 'TEXT',
      'passwordHash': 'TEXT',
      'invitationPolicy': 'TEXT?',
      'themeMode': 'TEXT?',
    },
    ['id'],
    constraints: ['UNIQUE ("email")'],
  ),
  VaultTable(
    'organizations',
    {
      'id': 'TEXT',
      'name': 'TEXT',
      'createdAt': 'TEXT',
    },
    ['id'],
  ),
  VaultTable(
    'members',
    {
      'organizationId': 'TEXT',
      'accountId': 'TEXT',
      'role': 'TEXT',
    },
    ['organizationId', 'accountId'],
    constraints: [
      'FOREIGN KEY ("organizationId") REFERENCES vault_organizations("id")',
      'FOREIGN KEY ("accountId") REFERENCES vault_accounts("id")',
      'CHECK ("role" IN (\'owner\', \'editor\', \'reader\'))',
    ],
  ),
  VaultTable(
    'sessions',
    {
      'digest': 'TEXT',
      'accountId': 'TEXT',
      'expiresAt': 'TEXT',
    },
    ['digest'],
    constraints: [
      'FOREIGN KEY ("accountId") REFERENCES vault_accounts("id")',
    ],
  ),
  VaultTable(
    'secrets',
    {
      'id': 'TEXT',
      'organizationId': 'TEXT',
      'name': 'TEXT',
      'project': 'TEXT',
      'environment': 'TEXT',
      'kind': 'TEXT',
      'description': 'TEXT',
      'ciphertext': 'TEXT',
      'usernameCiphertext': 'TEXT?',
      'url': 'TEXT?',
      'expiresAt': 'TEXT?',
      'needsRotation': 'INTEGER?',
      'version': 'INTEGER',
      'createdAt': 'TEXT',
      'updatedAt': 'TEXT',
    },
    ['id'],
    constraints: [
      'FOREIGN KEY ("organizationId") REFERENCES vault_organizations("id")',
      'CHECK ("version" > 0)',
    ],
  ),
  VaultTable(
    'events',
    {
      'id': 'TEXT',
      'organizationId': 'TEXT',
      'actor': 'TEXT',
      'action': 'TEXT',
      'target': 'TEXT',
      'createdAt': 'TEXT',
      'secretId': 'TEXT?',
      'actorId': 'TEXT?',
      'version': 'INTEGER?',
      'details': 'TEXT?',
    },
    ['id'],
    constraints: [
      'FOREIGN KEY ("organizationId") REFERENCES vault_organizations("id")',
    ],
  ),
  VaultTable(
    'invitations',
    {
      'id': 'TEXT',
      'organizationId': 'TEXT',
      'inviterId': 'TEXT',
      'inviterName': 'TEXT',
      'inviterEmail': 'TEXT',
      'recipientEmail': 'TEXT',
      'recipientName': 'TEXT',
      'role': 'TEXT',
      'tokenDigest': 'TEXT',
      'status': 'TEXT',
      'createdAt': 'TEXT',
      'expiresAt': 'TEXT',
      'respondedAt': 'TEXT?',
    },
    ['id'],
    constraints: [
      'FOREIGN KEY ("organizationId") REFERENCES vault_organizations("id")',
      'FOREIGN KEY ("inviterId") REFERENCES vault_accounts("id")',
      'UNIQUE ("tokenDigest")',
      'CHECK ("role" IN (\'reader\', \'editor\'))',
      'CHECK ("status" IN (\'pending\', \'accepted\', \'declined\', \'revoked\', \'blocked\', \'expired\'))',
    ],
  ),
];

const vaultIndexes = [
  'CREATE INDEX vault_members_account ON vault_members("accountId")',
  'CREATE INDEX vault_sessions_account ON vault_sessions("accountId")',
  'CREATE INDEX vault_secrets_organization ON vault_secrets("organizationId", "project", "environment")',
  'CREATE INDEX vault_events_organization ON vault_events("organizationId", "_order")',
  'CREATE INDEX vault_events_secret ON vault_events("organizationId", "secretId", "_order")',
  'CREATE INDEX vault_invitations_recipient ON vault_invitations("recipientEmail", "_order")',
  'CREATE UNIQUE INDEX vault_invitations_pending ON vault_invitations("organizationId", "recipientEmail") WHERE "status" = \'pending\'',
];

VaultData emptyVault() => {
  'schema': 1,
  for (final table in vaultTables) table.collection: <Map<String, dynamic>>[],
};

/// Reject malformed or unsupported rows instead of silently losing fields.
void validateVaultShape(VaultData data) {
  if (data['schema'] != 1) throw StateError('Unsupported vault data format.');
  if (data.containsKey('keyCheck') && data['keyCheck'] is! String) {
    throw StateError('Invalid vault key check.');
  }
  for (final table in vaultTables) {
    final collection = data[table.collection];
    if (collection is! List) throw StateError('Invalid vault collection.');
    final identifiers = <String>{};
    for (final row in collection) {
      if (row is! Map<String, dynamic> ||
          row.keys.any((key) => !table.columns.containsKey(key))) {
        throw StateError('Invalid or unsupported vault record.');
      }
      for (final column in table.columns.entries) {
        final value = row[column.key];
        if (value == null && column.value.endsWith('?')) continue;
        if (column.value.startsWith('INTEGER')
            ? value is! int
            : value is! String) {
          throw StateError('Invalid vault field type.');
        }
      }
      if (table.primaryKey.any((key) => (row[key] as String).isEmpty) ||
          !identifiers.add(table.identity(row))) {
        throw StateError('Invalid or duplicate vault record identity.');
      }
    }
  }
}
