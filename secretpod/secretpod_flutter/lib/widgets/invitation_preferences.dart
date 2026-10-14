import 'package:flutter/material.dart';
import '../state/vault_controller.dart';
import 'common.dart';
import 'dropdown_field.dart';

class InvitationPreferences extends StatefulWidget {
  const InvitationPreferences({
    super.key,
    required this.controller,
    this.enabled = true,
  });
  final VaultController controller;
  final bool enabled;
  @override
  State<InvitationPreferences> createState() => _InvitationPreferencesState();
}

class _InvitationPreferencesState extends State<InvitationPreferences> {
  late String _policy, _savedPolicy;
  late String? _accountId;
  bool _busy = false;
  String? _error, _notice;

  @override
  void initState() {
    super.initState();
    _policy = _savedPolicy =
        widget.controller.account?.invitationPolicy ?? 'all';
    _accountId = widget.controller.account?.id;
  }

  @override
  void didUpdateWidget(covariant InvitationPreferences oldWidget) {
    super.didUpdateWidget(oldWidget);
    final account = widget.controller.account;
    final saved = account?.invitationPolicy ?? 'all';
    if (account?.id != _accountId || _policy == _savedPolicy) _policy = saved;
    _accountId = account?.id;
    _savedPolicy = saved;
  }

  Future<void> _save() async {
    if (_busy || !widget.enabled) return;
    final accountId = _accountId;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.controller.updateInvitationPolicy(_policy);
      if (!mounted || widget.controller.account?.id != accountId) return;
      setState(() {
        _policy = _savedPolicy =
            widget.controller.account!.invitationPolicy ?? 'all';
        _notice = 'Invitation preference saved.';
      });
      await widget.controller.refresh();
    } catch (error) {
      if (mounted) {
        setState(() => _error = VaultController.describeError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Who can invite you?',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 8),
      Text(
        'Choose which organization invitations you receive.',
        style: TextStyle(color: context.colors.muted, height: 1.5),
      ),
      const SizedBox(height: 20),
      SecretPodDropdown<String>(
        key: const ValueKey('invitation-policy'),
        initialValue: _policy,
        items: const [
          DropdownMenuItem(value: 'all', child: Text('Allow all invitations')),
          DropdownMenuItem(
            value: 'sameDomain',
            child: Text('Same email domain only'),
          ),
          DropdownMenuItem(value: 'none', child: Text('Block all invitations')),
        ],
        onChanged: _busy || !widget.enabled
            ? null
            : (value) => setState(() {
                _policy = value!;
                _notice = null;
              }),
        decoration: const InputDecoration(labelText: 'Invitation preference'),
      ),
      const SizedBox(height: 12),
      Text(
        'Same domain means the inviter’s email ends in @${widget.controller.account?.email.split('@').last ?? ''}. Changing this also blocks pending invitations that no longer qualify.',
        style: TextStyle(
          color: context.colors.muted,
          height: 1.5,
          fontSize: 12,
        ),
      ),
      if (_error != null) ...[const SizedBox(height: 16), ErrorNotice(_error!)],
      if (_notice != null) ...[
        const SizedBox(height: 16),
        Text(_notice!, style: TextStyle(color: context.colors.blue)),
      ],
      const SizedBox(height: 16),
      FilledButton.tonal(
        onPressed: _busy || !widget.enabled ? null : _save,
        child: Text(_busy ? 'Saving…' : 'Save preference'),
      ),
    ],
  );
}
