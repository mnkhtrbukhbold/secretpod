import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';
import 'package:secretpod_flutter/state/page_size_store.dart';
import 'package:secretpod_flutter/state/page_size_store_memory.dart';
import 'package:secretpod_flutter/state/list_state_store.dart';
import 'package:secretpod_flutter/state/list_state_store_memory.dart';

class UnavailableListStateStore implements ListStateStore {
  @override
  String? read(String accountId, String key) => throw StateError('Unavailable');
  @override
  void write(String accountId, String key, String value) =>
      throw StateError('Unavailable');
}

class PagingFixture {
  final account = AccountView(id: 'a', name: 'Alex', email: 'a@example.test');
  final organizations = List.generate(
    31,
    (i) => OrganizationView(
      id: 'o$i',
      name: 'Team $i',
      role: 'owner',
      createdAt: DateTime.utc(2026),
    ),
  );
  final requests = <Map<String, dynamic>>[];
  late final VaultController controller;
  Completer<void>? gate, started;
  String? delayedQuery;
  bool fail = false;
  bool insertInvitationBetweenPages = false;
  int count = 61;

  PagingFixture({
    PageSizeStore? pageSizeStore,
    ListStateStore? listStateStore,
  }) {
    controller = VaultController(
      'http://localhost/',
      pageSizeStore: pageSizeStore,
      listStateStore: listStateStore,
      api: Client(
        'http://localhost/',
        httpClientOverride: MockClient((request) async {
          final args = jsonDecode(request.body) as Map<String, dynamic>;
          final method = request.url.pathSegments.last;
          requests.add({'method': method, ...args});
          if (method == 'logout') return http.Response('null', 200);
          final orgId = args['organizationId'] as String? ?? 'o0';
          final query = args['query'] as String? ?? '';
          final secrets =
              List.generate(
                    count,
                    (i) => SecretView(
                      id: '$orgId-s$i',
                      organizationId: orgId,
                      name: 'Secret $i',
                      project: i < 30 ? 'Default' : 'Other',
                      environment: 'Production',
                      kind: 'API key',
                      description: '',
                      version: 1,
                      createdAt: DateTime.utc(2026),
                      updatedAt: DateTime.utc(2026),
                    ),
                  )
                  .where(
                    (s) =>
                        s.name.contains(query) &&
                        (args['project'] == null ||
                            args['project'] == s.project) &&
                        (args['environment'] == null ||
                            args['environment'] == s.environment),
                  )
                  .toList();
          Object result;
          switch (method) {
            case 'profile':
              result = account.toJson();
            case 'summary':
              result = WorkspaceSummary(
                secretCount: count,
                filteredSecretCount: secrets.length,
                memberCount: count,
                activityCount: count,
                projectCounts: {'Default': 30, 'Other': count - 30},
              ).toJson();
            case 'organizations':
              result = organizations.map((o) => o.toJson()).toList();
            case 'listSecrets':
              if (gate != null && query == delayedQuery) {
                final waiting = gate!;
                if (!(started?.isCompleted ?? true)) started!.complete();
                await waiting.future;
              }
              if (fail) return http.Response('', 503);
              result = secrets.map((s) => s.toJson()).toList();
            case 'members':
              result = List.generate(
                count,
                (i) => MemberView(
                  account: account.copyWith(id: 'a$i'),
                  role: 'reader',
                ).toJson(),
              );
            case 'activity':
              result = List.generate(
                count,
                (i) => AuditView(
                  id: 'e$i',
                  actor: 'Alex',
                  action: 'created',
                  target: 'Fixture $i',
                  createdAt: DateTime.utc(2026),
                ).toJson(),
              );
            case 'inbox':
            case 'outgoing':
              result = List.generate(
                31,
                (i) => InvitationView(
                  id: 'i$i',
                  organizationId: orgId,
                  organizationName: 'Team',
                  inviterName: 'Owner',
                  inviterEmail: 'owner@example.test',
                  recipientEmail: account.email,
                  recipientName: 'Alex',
                  role: 'reader',
                  status: 'pending',
                  createdAt: DateTime.utc(2026),
                  expiresAt: DateTime.utc(2099),
                ).toJson(),
              );
            default:
              throw StateError('Unexpected $method');
          }
          if (insertInvitationBetweenPages &&
              (method == 'inbox' || method == 'outgoing') &&
              (args['offset'] as int? ?? 0) > 0) {
            result = [(result as List).first, ...result];
          }
          if (result is List) {
            result = result
                .skip(args['offset'] as int? ?? 0)
                .take(args['limit'] as int? ?? 10)
                .toList();
          }
          return http.Response(jsonEncode(result), 200);
        }),
      ),
    )..account = account;
    controller.auth.token = 'synthetic-session';
  }
}

void main() {
  late PagingFixture fixture;
  late VaultController controller;
  setUp(() {
    fixture = PagingFixture();
    controller = fixture.controller;
  });
  tearDown(() => controller.dispose());

  test(
    'unavailable browser preferences do not prevent loading or paging',
    () async {
      final instance = PagingFixture(
        listStateStore: UnavailableListStateStore(),
      );
      addTearDown(instance.controller.dispose);
      await instance.controller.refresh();
      expect(instance.controller.error, isNull);
      expect(instance.controller.secrets, hasLength(10));
      expect(instance.controller.listPreferencesStorageWarning, isNotNull);
      await instance.controller.changePage(0, 2);
      expect(instance.controller.pages[0], 2);
      expect(instance.controller.preferredListState('secrets').page, 2);
    },
  );

  test(
    'clearing filters and changing page size save page one across reload',
    () async {
      final states = MemoryListStateStore();
      final sizes = MemoryPageSizeStore();
      final first = PagingFixture(listStateStore: states, pageSizeStore: sizes);
      await first.controller.refresh();
      await first.controller.filterSecrets(
        query: 'Secret',
        project: 'Other',
        environment: 'Production',
      );
      await first.controller.changePage(0, 2);
      await first.controller.filterSecrets();
      await first.controller.changePage(0, 1);
      await first.controller.changePage(0, 0, pageSize: 25);
      first.controller.dispose();
      final second = PagingFixture(
        listStateStore: states,
        pageSizeStore: sizes,
      );
      addTearDown(second.controller.dispose);
      await second.controller.refresh();
      expect(second.controller.pages[0], 0);
      expect(second.controller.pageSizes[0], 25);
      expect(second.controller.secretQuery, isEmpty);
      expect(second.controller.secretProject, isNull);
      expect(second.controller.secretEnvironment, isNull);
      expect(second.controller.secrets, hasLength(25));
    },
  );

  test(
    'filters chosen while switching organizations override saved filters',
    () async {
      await controller.refresh();
      await controller.selectOrganization(fixture.organizations[1]);
      await controller.filterSecrets(query: 'Secret 1');
      await controller.selectOrganization(fixture.organizations[0]);
      final switching = controller.selectOrganization(fixture.organizations[1]);
      final filtering = controller.filterSecrets(query: 'Secret 60');
      await Future.wait([switching, filtering]);
      expect(controller.secretQuery, 'Secret 60');
      expect(controller.secrets.single.name, 'Secret 60');
      expect(
        controller.preferredListState('secrets').filters['query'],
        'Secret 60',
      );
    },
  );

  test(
    'app recreation restores organization, all pages and secret filters before requests',
    () async {
      final states = MemoryListStateStore();
      final sizes = MemoryPageSizeStore();
      final first = PagingFixture(pageSizeStore: sizes, listStateStore: states);
      await first.controller.refresh();
      await first.controller.selectOrganization(first.organizations[2]);
      await first.controller.filterSecrets(
        query: 'Secret',
        project: 'Other',
        environment: 'Production',
      );
      await first.controller.changePage(0, 1, pageSize: 25);
      await first.controller.changePage(1, 3);
      await first.controller.changePage(2, 2);
      first.controller.rememberInvitationPage('received-invitations', 2);
      first.controller.rememberInvitationPage('sent-invitations', 1);
      first.controller.dispose();
      final second = PagingFixture(
        pageSizeStore: sizes,
        listStateStore: states,
      );
      addTearDown(second.controller.dispose);
      await second.controller.refresh();
      expect(second.controller.organization?.id, 'o2');
      expect(second.controller.pages, [1, 3, 2]);
      expect(second.controller.pageSizes, [25, 10, 10]);
      expect(second.controller.secretQuery, 'Secret');
      expect(second.controller.secretProject, 'Other');
      expect(second.controller.secretEnvironment, 'Production');
      expect(second.controller.secrets.first.id, 'o2-s55');
      expect(
        second.controller.preferredListState('received-invitations').page,
        2,
      );
      expect(second.controller.preferredListState('sent-invitations').page, 1);
      final summary = second.requests.firstWhere(
        (r) => r['method'] == 'summary',
      );
      expect(summary['query'], 'Secret');
      expect(summary['project'], 'Other');
      expect(summary['environment'], 'Production');
      for (final entry in {
        'listSecrets': 25,
        'activity': 30,
        'members': 20,
      }.entries) {
        expect(
          second.requests.firstWhere((r) => r['method'] == entry.key)['offset'],
          entry.value,
        );
      }
    },
  );

  test(
    'saved pages clamp after deletion and inaccessible organization falls back',
    () async {
      final states = MemoryListStateStore()
        ..write('a', ListStateStore.organizationKey, 'removed')
        ..write(
          'a',
          ListStateStore.listKey('secrets', 'removed'),
          const ListViewState(page: 4, filters: {'query': 'missing'}).encode(),
        );
      for (final list in [
        'secrets',
        'activity',
        'members',
        'sent-invitations',
      ]) {
        states.write(
          'a',
          ListStateStore.listKey(list, 'o0'),
          const ListViewState(page: 99).encode(),
        );
      }
      states.write(
        'a',
        ListStateStore.listKey('received-invitations', null),
        const ListViewState(page: 99).encode(),
      );
      final instance = PagingFixture(listStateStore: states);
      addTearDown(instance.controller.dispose);
      await instance.controller.refresh();
      expect(instance.controller.organization?.id, 'o0');
      expect(instance.controller.pages, [6, 6, 6]);
      expect(instance.controller.secretQuery, isEmpty);
      expect(
        instance.controller.preferredListState('sent-invitations').page,
        3,
      );
      expect(
        instance.controller.preferredListState('received-invitations').page,
        3,
      );
      instance.count = 0;
      await instance.controller.refresh();
      expect(instance.controller.pages, [0, 0, 0]);
      expect(
        ListViewState.decode(
          states.read('a', ListStateStore.listKey('secrets', 'o0')),
        ).page,
        0,
      );
    },
  );

  test(
    'failed and stale requests cannot overwrite confirmed saved filters or pages',
    () async {
      final states = MemoryListStateStore();
      final instance = PagingFixture(listStateStore: states);
      final c = instance.controller;
      addTearDown(c.dispose);
      await c.refresh();
      await c.changePage(0, 2);
      final key = ListStateStore.listKey('secrets', 'o0');
      final confirmed = states.read('a', key);
      instance.fail = true;
      await c.filterSecrets(query: 'Secret 60');
      expect(states.read('a', key), confirmed);
      instance.fail = false;
      instance.gate = Completer<void>();
      instance.started = Completer<void>();
      instance.delayedQuery = 'Secret 1';
      final pending = c.filterSecrets(query: 'Secret 1');
      await instance.started!.future;
      await c.filterSecrets(query: 'Secret 60');
      instance.gate!.complete();
      await pending;
      final saved = ListViewState.decode(states.read('a', key));
      expect(saved.page, 0);
      expect(saved.filters['query'], 'Secret 60');
      instance.gate = Completer<void>();
      instance.started = Completer<void>();
      instance.delayedQuery = 'Secret';
      final loggingOut = c.filterSecrets(query: 'Secret');
      await instance.started!.future;
      await c.logout();
      instance.gate!.complete();
      await loggingOut;
      expect(
        ListViewState.decode(states.read('a', key)).filters['query'],
        'Secret 60',
      );
      expect(c.preferredListState('secrets').filters, isEmpty);
    },
  );

  test(
    'list preferences remain separate by account and invitation organization',
    () async {
      final states = MemoryListStateStore();
      final instance = PagingFixture(listStateStore: states);
      final c = instance.controller;
      addTearDown(c.dispose);
      await c.refresh();
      c.rememberInvitationPage('received-invitations', 2);
      c.rememberInvitationPage('sent-invitations', 1);
      await c.selectOrganization(instance.organizations[1]);
      expect(c.preferredListState('received-invitations').page, 2);
      expect(c.preferredListState('sent-invitations').page, 0);
      c.rememberInvitationPage('sent-invitations', 3);
      await c.selectOrganization(instance.organizations[0]);
      expect(c.preferredListState('sent-invitations').page, 1);
      await c.logout();
      c.account = instance.account.copyWith(id: 'other-account');
      expect(c.preferredListState('received-invitations').page, 0);
      expect(c.preferredListState('secrets').filters, isEmpty);
    },
  );

  test(
    'invalid stored list state safely defaults and preserves valid fields',
    () {
      for (final value in [
        null,
        '',
        '{',
        '[]',
        'null',
        '{"version":2,"page":4}',
      ]) {
        expect(ListViewState.decode(value).page, 0);
        expect(ListViewState.decode(value).filters, isEmpty);
      }
      final state = ListViewState.decode(
        '{"version":1,"page":-3,"filters":{"query":"Secret","project":123}}',
      );
      expect(state.page, 0);
      expect(state.filters, {'query': 'Secret'});
    },
  );

  test('returning to an organization restores its pages and filters', () async {
    await controller.refresh();
    await controller.filterSecrets(
      query: 'Secret',
      project: 'Other',
      environment: 'Production',
    );
    await controller.changePage(0, 2);
    await controller.changePage(1, 3);
    await controller.changePage(2, 1);
    await controller.selectOrganization(fixture.organizations[1]);
    expect(controller.pages, [0, 0, 0]);
    expect(controller.secretQuery, isEmpty);
    await controller.selectOrganization(fixture.organizations[0]);
    expect(controller.pages, [2, 3, 1]);
    expect(controller.secretQuery, 'Secret');
    expect(controller.secretProject, 'Other');
    expect(controller.secretEnvironment, 'Production');
    expect(controller.secrets.first.id, 'o0-s50');
  });

  test(
    'organization fallback applies and saves the same requested size',
    () async {
      final store = MemoryPageSizeStore();
      final instance = PagingFixture(pageSizeStore: store);
      addTearDown(instance.controller.dispose);
      await instance.controller.refresh();
      instance.organizations.removeAt(0);
      await instance.controller.changePage(0, 0, pageSize: 50);
      expect(instance.controller.organization?.id, 'o1');
      expect(instance.controller.pageSizes[0], 50);
      expect(instance.controller.secrets, hasLength(50));
      expect(store.read('a', 'secrets'), 50);
    },
  );

  test(
    'each list restores its saved size before fetching after app recreation',
    () async {
      final store = MemoryPageSizeStore();
      final first = PagingFixture(pageSizeStore: store);
      await first.controller.refresh();
      await first.controller.changePage(0, 0, pageSize: 25);
      await first.controller.changePage(1, 0, pageSize: 50);
      await first.controller.changePage(2, 0, pageSize: 100);
      first.controller.rememberPageSize('received-invitations', 50);
      first.controller.rememberPageSize('sent-invitations', 25);
      await first.controller.logout();
      first.controller.dispose();
      final reloaded = PagingFixture(pageSizeStore: store);
      addTearDown(reloaded.controller.dispose);
      await reloaded.controller.refresh();
      expect(reloaded.controller.pageSizes, [25, 50, 100]);
      expect(reloaded.controller.preferredPageSize('received-invitations'), 50);
      expect(reloaded.controller.preferredPageSize('sent-invitations'), 25);
      for (final entry in {
        'listSecrets': 25,
        'activity': 50,
        'members': 100,
      }.entries) {
        expect(
          reloaded.requests.firstWhere(
            (r) => r['method'] == entry.key,
          )['limit'],
          entry.value,
        );
      }
      expect(reloaded.controller.pages, [0, 0, 0]);
    },
  );

  test(
    'invalid saved sizes fall back to 10 and accounts have separate choices',
    () async {
      final store = MemoryPageSizeStore()
        ..write('a', 'secrets', 123)
        ..write('a', 'activity', 0)
        ..write('other-account', 'members', 100);
      final instance = PagingFixture(pageSizeStore: store);
      addTearDown(instance.controller.dispose);
      await instance.controller.refresh();
      expect(instance.controller.pageSizes, [10, 10, 10]);
      await instance.controller.changePage(0, 0, pageSize: 25);
      await instance.controller.logout();
      instance.controller.account = instance.account.copyWith(
        id: 'other-account',
      );
      expect(instance.controller.preferredPageSize('members'), 100);
      expect(instance.controller.pageSizes, [10, 10, 100]);
      expect(store.read('a', 'secrets'), 25);
    },
  );

  test('failed or stale requests do not replace saved page size', () async {
    final store = MemoryPageSizeStore()..write('a', 'secrets', 25);
    final instance = PagingFixture(pageSizeStore: store);
    addTearDown(instance.controller.dispose);
    await instance.controller.refresh();
    instance.fail = true;
    await instance.controller.changePage(0, 0, pageSize: 50);
    expect(store.read('a', 'secrets'), 25);
    instance.fail = false;
    instance.gate = Completer<void>();
    instance.started = Completer<void>();
    instance.delayedQuery = '';
    final pending = instance.controller.changePage(0, 0, pageSize: 100);
    await instance.started!.future;
    await instance.controller.logout();
    instance.gate!.complete();
    await pending;
    expect(store.read('a', 'secrets'), 25);
  });

  test(
    'selected page sizes survive organization changes and refresh',
    () async {
      await controller.refresh();
      await controller.changePage(0, 0, pageSize: 25);
      await controller.changePage(1, 0, pageSize: 50);
      await controller.changePage(2, 0, pageSize: 100);
      await controller.selectOrganization(fixture.organizations[1]);
      await controller.refresh();
      expect(controller.pageSizes, [25, 50, 100]);
    },
  );

  test(
    'insertion between invitation pages does not duplicate rows or badge counts',
    () async {
      fixture.insertInvitationBetweenPages = true;
      await controller.refresh();
      expect(controller.invitations, hasLength(31));
      expect(controller.sentInvitations, hasLength(31));
      expect(controller.invitations.map((i) => i.id).toSet(), hasLength(31));
    },
  );

  test(
    'ancillary lists stay complete and all primary lists page independently',
    () async {
      await controller.refresh();
      expect(controller.error, isNull);
      expect(controller.organizations, hasLength(31));
      expect(controller.invitations, hasLength(31));
      expect(controller.sentInvitations, hasLength(31));
      expect(controller.secrets, hasLength(10));
      expect(controller.members, hasLength(10));
      expect(controller.activity, hasLength(10));
      expect(controller.secretCount, 61);
      expect(controller.projectCount('Other'), 31);
      await controller.changePage(1, 2);
      expect(controller.activity, hasLength(10));
      expect(controller.pages, [0, 2, 0]);
      await controller.changePage(2, 1);
      expect(controller.members.first.account.id, 'a10');
      expect(controller.pages, [0, 2, 1]);
      await controller.changePage(0, 0, pageSize: 50);
      expect(controller.secrets, hasLength(50));
      await controller.changePage(0, 0, pageSize: 100);
      expect(controller.secrets, hasLength(61));
      expect(controller.pageSizes, [100, 10, 10]);
    },
  );

  test(
    'filtering resets page and late query responses cannot replace newer ones',
    () async {
      await controller.refresh();
      await controller.changePage(0, 2);
      fixture.gate = Completer<void>();
      fixture.started = Completer<void>();
      fixture.delayedQuery = 'Secret 1';
      final older = controller.filterSecrets(query: 'Secret 1');
      await fixture.started!.future;
      await controller.filterSecrets(query: 'Secret 60');
      expect(controller.secrets.single.name, 'Secret 60');
      expect(controller.filteredSecretCount, 1);
      expect(controller.pages[0], 0);
      fixture.gate!.complete();
      await older;
      expect(controller.secrets.single.name, 'Secret 60');
      expect(controller.loading, isFalse);
    },
  );

  test(
    'failed navigation retains current page; deletion clamps to last page',
    () async {
      await controller.refresh();
      fixture.fail = true;
      await controller.changePage(0, 1);
      expect(controller.error, isNotNull);
      expect(controller.pages[0], 0);
      expect(controller.secrets.first.id, 'o0-s0');
      fixture.fail = false;
      await controller.changePage(0, 6);
      fixture.count = 50;
      await controller.refresh();
      expect(controller.error, isNull);
      expect(controller.pages[0], 4);
      expect(controller.secrets.first.id, 'o0-s40');
    },
  );

  for (final logout in [false, true]) {
    test(
      'pending page is discarded after ${logout ? 'logout' : 'organization switch'}',
      () async {
        await controller.refresh();
        fixture.gate = Completer<void>();
        fixture.started = Completer<void>();
        fixture.delayedQuery = '';
        final pending = controller.changePage(0, 1);
        await fixture.started!.future;
        final gate = fixture.gate!;
        fixture.gate = null;
        if (logout) {
          await controller.logout();
        } else {
          await controller.selectOrganization(fixture.organizations[1]);
        }
        gate.complete();
        await pending;
        expect(controller.pages, [0, 0, 0]);
        if (logout) {
          expect(controller.secrets, isEmpty);
          expect(controller.summary, isNull);
        } else {
          expect(controller.secrets.first.id, 'o1-s0');
        }
      },
    );
  }
}
