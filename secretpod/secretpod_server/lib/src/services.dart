import 'dart:io';
import 'account/account_service.dart';
import 'crypto/crypto_service.dart';
import 'organization/organization_service.dart';
import 'invitation/invitation_service.dart';
import 'storage/vault_store.dart';
import 'storage/sqlite_vault_store.dart';
import 'tracking/tracking_service.dart';
import 'vault/vault_service.dart';

class VaultServices {
  VaultServices._(this.store, this.crypto) {
    accounts = AccountService(store);
    organizations = OrganizationService(store);
    invitations = InvitationService(store, accounts);
    tracking = TrackingService(store);
    vault = VaultService(store, crypto);
  }
  final VaultStore store;
  final CryptoService crypto;
  late final AccountService accounts;
  late final OrganizationService organizations;
  late final InvitationService invitations;
  late final TrackingService tracking;
  late final VaultService vault;
  static late VaultServices instance;

  static Future<VaultServices> open(
    Directory directory,
    String masterKey,
  ) async {
    final crypto = CryptoService(masterKey);
    final store = await SqliteVaultStore.open(
      directory,
      validate: (data) async {
        final check = data['keyCheck'] as String?;
        if (check == null) {
          if ([
            'accounts',
            'sessions',
            'organizations',
            'members',
            'secrets',
            'events',
            'invitations',
            'projects',
          ].any((collection) => rows(data, collection).isNotEmpty)) {
            throw StateError('Existing vault is missing its master-key check.');
          }
          return;
        }
        final marker = await crypto.decrypt(check, 'key-check');
        if (marker != 'SecretPod key check v1' &&
            marker != 'PodVault key check v1') {
          throw StateError('Invalid master key.');
        }
        // Verify imported ciphertext without replacing it or exposing plaintext.
        for (final secret in rows(data, 'secrets')) {
          await crypto.decrypt(
            secret['ciphertext'] as String,
            '${secret['organizationId']}:${secret['id']}',
          );
          final username = secret['usernameCiphertext'] as String?;
          if (username != null) {
            await crypto.decrypt(
              username,
              '${secret['organizationId']}:${secret['id']}:username',
            );
          }
        }
      },
    );
    try {
      final check = await store.read((data) => data['keyCheck'] as String?);
      const currentMarker = 'SecretPod key check v1';
      // Existing installations used this marker before the package rename.
      const legacyMarker = 'PodVault key check v1';
      final marker = check == null
          ? null
          : await crypto.decrypt(check, 'key-check');
      if (marker != null && marker != currentMarker && marker != legacyMarker) {
        throw StateError('Invalid master key.');
      }
      if (marker != currentMarker) {
        await store.write(
          (data) async => data['keyCheck'] = await crypto.encrypt(
            currentMarker,
            'key-check',
          ),
        );
      }
      return VaultServices._(store, crypto);
    } catch (_) {
      await store.close();
      rethrow;
    }
  }

  Future<void> close() => store.close();
}
