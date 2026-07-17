import 'admin_auth_failure.dart';
import 'admin_auth_models.dart';

abstract interface class AdminAuthListener {
  Future<void> cancel();
}

abstract interface class AdminAuthRepository {
  Future<AdminAuthSession?> restoreSession();

  Future<AdminAuthSession> signIn({
    required String email,
    required String password,
  });

  Future<AdminAuthSession> refreshSession();

  AdminAuthListener listenToAuthChanges({
    required void Function(AdminAuthEvent event) onData,
    required void Function(AdminAuthFailure failure) onError,
  });

  Future<void> signOutLocal();
}
