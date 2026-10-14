import 'package:uuid/uuid.dart';
import '../crypto/crypto_service.dart';
import '../generated/protocol.dart';
import '../invitation/invitation_policy.dart';
import '../storage/vault_store.dart';
import '../validation.dart';

class AccountService {
  AccountService(this.store);
  final VaultStore store;
  final _attempts = <String, List<DateTime>>{};
  final _globalAttempts = <DateTime>[];
  int _activeHashes = 0;
  static const _uuid = Uuid();

  void _limit(String email) {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(minutes: 15));
    _attempts.removeWhere((_, times) => times.every((t) => t.isBefore(cutoff)));
    final attempts = _attempts.putIfAbsent(email, () => []);
    attempts.removeWhere((t) => t.isBefore(cutoff));
    _globalAttempts.removeWhere(
      (t) => t.isBefore(
        DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      ),
    );
    if (attempts.length >= 10 ||
        _globalAttempts.length >= 60 ||
        _activeHashes >= 4) {
      throw VaultException(
        message: 'Too many attempts. Please try again later.',
      );
    }
    attempts.add(DateTime.now().toUtc());
    _globalAttempts.add(DateTime.now().toUtc());
  }

  Future<String> _hash(String password, String salt) async {
    if (_activeHashes >= 4) {
      throw VaultException(
        message: 'Too many attempts. Please try again later.',
      );
    }
    _activeHashes++;
    try {
      return await CryptoService.hashPassword(password, salt);
    } finally {
      _activeHashes--;
    }
  }

  Future<AuthResult> register(
    String email,
    String password,
    String name, {
    void Function(VaultData, Map<String, dynamic>)? onRegistered,
  }) async {
    email = normalizedEmail(email);
    name = bounded(name, 'Name', max: 80);
    if (password.length < 12 || password.length > 256) {
      throw VaultException(
        message: 'Use a password between 12 and 256 characters.',
      );
    }
    _limit(email);
    final salt = CryptoService.randomToken();
    final hash = await _hash(password, salt);
    return store.write((data) {
      if (rows(data, 'accounts').any((a) => a['email'] == email)) {
        throw VaultException(
          message: 'This email is already registered. Sign in instead.',
        );
      }
      final account = <String, dynamic>{
        'id': _uuid.v4(),
        'email': email,
        'name': name,
        'salt': salt,
        'passwordHash': hash,
      };
      rows(data, 'accounts').add(account);
      onRegistered?.call(data, account);
      return _issue(data, account);
    });
  }

  Future<AuthResult> login(String email, String password) async {
    email = normalizedEmail(email);
    if (password.length > 256) {
      throw VaultException(message: 'Invalid email or password.');
    }
    _limit(email);
    final account = await store.read(
      (data) =>
          rows(data, 'accounts').where((a) => a['email'] == email).firstOrNull,
    );
    final salt =
        account?['salt'] as String? ??
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
    final hash = await _hash(password, salt);
    if (account == null ||
        !CryptoService.constantTimeEquals(
          hash,
          account['passwordHash'] as String,
        )) {
      throw VaultException(message: 'Invalid email or password.');
    }
    _attempts.remove(email);
    return store.write((data) {
      final current = _account(data, account['id'] as String);
      if (!_sameCredentials(current, account) || current['email'] != email) {
        throw VaultException(message: 'Invalid email or password.');
      }
      return _issue(data, current);
    });
  }

  Map<String, dynamic> _account(VaultData data, String actor) =>
      rows(data, 'accounts').where((a) => a['id'] == actor).firstOrNull ??
      (throw VaultException(message: 'Sign in to continue.'));

  bool _sameCredentials(Map<String, dynamic> a, Map<String, dynamic> b) =>
      a['salt'] == b['salt'] && a['passwordHash'] == b['passwordHash'];

  Future<Map<String, dynamic>> _verifyCurrentPassword(
    String actor,
    String password,
  ) async {
    _limit('profile:$actor');
    if (password.length > 256) {
      throw VaultException(message: 'Current password is incorrect.');
    }
    final account = await store.read((data) => _account(data, actor));
    final hash = await _hash(password, account['salt'] as String);
    if (!CryptoService.constantTimeEquals(
      hash,
      account['passwordHash'] as String,
    )) {
      throw VaultException(message: 'Current password is incorrect.');
    }
    return account;
  }

  Map<String, dynamic> _recheckCredentials(
    VaultData data,
    String actor,
    Map<String, dynamic> verified,
  ) {
    final current = _account(data, actor);
    if (!_sameCredentials(current, verified) ||
        current['email'] != verified['email']) {
      throw VaultException(message: 'Account credentials changed. Try again.');
    }
    return current;
  }

  Future<AccountView> updateName(String actor, String name) {
    name = bounded(name, 'Name', max: 80);
    return store.write((data) {
      final account = _account(data, actor);
      account['name'] = name;
      return view(account);
    });
  }

  Future<AccountView> updateTheme(String actor, String themeMode) {
    if (!['system', 'light', 'dark'].contains(themeMode)) {
      throw VaultException(
        message: 'Choose System, Light, or Dark appearance.',
      );
    }
    return store.write((data) {
      final account = _account(data, actor);
      account['themeMode'] = themeMode;
      return view(account);
    });
  }

  Future<AccountView> updateEmail(
    String actor,
    String currentPassword,
    String email,
  ) async {
    email = normalizedEmail(email);
    final verified = await _verifyCurrentPassword(actor, currentPassword);
    return store.write((data) {
      final account = _recheckCredentials(data, actor, verified);
      if (rows(
        data,
        'accounts',
      ).any((a) => a['id'] != actor && a['email'] == email)) {
        throw VaultException(message: 'This email is already registered.');
      }
      account['email'] = email;
      blockIncompatibleInvitations(data, account, DateTime.now().toUtc());
      return view(account);
    });
  }

  Future<void> changePassword(
    String actor,
    String sessionDigest,
    String currentPassword,
    String newPassword,
  ) async {
    if (newPassword.length < 12 || newPassword.length > 256) {
      throw VaultException(
        message: 'Use a password between 12 and 256 characters.',
      );
    }
    final verified = await _verifyCurrentPassword(actor, currentPassword);
    final salt = CryptoService.randomToken();
    final hash = await _hash(newPassword, salt);
    await store.write((data) {
      final account = _recheckCredentials(data, actor, verified);
      final sessions = rows(data, 'sessions');
      if (!sessions.any(
        (s) =>
            s['digest'] == sessionDigest &&
            s['accountId'] == actor &&
            DateTime.parse(
              s['expiresAt'] as String,
            ).isAfter(DateTime.now().toUtc()),
      )) {
        throw VaultException(message: 'Sign in to continue.');
      }
      account['salt'] = salt;
      account['passwordHash'] = hash;
      sessions.removeWhere(
        (s) => s['accountId'] == actor && s['digest'] != sessionDigest,
      );
    });
  }

  AuthResult _issue(VaultData data, Map<String, dynamic> account) {
    final token = CryptoService.randomToken();
    final now = DateTime.now().toUtc();
    final sessions = rows(data, 'sessions');
    sessions.removeWhere(
      (s) => DateTime.parse(s['expiresAt'] as String).isBefore(now),
    );
    final own = sessions.where((s) => s['accountId'] == account['id']).toList();
    if (own.length >= 10) sessions.remove(own.first);
    sessions.add({
      'digest': CryptoService.tokenDigest(token),
      'accountId': account['id'],
      'expiresAt': now.add(const Duration(hours: 12)).toIso8601String(),
    });
    return AuthResult(token: token, account: view(account));
  }

  Future<String?> authenticate(String token) async {
    if (token.length != 44) return null;
    final digest = CryptoService.tokenDigest(token);
    return store.read((data) {
      final session = rows(
        data,
        'sessions',
      ).where((s) => s['digest'] == digest).firstOrNull;
      if (session == null ||
          !DateTime.parse(
            session['expiresAt'] as String,
          ).isAfter(DateTime.now().toUtc())) {
        return null;
      }
      return session['accountId'] as String;
    });
  }

  Future<void> logout(String token) =>
      revokeDigest(CryptoService.tokenDigest(token));
  Future<void> revokeDigest(String digest) => store.write((data) {
    rows(data, 'sessions').removeWhere((s) => s['digest'] == digest);
  });

  static AccountView view(Map<String, dynamic> account) => AccountView(
    id: account['id'] as String,
    name: account['name'] as String,
    email: account['email'] as String,
    invitationPolicy: account['invitationPolicy'] as String? ?? 'all',
    themeMode: account['themeMode'] as String? ?? 'system',
  );
}
