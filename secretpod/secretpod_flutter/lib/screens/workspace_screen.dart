import 'package:flutter/material.dart';
import 'package:secretpod_client/secretpod_client.dart';
import '../state/vault_controller.dart';
import '../widgets/action_dialog.dart';
import '../widgets/common.dart';
import '../widgets/dropdown_field.dart';
import '../widgets/secret_activity.dart';
import '../widgets/activity_filters.dart';
import '../widgets/pagination_controls.dart';
import '../widgets/list_table.dart';
import 'secret_dialogs.dart';
import 'invitation_dialogs.dart';
import 'invitations_screen.dart';
import 'profile_settings_screen.dart';
import 'member_removal_dialog.dart';
import 'member_access_dialog.dart';
import '../widgets/member_access_fields.dart';
import 'projects_dialog.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.controller,
    required this.page,
    required this.lastWorkspacePage,
    required this.onNavigate,
  });
  final VaultController controller;
  final int page;
  final int lastWorkspacePage;
  final ValueChanged<int> onNavigate;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  int get _page => widget.page;
  bool _openInvitationPreferences = false;
  void _navigate(int page, {bool invitationPreferences = false}) {
    _openInvitationPreferences = invitationPreferences;
    widget.onNavigate(page);
  }

  String get _query => c.secretQuery;
  set _query(String value) => c.secretQuery = value;
  String get _environment => c.secretEnvironment ?? 'All environments';
  set _environment(String value) =>
      c.secretEnvironment = value == 'All environments' ? null : value;
  final _search = TextEditingController();
  String? get _project => c.secretProject;
  set _project(String? value) => c.secretProject = value;
  @override
  void initState() {
    super.initState();
    _search.text = _query;
  }

  @override
  void didUpdateWidget(WorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_search.text != _query) _search.text = _query;
  }

  void _applyFilters() {
    c.filterSecrets(
      query: _query,
      project: _project,
      environment: _environment == 'All environments' ? null : _environment,
    );
  }

  Widget _pagination(int list, int total) => PaginationControls(
    key: ValueKey('paging-$list-${c.pagingRevision}'),
    page: c.pages[list],
    pageSize: c.pageSizes[list],
    total: total,
    loading: c.loading,
    onPage: (page) => c.changePage(list, page),
    onPageSize: (size) => c.changePage(list, 0, pageSize: size),
  );
  VaultController get c => widget.controller;
  static const _titles = ['Secrets', 'Activity', 'Members'];
  static const _icons = [
    Icons.key_outlined,
    Icons.history_rounded,
    Icons.people_outline,
  ];
  int get _pendingInvitations =>
      c.invitations.where((i) => i.status == 'pending').length;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _newOrganization() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ActionDialog(
        title: 'Create an organization',
        label: 'Organization name',
        description:
            'A shared home for your team’s secrets. You’ll be its first owner.',
        submitLabel: 'Create organization',
        onSubmit: (name, _) => c.createOrganization(name),
      ),
    );
  }

  Future<void> _newSecret() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SecretEditor(controller: c),
    );
    if (changed == true) await c.refresh();
  }

  Future<void> _renameOrganization() async {
    final organization = c.organization;
    if (organization == null || !c.isOwner) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ActionDialog(
        title: 'Rename organization',
        label: 'Organization name',
        description: 'Choose the name your team sees throughout the workspace.',
        submitLabel: 'Save changes',
        initialValue: organization.name,
        onSubmit: (name, _) => c.renameOrganization(organization.id, name),
      ),
    );
    if (changed == true && mounted && c.organization?.id == organization.id) {
      await c.refresh();
    }
  }

  Future<void> _details(SecretView secret) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => SecretDetails(controller: c, secret: secret),
    );
    await c.refresh();
  }

  Future<void> _addMember() async {
    final orgId = c.organization!.id;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InviteMemberDialog(controller: c, organizationId: orgId),
    );
    if (changed == true) await c.refresh();
  }

  Future<void> _editMemberAccess(MemberView member) async {
    final orgId = c.organization!.id;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MemberAccessDialog(
        controller: c,
        organizationId: orgId,
        member: member,
      ),
    );
  }

  Future<void> _removeMember(
    MemberView member, {
    MemberAccessAction action = MemberAccessAction.remove,
  }) async {
    final orgId = c.organization!.id;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MemberRemovalDialog(
        controller: c,
        organizationId: orgId,
        member: member,
        action: action,
      ),
    );
    if (changed == true && mounted && c.organization?.id == orgId) {
      await c.refresh();
    }
  }

  Future<void> _logout() async {
    try {
      await c.logout();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(VaultController.describeError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1000;
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              if (wide) _sidebar(),
              Expanded(
                child: Column(
                  children: [
                    _topbar(wide),
                    if (c.loading) const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          wide ? 40 : 20,
                          24,
                          wide ? 40 : 20,
                          32,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1250),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (c.sessionStorageWarning != null) ...[
                                  ErrorNotice(c.sessionStorageWarning!),
                                  const SizedBox(height: 24),
                                ],
                                if (c.listPreferencesStorageWarning !=
                                    null) ...[
                                  ErrorNotice(c.listPreferencesStorageWarning!),
                                  const SizedBox(height: 16),
                                ],
                                if (c.error != null) ...[
                                  ErrorNotice(c.error!, onRetry: c.refresh),
                                  const SizedBox(height: 24),
                                ],
                                if (_page == 3)
                                  InvitationsScreen(
                                    controller: c,
                                    onOpenSettings: () => _navigate(
                                      4,
                                      invitationPreferences: true,
                                    ),
                                  )
                                else if (_page == 4)
                                  ProfileSettingsScreen(
                                    key: ValueKey(c.account!.id),
                                    controller: c,
                                    onSignOut: _logout,
                                    openInvitationPreferences:
                                        _openInvitationPreferences,
                                  )
                                else if (c.organization == null)
                                  _onboarding()
                                else ...[
                                  Text(
                                    'WORKSPACE  /  ${c.organization!.name.toUpperCase()}',
                                    style: TextStyle(
                                      color: context.colors.muted,
                                      fontSize: 10,
                                      letterSpacing: 1.3,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _heading(wide),
                                  const SizedBox(height: 30),
                                  if (_page == 0)
                                    _vault()
                                  else if (_page == 1)
                                    _activity()
                                  else
                                    _members(),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: wide || _page >= 3
            ? null
            : NavigationBar(
                selectedIndex: _page,
                onDestinationSelected: _navigate,
                destinations: List.generate(
                  _titles.length,
                  (i) => NavigationDestination(
                    icon: Icon(_icons[i]),
                    label: _titles[i],
                  ),
                ),
              ),
      );
    },
  );

  Widget _sidebar() => Container(
    width: 320,
    padding: const EdgeInsets.fromLTRB(18, 30, 18, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: () => _navigate(0),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          child: const Tooltip(message: 'Home', child: Brand()),
        ),
        const SizedBox(height: 44),
        Padding(
          padding: EdgeInsets.only(left: 18, bottom: 16),
          child: Text(
            'ORGANIZATION',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.4,
              color: context.colors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (var i = 0; i < _titles.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(_icons[i], size: 22),
              title: Text(_titles[i]),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  const [
                    'Store and manage your team’s secrets.',
                    'See who created, changed, or viewed secrets.',
                    'Manage members and their access.',
                  ][i],
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: context.colors.muted,
                  ),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              selected: _page == i,
              selectedTileColor: context.colors.selectedSurface,
              selectedColor: context.colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              trailing: i == 0 && c.organization != null
                  ? Text(
                      '${c.secretCount}',
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
              onTap: () => _navigate(i),
            ),
          ),
        const SizedBox(height: 24),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Divider(color: context.colors.outline),
        ),
        ListTile(
          leading: const Icon(Icons.add_circle_outline, size: 20),
          title: const Text('New organization', style: TextStyle(fontSize: 13)),
          onTap: _newOrganization,
        ),
        const Spacer(),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.panel.withValues(alpha: .8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.colors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.dns_outlined,
                    size: 18,
                    color: context.colors.blue,
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Hosted by you',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Your secrets stay on your infrastructure.',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.muted,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 14),
              Text(
                'BUILT WITH SERVERPOD',
                style: TextStyle(
                  fontSize: 9,
                  color: context.colors.muted,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _topbar(bool wide) => Padding(
    padding: EdgeInsets.fromLTRB(wide ? 40 : 20, 18, wide ? 40 : 12, 12),
    child: Row(
      children: [
        if (!wide && _page < 3) ...[
          Icon(Icons.shield_outlined, color: context.colors.blue, size: 28),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _page >= 3
                ? TextButton.icon(
                    onPressed: () => _navigate(widget.lastWorkspacePage),
                    icon: const Icon(Icons.arrow_back, size: 20),
                    label: const Text('Back to workspace'),
                  )
                : _organizationMenu(),
          ),
        ),
        IconButton(
          tooltip: _page == 4
              ? 'Refresh profile'
              : _page == 3
              ? 'Refresh invitations'
              : 'Refresh workspace',
          onPressed: c.loading ? null : c.refresh,
          icon: Icon(Icons.refresh, size: 21, color: context.colors.muted),
        ),
        const SizedBox(width: 10),
        _accountMenu(),
      ],
    ),
  );

  Widget _organizationMenu() => SecretPodMenu(
    children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          'Organizations',
          style: TextStyle(fontSize: 12, color: context.colors.muted),
        ),
      ),
      for (final org in c.organizations)
        SecretPodMenuItem(
          selected: org.id == c.organization?.id,
          autofocus: org.id == c.organization?.id,
          leading: const Icon(Icons.workspaces_outline, size: 16),
          onPressed: () {
            setState(() {
              _query = '';
              _search.clear();
              _environment = 'All environments';
              _project = null;
            });
            c.selectOrganization(org);
          },
          child: Text(org.name),
        ),
      const SecretPodMenuDivider(),
      if (c.isOwner)
        SecretPodMenuItem(
          leading: const Icon(Icons.edit_outlined, size: 16),
          onPressed: _renameOrganization,
          child: const Text('Rename organization'),
        ),
      SecretPodMenuItem(
        leading: const Icon(Icons.add, size: 16),
        autofocus: c.organizations.isEmpty,
        onPressed: _newOrganization,
        child: const Text('Create organization'),
      ),
    ],
    builder: (context, toggle, focus) => Tooltip(
      message: 'Switch organization',
      child: TextButton(
        focusNode: focus,
        onPressed: toggle,
        style: selectTriggerStyle(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspaces_outline,
              size: 16,
              color: context.colors.muted,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                c.organization?.name ?? 'Your workspace',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: context.colors.muted,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _accountMenu() => SecretPodMenu(
    alignEnd: true,
    // Reserve 20px on the left plus the top bar's 12px right inset.
    width: (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 248.0),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.account!.name,
              style: menuTextStyle(
                context.colors,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              c.account!.email,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: context.colors.muted,
              ),
            ),
          ],
        ),
      ),
      const SecretPodMenuDivider(),
      SecretPodMenuItem(
        autofocus: true,
        leading: const Icon(Icons.manage_accounts_outlined, size: 16),
        onPressed: () => _navigate(4),
        child: const Text('Profile settings'),
      ),
      SecretPodMenuItem(
        leading: const Icon(Icons.mail_outline, size: 16),
        trailing: _pendingInvitations > 0
            ? Badge.count(count: _pendingInvitations)
            : null,
        onPressed: () => _navigate(3),
        child: const Text('My invitations'),
      ),
      const SecretPodMenuDivider(),
      SecretPodMenuItem(
        leading: const Icon(Icons.logout_rounded, size: 16),
        onPressed: _logout,
        child: const Text('Sign out'),
      ),
    ],
    builder: (context, toggle, focus) => IconButton(
      tooltip: 'Account',
      focusNode: focus,
      onPressed: toggle,
      icon: Badge.count(
        count: _pendingInvitations,
        isLabelVisible: _pendingInvitations > 0,
        child: CircleAvatar(
          radius: 18,
          backgroundColor: context.colors.selectedSurface,
          child: Text(
            c.account!.name.characters.first.toUpperCase(),
            style: TextStyle(color: context.colors.blue, fontSize: 14),
          ),
        ),
      ),
    ),
  );
  Widget _onboarding() => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 40),
    decoration: BoxDecoration(
      color: context.colors.panel,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: context.colors.outline),
    ),
    child: EmptyState(
      icon: Icons.workspaces_outline,
      title: 'Give your team a home',
      subtitle:
          'Create an organization to start storing secrets and sharing access with your teammates.',
      action: FilledButton.icon(
        onPressed: c.loading ? null : _newOrganization,
        icon: const Icon(Icons.add),
        label: const Text('Create organization'),
      ),
    ),
  );

  Widget _heading(bool wide) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _titles[_page],
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w500,
            letterSpacing: -1.1,
            color: context.colors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          [
            'Everything your team needs. Only for the people who need it.',
            'A record of who accessed and changed your vault.',
            'The right access for the people you work with.',
          ][_page],
          style: TextStyle(color: context.colors.muted, height: 1.5),
        ),
      ],
    );
    final action = _page == 0 && c.canEdit
        ? FilledButton.icon(
            onPressed: _newSecret,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add secret'),
          )
        : _page == 2 && c.isOwner
        ? FilledButton.icon(
            onPressed: _addMember,
            icon: const Icon(Icons.person_add_outlined, size: 20),
            label: const Text('Invite member'),
          )
        : null;
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          if (action != null) ...[const SizedBox(height: 20), action],
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: title),
        ?action,
      ],
    );
  }

  Widget _vault() {
    final filtered = c.secrets
        .where(
          (s) =>
              (_project == null ||
                  s.project.toLowerCase() == _project!.toLowerCase()) &&
              (_environment == 'All environments' ||
                  s.environment == _environment) &&
              '${s.name} ${s.project} ${s.kind} ${s.description}'
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (_, size) {
            final cards = [
              _stat(
                'Total secrets',
                '${c.secretCount}',
                Icons.key_outlined,
                context.colors.blueContainer,
                context.colors.blue,
                () => _showSecrets(),
              ),
              _stat(
                'Projects',
                '${c.projects.length}',
                Icons.folder_outlined,
                context.colors.purpleContainer,
                context.colors.purple,
                _showProjects,
              ),
              _stat(
                'Team members',
                '${c.memberCount}',
                Icons.people_outline,
                context.colors.successContainer,
                context.colors.success,
                () => _navigate(2),
              ),
            ];
            return size.maxWidth < 600
                ? Column(
                    children: [
                      for (final card in cards)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: card,
                        ),
                    ],
                  )
                : Row(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 16),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  );
          },
        ),
        const SizedBox(height: 24),
        ListTablePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _search,
                      onChanged: (v) {
                        setState(() => _query = v);
                        _applyFilters();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search secrets, projects, or descriptions',
                        prefixIcon: Icon(
                          Icons.search,
                          color: context.colors.muted,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () => setState(() {
                                  _query = '';
                                  _search.clear();
                                  _applyFilters();
                                }),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ProjectFilterButton(
                        project: _project,
                        onChoose: _showProjects,
                        onClear: () {
                          setState(() => _project = null);
                          _applyFilters();
                        },
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                                'All environments',
                                'Development',
                                'Staging',
                                'Production',
                              ]
                              .map(
                                (e) => FilterChip(
                                  label: Text(
                                    e,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  selected: _environment == e,
                                  onSelected: (_) {
                                    setState(() => _environment = e);
                                    _applyFilters();
                                  },
                                  backgroundColor: context.colors.panel,
                                  selectedColor: context.colors.blueContainer,
                                  side: BorderSide(
                                    color: _environment == e
                                        ? Colors.transparent
                                        : context.colors.outline,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.colors.outline),
              if (c.secretCount == 0)
                EmptyState(
                  icon: Icons.key_outlined,
                  title: 'Your vault starts here',
                  subtitle:
                      'Add your first API key, environment variable, or credential. Give every secret a place.',
                  action: c.canEdit
                      ? OutlinedButton.icon(
                          onPressed: _newSecret,
                          icon: const Icon(Icons.add),
                          label: const Text('Add your first secret'),
                        )
                      : null,
                )
              else if (filtered.isEmpty)
                const EmptyState(
                  icon: Icons.search_off,
                  title: 'No matching secrets',
                  subtitle:
                      'Try another search or choose a different environment.',
                )
              else
                LayoutBuilder(
                  builder: (context, size) => Column(
                    children: [
                      if (ListTable.isWide(context, size.maxWidth))
                        const ListTableHeader(columns: _secretColumns),
                      for (final secret in filtered)
                        _secretRow(
                          secret,
                          ListTable.isWide(context, size.maxWidth),
                        ),
                    ],
                  ),
                ),
              if (c.summary != null) _pagination(0, c.filteredSecretCount),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} ${filtered.length == 1 ? 'secret' : 'secrets'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.muted,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: context.colors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AES-256-GCM',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: context.colors.muted, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Secret values stay hidden until you reveal them. Every reveal is recorded in activity.',
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static const _secretColumns = [
    ListTableColumn('NAME', flex: 4),
    ListTableColumn('PROJECT', flex: 2),
    ListTableColumn('ENVIRONMENT', flex: 2),
    ListTableColumn('UPDATED', flex: 2),
    ListTableColumn('', width: 24),
  ];

  Widget _stat(
    String label,
    String value,
    IconData icon,
    Color background,
    Color color,
    VoidCallback onTap,
  ) => Material(
    color: context.colors.panel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: context.colors.outline),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: context.colors.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      color: context.colors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _showSecrets([String? project]) => setState(() {
    _navigate(0);
    _project = project;
    _query = '';
    _search.clear();
    _environment = 'All environments';
    _applyFilters();
  });

  Future<void> _showProjects() async {
    final organizationId = c.organization!.id;
    final accountId = c.account?.id;
    final token = c.auth.token;
    final project = await showDialog<String>(
      context: context,
      builder: (_) =>
          ProjectsDialog(controller: c, organizationId: organizationId),
    );
    if (mounted &&
        project != null &&
        c.organization?.id == organizationId &&
        c.account?.id == accountId &&
        c.auth.token == token) {
      setState(() => _project = project.isEmpty ? null : project);
      _applyFilters();
    }
  }

  Widget _secretRow(SecretView secret, bool wide) {
    final name = Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: context.colors.iconPanel,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            kindIcon(secret.kind),
            color: context.colors.blue,
            size: 19,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                secret.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                secret.kind,
                style: TextStyle(fontSize: 11, color: context.colors.muted),
              ),
              if (secret.expiresAt != null) ...[
                const SizedBox(height: 5),
                ExpiryLabel(secret.expiresAt),
              ],
              if (secret.needsRotation) ...[
                const SizedBox(height: 5),
                const RotationLabel(),
              ],
            ],
          ),
        ),
      ],
    );
    return ListTableRow(
      onTap: () => _details(secret),
      child: wide
          ? ListTableCells(
              columns: _secretColumns,
              children: [
                name,
                Text(
                  secret.project,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.colors.muted),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: EnvironmentBadge(secret.environment),
                ),
                Text(
                  friendlyDate(secret.updatedAt),
                  style: TextStyle(fontSize: 11, color: context.colors.muted),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: context.colors.muted,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                name,
                const SizedBox(height: 16),
                Row(
                  children: [
                    EnvironmentBadge(secret.environment),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        secret.project,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.muted,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: context.colors.muted,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  static const _activityColumns = [
    ListTableColumn('ACTOR', flex: 3),
    ListTableColumn('ACTION', flex: 2),
    ListTableColumn('TARGET', flex: 4),
    ListTableColumn('TIME', flex: 2),
  ];

  Widget _activity() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ActivityFilters(controller: c),
      const SizedBox(height: 16),
      ListTable(
        columns: _activityColumns,
        empty: c.activity.isEmpty
            ? EmptyState(
                icon: Icons.history,
                title: c.hasActivityFilters
                    ? 'No matching activity'
                    : 'Nothing to report yet',
                subtitle: c.hasActivityFilters
                    ? 'Change or clear the filters to see more activity.'
                    : 'Changes and secret reveals will appear here.',
              )
            : null,
        rowsBuilder: (wide) => [
          for (final event in c.activity) _activityRow(event, wide),
        ],
        footer: c.summary == null
            ? null
            : _pagination(1, c.filteredActivityCount),
      ),
    ],
  );

  Widget _activityRow(AuditView event, bool wide) {
    final colors = activityColors(context, event.action);
    final actor = Row(
      children: [
        CircleAvatar(
          backgroundColor: colors.background,
          child: Icon(
            activityIcon(event.action),
            size: 20,
            color: colors.foreground,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            event.actor,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
    final action = ActivityBadge(event.action);
    final target = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(event.target, style: const TextStyle(fontSize: 13)),
        if (event.version != null)
          Text(
            'Version ${event.version}',
            style: TextStyle(fontSize: 12, color: context.colors.muted),
          ),
        if (event.details != null)
          Text(
            event.details!,
            style: TextStyle(fontSize: 12, color: context.colors.muted),
          ),
      ],
    );
    final time = Text(
      activityTime(event.createdAt),
      style: TextStyle(fontSize: 12, color: context.colors.muted),
    );
    return ListTableRow(
      child: wide
          ? ListTableCells(
              columns: _activityColumns,
              children: [actor, action, target, time],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                actor,
                const SizedBox(height: 12),
                action,
                const SizedBox(height: 8),
                target,
                const SizedBox(height: 8),
                time,
              ],
            ),
    );
  }

  static const _memberColumns = [
    ListTableColumn('NAME', flex: 3),
    ListTableColumn('EMAIL', flex: 4),
    ListTableColumn('ROLE', flex: 2),
    ListTableColumn('ACTIONS', width: 160),
  ];

  Widget _memberRow(MemberView member, bool wide) {
    final identity = Row(
      children: [
        CircleAvatar(
          backgroundColor: context.colors.blueContainer,
          child: Text(
            member.account.name.characters.firstOrNull?.toUpperCase() ?? '?',
            style: TextStyle(color: context.colors.blue),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            member.account.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
    final email = Text(
      member.account.email,
      style: TextStyle(fontSize: 12, color: context.colors.muted),
    );
    final role = Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.colors.canvas,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.role,
              style: TextStyle(fontSize: 11, color: context.colors.muted),
            ),
            if (member.accessDisabled)
              Text(
                'Access disabled',
                style: TextStyle(fontSize: 11, color: context.colors.danger),
              ),
            if (member.role != 'owner')
              Text(
                accessDescription(
                  member.role,
                  member.readProjects,
                  member.writeProjects,
                  deniedReadProjects: member.deniedReadProjects,
                  deniedWriteProjects: member.deniedWriteProjects,
                  canCreateProjects: member.canCreateProjects,
                ),
                style: TextStyle(fontSize: 11, color: context.colors.muted),
              ),
          ],
        ),
      ),
    );
    final action =
        c.isOwner &&
            member.role != 'owner' &&
            member.account.id != c.account?.id
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit access for ${member.account.name}',
                onPressed: () => _editMemberAccess(member),
                icon: const Icon(Icons.manage_accounts_outlined),
              ),
              IconButton(
                tooltip:
                    '${member.accessDisabled ? 'Enable' : 'Disable'} access for ${member.account.name}',
                onPressed: () => _removeMember(
                  member,
                  action: member.accessDisabled
                      ? MemberAccessAction.enable
                      : MemberAccessAction.disable,
                ),
                icon: Icon(
                  member.accessDisabled
                      ? Icons.lock_open_outlined
                      : Icons.block_outlined,
                ),
              ),
              IconButton(
                tooltip: 'Remove ${member.account.name}',
                onPressed: () => _removeMember(member),
                icon: Icon(
                  Icons.person_remove_outlined,
                  color: context.colors.danger,
                ),
              ),
            ],
          )
        : const SizedBox.shrink();
    return ListTableRow(
      child: wide
          ? ListTableCells(
              columns: _memberColumns,
              children: [
                identity,
                email,
                role,
                Align(alignment: Alignment.centerRight, child: action),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: 12),
                email,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: role),
                    action,
                  ],
                ),
              ],
            ),
    );
  }

  Widget _members() {
    if (!c.isOwner) return _memberList();
    return DefaultTabController(
      key: ValueKey(c.organization!.id),
      length: 2,
      child: Builder(
        builder: (context) {
          final tabs = DefaultTabController.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Members'),
                  Tab(text: 'Invitations'),
                ],
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: tabs,
                builder: (context, _) => tabs.index == 0
                    ? _memberList()
                    : OutgoingInvitations(controller: c),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _memberList() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ListTable(
        columns: _memberColumns,
        rowsBuilder: (wide) => [
          for (final member in c.members) _memberRow(member, wide),
        ],
        footer: c.summary == null ? null : _pagination(2, c.memberCount),
      ),
      const SizedBox(height: 24),
      Text(
        'Owners manage membership. Editors manage secrets. Readers can view and reveal values.',
        style: TextStyle(
          color: context.colors.muted,
          fontSize: 12,
          height: 1.6,
        ),
      ),
    ],
  );
}
