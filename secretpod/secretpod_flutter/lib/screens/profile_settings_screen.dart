import 'package:flutter/material.dart';
import '../state/vault_controller.dart';
import '../widgets/common.dart';
import '../widgets/dialog_shell.dart';
import '../widgets/dropdown_field.dart';
import '../widgets/invitation_preferences.dart';
import 'profile_credential_dialog.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({
    super.key,
    required this.controller,
    required this.onSignOut,
  });
  final VaultController controller;
  final VoidCallback onSignOut;
  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.controller.account!.name,
  );
  late String _savedName = widget.controller.account!.name;
  bool _busy = false;
  String? _notice, _error;
  int _errorRevision = 0;

  @override
  void didUpdateWidget(covariant ProfileSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final name = widget.controller.account!.name;
    if (_name.text == _savedName) _name.text = name;
    _savedName = name;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(Future<void> Function() operation, String notice) async {
    if (_busy) return;
    final accountId = widget.controller.account!.id;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
      _errorRevision++;
    });
    try {
      await operation();
      if (mounted && widget.controller.account?.id == accountId) {
        setState(() => _notice = notice);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = VaultController.describeError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editCredential(bool email) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProfileCredentialDialog(
        controller: widget.controller,
        changeEmail: email,
      ),
    );
    if (mounted && saved == true) {
      setState(() {
        _error = null;
        _notice = email
            ? 'Email address updated.'
            : 'Password changed. Other sessions have been signed out.';
      });
    }
  }

  Widget _section(BuildContext context, List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: context.colors.panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.colors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final account = widget.controller.account!;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile settings',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your account, appearance, and receiving invitations.',
              style: TextStyle(color: context.colors.muted, height: 1.5),
            ),
            if (_error != null) ...[
              const SizedBox(height: 20),
              DialogErrorNotice(_error!, key: ValueKey(_errorRevision)),
            ],
            if (_notice != null) ...[
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: Text(
                  _notice!,
                  style: TextStyle(color: context.colors.blue),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _section(context, [
              const Text(
                'Your profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              Form(
                key: _form,
                child: TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name.'
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        if (!validateDialogForm(_form.currentState!)) return;
                        _save(() async {
                          await widget.controller.updateName(_name.text.trim());
                          if (mounted &&
                              widget.controller.account?.id == account.id) {
                            _name.text = _savedName =
                                widget.controller.account!.name;
                          }
                        }, 'Profile saved.');
                      },
                child: const Text('Save profile'),
              ),
              const SizedBox(height: 24),
              Divider(height: 1, color: context.colors.outline),
              const SizedBox(height: 20),
              Text(
                'Email address',
                style: TextStyle(fontSize: 12, color: context.colors.muted),
              ),
              const SizedBox(height: 6),
              SelectableText(account.email),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _editCredential(true),
                icon: const Icon(Icons.alternate_email, size: 18),
                label: const Text('Change email'),
              ),
            ]),
            const SizedBox(height: 20),
            _section(context, [
              const Text(
                'Appearance',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'System follows your device’s light or dark setting. Your choice is saved to your account.',
                style: TextStyle(color: context.colors.muted, height: 1.5),
              ),
              const SizedBox(height: 20),
              SecretPodDropdown<String>(
                key: ValueKey((
                  'profile-theme',
                  account.themeMode ?? 'system',
                  _errorRevision,
                )),
                initialValue: account.themeMode ?? 'system',
                decoration: const InputDecoration(labelText: 'Theme'),
                items: const [
                  DropdownMenuItem(value: 'system', child: Text('System')),
                  DropdownMenuItem(value: 'light', child: Text('Light')),
                  DropdownMenuItem(value: 'dark', child: Text('Dark')),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value != null) {
                          _save(
                            () => widget.controller.updateTheme(value),
                            'Theme saved.',
                          );
                        }
                      },
              ),
            ]),
            const SizedBox(height: 20),
            _section(context, [
              InvitationPreferences(
                controller: widget.controller,
                enabled: !_busy,
              ),
            ]),
            const SizedBox(height: 20),
            _section(context, [
              const Text(
                'Security',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Update your password or sign out of this session.',
                style: TextStyle(color: context.colors.muted, height: 1.5),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _editCredential(false),
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Change password'),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : widget.onSignOut,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
