import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'session_store.dart';
import 'pagination.dart';
import 'page_size_store.dart';

class MemoryAuth implements ClientAuthKeyProvider {
  String? token;
  @override
  Future<String?> get authHeaderValue async =>
      token == null ? null : 'Bearer $token';
}

class VaultController extends ChangeNotifier {
  VaultController(
    String url, {
    Client? api,
    SessionStore? sessionStore,
    PageSizeStore? pageSizeStore,
  }) : _sessionStore = sessionStore ?? createSessionStore(url),
       _pageSizeStore = pageSizeStore ?? createPageSizeStore(url) {
    client = (api ?? Client(url))..authKeyProvider = auth;
    _sessionChanges = _sessionStore.changes.listen((_) {
      unawaited(synchronizeSession(storageChanged: true));
    });
  }
  final auth = MemoryAuth();
  final SessionStore _sessionStore;
  final PageSizeStore _pageSizeStore;
  final _savedPageSizes = <String, int>{};
  String? _pageSizeAccountId, pageSizeStorageWarning;
  late final StreamSubscription<void> _sessionChanges;
  late final Client client;
  AccountView? account;
  List<OrganizationView> organizations = [];
  OrganizationView? organization;
  List<SecretView> secrets = [];
  WorkspaceSummary? summary;
  final pages = [0, 0, 0];
  final pageSizes = List.filled(3, PaginationSettings.defaultPageSize);
  String secretQuery = '';
  String? secretProject, secretEnvironment;
  int get secretCount => summary?.secretCount ?? secrets.length;
  int get memberCount => summary?.memberCount ?? members.length;
  int get activityCount => summary?.activityCount ?? activity.length;
  int get filteredSecretCount => summary?.filteredSecretCount ?? secrets.length;
  int projectCount(String name) =>
      summary?.projectCounts.entries
          .where((e) => e.key.toLowerCase() == name.toLowerCase())
          .firstOrNull
          ?.value ??
      secrets
          .where((s) => s.project.toLowerCase() == name.toLowerCase())
          .length;
  List<String> get projects {
    final names = <String, String>{'default': 'Default'};
    for (final name in summary?.projectCounts.keys ?? <String>[]) {
      names.putIfAbsent(name.toLowerCase(), () => name);
    }
    for (final secret in secrets) {
      names.putIfAbsent(secret.project.toLowerCase(), () => secret.project);
    }
    final others =
        names.entries
            .where((entry) => entry.key != 'default')
            .map((entry) => entry.value)
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['Default', ...others];
  }

  List<AuditView> activity = [];
  List<MemberView> members = [];
  List<InvitationView> invitations = [];
  List<InvitationView> sentInvitations = [];
  bool loading = false;
  bool restoringSession = false;
  String? sessionRestoreError, sessionStorageWarning;
  bool _disposed = false;
  bool _sessionNotSaved = false;
  String? error;
  int _generation = 0;
  int get pagingRevision => _generation;
  int _profileRevision = 0;
  Future<void>? _profileWrites;
  final _organizationRevisions = <String, int>{};
  Future<void>? _organizationWrites;
  bool get canEdit => organization != null && organization!.role != 'reader';
  bool get isOwner => organization?.role == 'owner';

  Future<void> removeMember(
    String organizationId,
    String accountId,
    List<String> reviewedSecretIds,
    List<String> rotateSecretIds,
  ) async {
    final actor = account?.id;
    final token = auth.token;
    await client.vault.removeMember(
      organizationId,
      accountId,
      reviewedSecretIds,
      rotateSecretIds,
      utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );
    if (_disposed ||
        actor != account?.id ||
        token != auth.token ||
        organization?.id != organizationId) {
      return;
    }
    _generation++;
    loading = false;
    final wasVisible = members.any((m) => m.account.id == accountId);
    members = members.where((m) => m.account.id != accountId).toList();
    final selected = rotateSecretIds.toSet();
    secrets = secrets
        .map(
          (s) => selected.contains(s.id) ? s.copyWith(needsRotation: true) : s,
        )
        .toList();
    // A refresh may already have published the removal while its HTTP response
    // was delayed. Only subtract when removing a member still in this snapshot.
    if (wasVisible && summary != null) {
      final previous = summary!;
      final count = (previous.memberCount - 1).clamp(0, previous.memberCount);
      summary = previous.copyWith(memberCount: count);
      if (pages[2] * pageSizes[2] >= count && pages[2] > 0) pages[2]--;
    }
    notifyListeners();
  }

  void _saveSession(String? token) {
    try {
      _sessionStore.write(token);
      _sessionNotSaved = false;
      sessionStorageWarning = null;
    } catch (_) {
      _sessionNotSaved = token != null;
      sessionStorageWarning = token == null
          ? 'This browser could not clear your saved sign-in. Clear this site’s browser data before leaving this device.'
          : 'This browser could not save your sign-in. New tabs and browser restarts will require signing in again.';
    }
  }

  Future<void> synchronizeSession({bool storageChanged = false}) async {
    if (_disposed) return;
    // A failed local write leaves an intentional in-memory login. A lifecycle
    // resume is not a remote logout; an actual storage event still takes effect.
    if (_sessionNotSaved && !storageChanged) return;
    String? saved;
    try {
      saved = _sessionStore.read();
    } catch (_) {
      sessionStorageWarning =
          'This browser could not check your saved sign-in. Reload to try again.';
      notifyListeners();
      return;
    }
    if (saved == auth.token) return;
    _generation++;
    _clearSession(clearSaved: false);
    auth.token = saved;
    notifyListeners();
    if (saved != null) await restoreSession();
  }

  Future<void> _rejectSession() async {
    // Storage events can arrive after a response for an older token. Do not
    // erase a newer login that another tab has already committed.
    try {
      final saved = _sessionStore.read();
      if (saved != null && saved != auth.token) {
        await synchronizeSession(storageChanged: true);
        return;
      }
    } catch (_) {
      // Clear in-memory state even when browser storage is unavailable.
    }
    _clearSession();
    notifyListeners();
  }

  Future<void> restoreSession() async {
    if (_disposed || restoringSession || account != null) return;
    String? token = auth.token;
    try {
      token ??= _sessionStore.read();
    } catch (_) {
      sessionStorageWarning =
          'This browser could not restore your sign-in. Sign in again to continue.';
    }
    if (token == null || token.isEmpty) return;
    final generation = ++_generation;
    auth.token = token;
    restoringSession = true;
    sessionRestoreError = null;
    notifyListeners();
    try {
      final profile = await client.invitation.profile();
      if (_disposed || generation != _generation) return;
      account = profile;
    } on ServerpodClientUnauthorized {
      if (!_disposed && generation == _generation) await _rejectSession();
    } catch (e) {
      if (!_disposed && generation == _generation) {
        sessionRestoreError = describeError(e);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        restoringSession = false;
        notifyListeners();
      }
    }
    if (!_disposed && generation == _generation && account != null) {
      await refresh();
    }
  }

  Future<void> authenticate({
    required String email,
    required String password,
    String? name,
  }) async {
    final result = name == null
        ? await client.account.login(email, password)
        : await client.account.register(email, password, name);
    await useAuthentication(result);
  }

  Future<void> useAuthentication(AuthResult result) async {
    if (_disposed) return;
    _generation++;
    auth.token = result.token;
    account = result.account;
    restoringSession = false;
    sessionRestoreError = null;
    _saveSession(result.token);
    notifyListeners();
    await refresh();
  }

  /// Follow bounded API pages for small ancillary collections used in menus and
  /// badges. Stop dispatching as soon as this refresh loses its session/context.
  Future<List<T>> _allPages<T>(
    Future<List<T>> Function(int offset) fetch,
    int generation,
    String Function(T) id,
  ) async {
    final result = <String, T>{};
    var offset = 0;
    while (!_disposed && generation == _generation) {
      final items = await fetch(offset);
      offset += items.length;
      for (final item in items) {
        result[id(item)] = item;
      }
      if (items.length < PaginationSettings.defaultPageSize) break;
    }
    return result.values.toList();
  }

  Future<void> changePage(int list, int page, {int? pageSize}) =>
      refresh(list: list, page: page, pageSize: pageSize);

  Future<void> filterSecrets({
    String query = '',
    String? project,
    String? environment,
  }) async {
    secretQuery = query;
    secretProject = project;
    secretEnvironment = environment;
    pages[0] = 0;
    // In-memory fixture/offline screens can still filter their local rows.
    if (auth.token == null) return;
    secrets = [];
    await refresh();
  }

  void _resetPaging() {
    summary = null;
    pages.setAll(0, [0, 0, 0]);
    secretQuery = '';
    secretProject = secretEnvironment = null;
  }

  void _restorePageSizes() {
    final accountId = account?.id;
    if (accountId == null || accountId == _pageSizeAccountId) return;
    _pageSizeAccountId = accountId;
    _savedPageSizes.clear();
    pageSizeStorageWarning = null;
    for (final list in PaginationSettings.lists) {
      int? saved;
      try {
        saved = _pageSizeStore.read(accountId, list);
      } catch (_) {
        pageSizeStorageWarning =
            'This browser could not restore your saved page sizes.';
      }
      _savedPageSizes[list] = PaginationSettings.pageSizes.contains(saved)
          ? saved!
          : PaginationSettings.defaultPageSize;
    }
    pageSizes.setAll(
      0,
      PaginationSettings.primaryLists.map((list) => _savedPageSizes[list]!),
    );
  }

  int preferredPageSize(String list) {
    _restorePageSizes();
    return _savedPageSizes[list] ?? PaginationSettings.defaultPageSize;
  }

  void rememberPageSize(String list, int size, {bool notify = true}) {
    if (!PaginationSettings.lists.contains(list) ||
        !PaginationSettings.pageSizes.contains(size)) {
      return;
    }
    _restorePageSizes();
    final accountId = account?.id;
    if (accountId == null) return;
    _savedPageSizes[list] = size;
    try {
      _pageSizeStore.write(accountId, list, size);
      pageSizeStorageWarning = null;
    } catch (_) {
      pageSizeStorageWarning =
          'This browser could not save your page size. It may reset after refreshing.';
    }
    if (notify) notifyListeners();
  }

  Future<void> refresh({int? list, int? page, int? pageSize}) async {
    if (_disposed || account == null || restoringSession) return;
    _restorePageSizes();
    if (list != null &&
        (list < 0 ||
            list > 2 ||
            page == null ||
            page < 0 ||
            (pageSize != null &&
                !PaginationSettings.pageSizes.contains(pageSize)))) {
      return;
    }
    final requestedPages = [...pages];
    final requestedSizes = [...pageSizes];
    if (list != null) {
      requestedPages[list] = page!;
      requestedSizes[list] = pageSize ?? requestedSizes[list];
    }
    final generation = ++_generation;
    final sentIdsBeforeRefresh = sentInvitations.map((i) => i.id).toSet();
    final profileRevision = _profileRevision;
    final organizationRevisions = Map.of(_organizationRevisions);
    loading = true;
    error = null;
    notifyListeners();
    try {
      final overview = await Future.wait<dynamic>([
        _allPages(
          (offset) => client.vault.organizations(
            offset: offset,
            limit: PaginationSettings.defaultPageSize,
          ),
          generation,
          (o) => o.id,
        ),
        _allPages(
          (offset) => client.invitation.inbox(
            offset: offset,
            limit: PaginationSettings.defaultPageSize,
          ),
          generation,
          (i) => i.id,
        ),
        client.invitation.profile(),
      ]);
      if (generation != _generation) return;
      final orgs = (overview[0] as List<OrganizationView>).map((fetched) {
        final current = organizations
            .where((o) => o.id == fetched.id)
            .firstOrNull;
        // A saved name wins over a snapshot requested before that save. Keep
        // fetched membership/roles authoritative and never restore removed rows.
        return current != null &&
                organizationRevisions[fetched.id] !=
                    _organizationRevisions[fetched.id]
            ? fetched.copyWith(name: current.name)
            : fetched;
      }).toList();
      invitations = overview[1] as List<InvitationView>;
      if (profileRevision == _profileRevision) {
        account = overview[2] as AccountView;
      }
      organizations = orgs;
      final previousOrganizationId = organization?.id;
      organization =
          orgs.where((o) => o.id == organization?.id).firstOrNull ??
          orgs.firstOrNull;
      final org = organization;
      if (previousOrganizationId != org?.id) {
        _resetPaging();
        requestedPages.setAll(0, pages);
        secrets = [];
        members = [];
        activity = [];
        sentInvitations = [];
      }
      if (org != null) {
        final counts = await client.vault.summary(
          org.id,
          query: secretQuery,
          project: secretProject,
          environment: secretEnvironment,
        );
        if (generation != _generation) return;
        final totals = [
          counts.filteredSecretCount,
          counts.activityCount,
          counts.memberCount,
        ];
        for (var i = 0; i < 3; i++) {
          final last = totals[i] == 0
              ? 0
              : (totals[i] - 1) ~/ requestedSizes[i];
          requestedPages[i] = requestedPages[i].clamp(0, last);
        }
        final data = await Future.wait<dynamic>([
          client.vault.listSecrets(
            org.id,
            offset: requestedPages[0] * requestedSizes[0],
            limit: requestedSizes[0],
            query: secretQuery,
            project: secretProject,
            environment: secretEnvironment,
          ),
          client.vault.activity(
            org.id,
            offset: requestedPages[1] * requestedSizes[1],
            limit: requestedSizes[1],
          ),
          client.vault.members(
            org.id,
            offset: requestedPages[2] * requestedSizes[2],
            limit: requestedSizes[2],
          ),
          if (org.role == 'owner')
            _allPages(
              (offset) => client.invitation.outgoing(
                org.id,
                offset: offset,
                limit: PaginationSettings.defaultPageSize,
              ),
              generation,
              (i) => i.id,
            ),
        ]);
        if (generation != _generation) return;
        secrets = data[0] as List<SecretView>;
        activity = data[1] as List<AuditView>;
        members = data[2] as List<MemberView>;
        summary = counts;
        pages.setAll(0, requestedPages);
        pageSizes.setAll(0, requestedSizes);
        if (list != null && pageSize != null) {
          rememberPageSize(
            PaginationSettings.primaryLists[list],
            pageSize,
            notify: false,
          );
        }
        final fetchedInvitations = data.length > 3
            ? data[3] as List<InvitationView>
            : <InvitationView>[];
        final fetchedIds = fetchedInvitations.map((i) => i.id).toSet();
        sentInvitations = [
          // Keep creations missing from this older snapshot without cancelling
          // the rest of the workspace load. Fetched rows remain authoritative
          // when they include the new invite, which may already be accepted.
          if (org.role == 'owner')
            ...sentInvitations.where(
              (i) =>
                  i.organizationId == org.id &&
                  !sentIdsBeforeRefresh.contains(i.id) &&
                  !fetchedIds.contains(i.id),
            ),
          ...fetchedInvitations,
        ];
      } else {
        _resetPaging();
        secrets = [];
        activity = [];
        members = [];
        sentInvitations = [];
      }
    } catch (e) {
      if (generation == _generation) {
        if (e is ServerpodClientUnauthorized) {
          await _rejectSession();
        } else {
          error = describeError(e);
        }
      }
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectOrganization(OrganizationView org) async {
    _resetPaging();
    organization = org;
    secrets = [];
    activity = [];
    members = [];
    sentInvitations = [];
    await refresh();
  }

  Future<void> updateInvitationPolicy(String policy) => _updateProfile(
    () => client.invitation.updatePolicy(policy),
    (current, updated) =>
        current.copyWith(invitationPolicy: updated.invitationPolicy),
  );

  Future<void> _updateProfile(
    Future<AccountView> Function() operation,
    AccountView Function(AccountView current, AccountView updated) merge,
  ) {
    final sessionToken = auth.token;
    final accountId = account?.id;
    if (accountId == null) return Future<void>.value();
    // Serialize dispatch as well as local updates, so reopening settings cannot
    // let an earlier choice reach the server after a later choice.
    final previous = _profileWrites;
    Future<void> perform() async {
      if (previous != null) await previous;
      if (_disposed || auth.token != sessionToken || account?.id != accountId) {
        return;
      }
      try {
        final updated = await operation();
        if (_disposed ||
            auth.token != sessionToken ||
            account?.id != accountId) {
          return;
        }
        // A settings response owns only the field it saved. Concurrent settings
        // saves must not overwrite one another with older full-account snapshots.
        // Ignore older profile snapshots without cancelling workspace loads.
        _profileRevision++;
        account = merge(account!, updated);
        notifyListeners();
      } on ServerpodClientUnauthorized {
        if (!_disposed &&
            auth.token == sessionToken &&
            account?.id == accountId) {
          await _rejectSession();
          notifyListeners();
        }
        rethrow;
      }
    }

    final result = perform();
    // A failed save must not prevent subsequent settings changes.
    _profileWrites = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<void> updateName(String name) => _updateProfile(
    () => client.profile.updateName(name),
    (current, updated) => current.copyWith(name: updated.name),
  );

  Future<void> updateTheme(String themeMode) => _updateProfile(
    () => client.profile.updateTheme(themeMode),
    (current, updated) => current.copyWith(themeMode: updated.themeMode),
  );

  Future<void> updateEmail(String currentPassword, String email) async {
    final sessionToken = auth.token;
    final accountId = account?.id;
    await _updateProfile(
      () => client.profile.updateEmail(currentPassword, email),
      (current, updated) => current.copyWith(email: updated.email),
    );
    if (!_disposed && auth.token == sessionToken && account?.id == accountId) {
      // Inbox eligibility and the same-domain policy now use the new address.
      invitations = [];
      notifyListeners();
      await refresh();
    }
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final sessionToken = auth.token;
    final accountId = account?.id;
    try {
      await client.profile.changePassword(currentPassword, newPassword);
    } on ServerpodClientUnauthorized {
      if (!_disposed &&
          auth.token == sessionToken &&
          account?.id == accountId) {
        await _rejectSession();
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> createOrganization(String name) async {
    final sessionToken = auth.token;
    final accountId = account?.id;
    final created = await client.vault.createOrganization(name);
    if (_disposed || auth.token != sessionToken || account?.id != accountId) {
      return;
    }
    organization = created;
    await refresh();
  }

  Future<void> renameOrganization(String organizationId, String name) {
    final sessionToken = auth.token;
    final accountId = account?.id;
    final previous = _organizationWrites;
    Future<void> perform() async {
      if (previous != null) await previous;
      if (_disposed ||
          accountId == null ||
          auth.token != sessionToken ||
          account?.id != accountId) {
        return;
      }
      try {
        final updated = await client.vault.renameOrganization(
          organizationId,
          name,
        );
        if (_disposed ||
            auth.token != sessionToken ||
            account?.id != accountId) {
          return;
        }
        _organizationRevisions[organizationId] =
            (_organizationRevisions[organizationId] ?? 0) + 1;
        organizations = organizations
            .map(
              (org) => org.id == organizationId
                  ? org.copyWith(name: updated.name)
                  : org,
            )
            .toList();
        if (organization?.id == organizationId) {
          organization = organization!.copyWith(name: updated.name);
        }
        notifyListeners();
      } on ServerpodClientUnauthorized {
        if (!_disposed &&
            auth.token == sessionToken &&
            account?.id == accountId) {
          await _rejectSession();
          notifyListeners();
        }
        rethrow;
      }
    }

    final result = perform();
    _organizationWrites = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<InvitationCreated> createInvitation(
    String organizationId,
    String email,
    String name,
    String role,
  ) async {
    final sessionToken = auth.token;
    final accountId = account?.id;
    final created = await client.invitation.create(
      organizationId,
      email,
      name,
      role,
    );
    if (!_disposed &&
        auth.token == sessionToken &&
        account?.id == accountId &&
        organization?.id == organizationId &&
        isOwner &&
        !sentInvitations.any((i) => i.id == created.invitation.id)) {
      // Publish the confirmed invitation before the dialog closes. Refresh
      // preserves creations absent from a snapshot taken before this response.
      // An existing row came from refresh and may already have a newer status.
      sentInvitations = [created.invitation, ...sentInvitations];
      notifyListeners();
    }
    return created;
  }

  Future<void> logout() async {
    _generation++;
    // Serverpod captures the auth header on dispatch. Clear local state before
    // waiting so neither reload nor a delayed response can restore this login.
    final revocation = client.vault.logout();
    _clearSession();
    notifyListeners();
    try {
      await revocation;
    } on ServerpodClientUnauthorized {
      // An expired or revoked session is already signed out on the server.
    }
  }

  void _clearSession({bool clearSaved = true}) {
    _resetPaging();
    _pageSizeAccountId = null;
    _savedPageSizes.clear();
    pageSizes.fillRange(
      0,
      pageSizes.length,
      PaginationSettings.defaultPageSize,
    );
    pageSizeStorageWarning = null;
    _generation++;
    _profileWrites = null;
    _organizationWrites = null;
    _organizationRevisions.clear();
    if (clearSaved) _saveSession(null);
    _sessionNotSaved = false;
    auth.token = null;
    account = null;
    organization = null;
    organizations = [];
    secrets = [];
    members = [];
    invitations = [];
    sentInvitations = [];
    activity = [];
    error = null;
    loading = false;
    restoringSession = false;
    sessionRestoreError = null;
  }

  static String describeError(Object e) {
    if (e is VaultException) return e.message;
    if (e is ServerpodClientUnauthorized) {
      return 'Your session has expired. Sign out and sign in again.';
    }
    return 'Could not reach the vault. Check the server connection and try again.';
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_sessionChanges.cancel());
    client.close();
    super.dispose();
  }
}
