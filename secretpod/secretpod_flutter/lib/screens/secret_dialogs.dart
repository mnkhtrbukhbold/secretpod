import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secretpod_client/secretpod_client.dart';
import '../state/vault_controller.dart';
import '../widgets/common.dart';
import '../widgets/dialog_shell.dart';
import '../widgets/dropdown_field.dart';
import '../widgets/secret_activity.dart';

class SecretEditor extends StatefulWidget {
  const SecretEditor({super.key, required this.controller, this.secret});
  final VaultController controller;
  final SecretView? secret;
  @override
  State<SecretEditor> createState() => _SecretEditorState();
}

class _SecretEditorState extends State<SecretEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.secret?.name);
  late final _initialProject =
      widget.secret?.project ??
      widget.controller.writableProjects
          .where(
            (name) =>
                name.toLowerCase() ==
                widget.controller.secretProject?.toLowerCase(),
          )
          .firstOrNull ??
      widget.controller.writableProjects.firstOrNull ??
      'Default';
  late String _project = _initialProject;
  final _addedProjects = <String>[];
  List<String> get _projects {
    final names = <String, String>{
      for (final name in [
        ...widget.controller.writableProjects,
        ..._addedProjects,
      ])
        name.toLowerCase(): name,
    };
    final original = widget.secret?.project;
    if (original != null) names[original.toLowerCase()] = original;
    // Preserve the exact existing value so opening an editor never changes it.
    names[_project.toLowerCase()] = _project;
    return names.values.toList();
  }

  late final _description = TextEditingController(
    text: widget.secret?.description,
  );
  final _value = TextEditingController();
  final _username = TextEditingController();
  late final _url = TextEditingController(text: widget.secret?.url);
  late DateTime? _expiresAt = widget.secret?.expiresAt;
  late String _environment = widget.secret?.environment ?? 'Development';
  late String _kind = widget.secret?.kind ?? 'API key';
  bool _busy = false, _obscure = true;
  bool _confirmingClose = false;
  int _errorRevision = 0;
  bool get _credential => _kind == 'Username and password';
  String? _error;

  bool get _hasChanges =>
      _name.text != (widget.secret?.name ?? '') ||
      _project != _initialProject ||
      _description.text != (widget.secret?.description ?? '') ||
      _url.text != (widget.secret?.url ?? '') ||
      _value.text.isNotEmpty ||
      _username.text.isNotEmpty ||
      _environment != (widget.secret?.environment ?? 'Development') ||
      _kind != (widget.secret?.kind ?? 'API key') ||
      _expiresAt != widget.secret?.expiresAt;

  Future<void> _requestClose() async {
    if (_busy || _confirmingClose) return;
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }
    _confirmingClose = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved changes will be lost.'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard changes'),
          ),
        ],
      ),
    );
    _confirmingClose = false;
    if (discard == true && mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _value.dispose();
    _username.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !validateDialogForm(_form.currentState!)) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorRevision++;
    });
    try {
      await widget.controller.client.vault.saveSecret(
        widget.controller.organization!.id,
        widget.secret?.id,
        _name.text,
        widget.secret != null && _value.text.isEmpty ? null : _value.text,
        _project,
        _environment,
        _kind,
        _description.text,
        username: _credential && _username.text.isNotEmpty
            ? _username.text
            : null,
        url: _url.text,
        expiresAt: _expiresAt,
        replaceMetadata: true,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = VaultController.describeError(e);
          _busy = false;
        });
      }
    }
  }

  String? _required(String? s) =>
      s == null || s.trim().isEmpty ? 'This field is required.' : null;

  Future<void> _addProject() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewProjectDialog(),
    );
    if (!mounted || name == null) return;
    setState(() {
      final existing = _projects
          .where(
            (project) => project.toLowerCase() == name.toLowerCase(),
          )
          .firstOrNull;
      _project = existing ?? name;
      if (existing == null) _addedProjects.add(name);
    });
  }

  Future<void> _chooseExpiry() async {
    final now = DateTime.now();
    final current = _expiresAt;
    final selected = await showDatePicker(
      context: context,
      helpText: 'Expiry date',
      initialDate: current == null
          ? now
          : DateTime(current.year, current.month, current.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(9999, 12, 31),
    );
    if (selected != null && mounted) {
      setState(
        () => _expiresAt = DateTime.utc(
          selected.year,
          selected.month,
          selected.day,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    // All user dismissals pass through the same dirty/busy check. Successful
    // saves and confirmed discards pop explicitly; session resets still dispose.
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _requestClose();
    },
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _requestClose,
      },
      child: SecretPodDialog(
        title: widget.secret == null ? 'Add a secret' : 'Edit secret',
        icon: Icons.key_outlined,
        onClose: _busy ? null : _requestClose,
        actions: [
          TextButton(
            onPressed: _busy ? null : _requestClose,
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.lock_outline, size: 18),
            label: Text(_busy ? 'Saving…' : 'Save secret'),
          ),
        ],
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.secret == null
                    ? 'Give your team a secure place to find it.'
                    : 'Update details or replace credentials. Leave credential fields blank to keep their current values.',
                style: TextStyle(color: context.colors.muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 120,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'Secret name',
                  hintText: 'e.g. STRIPE_API_KEY',
                ),
              ),
              const SizedBox(height: 12),
              SecretPodDropdown<String>(
                initialValue: _project,
                decoration: const InputDecoration(labelText: 'Project'),
                items: _projects
                    .map(
                      (name) =>
                          DropdownMenuItem(value: name, child: Text(name)),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _project = value!),
              ),
              TextButton.icon(
                onPressed: _busy || !widget.controller.canCreateProject
                    ? null
                    : _addProject,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New project'),
              ),
              const SizedBox(height: 12),
              SecretPodDropdown<String>(
                initialValue: _environment,
                decoration: const InputDecoration(labelText: 'Environment'),
                items: ['Development', 'Staging', 'Production']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _environment = v!),
              ),
              const SizedBox(height: 20),
              SecretPodDropdown<String>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Type'),
                items:
                    [
                          'API key',
                          'Environment variable',
                          'Password',
                          'Username and password',
                          'Certificate',
                          'Other',
                        ]
                        .map(
                          (e) => DropdownMenuItem(value: e, child: Text(e)),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _kind = v!),
              ),
              const SizedBox(height: 20),
              if (widget.secret?.kind == 'Username and password' &&
                  !_credential) ...[
                Text(
                  'Saving this type will remove the saved username. Leave the value field blank to keep the current password.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_credential) ...[
                TextFormField(
                  key: const ValueKey('secret-username'),
                  controller: _username,
                  maxLength: 320,
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: (s) =>
                      widget.secret?.kind == 'Username and password' &&
                          (s?.isEmpty ?? true)
                      ? null
                      : _required(s),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    helperText: widget.secret?.kind == 'Username and password'
                        ? 'Leave blank to keep the current username'
                        : 'Encrypted before it is stored',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: const ValueKey('secret-value'),
                controller: _value,
                maxLines: _credential || _kind == 'Password' ? 1 : 5,
                obscureText: (_credential || _kind == 'Password') && _obscure,
                keyboardType: _credential || _kind == 'Password'
                    ? TextInputType.visiblePassword
                    : TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                validator: (s) => s!.isEmpty && widget.secret == null
                    ? 'Enter a secret value.'
                    : (s.length > 65536 ? 'Maximum 65536 characters.' : null),
                decoration: InputDecoration(
                  labelText: _credential || _kind == 'Password'
                      ? 'Password'
                      : 'Secret value',
                  helperText: widget.secret == null
                      ? 'Encrypted before it is stored'
                      : 'Leave blank to keep the current value',
                  suffixIcon: _credential || _kind == 'Password'
                      ? IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const ValueKey('secret-url'),
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                maxLength: 2048,
                validator: (text) {
                  final value = text?.trim() ?? '';
                  if (value.isEmpty) return null;
                  final uri = Uri.tryParse(value);
                  return uri != null &&
                          ['http', 'https'].contains(uri.scheme) &&
                          uri.host.isNotEmpty &&
                          uri.userInfo.isEmpty &&
                          !RegExp(r'\s').hasMatch(value)
                      ? null
                      : 'Enter an http:// or https:// URL without embedded credentials.';
                },
                decoration: const InputDecoration(
                  labelText: 'URL (optional)',
                  hintText: 'https://example.com/login',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Expiry date',
                style: TextStyle(color: context.colors.muted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _chooseExpiry,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      _expiresAt == null
                          ? 'Set expiry date'
                          : calendarDate(_expiresAt!),
                    ),
                  ),
                  if (_expiresAt == null)
                    Text(
                      'Never expires',
                      style: TextStyle(color: context.colors.muted),
                    ),
                  if (_expiresAt != null)
                    IconButton(
                      tooltip: 'Remove expiry date',
                      onPressed: _busy
                          ? null
                          : () => setState(() => _expiresAt = null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _description,
                maxLines: 2,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'What is this secret used for?',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                DialogErrorNotice(_error!, key: ValueKey(_errorRevision)),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _NewProjectDialog extends StatefulWidget {
  const _NewProjectDialog();

  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (validateDialogForm(_form.currentState!)) {
      Navigator.pop(context, _name.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => SecretPodDialog(
    title: 'New project',
    icon: Icons.folder_outlined,
    onClose: () => Navigator.pop(context),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Add project')),
    ],
    child: Form(
      key: _form,
      child: TextFormField(
        controller: _name,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(
          labelText: 'Project name',
          helperText: 'Added when you save the secret.',
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'This field is required.'
            : null,
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
  );
}

class SecretDetails extends StatefulWidget {
  const SecretDetails({
    super.key,
    required this.controller,
    required this.secret,
  });
  final VaultController controller;
  final SecretView secret;
  @override
  State<SecretDetails> createState() => _SecretDetailsState();
}

class _SecretDetailsState extends State<SecretDetails> {
  final _scrollController = ScrollController();
  int _tab = 0;
  String? _value, _username, _error;
  String? _pendingCopyId;
  String? _copiedField, _pendingCopyField;
  int _activityRevision = 0;
  int _errorRevision = 0;
  bool _busy = false;
  bool get _credential => widget.secret.kind == 'Username and password';
  Timer? _hideTimer;
  Timer? _revealCooldownTimer;
  int _revealCooldownSeconds = 0;
  @override
  void dispose() {
    _hideTimer?.cancel();
    _revealCooldownTimer?.cancel();
    _scrollController.dispose();
    _value = null;
    _username = null;
    super.dispose();
  }

  Future<void> _reveal() async {
    if (_value != null) {
      _hideTimer?.cancel();
      setState(() {
        _value = null;
        _username = null;
      });
      return;
    }
    if (_busy || _revealCooldownSeconds > 0) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorRevision++;
    });
    try {
      final api = widget.controller.client.vault;
      final fields = _credential
          ? await api.revealSecretFields(
              widget.secret.organizationId,
              widget.secret.id,
            )
          : SecretFields(
              value: await api.revealSecret(
                widget.secret.organizationId,
                widget.secret.id,
              ),
            );
      if (!mounted) return;
      setState(() {
        _value = fields.value;
        _username = fields.username;
        _copiedField = null;
        _activityRevision++;
      });
      _hideTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) {
          setState(() {
            _value = null;
            _username = null;
            _copiedField = null;
          });
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = VaultController.describeError(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _revealCooldownSeconds = 2;
        });
        _revealCooldownTimer = Timer.periodic(const Duration(seconds: 1), (
          timer,
        ) {
          setState(() => _revealCooldownSeconds--);
          if (_revealCooldownSeconds == 0) timer.cancel();
        });
      }
    }
  }

  Future<void> _copy([String field = 'value']) async {
    if (_busy || _pendingCopyId != null) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorRevision++;
      _copiedField = null;
    });
    SecretCopy? receipt;
    var clipboardWritten = false;
    try {
      receipt = await widget.controller.client.vault.copySecret(
        widget.secret.organizationId,
        widget.secret.id,
        field: field,
      );
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: receipt.value));
      clipboardWritten = true;
      _pendingCopyId = receipt.eventId;
      _pendingCopyField = field;
      await widget.controller.client.vault.confirmCopy(
        widget.secret.organizationId,
        widget.secret.id,
        receipt.eventId,
      );
      _pendingCopyId = null;
      _pendingCopyField = null;
      if (mounted) setState(() => _copiedField = field);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = clipboardWritten
              ? 'Value copied, but its confirmation could not be saved. The copy request is recorded.'
              : receipt != null
              ? 'Clipboard access failed. The copy request is recorded, but no completed copy was reported.'
              : VaultController.describeError(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activityRevision++;
        });
      }
    }
  }

  Future<void> _retryConfirmation() async {
    final eventId = _pendingCopyId;
    if (_busy || eventId == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorRevision++;
    });
    try {
      await widget.controller.client.vault.confirmCopy(
        widget.secret.organizationId,
        widget.secret.id,
        eventId,
      );
      _pendingCopyId = null;
      final field = _pendingCopyField;
      _pendingCopyField = null;
      if (mounted) setState(() => _copiedField = field);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Value copied, but its confirmation could not be saved. The copy request is recorded.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _activityRevision++;
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this secret?'),
        content: Text(
          '“${widget.secret.name}” will be permanently removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.danger,
              foregroundColor: context.colors.onDanger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete secret'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorRevision++;
    });
    try {
      await widget.controller.client.vault.deleteSecret(
        widget.secret.organizationId,
        widget.secret.id,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = VaultController.describeError(e);
        });
      }
    }
  }

  Future<void> _setRotationFlag() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorRevision++;
    });
    try {
      await widget.controller.client.vault.setSecretRotationRequired(
        widget.secret.organizationId,
        widget.secret.id,
        !widget.secret.needsRotation,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = VaultController.describeError(e);
        });
      }
    }
  }

  Future<void> _rotate() async {
    _hideTimer?.cancel();
    setState(() {
      _value = null;
      _username = null;
    });
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          SecretEditor(controller: widget.controller, secret: widget.secret),
    );
    if (changed == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final secret = widget.secret;
    return DefaultTabController(
      length: 2,
      child: SecretPodDialog(
        maxWidth: 580,
        title: secret.name,
        selectableTitle: true,
        icon: kindIcon(secret.kind),
        onClose: _busy ? null : () => Navigator.pop(context),
        scrollController: _scrollController,
        headerBottom: TabBar(
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Activity'),
          ],
          onTap: (index) {
            if (index == _tab) return;
            if (_scrollController.hasClients) _scrollController.jumpTo(0);
            setState(() => _tab = index);
          },
        ),
        actions: [
          if (widget.controller.canWriteProject(secret.project)) ...[
            TextButton.icon(
              onPressed: _busy ? null : _delete,
              style: TextButton.styleFrom(
                foregroundColor: context.colors.danger,
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _rotate,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit secret'),
            ),
          ],
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_tab == 1)
              SecretActivity(
                controller: widget.controller,
                secret: secret,
                revision: _activityRevision,
              )
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  EnvironmentBadge(secret.environment),
                  if (secret.needsRotation) const RotationLabel(),
                  Text(
                    secret.kind,
                    style: TextStyle(color: context.colors.muted),
                  ),
                  Text(
                    'Version ${secret.version}',
                    style: TextStyle(color: context.colors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (_credential) ...[
                Text(
                  'USERNAME',
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.colors.canvas,
                    border: Border.all(color: context.colors.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _username == null
                      ? Text(
                          '••••••••••••',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: context.colors.muted,
                          ),
                        )
                      : SelectableText(
                          _username!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy || _pendingCopyId != null
                      ? null
                      : () => _copy('username'),
                  icon: Icon(
                    _copiedField == 'username'
                        ? Icons.check
                        : Icons.copy_outlined,
                    size: 18,
                  ),
                  label: Text(
                    _copiedField == 'username'
                        ? 'Username copied'
                        : 'Copy username',
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                _credential || secret.kind == 'Password'
                    ? 'PASSWORD'
                    : 'SECRET VALUE',
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.colors.canvas,
                  border: Border.all(color: context.colors.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _value == null
                    ? Text(
                        '••••••••••••••••••••••••',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          color: context.colors.muted,
                        ),
                      )
                    : SelectableText(
                        _value!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _value == null && (_busy || _revealCooldownSeconds > 0)
                        ? null
                        : _reveal,
                    icon: Icon(
                      _value == null
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _value != null
                          ? (_credential ? 'Hide credentials' : 'Hide value')
                          : _busy
                          ? 'Loading…'
                          : _revealCooldownSeconds > 0
                          ? 'Reveal in ${_revealCooldownSeconds}s'
                          : (_credential
                                ? (_value == null
                                      ? 'Reveal credentials'
                                      : 'Hide credentials')
                                : (_value == null
                                      ? 'Reveal value'
                                      : 'Hide value')),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || _pendingCopyId != null
                        ? null
                        : () => _copy(),
                    icon: Icon(
                      _copiedField == 'value'
                          ? Icons.check
                          : Icons.copy_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _credential
                          ? (_copiedField == 'value'
                                ? 'Password copied'
                                : 'Copy password')
                          : (_copiedField == 'value' ? 'Copied' : 'Copy'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Reveals and Copy button actions are recorded. Values hide after 30 seconds.',
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(color: context.colors.outline),
              ),
              Text(
                'Project · ${secret.project}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Text(
                secret.description.isEmpty
                    ? 'No description added.'
                    : secret.description,
                style: TextStyle(color: context.colors.muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              if (secret.url != null) ...[
                Text(
                  'URL',
                  style: TextStyle(color: context.colors.muted, fontSize: 11),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  secret.url!,
                  style: TextStyle(color: context.colors.blue),
                ),
                const SizedBox(height: 12),
              ],
              ExpiryLabel(secret.expiresAt),
              if (widget.controller.canWriteProject(secret.project)) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _busy ? null : _setRotationFlag,
                  icon: const Icon(Icons.change_circle_outlined, size: 18),
                  label: Text(
                    secret.needsRotation
                        ? 'Clear rotation flag'
                        : 'Mark as needs rotating',
                  ),
                ),
                if (secret.needsRotation)
                  Text(
                    'Saving a changed secret value clears this flag. Clear it manually only when rotation is complete.',
                    style: TextStyle(color: context.colors.muted, fontSize: 12),
                  ),
              ],
              const SizedBox(height: 12),
              Text(
                'Updated ${friendlyDate(secret.updatedAt)}',
                style: TextStyle(color: context.colors.muted, fontSize: 12),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              DialogErrorNotice(_error!, key: ValueKey(_errorRevision)),
            ],
            if (_pendingCopyId != null)
              TextButton(
                onPressed: _busy ? null : _retryConfirmation,
                child: const Text('Retry confirmation'),
              ),
          ],
        ),
      ),
    );
  }
}
