import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/platform_payload_reader.dart';

void main() {
  group('PlatformPayloadReader', () {
    test('reads required scalar fields strictly', () {
      const reader = PlatformPayloadReader(<String, Object?>{
        'name': 'Free Fire',
        'count': 4,
        'enabled': true,
      });

      expect(reader.requiredString('name'), 'Free Fire');
      expect(reader.requiredInt('count'), 4);
      expect(reader.requiredBool('enabled'), isTrue);
    });

    test('reads optional fields when present, null, or missing', () {
      const reader = PlatformPayloadReader(<String, Object?>{
        'name': 'Player',
        'nullable': null,
        'count': 2,
        'enabled': false,
      });

      expect(reader.optionalString('name'), 'Player');
      expect(reader.optionalString('nullable'), isNull);
      expect(reader.optionalString('missing'), isNull);
      expect(reader.optionalInt('count'), 2);
      expect(reader.optionalInt('missing_count'), isNull);
      expect(reader.optionalBool('enabled'), isFalse);
      expect(reader.optionalBool('missing_enabled'), isNull);
    });

    test('rejects a missing required field', () {
      const reader = PlatformPayloadReader(<String, Object?>{});

      expect(
        () => reader.requiredString('name'),
        throwsA(
          isA<PlatformPayloadException>()
              .having((error) => error.field, 'field', 'name')
              .having(
                (error) => error.reason,
                'reason',
                PlatformPayloadFailureReason.missingField,
              ),
        ),
      );
    });

    test('rejects a wrong scalar type', () {
      const reader = PlatformPayloadReader(<String, Object?>{
        'count': '4',
        'enabled': 1,
      });

      expect(
        () => reader.requiredInt('count'),
        throwsA(
          isA<PlatformPayloadException>().having(
            (error) => error.reason,
            'reason',
            PlatformPayloadFailureReason.wrongType,
          ),
        ),
      );
      expect(
        () => reader.requiredBool('enabled'),
        throwsA(isA<PlatformPayloadException>()),
      );
    });

    test('parses timestamps and normalizes them to UTC', () {
      final reader = PlatformPayloadReader(<String, Object?>{
        'created_at': '2026-07-17T12:00:00+01:00',
        'updated_at': DateTime(2026, 7, 17, 13),
      });

      expect(
        reader.requiredDateTime('created_at'),
        DateTime.utc(2026, 7, 17, 11),
      );
      expect(reader.requiredDateTime('updated_at').isUtc, isTrue);
    });

    test('rejects an invalid timestamp without exposing it', () {
      const rawValue = 'private-invalid-timestamp';
      const reader = PlatformPayloadReader(<String, Object?>{
        'created_at': rawValue,
      });

      try {
        reader.requiredDateTime('created_at');
        fail('Expected PlatformPayloadException.');
      } on PlatformPayloadException catch (error) {
        expect(error.field, 'created_at');
        expect(error.reason, PlatformPayloadFailureReason.invalidValue);
        expect(error.toString(), isNot(contains(rawValue)));
      }
    });

    test('exception output never includes a raw payload value', () {
      const rawValue = 'customer@example.test';
      const reader = PlatformPayloadReader(<String, Object?>{
        'customer_email_snapshot': 12,
        'unrelated': rawValue,
      });

      try {
        reader.requiredString('customer_email_snapshot');
        fail('Expected PlatformPayloadException.');
      } on PlatformPayloadException catch (error) {
        final text = error.toString();
        expect(text, contains('customer_email_snapshot'));
        expect(text, contains('wrongType'));
        expect(text, isNot(contains(rawValue)));
        expect(text, isNot(contains('unrelated')));
      }
    });
  });
}
