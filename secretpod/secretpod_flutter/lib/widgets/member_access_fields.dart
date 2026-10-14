import 'package:flutter/material.dart';
import 'dropdown_field.dart';

class MemberAccess {
  const MemberAccess({
    this.role = 'reader',
    this.readProjects,
    this.writeProjects,
    this.deniedReadProjects,
    this.deniedWriteProjects,
    this.canCreateProjects,
  });
  final String role;
  final List<String>? readProjects,
      writeProjects,
      deniedReadProjects,
      deniedWriteProjects;
  final bool? canCreateProjects;
  bool get allowsCreation =>
      role == 'editor' &&
      (canCreateProjects ?? (readProjects == null && writeProjects == null));
}

String accessDescription(
  String role,
  List<String>? read,
  List<String>? write, {
  List<String>? deniedReadProjects,
  List<String>? deniedWriteProjects,
  bool? canCreateProjects,
}) {
  if (role == 'owner') return 'Full organization access';
  String scope(List<String>? projects, List<String>? denied) => projects == null
      ? (denied == null || denied.isEmpty
            ? 'all projects'
            : 'all except ${denied.join(', ')}')
      : projects.isEmpty
      ? 'no projects'
      : projects.join(', ');
  final create =
      role == 'editor' &&
      (canCreateProjects ?? (read == null && write == null));
  return 'Read: ${scope(read, deniedReadProjects)}${role == 'editor' ? '\nWrite: ${scope(write, deniedWriteProjects)}\nCreate projects: ${create ? 'allowed' : 'not allowed'}' : ''}';
}

class MemberAccessFields extends StatefulWidget {
  const MemberAccessFields({
    super.key,
    required this.initialValue,
    required this.projects,
    required this.onChanged,
    this.enabled = true,
  });
  final MemberAccess initialValue;
  final List<String> projects;
  final ValueChanged<MemberAccess> onChanged;
  final bool enabled;
  @override
  State<MemberAccessFields> createState() => _MemberAccessFieldsState();
}

class _MemberAccessFieldsState extends State<MemberAccessFields> {
  late String _role = widget.initialValue.role;
  late bool _readAll = widget.initialValue.readProjects == null;
  late bool _writeAll = widget.initialValue.writeProjects == null;
  late bool _create = widget.initialValue.allowsCreation;
  late final _read = <String>{...?widget.initialValue.readProjects};
  late final _write = <String>{...?widget.initialValue.writeProjects};
  late final _denyRead = <String>{...?widget.initialValue.deniedReadProjects};
  late final _denyWrite = <String>{...?widget.initialValue.deniedWriteProjects};
  List<String> get _projects {
    final names = <String, String>{};
    for (final name in [
      ...widget.projects,
      ..._read,
      ..._write,
      ..._denyRead,
      ..._denyWrite,
    ]) {
      names.putIfAbsent(name.toLowerCase(), () => name);
    }
    return names.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  bool _contains(Set<String> values, String project) =>
      values.any((p) => p.toLowerCase() == project.toLowerCase());
  bool _canRead(String project) =>
      _readAll ? !_contains(_denyRead, project) : _contains(_read, project);
  bool _canWrite(String project) =>
      _canRead(project) &&
      (_writeAll
          ? !_contains(_denyWrite, project)
          : _contains(_write, project));
  void _set(Set<String> values, String project, bool selected) {
    values.removeWhere((p) => p.toLowerCase() == project.toLowerCase());
    if (selected) values.add(project);
  }

  void _change(VoidCallback update) {
    setState(() {
      update();
      if (_role == 'reader') _create = false;
      _write.removeWhere((p) => !_canRead(p));
      if (_writeAll) _denyWrite.addAll(_projects.where((p) => !_canRead(p)));
    });
    widget.onChanged(
      MemberAccess(
        role: _role,
        readProjects: _readAll ? null : (_read.toList()..sort()),
        writeProjects: _role == 'reader'
            ? []
            : _writeAll
            ? null
            : (_write.toList()..sort()),
        deniedReadProjects: _readAll ? (_denyRead.toList()..sort()) : [],
        deniedWriteProjects: _role == 'editor' && _writeAll
            ? (_denyWrite.toList()..sort())
            : [],
        canCreateProjects: _create,
      ),
    );
  }

  // Mode conversion preserves current permissions; only future access changes.
  void _mode(bool all, {required bool write}) {
    final projects = _projects;
    final allowed = projects.where(write ? _canWrite : _canRead).toList();
    if (write) {
      _writeAll = all;
      _write
        ..clear()
        ..addAll(allowed);
      _denyWrite
        ..clear()
        ..addAll(projects.where((p) => !allowed.contains(p)));
    } else {
      if (!all && _writeAll) _mode(false, write: true);
      _readAll = all;
      _read
        ..clear()
        ..addAll(allowed);
      _denyRead
        ..clear()
        ..addAll(projects.where((p) => !allowed.contains(p)));
    }
  }

  Widget _permission(String project, {required bool write}) => CheckboxListTile(
    key: ValueKey('access-${write ? 'write' : 'read'}-$project'),
    contentPadding: const EdgeInsets.only(left: 12),
    controlAffinity: ListTileControlAffinity.leading,
    title: Text(project),
    value: write ? _canWrite(project) : _canRead(project),
    onChanged: widget.enabled && (!write || _canRead(project))
        ? (value) => _change(() {
            final all = write ? _writeAll : _readAll;
            _set(
              write ? (all ? _denyWrite : _write) : (all ? _denyRead : _read),
              project,
              all ? value != true : value == true,
            );
          })
        : null,
  );
  Widget _section({required bool write}) {
    final all = write ? _writeAll : _readAll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          write ? 'Write access' : 'Read access',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SecretPodDropdown<bool>(
          key: ValueKey('access-${write ? 'write' : 'read'}-mode-$all'),
          initialValue: all,
          decoration: InputDecoration(
            labelText: write ? 'Writable projects' : 'Readable projects',
          ),
          items: const [
            DropdownMenuItem(
              value: false,
              child: Text('Selected projects only'),
            ),
            DropdownMenuItem(
              value: true,
              child: Text('All projects, with exclusions'),
            ),
          ],
          onChanged: widget.enabled && !_create && (!write || _readAll)
              ? (value) => _change(() => _mode(value!, write: write))
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          all
              ? 'Includes future projects. Uncheck a project to deny access.'
              : 'Only checked projects are accessible. Future projects are excluded.',
        ),
        for (final project in _projects) _permission(project, write: write),
        if (_projects.isEmpty) const Text('No projects available.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SecretPodDropdown<String>(
        initialValue: _role,
        decoration: const InputDecoration(labelText: 'Role'),
        items: const [
          DropdownMenuItem(
            value: 'reader',
            child: Text('Reader · view and copy'),
          ),
          DropdownMenuItem(
            value: 'editor',
            child: Text('Editor · manage secrets'),
          ),
        ],
        onChanged: widget.enabled
            ? (value) => _change(() => _role = value!)
            : null,
      ),
      if (_role == 'editor') ...[
        const SizedBox(height: 12),
        CheckboxListTile(
          key: const ValueKey('access-create-projects'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Can create projects'),
          subtitle: const Text(
            'Creators use exclusions and receive read and write access to new projects.',
          ),
          value: _create,
          onChanged: widget.enabled
              ? (value) => _change(() {
                  if (value == true) {
                    _mode(true, write: false);
                    _mode(true, write: true);
                  }
                  _create = value!;
                })
              : null,
        ),
      ],
      _section(write: false),
      if (_role == 'editor') _section(write: true),
    ],
  );
}
