import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';
import 'package:secretpod_flutter/state/page_size_store.dart';
import 'package:secretpod_flutter/state/page_size_store_memory.dart';

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

  PagingFixture({PageSizeStore? pageSizeStore}) {
    controller = VaultController(
      'http://localhost/',
      pageSizeStore: pageSizeStore,
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
                            args['project'] == s.project),
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
