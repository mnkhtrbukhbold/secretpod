import 'package:flutter/material.dart';
import 'package:secretpod_client/secretpod_client.dart';
import '../state/vault_controller.dart';
import '../widgets/common.dart';
import '../widgets/dialog_shell.dart';

enum MemberAccessAction { remove, disable, enable }

class MemberRemovalDialog extends StatefulWidget {
  const MemberRemovalDialog({
    super.key,
    required this.controller,
    required this.organizationId,
    required this.member,
    this.action = MemberAccessAction.remove,
  });
  final VaultController controller;
  final String organizationId;
  final MemberView member;
  final MemberAccessAction action;

  @override
  State<MemberRemovalDialog> createState() => _MemberRemovalDialogState();
}

class _MemberRemovalDialogState extends State<MemberRemovalDialog> {
  bool get _enabling => widget.action == MemberAccessAction.enable;
  String get _submitLabel => switch (widget.action) {
    MemberAccessAction.remove => 'Remove member',
    MemberAccessAction.disable => 'Disable access',
    MemberAccessAction.enable => 'Enable access',
  };
  List<SecretView>? _secrets;
  final _selected = <String>{};
  bool _loading = true, _busy = false;
  String? _error;
  int _errorRevision = 0;
  late final String? _accountId = widget.controller.account?.id;
  late final String? _token = widget.controller.auth.token;
  bool get _current =>
      mounted &&
      widget.controller.account?.id == _accountId &&
      widget.controller.auth.token == _token &&
      widget.controller.isOwner &&
      widget.controller.organization?.id == widget.organizationId;

  @override
  void initState() {
    super.initState();
    // Capture identity before the first asynchronous request.
    _accountId;
    _token;
    _load();
  }

  Future<void> _load() async {
    if (!_current) return;
    if (_enabling) {
      setState(() {
        _secrets = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _secrets = null;
      _error = null;
      _errorRevision++;
    });
    try {
      final byId = <String, SecretView>{};
      var offset = 0;
      const limit = 100;
      while (true) {
        final page = await widget.controller.client.vault.memberRemovalSecrets(
          widget.organizationId,
          widget.member.account.id,
          offset: offset,
          limit: limit,
          utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
        );
        if (!_current) return;
        for (final secret in page) {
          byId[secret.id] = secret;
        }
        if (page.length < limit) break;
        offset += page.length;
      }
      final secrets = byId.values.toList()
        ..sort((a, b) {
          final kind = a.kind.compareTo(b.kind);
          return kind != 0 ? kind : a.name.compareTo(b.name);
        });
      setState(() {
        _secrets = secrets;
        _selected
          ..clear()
          ..addAll(byId.keys);
      });
    } catch (e) {
      if (_current) setState(() => _error = VaultController.describeError(e));
    } finally {
      if (_current) setState(() => _loading = false);
    }
  }

  Future<void> _remove() async {
    if (!_current || _busy || _loading || _secrets == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorRevision++;
    });
    try {
      if (widget.action == MemberAccessAction.remove) {
        await widget.controller.removeMember(
          widget.organizationId,
          widget.member.account.id,
          _secrets!.map((s) => s.id).toList(),
          _selected.toList(),
        );
      } else {
        await widget.controller.setMemberEnabled(
          widget.organizationId,
          widget.member.account.id,
          _enabling,
          _secrets!.map((s) => s.id).toList(),
          _selected.toList(),
        );
      }
      if (mounted && _current) Navigator.pop(context, true);
    } catch (e) {
      if (_current) {
        setState(() {
          // A failed confirmation may mean the member accessed another secret.
          // Require a fresh, complete review before confirming again.
          _secrets = null;
          _error = VaultController.describeError(e);
        });
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SecretPodDialog(
      maxWidth: 660,
      title: '$_submitLabel?',
      icon: switch (widget.action) {
        MemberAccessAction.remove => Icons.person_remove_outlined,
        MemberAccessAction.disable => Icons.block_outlined,
        MemberAccessAction.enable => Icons.lock_open_outlined,
      },
      onClose: _busy ? null : () => Navigator.pop(context),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy || _loading || _secrets == null ? null : _remove,
          style: _enabling
              ? null
              : FilledButton.styleFrom(
                  backgroundColor: context.colors.danger,
                  foregroundColor: context.colors.onDanger,
                ),
          child: Text(
            _busy
                ? (_enabling
                      ? 'Enabling…'
                      : widget.action == MemberAccessAction.disable
                      ? 'Disabling…'
                      : 'Removing…')
                : _submitLabel,
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _enabling
                ? '${widget.member.account.name} (${widget.member.account.email}) will regain access to this organization with their saved role and project permissions. Rotation flags will stay set.'
                : '${widget.member.account.name} (${widget.member.account.email}) will lose access to this organization.'
                      '${widget.action == MemberAccessAction.disable ? ' They will remain on the member list with access disabled. You can enable access again later.' : ''}',
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 16),
          if (!_enabling) ...[
            const Text(
              'Choose secrets to mark “Needs rotating”.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'These are existing, unexpired secrets this member created, modified, read, or requested to copy. Marking a secret does not change its value. Existing rotation flags stay set.',
              style: TextStyle(color: context.colors.muted, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Older activity without user and secret identifiers cannot be included.',
              style: TextStyle(color: context.colors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_secrets case final secrets?) ...[
              if (secrets.isEmpty)
                const Text(
                  'No unexpired secrets found in this member’s recorded activity.',
                )
              else ...[
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${_selected.length} of ${secrets.length} selected'),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(
                              () => _selected.addAll(secrets.map((s) => s.id)),
                            ),
                      child: const Text('Select all'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => setState(_selected.clear),
                      child: const Text('Select none'),
                    ),
                  ],
                ),
                for (final secret in secrets)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          key: ValueKey('rotate-${secret.id}'),
                          semanticLabel:
                              'Mark ${secret.name} as needs rotating',
                          value: _selected.contains(secret.id),
                          onChanged: _busy
                              ? null
                              : (value) => setState(() {
                                  if (value == true) {
                                    _selected.add(secret.id);
                                  } else {
                                    _selected.remove(secret.id);
                                  }
                                }),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                secret.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${secret.kind} · ${secret.project} · ${secret.environment}',
                                style: TextStyle(
                                  color: context.colors.muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ExpiryLabel(secret.expiresAt),
                              if (secret.needsRotation) const RotationLabel(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ],
          if (_error != null) ...[
            DialogErrorNotice(_error!, key: ValueKey(_errorRevision)),
            TextButton(
              onPressed: _busy || _loading ? null : _load,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    ),
  );
}
