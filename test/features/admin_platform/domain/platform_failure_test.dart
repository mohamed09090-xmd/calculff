import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_validation.dart';

void main() {
  group('PlatformFailure', () {
    test('exposes the complete safe failure code set', () {
      expect(PlatformFailureCode.values, <PlatformFailureCode>[
        PlatformFailureCode.networkUnavailable,
        PlatformFailureCode.sessionExpired,
        PlatformFailureCode.unauthorized,
        PlatformFailureCode.notFound,
        PlatformFailureCode.validation,
        PlatformFailureCode.duplicateSlug,
        PlatformFailureCode.dependencyExists,
        PlatformFailureCode.malformedResponse,
        PlatformFailureCode.temporarilyUnavailable,
        PlatformFailureCode.unknown,
      ]);
    });

    test('keeps only safe validation metadata', () {
      const failure = PlatformFailure(
        PlatformFailureCode.validation,
        validationIssue: PlatformValidationIssue(
          field: PlatformValidationField.slug,
          code: PlatformValidationCode.invalidFormat,
        ),
      );

      expect(failure.code, PlatformFailureCode.validation);
      expect(failure.validationIssue?.field, PlatformValidationField.slug);
      expect(
        failure.validationIssue?.code,
        PlatformValidationCode.invalidFormat,
      );
    });

    test('general representation excludes raw errors, tokens, and PII', () {
      const failure = PlatformFailure(PlatformFailureCode.unknown);
      final text = failure.toString().toLowerCase();

      expect(text, contains('unknown'));
      expect(text, isNot(contains('postgrest')));
      expect(text, isNot(contains('select *')));
      expect(text, isNot(contains('test-access-token')));
      expect(text, isNot(contains('test-refresh-token')));
      expect(text, isNot(contains('admin@example.test')));
      expect(text, isNot(contains('0550000000')));
    });
  });
}
