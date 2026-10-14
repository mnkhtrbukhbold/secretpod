import 'package:uuid/uuid.dart';
import '../account/account_service.dart';
import '../crypto/crypto_service.dart';
import '../generated/protocol.dart';
import '../organization/access.dart';
import '../storage/vault_store.dart';
import '../tracking/tracking_service.dart';
import '../validation.dart';
import 'invitation_policy.dart';
import '../paging.dart';

class InvitationService {
  InvitationService(this.store, this.accounts, {DateTime Function()? now})
    : _now = now ?? (() => DateTime.now().toUtc());
  final VaultStore store;
  final AccountService accounts;
  final DateTime Function() _now;

  Map<String, dynamic> _account(VaultData data, String actor) =>
      rows(data, 'accounts').where((a) => a['id'] == actor).firstOrNull ??
      (throw VaultException(message: 'Sign in to continue.'));

  bool _allowed(Map<String, dynamic> account, String inviterEmail) =>
      allowsInvitation(account, inviterEmail);

  String _status(Map<String, dynamic> invite) =>
      invite['status'] == 'pending' &&
          !DateTime.parse(invite['expiresAt'] as String).isAfter(_now())
      ? 'expired'
      : invite['status'] as String;

  Map<String, dynamic> _pending(VaultData data, String id) {
    final invite = rows(
      data,
      'invitations',
    ).where((i) => i['id'] == id).firstOrNull;
    if (invite == null || _status(invite) != 'pending') {
      throw VaultException(
        message:
            'This invitation is no longer available. It may have expired or already been answered.',
      );
    }
    return invite;
  }

  Map<String, dynamic> _byToken(VaultData data, String token) {
    if (!RegExp(r'^[A-Za-z0-9_-]{43}=$').hasMatch(token)) {
      throw VaultException(message: 'Invalid invitation link.');
    }
    final digest = CryptoService.tokenDigest(token);
    final invite = rows(
      data,
      'invitations',
    ).where((i) => i['tokenDigest'] == digest).firstOrNull;
    if (invite == null) {
      throw VaultException(message: 'Invalid invitation link.');
    }
    return _pending(data, invite['id'] as String);
  }

  Future<InvitationCreated> create(
    String actor,
    String organizationId,
    String email,
    String name,
    String role,
  ) {
    email = normalizedEmail(email);
    name = bounded(name, 'Recipient name', max: 80);
    if (!['reader', 'editor'].contains(role)) {
      throw VaultException(message: 'Choose reader or editor.');
    }
    return store.write((data) {
      requireMembership(data, actor, organizationId, owner: true);
      final sender = _account(data, actor);
      final recipient = rows(
        data,
        'accounts',
      ).where((a) => a['email'] == email).firstOrNull;
      if (recipient != null) {
        if (!_allowed(recipient, sender['email'] as String)) {
          throw VaultException(
            message:
                'This recipient is not accepting invitations from this organization.',
          );
        }
        if (rows(data, 'members').any(
          (m) =>
              m['organizationId'] == organizationId &&
              m['accountId'] == recipient['id'],
        )) {
          throw VaultException(message: 'This person is already a member.');
        }
      }
      final invites = rows(data, 'invitations');
      final now = _now();
      for (final invite in invites.where(
        (i) => i['status'] == 'pending' && _status(i) == 'expired',
      )) {
        invite['status'] = 'expired';
        invite['respondedAt'] = invite['expiresAt'];
      }
      if (invites.any(
        (i) =>
            i['organizationId'] == organizationId &&
            i['recipientEmail'] == email &&
            i['status'] == 'pending',
      )) {
        throw VaultException(
          message: 'A pending invitation already exists for this email.',
        );
      }
      if (invites.any(
        (i) =>
            i['organizationId'] == organizationId &&
            i['recipientEmail'] == email &&
            i['status'] == 'declined' &&
            DateTime.parse(
              i['respondedAt'] as String,
            ).isAfter(now.subtract(const Duration(days: 7))),
      )) {
        throw VaultException(
          message:
              'This person declined recently. Wait seven days before inviting them again.',
        );
      }
      if (invites
                  .where(
                    (i) =>
                        i['inviterId'] == actor &&
                        DateTime.parse(
                          i['createdAt'] as String,
                        ).isAfter(now.subtract(const Duration(hours: 1))),
                  )
                  .length >=
              20 ||
          invites
                  .where(
                    (i) =>
                        i['organizationId'] == organizationId &&
                        i['status'] == 'pending',
                  )
                  .length >=
              100) {
        throw VaultException(
          message:
              'Invitation limit reached. Try again later or revoke pending invitations.',
        );
      }
      final token = CryptoService.randomToken();
      final invite = <String, dynamic>{
        'id': const Uuid().v4(),
        'organizationId': organizationId,
        'inviterId': actor,
        'inviterName': sender['name'],
        'inviterEmail': sender['email'],
        'recipientEmail': email,
        'recipientName': name,
        'role': role,
        'tokenDigest': CryptoService.tokenDigest(token),
        'status': 'pending',
        'createdAt': now.toIso8601String(),
        'expiresAt': now.add(const Duration(days: 7)).toIso8601String(),
      };
      invites.add(invite);
      recordEvent(
        data,
        actor,
        organizationId,
        'invited $role',
        email,
        details: 'Invitation ${invite['id']}',
      );
      return InvitationCreated(invitation: _view(data, invite), token: token);
    });
  }

  Future<List<InvitationView>> inbox(
    String actor, {
    int offset = 0,
    int limit = Pagination.defaultLimit,
  }) => store.read((data) {
    final email = _account(data, actor)['email'];
    return Pagination(offset: offset, limit: limit)
        .apply(
          rows(
            data,
            'invitations',
          ).reversed.where((i) => i['recipientEmail'] == email),
        )
        .map((i) => _view(data, i))
        .toList();
  });

  Future<List<InvitationView>> outgoing(
    String actor,
    String organizationId, {
    int offset = 0,
    int limit = Pagination.defaultLimit,
  }) => store.read((data) {
    requireMembership(data, actor, organizationId, owner: true);
    return Pagination(offset: offset, limit: limit)
        .apply(
          rows(
            data,
            'invitations',
          ).reversed.where((i) => i['organizationId'] == organizationId),
        )
        .map((i) => _view(data, i))
        .toList();
  });

  Future<InvitationView> preview(String token) => store.read((data) {
    final invite = _byToken(data, token);
    final account = rows(
      data,
      'accounts',
    ).where((a) => a['email'] == invite['recipientEmail']).firstOrNull;
    if (account != null &&
        !_allowed(account, invite['inviterEmail'] as String)) {
      throw VaultException(
        message: 'Your invitation preferences block this invitation.',
      );
    }
    return _view(data, invite);
  });

  void _finish(
    VaultData data,
    Map<String, dynamic> invite,
    String status, {
    String? actor,
  }) {
    invite['status'] = status;
    invite['respondedAt'] = _now().toIso8601String();
    if (actor != null) {
      recordEvent(
        data,
        actor,
        invite['organizationId'] as String,
        'invitation $status',
        invite['recipientEmail'] as String,
        details: 'Invitation ${invite['id']}',
      );
    }
  }

  void _accept(
    VaultData data,
    Map<String, dynamic> invite,
    Map<String, dynamic> account,
  ) {
    if (account['email'] != invite['recipientEmail']) {
      throw VaultException(
        message: 'Sign in with the email address this invitation was sent to.',
      );
    }
    if (!_allowed(account, invite['inviterEmail'] as String)) {
      throw VaultException(
        message: 'Your invitation preferences block this invitation.',
      );
    }
    requireMembership(
      data,
      invite['inviterId'] as String,
      invite['organizationId'] as String,
      owner: true,
    );
    if (rows(data, 'members').any(
      (m) =>
          m['organizationId'] == invite['organizationId'] &&
          m['accountId'] == account['id'],
    )) {
      throw VaultException(
        message: 'You are already a member of this organization.',
      );
    }
    rows(data, 'members').add({
      'organizationId': invite['organizationId'],
      'accountId': account['id'],
      'role': invite['role'],
    });
    _finish(data, invite, 'accepted', actor: account['id'] as String);
  }

  Future<void> accept(String actor, String id, String token) =>
      store.write((data) {
        final invite = _byToken(data, token);
        if (invite['id'] != id) {
          throw VaultException(
            message: 'This link belongs to a different invitation.',
          );
        }
        _accept(data, invite, _account(data, actor));
      });

  Future<AuthResult> registerAndAccept(
    String token,
    String name,
    String password,
  ) async {
    final previewed = await preview(token);
    return accounts.register(
      previewed.recipientEmail,
      password,
      name,
      onRegistered: (data, account) {
        // Recheck after password hashing; all account, session and membership writes roll back together.
        _accept(data, _byToken(data, token), account);
      },
    );
  }

  Future<void> decline(String actor, String id) => store.write((data) {
    final account = _account(data, actor);
    final invite = _pending(data, id);
    if (account['email'] != invite['recipientEmail']) {
      throw VaultException(message: 'Invitation access denied.');
    }
    _finish(data, invite, 'declined', actor: actor);
  });

  Future<void> declineToken(String token) => store.write((data) {
    // A recipient without an account can decline using the private link.
    _finish(data, _byToken(data, token), 'declined');
  });

  Future<void> revoke(String actor, String organizationId, String id) =>
      store.write((data) {
        requireMembership(data, actor, organizationId, owner: true);
        final invite = _pending(data, id);
        if (invite['organizationId'] != organizationId) {
          throw VaultException(message: 'Invitation access denied.');
        }
        _finish(data, invite, 'revoked', actor: actor);
      });

  Future<AccountView> profile(String actor) =>
      store.read((data) => AccountService.view(_account(data, actor)));

  Future<AccountView> updatePolicy(String actor, String policy) {
    if (!['all', 'sameDomain', 'none'].contains(policy)) {
      throw VaultException(message: 'Choose a valid invitation preference.');
    }
    return store.write((data) {
      final account = _account(data, actor);
      account['invitationPolicy'] = policy;
      blockIncompatibleInvitations(data, account, _now());
      return AccountService.view(account);
    });
  }

  InvitationView _view(VaultData data, Map<String, dynamic> i) =>
      InvitationView(
        id: i['id'] as String,
        organizationId: i['organizationId'] as String,
        organizationName:
            rows(
                  data,
                  'organizations',
                ).firstWhere((o) => o['id'] == i['organizationId'])['name']
                as String,
        inviterName: i['inviterName'] as String,
        inviterEmail: i['inviterEmail'] as String,
        recipientEmail: i['recipientEmail'] as String,
        recipientName: i['recipientName'] as String,
        role: i['role'] as String,
        status: _status(i),
        createdAt: DateTime.parse(i['createdAt'] as String),
        expiresAt: DateTime.parse(i['expiresAt'] as String),
        respondedAt: i['respondedAt'] == null
            ? (_status(i) == 'expired'
                  ? DateTime.parse(i['expiresAt'] as String)
                  : null)
            : DateTime.parse(i['respondedAt'] as String),
      );
}
