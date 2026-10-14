import '../generated/protocol.dart';
import '../storage/vault_store.dart';

String requireMembership(
  VaultData data,
  String actor,
  String organizationId, {
  bool write = false,
  bool owner = false,
}) {
  final members = rows(data, 'members').where(
    (m) => m['accountId'] == actor && m['organizationId'] == organizationId,
  );
  if (members.isEmpty) {
    throw VaultException(message: 'Organization access denied.');
  }
  final role = members.first['role'] as String;
  if ((write && role == 'reader') || (owner && role != 'owner')) {
    throw VaultException(message: 'Your role does not allow this action.');
  }
  return role;
}
