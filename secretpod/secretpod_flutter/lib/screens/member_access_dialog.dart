import 'package:flutter/material.dart';
import 'package:secretpod_client/secretpod_client.dart';
import '../state/vault_controller.dart';
import '../widgets/dialog_shell.dart';
import '../widgets/member_access_fields.dart';

class MemberAccessDialog extends StatefulWidget {
  const MemberAccessDialog({
    super.key,
    required this.controller,
    required this.organizationId,
    required this.member,
  });
  final VaultController controller;
  final String organizationId;
  final MemberView member;
  @override
  State<MemberAccessDialog> createState() => _MemberAccessDialogState();
}

class _MemberAccessDialogState extends State<MemberAccessDialog> {
  late MemberAccess _access = MemberAccess(
    role: widget.member.role,
    readProjects: widget.member.readProjects,
    writeProjects: widget.member.writeProjects,
    deniedReadProjects: widget.member.deniedReadProjects,
    deniedWriteProjects: widget.member.deniedWriteProjects,
    canCreateProjects: widget.member.canCreateProjects,
  );
  late final _account = widget.controller.account?.id;
  late final _token = widget.controller.auth.token;
  bool _busy = false;
  String? _error;
  int _errorRevision = 0;
  bool get _current =>
      mounted &&
      widget.controller.account?.id == _account &&
      widget.controller.auth.token == _token &&
      widget.controller.isOwner &&
      widget.controller.organization?.id == widget.organizationId;
  @override
  void initState() {
    super.initState();
    _account;
    _token;
  }

  Future<void> _save() async {
    if (_busy || !_current) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorRevision++;
    });
    try {
      await widget.controller.updateMemberAccess(
        widget.organizationId,
        widget.member.account.id,
        _access.role,
        readProjects: _access.readProjects,
        writeProjects: _access.role == 'reader' ? [] : _access.writeProjects,
        deniedReadProjects: _access.deniedReadProjects,
        deniedWriteProjects: _access.role == 'reader'
            ? []
            : _access.deniedWriteProjects,
        canCreateProjects: _access.allowsCreation,
      );
      if (mounted && _current) Navigator.pop(context, true);
    } catch (error) {
      if (_current) {
        setState(() => _error = VaultController.describeError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SecretPodDialog(
      title: 'Edit member access',
      maxWidth: 560,
      onClose: _busy ? null : () => Navigator.pop(context),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save access'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.member.account.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(widget.member.account.email),
          const SizedBox(height: 24),
          MemberAccessFields(
            initialValue: _access,
            projects: widget.controller.projects,
            enabled: !_busy,
            onChanged: (value) => _access = value,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            DialogErrorNotice(_error!, key: ValueKey(_errorRevision)),
          ],
        ],
      ),
    ),
  );
}
