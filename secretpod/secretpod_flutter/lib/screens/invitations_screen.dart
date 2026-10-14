import 'package:flutter/material.dart';
import 'package:secretpod_client/secretpod_client.dart';
import '../state/vault_controller.dart';
import '../widgets/common.dart';
import '../widgets/list_table.dart';
import '../widgets/pagination_controls.dart';
import 'invitation_dialogs.dart';

class InvitationsScreen extends StatefulWidget {
  const InvitationsScreen({
    super.key,
    required this.controller,
    required this.onOpenSettings,
  });
  final VaultController controller;
  final VoidCallback onOpenSettings;
  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> {
  bool _busy = false;
  String? _error, _notice;

  Future<void> _run(Future<void> Function() operation, String notice) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await operation();
      await widget.controller.refresh();
      if (mounted) setState(() => _notice = notice);
    } catch (e) {
      if (mounted) setState(() => _error = VaultController.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(InvitationView invite) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AcceptInvitationDialog(
        controller: widget.controller,
        invitation: invite,
      ),
    );
    if (accepted == true) {
      await widget.controller.refresh();
      if (mounted) {
        setState(
          () => _notice =
              'Invitation accepted. You can now open the organization’s vault.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My invitations',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text(
          'Review invitations and choose which teams you join.',
          style: TextStyle(color: context.colors.muted),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: widget.onOpenSettings,
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Manage invitation preferences'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          ErrorNotice(_error!),
        ],
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(_notice!, style: TextStyle(color: context.colors.blue)),
          ),
        const SizedBox(height: 24),
        if (widget.controller.invitations.isEmpty)
          const Center(
            child: EmptyState(
              icon: Icons.mail_outline,
              title: 'No invitations',
              subtitle:
                  'Invitations addressed to your account will appear here.',
            ),
          )
        else
          InvitationList(
            controller: widget.controller,
            children: [
              for (final invite in widget.controller.invitations)
                InvitationTile(
                  invitation: invite,
                  actions: invite.status != 'pending'
                      ? const []
                      : [
                          FilledButton.tonal(
                            onPressed: _busy ? null : () => _accept(invite),
                            child: const Text('Accept'),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _run(
                                    () => widget.controller.client.invitation
                                        .decline(
                                          invite.id,
                                        ),
                                    'Invitation declined.',
                                  ),
                            child: const Text('Decline'),
                          ),
                        ],
                ),
            ],
          ),
      ],
    ),
  );
}

List<ListTableColumn> _invitationColumns(bool outgoing) => [
  ListTableColumn(outgoing ? 'RECIPIENT' : 'ORGANIZATION', flex: 4),
  const ListTableColumn('ROLE'),
  const ListTableColumn('STATUS', flex: 2),
  const ListTableColumn('TIMING', flex: 3),
  const ListTableColumn('ACTIONS', width: 180),
];

class InvitationList extends StatefulWidget {
  const InvitationList({
    super.key,
    required this.controller,
    required this.children,
    this.outgoing = false,
  });
  final VaultController controller;
  final List<InvitationTile> children;
  final bool outgoing;
  @override
  State<InvitationList> createState() => _InvitationListState();
}

class _InvitationListState extends State<InvitationList> {
  int _page = 0;
  (String?, String?)? _context;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final current = (
      c.account?.id,
      widget.outgoing ? c.organization?.id : null,
    );
    if (_context != current) {
      _context = current;
      _page = 0;
    }
    final list = widget.outgoing ? 'sent-invitations' : 'received-invitations';
    final size = c.preferredPageSize(list);
    final count = widget.children.length;
    _page = _page.clamp(0, count == 0 ? 0 : (count - 1) ~/ size);
    return ListTable(
      columns: _invitationColumns(widget.outgoing),
      minWidth: 900,
      rowsBuilder: (wide) => [
        for (final tile in widget.children.skip(_page * size).take(size))
          InvitationTile(
            key: ValueKey(tile.invitation.id),
            invitation: tile.invitation,
            outgoing: tile.outgoing,
            actions: tile.actions,
            wide: wide,
          ),
      ],
      footer: PaginationControls(
        key: ValueKey('$list-$size'),
        page: _page,
        pageSize: size,
        total: count,
        loading: c.loading,
        onPage: (page) => setState(() => _page = page),
        onPageSize: (size) => setState(() {
          _page = 0;
          c.rememberPageSize(list, size);
        }),
      ),
    );
  }
}

class InvitationTile extends StatelessWidget {
  const InvitationTile({
    super.key,
    required this.invitation,
    this.outgoing = false,
    this.actions = const [],
    this.wide,
  });
  final InvitationView invitation;
  final bool outgoing;
  final List<Widget> actions;
  final bool? wide;
  @override
  Widget build(BuildContext context) {
    final i = invitation;
    final status = Chip(
      label: Text('${i.status[0].toUpperCase()}${i.status.substring(1)}'),
      visualDensity: VisualDensity.compact,
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          outgoing ? i.recipientName : i.organizationName,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 5),
        Text(
          outgoing
              ? i.recipientEmail
              : 'From ${i.inviterName} · ${i.inviterEmail}',
          style: TextStyle(color: context.colors.muted, fontSize: 12),
        ),
        const SizedBox(height: 5),
        Text(
          'Invited ${calendarDate(i.createdAt.toLocal())}',
          style: TextStyle(color: context.colors.muted, fontSize: 12),
        ),
      ],
    );
    final role = Text(
      '${i.role == 'reader' ? 'Reader' : 'Editor'} access',
      style: TextStyle(color: context.colors.muted, fontSize: 12),
    );
    final timing = Text(
      i.status == 'pending'
          ? 'Expires ${calendarDate(i.expiresAt.toLocal())} at ${TimeOfDay.fromDateTime(i.expiresAt.toLocal()).format(context)}'
          : 'Updated ${calendarDate((i.respondedAt ?? i.createdAt).toLocal())}',
      style: TextStyle(color: context.colors.muted, fontSize: 12),
    );
    final buttons = Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: actions,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => ListTableRow(
        child: (wide ?? ListTable.isWide(context, constraints.maxWidth, 900))
            ? ListTableCells(
                columns: _invitationColumns(outgoing),
                children: [
                  identity,
                  role,
                  Align(alignment: Alignment.centerLeft, child: status),
                  timing,
                  buttons,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  const SizedBox(height: 8),
                  role,
                  const SizedBox(height: 8),
                  Align(
                    alignment: outgoing
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Wrap(
                      alignment: outgoing
                          ? WrapAlignment.end
                          : WrapAlignment.start,
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [status, timing],
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    buttons,
                  ],
                ],
              ),
      ),
    );
  }
}

class OutgoingInvitations extends StatefulWidget {
  const OutgoingInvitations({super.key, required this.controller});
  final VaultController controller;
  @override
  State<OutgoingInvitations> createState() => _OutgoingInvitationsState();
}

class _OutgoingInvitationsState extends State<OutgoingInvitations> {
  bool _busy = false;
  String? _error;
  Future<void> _revoke(InvitationView i) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.client.invitation.revoke(i.organizationId, i.id);
      await widget.controller.refresh();
    } catch (e) {
      if (mounted) setState(() => _error = VaultController.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 28),
      const Text(
        'Invitation history',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 12),
      if (_error != null) ErrorNotice(_error!),
      if (widget.controller.sentInvitations.isEmpty)
        Text(
          'No invitations created yet.',
          style: TextStyle(color: context.colors.muted),
        ),
      if (widget.controller.sentInvitations.isNotEmpty)
        InvitationList(
          controller: widget.controller,
          outgoing: true,
          children: [
            for (final i in widget.controller.sentInvitations)
              InvitationTile(
                invitation: i,
                outgoing: true,
                actions: i.status == 'pending'
                    ? [
                        TextButton(
                          onPressed: _busy ? null : () => _revoke(i),
                          child: const Text('Revoke invitation'),
                        ),
                      ]
                    : const [],
              ),
          ],
        ),
    ],
  );
}
