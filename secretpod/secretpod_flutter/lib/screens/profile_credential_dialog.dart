import 'package:flutter/material.dart';
import '../state/vault_controller.dart';
import '../widgets/common.dart';
import '../widgets/dialog_shell.dart';

class ProfileCredentialDialog extends StatefulWidget {
  const ProfileCredentialDialog({
    super.key,
    required this.controller,
    required this.changeEmail,
  });
  final VaultController controller;
  final bool changeEmail;
  @override
  State<ProfileCredentialDialog> createState() =>
      _ProfileCredentialDialogState();
}

class _ProfileCredentialDialogState extends State<ProfileCredentialDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _replacement = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;
  int _errorRevision = 0;

  @override
  void dispose() {
    _current.dispose();
    _replacement.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !validateDialogForm(_form.currentState!)) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorRevision++;
    });
    try {
      if (widget.changeEmail) {
        await widget.controller.updateEmail(
          _current.text,
          _replacement.text.trim(),
        );
      } else {
        await widget.controller.changePassword(
          _current.text,
          _replacement.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = VaultController.describeError(error);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SecretPodDialog(
      title: widget.changeEmail ? 'Change email' : 'Change password',
      icon: widget.changeEmail ? Icons.alternate_email : Icons.lock_outline,
      onClose: _busy ? null : () => Navigator.pop(context),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(
            _busy
                ? 'Saving…'
                : widget.changeEmail
                ? 'Save email'
                : 'Save password',
          ),
        ),
      ],
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.changeEmail
                  ? 'Use your new email to sign in and receive invitations. Your organization memberships stay the same. Invitations addressed to your previous email will no longer appear in your inbox.'
                  : 'Choose a password between 12 and 256 characters. Other sessions will be signed out; this session stays signed in.',
              style: TextStyle(color: context.colors.muted, height: 1.5),
            ),
            const SizedBox(height: 24),
            if (widget.changeEmail) ...[
              TextFormField(
                controller: _replacement,
                enabled: !_busy,
                autofocus: true,
                maxLength: 254,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'New email address',
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                    return 'Enter a valid email.';
                  }
                  if (email.toLowerCase() ==
                      widget.controller.account?.email.toLowerCase()) {
                    return 'Enter a different email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
            ],
            TextFormField(
              controller: _current,
              enabled: !_busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              autofocus: !widget.changeEmail,
              decoration: const InputDecoration(labelText: 'Current password'),
              validator: (value) => value == null || value.isEmpty
                  ? 'Enter your current password.'
                  : value.length > 256
                  ? 'Use at most 256 characters.'
                  : null,
            ),
            if (!widget.changeEmail) ...[
              const SizedBox(height: 18),
              TextFormField(
                controller: _replacement,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  helperText: '12–256 characters',
                ),
                validator: (value) =>
                    value == null || value.length < 12 || value.length > 256
                    ? 'Use a password between 12 and 256 characters.'
                    : value == _current.text
                    ? 'Choose a different password.'
                    : null,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _confirmation,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (value) => value != _replacement.text
                    ? 'Passwords do not match.'
                    : null,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 18),
              DialogErrorNotice(_error!, key: ValueKey(_errorRevision)),
            ],
          ],
        ),
      ),
    ),
  );
}
