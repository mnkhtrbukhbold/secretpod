import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';
import '../services.dart';

class AccountEndpoint extends Endpoint {
  @override
  bool get logSessions => false;

  Future<AuthResult> register(
    Session session,
    String email,
    String password,
    String name,
  ) => VaultServices.instance.accounts.register(email, password, name);

  Future<AuthResult> login(Session session, String email, String password) =>
      VaultServices.instance.accounts.login(email, password);

  Future<InvitationView> previewInvitation(Session session, String token) =>
      VaultServices.instance.invitations.preview(token);
  Future<AuthResult> registerFromInvitation(
    Session session,
    String token,
    String name,
    String password,
  ) => VaultServices.instance.invitations.registerAndAccept(
    token,
    name,
    password,
  );
  Future<void> declineInvitation(Session session, String token) =>
      VaultServices.instance.invitations.declineToken(token);
}
