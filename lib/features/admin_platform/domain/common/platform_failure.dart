import 'platform_validation.dart';

enum PlatformFailureCode {
  networkUnavailable,
  sessionExpired,
  unauthorized,
  notFound,
  validation,
  duplicateSlug,
  dependencyExists,
  malformedResponse,
  temporarilyUnavailable,
  unknown,
}

class PlatformFailure implements Exception {
  const PlatformFailure(this.code, {this.validationIssue});

  final PlatformFailureCode code;
  final PlatformValidationIssue? validationIssue;

  @override
  String toString() {
    return 'PlatformFailure(code: ${code.name}, '
        'validationIssue: $validationIssue)';
  }
}
