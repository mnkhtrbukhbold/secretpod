import 'package:flutter/material.dart';
import 'package:secretpod_client/secretpod_client.dart';
import '../state/vault_controller.dart';
import '../widgets/common.dart';
import '../widgets/dropdown_field.dart';
import '../widgets/list_table.dart';
import '../widgets/pagination_controls.dart';
import '../widgets/member_access_fields.dart';
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
  if (outgoing) ...[
    const ListTableColumn('NAME', flex: 2),
    const ListTableColumn('EMAIL', flex: 3),
  ] else
    const ListTableColumn('ORGANIZATION', flex: 4),
  const ListTableColumn('ROLE'),
  const ListTableColumn('STATUS', flex: 2),
  const ListTableColumn('TIMING', flex: 3),
  const ListTableColumn('ACTIONS', width: 180),
];

const _invitationStatuses = [
  'pending',
  'accepted',
  'declined',
  'revoked',
  'expired',
  'blocked',
];

String _statusLabel(String status) => status.isEmpty
    ? 'Unknown'
    : '${status[0].toUpperCase()}${status.substring(1)}';

class InvitationStatusBadge extends StatelessWidget {
  const InvitationStatusBadge(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (foreground, background, icon) = switch (status) {
      'pending' => (colors.warning, colors.warningContainer, Icons.schedule),
      'accepted' => (
        colors.success,
        colors.successContainer,
        Icons.check_circle_outline,
      ),
      'declined' => (
        colors.danger,
        colors.dangerContainer,
        Icons.cancel_outlined,
      ),
      'revoked' => (colors.purple, colors.purpleContainer, Icons.undo_rounded),
      'expired' => (colors.muted, colors.iconPanel, Icons.timer_off_outlined),
      'blocked' => (colors.danger, colors.dangerContainer, Icons.block),
      _ => (colors.muted, colors.iconPanel, Icons.help_outline),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: foreground),
      label: Text(_statusLabel(status)),
      labelStyle: TextStyle(
        color: foreground,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: background,
      side: BorderSide(color: foreground.withValues(alpha: .18)),
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

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
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final list = widget.outgoing ? 'sent-invitations' : 'received-invitations';
    final size = c.preferredPageSize(list);
    final count = widget.children.length;
    final page = c
        .preferredListState(list)
        .page
        .clamp(
          0,
          count == 0 ? 0 : (count - 1) ~/ size,
        );
    return ListTable(
      columns: _invitationColumns(widget.outgoing),
      minWidth: 900,
      rowsBuilder: (wide) => [
        for (final tile in widget.children.skip(page * size).take(size))
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
        page: page,
        pageSize: size,
        total: count,
        loading: c.loading,
        onPage: (page) => setState(() => c.rememberInvitationPage(list, page)),
        onPageSize: (size) => setState(() {
          c.rememberInvitationPage(list, 0, notify: false);
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
    final status = InvitationStatusBadge(i.status);
    final name = Text(
      i.recipientName,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    );
    final email = Text(
      i.recipientEmail,
      style: TextStyle(color: context.colors.muted, fontSize: 12),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          i.organizationName,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 5),
        Text(
          'From ${i.inviterName} · ${i.inviterEmail}',
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
      '${i.role == 'reader' ? 'Reader' : 'Editor'} access\n${accessDescription(i.role, i.readProjects, i.writeProjects, deniedReadProjects: i.deniedReadProjects, deniedWriteProjects: i.deniedWriteProjects, canCreateProjects: i.canCreateProjects)}',
      style: TextStyle(color: context.colors.muted, fontSize: 12),
    );
    final updated = Text(
      i.status == 'pending'
          ? 'Expires ${calendarDate(i.expiresAt.toLocal())} at ${TimeOfDay.fromDateTime(i.expiresAt.toLocal()).format(context)}'
          : 'Updated ${calendarDate((i.respondedAt ?? i.createdAt).toLocal())}',
      style: TextStyle(color: context.colors.muted, fontSize: 12),
    );
    final timing = outgoing
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invited ${calendarDate(i.createdAt.toLocal())}',
                style: TextStyle(color: context.colors.muted, fontSize: 12),
              ),
              const SizedBox(height: 5),
              updated,
            ],
          )
        : updated;
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
                  if (outgoing) ...[name, email] else identity,
                  role,
                  Align(alignment: Alignment.centerLeft, child: status),
                  timing,
                  buttons,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (outgoing) ...[
                    name,
                    const SizedBox(height: 5),
                    email,
                  ] else
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
  final _search = TextEditingController();
  Map<String, String> get _filters =>
      widget.controller.preferredListState('sent-invitations').filters;
  String get _status => _invitationStatuses.contains(_filters['status'])
      ? _filters['status']!
      : '';

  @override
  void initState() {
    super.initState();
    _search.text = _filters['query'] ?? '';
  }

  @override
  void didUpdateWidget(OutgoingInvitations oldWidget) {
    super.didUpdateWidget(oldWidget);
    final query = _filters['query'] ?? '';
    if (_search.text != query) _search.text = query;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter({String? status}) => setState(() {
    widget.controller.filterSentInvitations(
      query: _search.text,
      status: status ?? _status,
    );
  });

  Widget _toolbar() => LayoutBuilder(
    builder: (context, constraints) {
      final search = TextField(
        controller: _search,
        onChanged: (_) => _filter(),
        decoration: InputDecoration(
          labelText: 'Search invitations',
          hintText: 'Name or email',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _search.clear();
                    _filter();
                  },
                ),
        ),
      );
      final status = SecretPodDropdown<String>(
        initialValue: _status,
        decoration: const InputDecoration(labelText: 'Status'),
        items: [
          const DropdownMenuItem(value: '', child: Text('All statuses')),
          for (final status in _invitationStatuses)
            DropdownMenuItem(value: status, child: Text(_statusLabel(status))),
        ],
        onChanged: (value) => _filter(status: value),
      );
      final wide = ListTable.isWide(context, constraints.maxWidth, 640);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: search),
                const SizedBox(width: 16),
                SizedBox(width: 240, child: status),
              ],
            )
          else ...[
            search,
            const SizedBox(height: 16),
            status,
          ],
          if (_search.text.isNotEmpty || _status.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  _search.clear();
                  _filter(status: '');
                },
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Reset filters'),
              ),
            ),
        ],
      );
    },
  );

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
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final invitations = widget.controller.sentInvitations
        .where(
          (invite) =>
              (_status.isEmpty || invite.status == _status) &&
              (query.isEmpty ||
                  invite.recipientName.toLowerCase().contains(query) ||
                  invite.recipientEmail.toLowerCase().contains(query)),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _toolbar(),
        const SizedBox(height: 20),
        if (_error != null) ErrorNotice(_error!),
        if (widget.controller.sentInvitations.isEmpty)
          Text(
            'No invitations created yet.',
            style: TextStyle(color: context.colors.muted),
          ),
        if (widget.controller.sentInvitations.isNotEmpty && invitations.isEmpty)
          const Center(
            child: EmptyState(
              icon: Icons.search_off,
              title: 'No matching invitations',
              subtitle: 'Try a different name, email, or status.',
            ),
          ),
        if (invitations.isNotEmpty)
          InvitationList(
            controller: widget.controller,
            outgoing: true,
            children: [
              for (final i in invitations)
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
}
