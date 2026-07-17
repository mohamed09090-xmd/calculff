enum AdminAuthFailureCode {
  invalidCredentials,
  networkUnavailable,
  sessionExpired,
  unauthorized,
  configurationUnavailable,
  operationInProgress,
  unknown,
}

class AdminAuthFailure implements Exception {
  const AdminAuthFailure(this.code);

  final AdminAuthFailureCode code;

  @override
  String toString() => 'AdminAuthFailure(code: ${code.name})';
}
