import '../storage/vault_store.dart';
import '../tracking/tracking_service.dart';

/// Update the flag and its audit event in the caller's storage transaction.
void markSecretRotation(
  VaultData data,
  String actor,
  Map<String, dynamic> secret,
  bool required, {
  String? details,
}) {
  if ((secret['needsRotation'] == 1) == required) return;
  secret['needsRotation'] = required ? 1 : 0;
  secret['updatedAt'] = DateTime.now().toUtc().toIso8601String();
  recordEvent(
    data,
    actor,
    secret['organizationId'] as String,
    required ? 'marked needs rotating' : 'cleared rotation flag',
    secret['name'] as String,
    secretId: secret['id'] as String,
    version: secret['version'] as int,
    details: details,
  );
}
