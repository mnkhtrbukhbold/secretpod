@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:secretpod_server/src/account/account_service.dart';
import 'package:secretpod_server/src/crypto/crypto_service.dart';
import 'package:secretpod_server/src/generated/protocol.dart';
import 'package:secretpod_server/src/services.dart';
import 'package:secretpod_server/src/storage/vault_store.dart';
import 'package:test/test.dart';

// Delay a real storage commit to reproduce credential/session races deterministically.
class PausedWriteStore implements VaultStore {
  PausedWriteStore(this.inner);
  final VaultStore inner;
  final reached = Completer<void>();
  final resume = Completer<void>();
  @override
  Future<T> read<T>(T Function(VaultData) operation) => inner.read(operation);
  @override
  Future<T> write<T>(FutureOr<T> Function(VaultData) operation) async {
    reached.complete();
    await resume.future;
    return inner.write(operation);
  }

  @override
  Future<void> close() async {}
}

void main() {
  late Directory directory;
  late VaultServices services;
  late AuthResult user;
  late String actor, digest;
  const password = '  current-password  ';
  const replacement = '  replacement-password  ';
  final key = base64Encode(List.filled(32, 19));
  final rejected = throwsA(isA<VaultException>());
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('secretpod-profile-');
    services = await VaultServices.open(directory, key);
    user = await services.accounts.register(
      'owner@example.com',
      password,
      'Owner',
    );
    actor = user.account.id;
    digest = CryptoService.tokenDigest(user.token);
  });
  tearDown(() async {
    await services.close();
    await directory.delete(recursive: true);
  });
  AccountService getAccounts() => services.accounts;

  test(
    'name and theme persist across restart without changing identity',
    () async {
      expect(
        (await services.invitations.profile(actor)).toJson()['themeMode'],
        'system',
      );
      final named = await getAccounts().updateName(actor, '  New name  ');
      expect(named.name, 'New name');
      expect(named.id, actor);
      await getAccounts().updateTheme(actor, 'dark');
      await services.close();
      services = await VaultServices.open(directory, key);
      final saved = await services.invitations.profile(actor);
      expect(saved.name, 'New name');
      expect(saved.toJson()['themeMode'], 'dark');
      for (final mode in ['light', 'system']) {
        expect(
          (await getAccounts().updateTheme(actor, mode)).toJson()['themeMode'],
          mode,
        );
      }
    },
  );
  test('invalid names and themes are rejected atomically', () async {
    for (final name in ['', '   ', 'x' * 81]) {
      await expectLater(
        Future.sync(() => getAccounts().updateName(actor, name)),
        rejected,
      );
    }
    await expectLater(
      Future.sync(() => getAccounts().updateTheme(actor, 'invalid')),
      rejected,
    );
    await expectLater(
      Future.sync(() => getAccounts().updateName('missing', 'Name')),
      rejected,
    );
    expect((await services.invitations.profile(actor)).name, 'Owner');
  });
  test(
    'email requires exact current password, normalizes, preserves memberships and login',
    () async {
      final org = await services.organizations.create(actor, 'Team');
      await expectLater(
        getAccounts().updateEmail(actor, password.trim(), 'new@example.com'),
        rejected,
      );
      final saved = await getAccounts().updateEmail(
        actor,
        password,
        '  NEW@Example.com  ',
      );
      expect(saved.email, 'new@example.com');
      expect(saved.id, actor);
      expect((await services.organizations.list(actor)).single.id, org.id);
      await expectLater(
        services.accounts.login('owner@example.com', password),
        rejected,
      );
      expect(
        (await services.accounts.login('new@example.com', password)).account.id,
        actor,
      );
      await services.close();
      services = await VaultServices.open(directory, key);
      expect(
        (await services.invitations.profile(actor)).email,
        'new@example.com',
      );
    },
  );
  test('email uniqueness and syntax failures preserve account', () async {
    await services.accounts.register('taken@example.com', password, 'Other');
    await expectLater(
      getAccounts().updateEmail(actor, password, 'TAKEN@example.com'),
      rejected,
    );
    await expectLater(
      getAccounts().updateEmail(actor, password, 'invalid'),
      rejected,
    );
    expect(
      (await services.invitations.profile(actor)).email,
      'owner@example.com',
    );
  });
  test(
    'password change retains caller, revokes others, preserves exact bytes',
    () async {
      final other = await services.accounts.login(user.account.email, password);
      await getAccounts().changePassword(actor, digest, password, replacement);
      expect(await services.accounts.authenticate(user.token), actor);
      expect(await services.accounts.authenticate(other.token), isNull);
      await expectLater(
        services.accounts.login(user.account.email, password),
        rejected,
      );
      await expectLater(
        services.accounts.login(user.account.email, replacement.trim()),
        rejected,
      );
      expect(
        (await services.accounts.login(
          user.account.email,
          replacement,
        )).account.id,
        actor,
      );
    },
  );
  test(
    'password validation and wrong current password do not revoke sessions',
    () async {
      for (final value in ['short', 'x' * 257]) {
        await expectLater(
          getAccounts().changePassword(actor, digest, password, value),
          rejected,
        );
      }
      await expectLater(
        getAccounts().changePassword(
          actor,
          digest,
          'wrong-password',
          replacement,
        ),
        rejected,
      );
      expect(await services.accounts.authenticate(user.token), actor);
      expect(
        (await services.accounts.login(
          user.account.email,
          password,
        )).account.id,
        actor,
      );
    },
  );
  test('credential changes cannot commit from a revoked session', () async {
    final gate = PausedWriteStore(services.store);
    final accounts = AccountService(gate);
    final changing = accounts.changePassword(
      actor,
      digest,
      password,
      replacement,
    );
    final assertion = expectLater(changing, rejected);
    await gate.reached.future;
    await services.accounts.logout(user.token);
    gate.resume.complete();
    await assertion;
    expect(
      (await services.accounts.login(user.account.email, password)).account.id,
      actor,
    );
  });
  test(
    'login verified before a password change cannot issue a stale session',
    () async {
      final gate = PausedWriteStore(services.store);
      final loggingIn = AccountService(
        gate,
      ).login(user.account.email, password);
      final assertion = expectLater(loggingIn, rejected);
      await gate.reached.future;
      await getAccounts().changePassword(actor, digest, password, replacement);
      gate.resume.complete();
      await assertion;
    },
  );
  test('email change rechecks credentials after hashing', () async {
    final gate = PausedWriteStore(services.store);
    final accounts = AccountService(gate);
    final changing = accounts.updateEmail(actor, password, 'new@example.com');
    final assertion = expectLater(changing, rejected);
    await gate.reached.future;
    await getAccounts().changePassword(actor, digest, password, replacement);
    gate.resume.complete();
    await assertion;
    expect(
      (await services.invitations.profile(actor)).email,
      user.account.email,
    );
  });
  test(
    'email change enforces receiving policy on newly eligible pending invitations',
    () async {
      final sender = await services.accounts.register(
        'sender@other.com',
        password,
        'Sender',
      );
      final org = await services.organizations.create(
        sender.account.id,
        'Inviting team',
      );
      final invite = await services.invitations.create(
        sender.account.id,
        org.id,
        'new@example.com',
        'Recipient',
        'reader',
      );
      final old = await services.invitations.create(
        sender.account.id,
        org.id,
        user.account.email,
        'Recipient',
        'reader',
      );
      await services.invitations.updatePolicy(actor, 'sameDomain');
      await getAccounts().updateEmail(actor, password, 'new@example.com');
      expect(
        (await services.invitations.inbox(actor)).single.status,
        'blocked',
      );
      await expectLater(
        services.invitations.accept(actor, invite.invitation.id, invite.token),
        rejected,
      );
      await expectLater(
        services.invitations.accept(actor, old.invitation.id, old.token),
        rejected,
      );
    },
  );
  test(
    'concurrent password changes cannot overwrite a newer credential',
    () async {
      final gate = PausedWriteStore(services.store);
      final changing = AccountService(
        gate,
      ).changePassword(actor, digest, password, 'stale-replacement-password');
      final assertion = expectLater(changing, rejected);
      await gate.reached.future;
      await services.accounts.changePassword(
        actor,
        digest,
        password,
        replacement,
      );
      gate.resume.complete();
      await assertion;
      expect(
        (await services.accounts.login(
          user.account.email,
          replacement,
        )).account.id,
        actor,
      );
      await expectLater(
        services.accounts.login(
          user.account.email,
          'stale-replacement-password',
        ),
        rejected,
      );
    },
  );
  test(
    'email change does not transfer old invitations and permits newly eligible ones',
    () async {
      final sender = await services.accounts.register(
        'sender@example.com',
        password,
        'Sender',
      );
      final org = await services.organizations.create(
        sender.account.id,
        'Inviting team',
      );
      final old = await services.invitations.create(
        sender.account.id,
        org.id,
        user.account.email,
        'Recipient',
        'reader',
      );
      final next = await services.invitations.create(
        sender.account.id,
        org.id,
        'new@example.com',
        'Recipient',
        'editor',
      );
      await services.accounts.updateEmail(actor, password, 'new@example.com');
      expect(
        (await services.invitations.inbox(actor)).single.id,
        next.invitation.id,
      );
      await expectLater(
        services.invitations.accept(actor, old.invitation.id, old.token),
        rejected,
      );
      expect(
        (await services.invitations.outgoing(
          sender.account.id,
          org.id,
        )).every((i) => i.status == 'pending'),
        isTrue,
      );
      await services.invitations.accept(actor, next.invitation.id, next.token);
      expect((await services.organizations.list(actor)).single.role, 'editor');
    },
  );
  test('current-password verification is rate limited per account', () async {
    for (var i = 0; i < 10; i++) {
      await expectLater(
        getAccounts().updateEmail(actor, 'wrong-password', 'new@example.com'),
        rejected,
      );
    }
    await expectLater(
      getAccounts().updateEmail(actor, password, 'new@example.com'),
      throwsA(
        isA<VaultException>().having(
          (e) => e.message,
          'message',
          contains('Too many'),
        ),
      ),
    );
  });
}
