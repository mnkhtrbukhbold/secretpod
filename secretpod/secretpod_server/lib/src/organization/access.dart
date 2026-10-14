import 'dart:convert';
import '../generated/protocol.dart';
import '../storage/vault_store.dart';

String requireMembership(
  VaultData data,
  String actor,
  String organizationId, {
  bool write = false,
  bool owner = false,
}) {
  final members = rows(data, 'members').where(
    (m) => m['accountId'] == actor && m['organizationId'] == organizationId,
  );
  if (members.isEmpty || members.first['accessDisabled'] == 1) {
    throw VaultException(message: 'Organization access denied.');
  }
  final role = members.first['role'] as String;
  if (!['owner', 'editor', 'reader'].contains(role) ||
      (write && role == 'reader') ||
      (owner && role != 'owner')) {
    throw VaultException(message: 'Your role does not allow this action.');
  }
  return role;
}

/// Null preserves legacy all-project access; an empty list grants no projects.
List<String>? projectScope(Map<String, dynamic> row, String field) {
  final encoded = row[field];
  if (encoded == null) return null;
  try {
    return (jsonDecode(encoded as String) as List).cast<String>().toList();
  } catch (_) {
    return const [];
  }
}

// Invalid exclusions cannot be treated as an empty denial list.
bool _validExclusions(Map<String, dynamic> row, String field) {
  if (row[field] == null) return true;
  try {
    final values = jsonDecode(row[field] as String);
    return values is List && values.every((value) => value is String);
  } catch (_) {
    return false;
  }
}

bool projectCreationAllowed(Map<String, dynamic> member) =>
    member['role'] == 'owner' ||
    (member['role'] == 'editor' &&
        (member['canCreateProjects'] == null ||
            member['canCreateProjects'] == 1) &&
        member['readProjects'] == null &&
        member['writeProjects'] == null &&
        _validExclusions(member, 'deniedReadProjects') &&
        _validExclusions(member, 'deniedWriteProjects'));

class ProjectAccess {
  ProjectAccess(VaultData data, String actor, String organizationId)
    : role = requireMembership(data, actor, organizationId),
      member = rows(data, 'members').firstWhere(
        (m) => m['accountId'] == actor && m['organizationId'] == organizationId,
      );

  final String role;
  final Map<String, dynamic> member;
  late final List<String>? readProjects = projectScope(member, 'readProjects');
  late final List<String>? writeProjects = projectScope(
    member,
    'writeProjects',
  );
  late final deniedReadProjects =
      projectScope(member, 'deniedReadProjects') ?? <String>[];
  late final deniedWriteProjects =
      projectScope(member, 'deniedWriteProjects') ?? <String>[];
  late final _validRead = _validExclusions(member, 'deniedReadProjects');
  late final _validWrite = _validExclusions(member, 'deniedWriteProjects');
  bool get canCreateProjects => projectCreationAllowed(member);
  bool get readAll =>
      role == 'owner' ||
      (_validRead && readProjects == null && deniedReadProjects.isEmpty);
  bool get writeAll =>
      role == 'owner' ||
      (role == 'editor' &&
          readAll &&
          _validWrite &&
          writeProjects == null &&
          deniedWriteProjects.isEmpty);
  bool canRead(String project) =>
      role == 'owner' ||
      (_validRead &&
          !_includes(deniedReadProjects, project) &&
          (readProjects == null || _includes(readProjects!, project)));
  bool canWrite(String project) =>
      role == 'owner' ||
      (role == 'editor' &&
          _validWrite &&
          !_includes(deniedWriteProjects, project) &&
          canRead(project) &&
          (writeProjects == null || _includes(writeProjects!, project)));
  static bool _includes(List<String> projects, String project) =>
      projects.any((p) => p.toLowerCase() == project.toLowerCase());

  void require(String project, {bool write = false}) {
    if (write ? !canWrite(project) : !canRead(project)) {
      throw VaultException(message: 'Project access denied.');
    }
  }

  bool canReadEvent(VaultData data, Map<String, dynamic> event) {
    if (readAll) return true;
    final project = event['project'] as String?;
    // Historical events without project evidence cannot establish access.
    if (project == null || !canRead(project)) return false;
    final secret = rows(data, 'secrets')
        .where(
          (s) =>
              s['organizationId'] == event['organizationId'] &&
              s['id'] == event['secretId'],
        )
        .firstOrNull;
    return secret == null || canRead(secret['project'] as String);
  }
}

/// Validate once for invitations and existing members, inside their transaction.
({
  List<String>? read,
  List<String>? write,
  List<String> deniedRead,
  List<String> deniedWrite,
  bool create,
})
validateProjectScopes(
  VaultData data,
  String organizationId,
  String role,
  List<String>? readProjects,
  List<String>? writeProjects, {
  Map<String, dynamic>? existingMember,
  List<String>? deniedReadProjects,
  List<String>? deniedWriteProjects,
  bool? canCreateProjects,
}) {
  if (!['reader', 'editor'].contains(role)) {
    throw VaultException(message: 'Choose reader or editor.');
  }
  final names = <String, String>{'default': 'Default'};
  // Legacy projects may exist only through secrets. Keep their existing grants
  // editable after the last secret is deleted, including historical access.
  if (existingMember != null) {
    for (final field in [
      'readProjects',
      'writeProjects',
      'deniedReadProjects',
      'deniedWriteProjects',
    ]) {
      for (final name in projectScope(existingMember, field) ?? <String>[]) {
        names.putIfAbsent(name.toLowerCase(), () => name);
      }
    }
  }
  for (final p in rows(
    data,
    'projects',
  ).where((p) => p['organizationId'] == organizationId)) {
    names.putIfAbsent(
      (p['name'] as String).toLowerCase(),
      () => p['name'] as String,
    );
  }
  for (final s in rows(
    data,
    'secrets',
  ).where((s) => s['organizationId'] == organizationId)) {
    names.putIfAbsent(
      (s['project'] as String).toLowerCase(),
      () => s['project'] as String,
    );
  }
  List<String>? normalize(List<String>? scope) {
    if (scope == null) return null;
    final selected = <String>{};
    for (final value in scope) {
      final canonical = names[value.trim().toLowerCase()];
      if (canonical == null) {
        throw VaultException(message: 'Choose an existing project.');
      }
      selected.add(canonical);
    }
    return selected.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  final read = normalize(readProjects);
  final write = normalize(writeProjects);
  final deniedRead = normalize(deniedReadProjects) ?? <String>[];
  final deniedWrite = normalize(deniedWriteProjects) ?? <String>[];
  if ((read != null && deniedRead.isNotEmpty) ||
      (write != null && deniedWrite.isNotEmpty)) {
    throw VaultException(
      message: 'Use selected projects or exclusions for each permission.',
    );
  }
  final create =
      canCreateProjects ?? (role == 'editor' && read == null && write == null);
  if (create && (role != 'editor' || read != null || write != null)) {
    throw VaultException(
      message:
          'Project creators must use all projects with exclusions for read and write access.',
    );
  }
  if (role == 'reader' &&
      ((write != null && write.isNotEmpty) || deniedWrite.isNotEmpty)) {
    throw VaultException(message: 'Readers cannot have write access.');
  }
  if (role == 'editor' &&
      read != null &&
      (write == null || write.any((p) => !read.contains(p)))) {
    throw VaultException(
      message: 'Write access requires read access to the same projects.',
    );
  }
  if (role == 'editor' && write != null && write.any(deniedRead.contains)) {
    throw VaultException(
      message: 'Write access requires read access to the same projects.',
    );
  }
  // A read exclusion also prevents writing, including future policy checks.
  if (role == 'editor' && write == null) {
    deniedWrite.addAll(deniedRead.where((p) => !deniedWrite.contains(p)));
    deniedWrite.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }
  return (
    read: read,
    write: role == 'reader' ? <String>[] : write,
    deniedRead: deniedRead,
    deniedWrite: role == 'reader' ? <String>[] : deniedWrite,
    create: create,
  );
}
