import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secretpod_client/secretpod_client.dart';
import '../state/vault_controller.dart';
import '../state/invitation_link.dart';
import '../widgets/common.dart';
import '../widgets/dialog_shell.dart';
import '../widgets/member_access_fields.dart';

class InviteMemberDialog extends StatefulWidget {
  const InviteMemberDialog({
    super.key,
    required this.controller,
    required this.organizationId,
  });
  final VaultController controller;
  final String organizationId;
  @override
  State<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<InviteMemberDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _email = TextEditingController();
  MemberAccess _access = const MemberAccess();
  String? _error;
  bool _busy = false, _copied = false;
  InvitationCreated? _created;
  int _errorRevision = 0;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy || !validateDialogForm(_form.currentState!)) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorRevision++;
    });
    try {
      final result = await widget.controller.createInvitation(
        widget.organizationId,
        _email.text,
        _name.text,
        _access.role,
        readProjects: _access.readProjects,
        writeProjects: _access.role == 'reader' ? [] : _access.writeProjects,
        deniedReadProjects: _access.deniedReadProjects,
        deniedWriteProjects: _access.role == 'reader'
            ? []
            : _access.deniedWriteProjects,
        canCreateProjects: _access.allowsCreation,
      );
      if (mounted) setState(() => _created = result);
    } catch (e) {
      if (mounted) setState(() => _error = VaultController.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    _errorRevision++;
    try {
      await Clipboard.setData(
        ClipboardData(text: invitationLink(_created!.token)),
      );
      if (mounted) {
        setState(() {
          _copied = true;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not copy the invitation link. Select and copy it manually.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SecretPodDialog(
      maxWidth: 540,
      title: _created == null ? 'Invite a teammate' : 'Invitation created',
      onClose: _busy ? null : () => Navigator.pop(context, _created != null),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () => Navigator.pop(context, _created != null),
          child: Text(_created == null ? 'Cancel' : 'Done'),
        ),
        if (_created == null)
          FilledButton(
            onPressed: _busy ? null : _create,
            child: Text(_busy ? 'Creating…' : 'Create invitation'),
          )
        else
          FilledButton.icon(
            onPressed: _copy,
            icon: Icon(_copied ? Icons.check : Icons.copy),
            label: Text(_copied ? 'Link copied' : 'Copy invitation link'),
          ),
      ],
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_created == null) ...[
              Text(
                'They can join with an existing account or create one. Access begins only after they accept.',
                style: TextStyle(color: context.colors.muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Recipient name',
                ),
                validator: (s) =>
                    s == null || s.trim().isEmpty ? 'Enter their name.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                maxLength: 254,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                ),
                validator: (s) =>
                    RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch(s?.trim() ?? '')
                    ? null
                    : 'Enter a valid email address.',
              ),
              const SizedBox(height: 16),
              MemberAccessFields(
                initialValue: _access,
                projects: widget.controller.projects,
                enabled: !_busy,
                onChanged: (value) => _access = value,
              ),
              const SizedBox(height: 16),
              Text(
                'You’ll receive a private link to share. Links expire after 7 days.',
                style: TextStyle(color: context.colors.muted, fontSize: 12),
              ),
            ] else ...[
              Text(
                'Share this private link with ${_created!.invitation.recipientEmail}. No email has been sent.',
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.canvas,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  invitationLink(_created!.token),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Copy the link before closing. You can track or revoke this invitation in Members.',
                style: TextStyle(color: context.colors.muted, height: 1.5),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              DialogErrorNotice(_error!, key: ValueKey(_errorRevision)),
            ],
          ],
        ),
      ),
    ),
  );
}

class AcceptInvitationDialog extends StatefulWidget {
  const AcceptInvitationDialog({
    super.key,
    required this.controller,
    required this.invitation,
  });
  final VaultController controller;
  final InvitationView invitation;
  @override
  State<AcceptInvitationDialog> createState() => _AcceptInvitationDialogState();
}

class _AcceptInvitationDialogState extends State<AcceptInvitationDialog> {
  final _link = TextEditingController();
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final token = invitationTokenFromLink(_link.text);
    if (token == null) {
      setState(
        () => _error = 'Paste the private invitation link you received.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.client.invitation.accept(
        widget.invitation.id,
        token,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = VaultController.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text('Join ${widget.invitation.organizationName}?'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You will join as ${widget.invitation.role}. ${accessDescription(widget.invitation.role, widget.invitation.readProjects, widget.invitation.writeProjects, deniedReadProjects: widget.invitation.deniedReadProjects, deniedWriteProjects: widget.invitation.deniedWriteProjects, canCreateProjects: widget.invitation.canCreateProjects)}\nPaste the private link shared by ${widget.invitation.inviterName} to confirm this invitation.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _link,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Invitation link'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorNotice(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _accept,
          child: Text(_busy ? 'Accepting…' : 'Accept invitation'),
        ),
      ],
    ),
  );
}
