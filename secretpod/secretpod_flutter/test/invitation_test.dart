import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:secretpod_flutter/widgets/dropdown_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secretpod_client/secretpod_client.dart';
import 'package:secretpod_flutter/main.dart';
import 'package:secretpod_flutter/screens/invitation_dialogs.dart';
import 'package:secretpod_flutter/screens/invitation_landing.dart';
import 'package:secretpod_flutter/screens/invitations_screen.dart';
import 'package:secretpod_flutter/state/invitation_link.dart';
import 'package:secretpod_flutter/state/vault_controller.dart';

void main() {
  late VaultController controller;
  final token = '${'a' * 43}=';
  final date = DateTime.utc(2026, 10, 14);
  final invitation = InvitationView(
    id: 'invite',
    organizationId: 'org',
    organizationName: 'Engineering',
    inviterName: 'Owner',
    inviterEmail: 'owner@company.test',
    recipientEmail: 'person@company.test',
    recipientName: 'Company supplied name',
    role: 'reader',
    status: 'pending',
    createdAt: date,
    expiresAt: date.add(const Duration(days: 7)),
  );
  final calls = <String>[];
  for (final width in [390.0, 1200.0]) {
    testWidgets('outgoing invitation actions stay at the row edge at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvitationTile(
              invitation: invitation,
              outgoing: true,
              actions: [
                TextButton(
                  onPressed: () {},
                  child: const Text('Revoke invitation'),
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getTopRight(find.byType(TextButton)).dx,
        closeTo(width - 24, .5),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvitationTile(
              invitation: invitation.copyWith(status: 'revoked'),
              outgoing: true,
            ),
          ),
        ),
      );
      expect(find.widgetWithText(Chip, 'Revoked'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  Map<String, dynamic>? submitted;
  String? clipboard;
  var fail = false, closed = false, failAfterPolicySave = false;
  String? profilePolicy;
  final outgoing = <InvitationView>[];
  final serverMembers = <MemberView>[];
  Completer<void>? invitationRefreshGate;
  Completer<void>? createGate;
  Completer<http.Response>? outgoingResponse;
  setUp(() {
    calls.clear();
    submitted = null;
    clipboard = null;
    fail = closed = false;
    failAfterPolicySave = false;
    profilePolicy = null;
    outgoing.clear();
    serverMembers.clear();
    invitationRefreshGate = null;
    createGate = null;
    outgoingResponse = null;
    controller = VaultController(
      'http://localhost/',
      api: Client(
        'http://localhost/',
        httpClientOverride: MockClient((request) async {
          final method = request.url.path.split('/').last;
          calls.add(method);
          final args = jsonDecode(request.body) as Map<String, dynamic>;
          if (fail) return http.Response('', 503);
          switch (method) {
            case 'summary':
              return http.Response(
                jsonEncode(
                  WorkspaceSummary(
                    secretCount: 0,
                    filteredSecretCount: 0,
                    memberCount: serverMembers.length,
                    activityCount: 0,
                    projectCounts: {'Default': 0},
                  ).toJson(),
                ),
                200,
              );
            case 'previewInvitation':
              return http.Response(jsonEncode(invitation.toJson()), 200);
            case 'create':
              await createGate?.future;
              submitted = args;
              outgoing.add(invitation);
              return http.Response(
                jsonEncode(
                  InvitationCreated(
                    invitation: invitation,
                    token: token,
                  ).toJson(),
                ),
                200,
              );
            case 'registerFromInvitation':
              submitted = args;
              return http.Response(
                jsonEncode(
                  AuthResult(
                    token: 'fixture-session',
                    account: AccountView(
                      id: 'recipient',
                      name: args['name'],
                      email: invitation.recipientEmail,
                      invitationPolicy: 'all',
                    ),
                  ).toJson(),
                ),
                200,
              );
            case 'profile':
              await invitationRefreshGate?.future;
              return http.Response(
                jsonEncode(
                  (profilePolicy != null
                          ? controller.account!.copyWith(
                              invitationPolicy: profilePolicy,
                            )
                          : controller.account ??
                                AccountView(
                                  id: 'recipient',
                                  name: 'Recipient',
                                  email: invitation.recipientEmail,
                                  invitationPolicy: 'all',
                                ))
                      .toJson(),
                ),
                200,
              );
            case 'updatePolicy':
              submitted = args;
              fail = failAfterPolicySave;
              return http.Response(
                jsonEncode(
                  AccountView(
                    id: 'recipient',
                    name: 'Recipient',
                    email: invitation.recipientEmail,
                    invitationPolicy: args['policy'],
                  ).toJson(),
                ),
                200,
              );
            case 'organizations':
              return http.Response(
                jsonEncode(
                  controller.organizations.map((o) => o.toJson()).toList(),
                ),
                200,
              );
            case 'outgoing':
              if (outgoingResponse != null) return outgoingResponse!.future;
              return http.Response(
                jsonEncode(outgoing.map((i) => i.toJson()).toList()),
                200,
              );
            case 'members':
              return http.Response(
                jsonEncode(serverMembers.map((m) => m.toJson()).toList()),
                200,
              );
            case 'listSecrets':
            case 'activity':
            case 'inbox':
              return http.Response('[]', 200);
            case 'accept':
            case 'decline':
            case 'declineInvitation':
            case 'revoke':
            case 'logout':
              submitted = args;
              return http.Response('null', 200);
          }
          throw StateError('Unexpected request: $method');
        }),
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });
  tearDown(() {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  void signedIn([String email = 'person@company.test']) {
    controller.account = AccountView(
      id: 'recipient',
      name: 'Recipient',
      email: email,
      invitationPolicy: 'all',
    );
  }

  void ownedWorkspace() {
    signedIn('owner@company.test');
    controller.organization = OrganizationView(
      id: 'org',
      name: 'Engineering',
      role: 'owner',
      createdAt: date,
    );
    controller.organizations = [controller.organization!];
  }

  Future<void> landing(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, _) => InvitationLanding(
            controller: controller,
            token: token,
            onClose: () => closed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openPersonalInvitations(WidgetTester tester) async {
    await tap(tester, find.byTooltip('Account'));
    expect(find.text('My invitations'), findsOneWidget);
    await tap(tester, find.text('My invitations'));
  }

  Future<void> openProfileSettings(WidgetTester tester) async {
    await tap(tester, find.byTooltip('Account'));
    await tap(tester, find.text('Profile settings'));
  }

  Future<void> pushRoute(WidgetTester tester, String location) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', {
          'location': location,
          'state': null,
        }),
      ),
      (_) {},
    );
  }

  test('invitation links round-trip their private fragment token', () {
    expect(invitationTokenFromLink(invitationLink(token)), token);
    expect(invitationTokenFromLink(token), token);
    expect(
      invitationTokenFromLink('https://example.com/#invite=wrong'),
      isNull,
    );
    expect(
      invitationTokenFromLink('https://example.com/?invite=$token'),
      isNull,
    );
  });

  test('a stale refresh cannot remove a newly created invitation', () async {
    ownedWorkspace();
    serverMembers.add(MemberView(account: controller.account!, role: 'owner'));
    final oldInvite = invitation.copyWith(id: 'older', status: 'accepted');
    outgoingResponse = Completer<http.Response>();
    final refresh = controller.refresh();
    while (!calls.contains('outgoing')) {
      await Future<void>.delayed(Duration.zero);
    }
    await controller.createInvitation(
      'org',
      'person@company.test',
      'Person',
      'reader',
    );
    outgoingResponse!.complete(
      http.Response(jsonEncode([oldInvite.toJson()]), 200),
    );
    await refresh;
    expect(controller.members.map((m) => m.account.id), ['recipient']);
    expect(controller.sentInvitations.map((i) => i.id), ['invite', 'older']);
    expect(controller.loading, isFalse);
  });

  for (final leaveSession in [false, true]) {
    test(
      'delayed invitation creation does not update ${leaveSession ? 'a signed-out account' : 'another organization'}',
      () async {
        ownedWorkspace();
        createGate = Completer<void>();
        final creation = controller.createInvitation(
          'org',
          'person@company.test',
          'Person',
          'reader',
        );
        if (leaveSession) {
          await controller.logout();
        } else {
          final other = controller.organization!.copyWith(
            id: 'other',
            name: 'Other',
          );
          controller.organizations.add(other);
          await controller.selectOrganization(other);
        }
        createGate!.complete();
        await creation;
        expect(controller.sentInvitations, isEmpty);
        expect(controller.members, isEmpty);
        if (leaveSession) expect(controller.account, isNull);
      },
    );
  }

  test(
    'overlapping refresh keeps the server status of a newly created invitation',
    () async {
      ownedWorkspace();
      outgoingResponse = Completer<http.Response>();
      final refresh = controller.refresh();
      while (!calls.contains('outgoing')) {
        await Future<void>.delayed(Duration.zero);
      }
      await controller.createInvitation(
        'org',
        'person@company.test',
        'Person',
        'reader',
      );
      outgoingResponse!.complete(
        http.Response(
          jsonEncode([
            invitation.copyWith(status: 'accepted', respondedAt: date).toJson(),
          ]),
          200,
        ),
      );
      await refresh;
      expect(controller.sentInvitations, hasLength(1));
      expect(controller.sentInvitations.single.status, 'accepted');
    },
  );

  test(
    'delayed creation preserves a newer status already loaded by refresh',
    () async {
      ownedWorkspace();
      createGate = Completer<void>();
      final creation = controller.createInvitation(
        'org',
        'person@company.test',
        'Person',
        'reader',
      );
      outgoing.add(invitation.copyWith(status: 'revoked', respondedAt: date));
      await controller.refresh();
      expect(controller.sentInvitations.single.status, 'revoked');
      createGate!.complete();
      await creation;
      expect(controller.sentInvitations, hasLength(1));
      expect(controller.sentInvitations.single.status, 'revoked');
    },
  );

  testWidgets(
    'new recipient edits prefilled name and creates account only on acceptance',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await landing(tester);
      expect(find.text('Company supplied name'), findsOneWidget);
      expect(find.text('Invited email: person@company.test'), findsOneWidget);
      expect(calls, ['previewInvitation']);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Your name'),
        'My chosen name',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'my-private-password',
      );
      await tap(tester, find.text('Create account and accept'));
      expect(calls, contains('registerFromInvitation'));
      expect(submitted!['name'], 'My chosen name');
      expect(submitted!['token'], token);
      expect(submitted!.containsKey('email'), isFalse);
      expect(closed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('wrong signed-in account cannot accept an invitation', (
    tester,
  ) async {
    signedIn('other@else.test');
    await landing(tester);
    expect(find.text('Accept invitation'), findsNothing);
    expect(find.text('Create account and accept'), findsNothing);
    expect(find.text('Switch account'), findsOneWidget);
    expect(calls, ['previewInvitation']);
  });

  testWidgets('switching accounts in the full invitation flow opens sign in', (
    tester,
  ) async {
    signedIn('other@else.test');
    controller.auth.token = 'existing-session';
    await tester.pumpWidget(MyApp(controller: controller));
    await pushRoute(tester, '/invite=$token');
    await tester.pumpAndSettle();
    await tap(tester, find.text('Switch account'));
    expect(find.text('Sign in to review and accept'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Your name'), findsNothing);
  });

  testWidgets(
    'invitation signup finishes when authentication changes in the full app',
    (tester) async {
      await tester.pumpWidget(MyApp(controller: controller));
      await pushRoute(tester, '/invite=$token');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Your name'),
        'Chosen name',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'my-private-password',
      );
      invitationRefreshGate = Completer<void>();
      await tester.ensureVisible(find.text('Create account and accept'));
      await tester.tap(find.text('Create account and accept'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      invitationRefreshGate!.complete();
      await tester.pumpAndSettle();
      expect(controller.account?.name, 'Chosen name');
      expect(find.byType(InvitationLanding), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an open signed-in app handles incoming and changed invitation routes',
    (tester) async {
      signedIn();
      await tester.pumpWidget(MyApp(controller: controller));
      await pushRoute(tester, '/invite=$token');
      await tester.pumpAndSettle();
      expect(find.text('Join Engineering'), findsOneWidget);
      expect(calls.where((c) => c == 'previewInvitation').length, 1);
      final nextToken = '${'b' * 43}=';
      await pushRoute(tester, '/invite=$nextToken');
      await tester.pumpAndSettle();
      expect(calls.where((c) => c == 'previewInvitation').length, 2);
      await pushRoute(tester, '/invite=malformed');
      await tester.pumpAndSettle();
      expect(find.text('Join Engineering'), findsNothing);
      expect(calls.where((c) => c == 'previewInvitation').length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'matching account still explicitly accepts and declines without joining',
    (tester) async {
      signedIn();
      await landing(tester);
      expect(calls, ['previewInvitation']);
      await tap(tester, find.text('Accept invitation'));
      expect(submitted, {'id': 'invite', 'token': token});
      expect(closed, isTrue);
    },
  );

  testWidgets('recipient without an account can decline without registering', (
    tester,
  ) async {
    await landing(tester);
    await tap(tester, find.text('Decline invitation'));
    expect(calls, ['previewInvitation', 'declineInvitation']);
    expect(controller.account, isNull);
    expect(find.text('Invitation declined'), findsOneWidget);
  });

  testWidgets(
    'owner creates pending invitation and copies link without adding membership',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InviteMemberDialog(
              controller: controller,
              organizationId: 'org',
            ),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Recipient name'),
        'Teammate',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'person@company.test',
      );
      await tap(tester, find.text('Create invitation'));
      expect(calls, ['create']);
      expect(find.textContaining('No email has been sent.'), findsOneWidget);
      await tap(tester, find.text('Copy invitation link'));
      expect(invitationTokenFromLink(clipboard!), token);
      expect(find.text('Link copied'), findsOneWidget);
    },
  );

  testWidgets(
    'creating from Members updates sent invitations before closing and leaves personal inbox alone',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      signedIn('owner@company.test');
      controller.organization = OrganizationView(
        id: 'org',
        name: 'Engineering',
        role: 'owner',
        createdAt: date,
      );
      controller.organizations = [controller.organization!];
      controller.invitations = [
        invitation.copyWith(
          id: 'personal-invite',
          organizationName: 'Another team',
        ),
      ];
      await tester.pumpWidget(MyApp(controller: controller));
      expect(find.widgetWithText(ListTile, 'Invitations'), findsNothing);
      await tap(tester, find.widgetWithText(ListTile, 'Members'));
      await tap(tester, find.text('Invite member'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Recipient name'),
        'Teammate',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'person@company.test',
      );
      await tap(tester, find.text('Create invitation'));
      expect(controller.sentInvitations.map((i) => i.id), ['invite']);
      expect(controller.invitations.single.id, 'personal-invite');
      expect(controller.members, isEmpty);
      // The browser/back dismissal does not return a success value to the page.
      Navigator.of(tester.element(find.byType(InviteMemberDialog))).pop();
      await tester.pumpAndSettle();
      await tap(tester, find.widgetWithText(Tab, 'Invitations'));
      expect(find.text('person@company.test'), findsOneWidget);
      final badge = tester.widget<Badge>(find.byType(Badge));
      expect((badge.label! as Text).data, '1');
      expect(badge.isLabelVisible, isTrue);
      await openPersonalInvitations(tester);
      expect(find.text('Another team'), findsOneWidget);
      expect(find.text('Company supplied name'), findsNothing);
      await tap(tester, find.text('Back to workspace'));
      expect(find.text('Invite member'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile sent list keeps history and revokes only the selected pending invitation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ownedWorkspace();
      controller.sentInvitations = [
        invitation.copyWith(
          recipientEmail: 'a.long.recipient.address@company.example.test',
        ),
        invitation.copyWith(
          id: 'accepted',
          recipientName: 'Already joined',
          status: 'accepted',
        ),
      ];
      await tester.pumpWidget(MyApp(controller: controller));
      await tap(tester, find.text('Members'));
      await tap(tester, find.widgetWithText(Tab, 'Invitations'));
      expect(find.text('Already joined'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Revoke invitation'), findsOneWidget);
      await tap(tester, find.text('Revoke invitation'));
      expect(submitted, {'organizationId': 'org', 'id': 'invite'});
      expect(calls.where((c) => c == 'revoke'), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile profile inbox opens acceptance and updates its badge after decline',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      signedIn();
      controller.invitations = [invitation];
      await tester.pumpWidget(MyApp(controller: controller));
      await openPersonalInvitations(tester);
      await tap(tester, find.text('Accept'));
      expect(find.byType(AcceptInvitationDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(AcceptInvitationDialog))).pop();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Decline'));
      expect(submitted, {'id': 'invite'});
      expect(find.text('No invitations'), findsOneWidget);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
      await tap(tester, find.text('Back to workspace'));
      expect(find.text('Give your team a home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [390.0, 1200.0]) {
    testWidgets('invitation shortcut reveals preferences at $width', (
      tester,
    ) async {
      signedIn();
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MyApp(controller: controller));
      await openPersonalInvitations(tester);
      await tap(tester, find.text('Manage invitation preferences'));
      expect(find.text('Who can invite you?').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('invitation-policy')).hitTestable(),
        findsOneWidget,
      );
      await tap(tester, find.text('Back to workspace'));
      await openProfileSettings(tester);
      expect(find.text('Your profile').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'invitations and preferences remain accessible without organization membership',
    (tester) async {
      signedIn();
      controller.invitations = [invitation];
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MyApp(controller: controller));
      await openProfileSettings(tester);
      expect(find.text('Who can invite you?'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('invitation-policy')));
      await tester.tap(find.text('Block all invitations').last);
      await tester.pumpAndSettle();
      await tap(tester, find.text('Save preference'));
      expect(submitted!['policy'], 'none');
      expect(find.text('Invitation preference saved.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inbox acceptance requires a valid link and reports connection failures',
    (tester) async {
      signedIn();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AcceptInvitationDialog(
              controller: controller,
              invitation: invitation,
            ),
          ),
        ),
      );
      await tap(tester, find.text('Accept invitation'));
      expect(calls, isEmpty);
      expect(
        find.textContaining('Paste the private invitation link'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Invitation link'),
        invitationLink(token),
      );
      fail = true;
      await tap(tester, find.text('Accept invitation'));
      expect(calls, ['accept']);
      expect(find.textContaining('Could not reach the vault'), findsOneWidget);
    },
  );

  testWidgets('refreshed invitation preference replaces a clean editor', (
    tester,
  ) async {
    signedIn();
    await tester.pumpWidget(MyApp(controller: controller));
    await openProfileSettings(tester);
    profilePolicy = 'none';
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SecretPodDropdown<String>>(
            find.byKey(const ValueKey('invitation-policy')),
          )
          .initialValue,
      'none',
    );
    await tap(tester, find.text('Save preference'));
    expect(submitted!['policy'], 'none');
  });

  testWidgets('saved preference survives a failed follow-up refresh', (
    tester,
  ) async {
    signedIn();
    await tester.pumpWidget(MyApp(controller: controller));
    await openProfileSettings(tester);
    await tap(tester, find.byKey(const ValueKey('invitation-policy')));
    await tap(tester, find.text('Block all invitations').last);
    failAfterPolicySave = true;
    await tap(tester, find.text('Save preference'));
    expect(controller.account!.invitationPolicy, 'none');
    expect(controller.error, isNotNull);
  });

  testWidgets('refresh preserves an unsaved invitation preference edit', (
    tester,
  ) async {
    signedIn();
    await tester.pumpWidget(MyApp(controller: controller));
    await openProfileSettings(tester);
    await tap(tester, find.byKey(const ValueKey('invitation-policy')));
    await tap(tester, find.text('Same email domain only').last);
    profilePolicy = 'none';
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SecretPodDropdown<String>>(
            find.byKey(const ValueKey('invitation-policy')),
          )
          .initialValue,
      'sameDomain',
    );
  });
}
