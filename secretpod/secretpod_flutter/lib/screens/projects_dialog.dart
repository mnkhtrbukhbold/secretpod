import 'package:flutter/material.dart';
import '../state/vault_controller.dart';
import '../widgets/common.dart';
import '../widgets/dialog_shell.dart';
import '../widgets/dropdown_field.dart';

/// Returns a project name, or an empty string for all projects. Cancel is null.
class ProjectsDialog extends StatelessWidget {
  const ProjectsDialog({
    super.key,
    required this.controller,
    required this.organizationId,
  });
  final VaultController controller;
  final String organizationId;

  Future<void> _create(BuildContext context) async {
    final accountId = controller.account?.id;
    final token = controller.auth.token;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CreateProjectDialog(
        controller: controller,
        organizationId: organizationId,
      ),
    );
    if (context.mounted &&
        name != null &&
        controller.organization?.id == organizationId &&
        controller.account?.id == accountId &&
        controller.auth.token == token) {
      Navigator.pop(context, name);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final current = controller.organization?.id == organizationId;
      final names = current ? controller.projects : <String>[];
      final selected = controller.secretProject?.toLowerCase();
      return SecretPodDialog(
        title: 'Projects',
        icon: Icons.folder_outlined,
        onClose: () => Navigator.pop(context),
        scrollBody: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (current && controller.canCreateProject)
            FilledButton.icon(
              onPressed: () => _create(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create project'),
            ),
        ],
        child: SizedBox(
          height: ((names.length + 1) * 80.0).clamp(160.0, 360.0),
          child: ListView.builder(
            itemCount: current ? names.length + 1 : 0,
            itemBuilder: (context, index) {
              final name = index == 0 ? '' : names[index - 1];
              final isSelected = index == 0
                  ? selected == null
                  : name.toLowerCase() == selected;
              final count = index == 0
                  ? controller.secretCount
                  : controller.projectCount(name);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: isSelected
                      ? context.colors.purpleContainer
                      : Colors.transparent,
                  borderRadius: menuRadius,
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    selected: isSelected,
                    selectedColor: context.colors.ink,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Tooltip(
                      message: name.isEmpty ? 'All projects' : name,
                      child: Text(
                        name.isEmpty ? 'All projects' : name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    subtitle: Text(
                      '$count ${count == 1 ? 'secret' : 'secrets'}',
                      style: TextStyle(color: context.colors.muted),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            color: context.colors.purple,
                          )
                        : null,
                    onTap: () => Navigator.pop(context, name),
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

class ProjectFilterButton extends StatelessWidget {
  const ProjectFilterButton({
    super.key,
    required this.project,
    required this.onChoose,
    required this.onClear,
  });
  final String? project;
  final VoidCallback onChoose, onClear;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: TextButton(
              onPressed: onChoose,
              style: selectTriggerStyle(context).copyWith(
                backgroundColor: project == null
                    ? null
                    : WidgetStatePropertyAll(context.colors.purpleContainer),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 18,
                    color: context.colors.purple,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Tooltip(
                      message: project ?? 'All projects',
                      child: Text(
                        project == null ? 'All projects' : 'Project: $project',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down, size: 18),
                ],
              ),
            ),
          ),
          if (project != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Clear project filter',
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ],
      ),
    ),
  );
}

class _CreateProjectDialog extends StatefulWidget {
  const _CreateProjectDialog({
    required this.controller,
    required this.organizationId,
  });
  final VaultController controller;
  final String organizationId;
  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;
  int _errorRevision = 0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !validateDialogForm(_form.currentState!)) return;
    final controller = widget.controller;
    final accountId = controller.account?.id;
    final token = controller.auth.token;
    setState(() {
      _busy = true;
      _error = null;
      _errorRevision++;
    });
    try {
      final name = await controller.createProject(
        widget.organizationId,
        _name.text.trim(),
      );
      if (!mounted) return;
      if (controller.organization?.id != widget.organizationId ||
          controller.account?.id != accountId ||
          controller.auth.token != token) {
        Navigator.pop(context);
        return;
      }
      Navigator.pop(context, name);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = VaultController.describeError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SecretPodDialog(
      title: 'Create project',
      icon: Icons.create_new_folder_outlined,
      onClose: _busy ? null : () => Navigator.pop(context),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Creating…' : 'Create'),
        ),
      ],
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              DialogErrorNotice(_error!, key: ValueKey(_errorRevision)),
            TextFormField(
              controller: _name,
              autofocus: true,
              enabled: !_busy,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Project name'),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              validator: (value) {
                final name = (value ?? '').trim();
                if (name.isEmpty) return 'This field is required.';
                if (name.length > 80) return 'Use 80 characters or fewer.';
                if (widget.controller.projects.any(
                  (p) => p.toLowerCase() == name.toLowerCase(),
                )) {
                  return 'A project with this name already exists.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    ),
  );
}
