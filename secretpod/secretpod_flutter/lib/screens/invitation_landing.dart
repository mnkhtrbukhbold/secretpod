import 'package:flutter/material.dart';
import 'package:secretpod_client/secretpod_client.dart';
import '../state/vault_controller.dart';
import '../widgets/common.dart';

class InvitationLanding extends StatefulWidget {
  const InvitationLanding({
    super.key,
    required this.controller,
    required this.token,
    required this.onClose,
    this.initialSignIn = false,
  });
  final VaultController controller;
  final String token;
  final VoidCallback onClose;
  final bool initialSignIn;
  @override
  State<InvitationLanding> createState() => _InvitationLandingState();
}

class _InvitationLandingState extends State<InvitationLanding> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _password = TextEditingController();
  InvitationView? _invitation;
  String? _error;
  bool _loading = true,
      _busy = false,
      _signIn = false,
      _obscure = true,
      _declined = false;
  @override
  void initState() {
    super.initState();
    _signIn = widget.initialSignIn;
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invite = await widget.controller.client.account.previewInvitation(
        widget.token,
      );
      if (mounted) {
        setState(() {
          _invitation = invite;
          _name.text = invite.recipientName;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = VaultController.describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? true)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = widget.controller;
      if (c.account != null) {
        await c.client.invitation.accept(_invitation!.id, widget.token);
        await c.refresh();
        if (mounted) widget.onClose();
      } else if (_signIn) {
        await c.authenticate(
          email: _invitation!.recipientEmail,
          password: _password.text,
        );
        _password.clear();
      } else {
        final auth = await c.client.account.registerFromInvitation(
          widget.token,
          _name.text,
          _password.text,
        );
        _password.clear();
        await c.useAuthentication(auth);
        if (mounted) widget.onClose();
      }
    } catch (e) {
      if (mounted) setState(() => _error = VaultController.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = widget.controller;
      if (c.account != null) {
        await c.client.invitation.decline(_invitation!.id);
        await c.refresh();
      } else {
        await c.client.account.declineInvitation(widget.token);
      }
      if (mounted) setState(() => _declined = true);
    } catch (e) {
      if (mounted) setState(() => _error = VaultController.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchAccount() async {
    try {
      await widget.controller.logout();
    } catch (_) {
      /* Local credentials are still cleared by logout. */
    }
    if (mounted) {
      setState(() {
        _signIn = true;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invitation;
    final account = widget.controller.account;
    final wrongAccount =
        account != null &&
        invite != null &&
        account.email != invite.recipientEmail;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card.filled(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Brand(),
                        const SizedBox(height: 28),
                        if (_loading)
                          const Center(child: CircularProgressIndicator())
                        else if (_declined) ...[
                          const Text(
                            'Invitation declined',
                            style: TextStyle(fontSize: 28),
                          ),
                          const SizedBox(height: 12),
                          const Text('You have not joined this organization.'),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: widget.onClose,
                            child: const Text('Continue to SecretPod'),
                          ),
                        ] else if (invite != null) ...[
                          Text(
                            'Join ${invite.organizationName}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${invite.inviterName} (${invite.inviterEmail}) invited you as ${invite.role}.',
                            style: const TextStyle(height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Invited email: ${invite.recipientEmail}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Expires ${calendarDate(invite.expiresAt.toLocal())}',
                            style: TextStyle(
                              color: context.colors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (wrongAccount) ...[
                            Text(
                              'You are signed in as ${account.email}. Switch to the invited account to continue.',
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _busy ? null : _switchAccount,
                              child: const Text('Switch account'),
                            ),
                          ] else ...[
                            if (account == null) ...[
                              Text(
                                _signIn
                                    ? 'Sign in to review and accept'
                                    : 'Create your account and accept',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (!_signIn) ...[
                                TextFormField(
                                  controller: _name,
                                  maxLength: 80,
                                  decoration: const InputDecoration(
                                    labelText: 'Your name',
                                    helperText:
                                        'You can edit the name provided by your team',
                                  ),
                                  validator: (s) =>
                                      s == null || s.trim().isEmpty
                                      ? 'Enter your name.'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextFormField(
                                controller: _password,
                                obscureText: _obscure,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  helperText: _signIn
                                      ? null
                                      : 'At least 12 characters',
                                  suffixIcon: IconButton(
                                    tooltip: _obscure
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (s) => s == null || s.isEmpty
                                    ? 'Enter your password.'
                                    : (!_signIn && s.length < 12
                                          ? 'Use at least 12 characters.'
                                          : null),
                              ),
                              const SizedBox(height: 20),
                            ],
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: _busy ? null : _submit,
                                  child: Text(
                                    _busy
                                        ? 'Please wait…'
                                        : account != null
                                        ? 'Accept invitation'
                                        : _signIn
                                        ? 'Sign in'
                                        : 'Create account and accept',
                                  ),
                                ),
                                TextButton(
                                  onPressed: _busy ? null : _decline,
                                  child: const Text('Decline invitation'),
                                ),
                              ],
                            ),
                            if (account == null)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        _signIn = !_signIn;
                                        _error = null;
                                        _password.clear();
                                      }),
                                child: Text(
                                  _signIn
                                      ? 'Create an account instead'
                                      : 'Already have an account? Sign in',
                                ),
                              ),
                          ],
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          ErrorNotice(
                            _error!,
                            onRetry: invite == null ? _load : null,
                          ),
                        ],
                        if (!_declined) ...[
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: _busy ? null : widget.onClose,
                            child: const Text('Back to SecretPod'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
