import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';
import '../services.dart';

class ProfileEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;
  @override
  bool get logSessions => false;

  String _actor(Session session) => session.authenticated!.userIdentifier;

  Future<AccountView> updateName(Session session, String name) =>
      VaultServices.instance.accounts.updateName(_actor(session), name);

  Future<AccountView> updateEmail(
    Session session,
    String currentPassword,
    String email,
  ) => VaultServices.instance.accounts.updateEmail(
    _actor(session),
    currentPassword,
    email,
  );

  Future<AccountView> updateTheme(Session session, String themeMode) =>
      VaultServices.instance.accounts.updateTheme(_actor(session), themeMode);

  Future<void> changePassword(
    Session session,
    String currentPassword,
    String newPassword,
  ) => VaultServices.instance.accounts.changePassword(
    _actor(session),
    session.authenticated!.authId,
    currentPassword,
    newPassword,
  );
}
