import 'admin_auth_failure.dart';

enum AdminAuthStatus {
  unavailable,
  restoring,
  signedOut,
  authenticating,
  authorized,
  unauthorized,
  sessionExpired,
  offline,
  failure,
}

class AdminAuthState {
  const AdminAuthState._({required this.status, this.failureCode});

  const AdminAuthState.unavailable()
      : this._(
          status: AdminAuthStatus.unavailable,
          failureCode: AdminAuthFailureCode.configurationUnavailable,
        );

  const AdminAuthState.restoring()
      : this._(status: AdminAuthStatus.restoring);

  const AdminAuthState.signedOut()
      : this._(status: AdminAuthStatus.signedOut);

  const AdminAuthState.authenticating()
      : this._(status: AdminAuthStatus.authenticating);

  const AdminAuthState.authorized()
      : this._(status: AdminAuthStatus.authorized);

  const AdminAuthState.unauthorized()
      : this._(
          status: AdminAuthStatus.unauthorized,
          failureCode: AdminAuthFailureCode.unauthorized,
        );

  const AdminAuthState.sessionExpired()
      : this._(
          status: AdminAuthStatus.sessionExpired,
          failureCode: AdminAuthFailureCode.sessionExpired,
        );

  const AdminAuthState.offline()
      : this._(
          status: AdminAuthStatus.offline,
          failureCode: AdminAuthFailureCode.networkUnavailable,
        );

  const AdminAuthState.failure(AdminAuthFailureCode failureCode)
      : this._(status: AdminAuthStatus.failure, failureCode: failureCode);

  final AdminAuthStatus status;
  final AdminAuthFailureCode? failureCode;

  bool get isBusy =>
      status == AdminAuthStatus.restoring ||
      status == AdminAuthStatus.authenticating;

  @override
  String toString() {
    return 'AdminAuthState(status: ${status.name}, '
        'failureCode: ${failureCode?.name})';
  }
}

class AdminAuthSession {
  const AdminAuthSession({
    required this.isAdmin,
    required this.isExpired,
  });

  final bool isAdmin;
  final bool isExpired;
}

enum AdminAuthEventType {
  initialSession,
  signedIn,
  signedOut,
  tokenRefreshed,
  userUpdated,
  other,
}

class AdminAuthEvent {
  const AdminAuthEvent({required this.type, this.session});

  final AdminAuthEventType type;
  final AdminAuthSession? session;
}
