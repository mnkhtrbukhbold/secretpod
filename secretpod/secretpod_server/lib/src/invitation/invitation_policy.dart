import '../storage/vault_store.dart';
import '../tracking/tracking_service.dart';

bool allowsInvitation(Map<String, dynamic> account, String inviterEmail) {
  final policy = account['invitationPolicy'] ?? 'all';
  return policy == 'all' ||
      (policy == 'sameDomain' &&
          (account['email'] as String).split('@').last.toLowerCase() ==
              inviterEmail.split('@').last.toLowerCase());
}

void blockIncompatibleInvitations(
  VaultData data,
  Map<String, dynamic> account,
  DateTime now,
) {
  for (final invite in rows(data, 'invitations').where(
    (i) =>
        i['recipientEmail'] == account['email'] &&
        i['status'] == 'pending' &&
        DateTime.parse(i['expiresAt'] as String).isAfter(now),
  )) {
    if (!allowsInvitation(account, invite['inviterEmail'] as String)) {
      invite['status'] = 'blocked';
      invite['respondedAt'] = now.toIso8601String();
      recordEvent(
        data,
        account['id'] as String,
        invite['organizationId'] as String,
        'invitation blocked',
        invite['recipientEmail'] as String,
        details: 'Invitation ${invite['id']}',
      );
    }
  }
}
