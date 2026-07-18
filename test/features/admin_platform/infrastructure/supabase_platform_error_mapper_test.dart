import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/platform_payload_reader.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/supabase_platform_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const mapper = SupabasePlatformErrorMapper();

  group('SupabasePlatformErrorMapper', () {
    test('maps socket, timeout, and TLS failures to networkUnavailable', () {
      final failures = <Object>[
        const SocketException('private socket message'),
        TimeoutException('private timeout message'),
        HandshakeException('private handshake message'),
      ];

      for (final error in failures) {
        expect(mapper.map(error).code, PlatformFailureCode.networkUnavailable);
      }
    });

    test('maps auth session failures to sessionExpired', () {
      final failure = mapper.map(
        const AuthException(
          'private auth message',
          code: 'session_expired',
          statusCode: '401',
        ),
      );

      expect(failure.code, PlatformFailureCode.sessionExpired);
    });

    test('maps unauthorized auth and RLS failures', () {
      final authFailure = mapper.map(
        const AuthException(
          'private auth message',
          code: 'not_admin',
          statusCode: '403',
        ),
      );
      final rlsFailure = mapper.map(
        const PostgrestException(
          message: 'private database message',
          code: '42501',
        ),
      );

      expect(authFailure.code, PlatformFailureCode.unauthorized);
      expect(rlsFailure.code, PlatformFailureCode.unauthorized);
    });

    test('maps duplicate and dependency SQLSTATE codes', () {
      final duplicate = mapper.map(
        const PostgrestException(message: 'private', code: '23505'),
      );
      final dependency = mapper.map(
        const PostgrestException(message: 'private', code: '23503'),
      );

      expect(duplicate.code, PlatformFailureCode.duplicateSlug);
      expect(dependency.code, PlatformFailureCode.dependencyExists);
    });

    test('maps missing rows and temporary service failures', () {
      final notFound = mapper.map(
        const PostgrestException(message: 'private', code: 'PGRST116'),
      );
      final temporary = mapper.map(
        const PostgrestException(message: 'private', code: 'PGRST002'),
      );

      expect(notFound.code, PlatformFailureCode.notFound);
      expect(temporary.code, PlatformFailureCode.temporarilyUnavailable);
    });

    test('maps malformed payloads without retaining the payload error', () {
      final failure = mapper.map(
        const PlatformPayloadException(
          field: 'customer_email_snapshot',
          reason: PlatformPayloadFailureReason.wrongType,
        ),
      );

      expect(failure.code, PlatformFailureCode.malformedResponse);
      expect(failure.toString(), isNot(contains('customer_email_snapshot')));
    });

    test('maps unknown exceptions to a stable unknown failure', () {
      final failure = mapper.map(StateError('private unknown message'));

      expect(failure.code, PlatformFailureCode.unknown);
    });

    test('never exposes raw messages, tokens, UUIDs, email, or phone', () {
      const sensitiveText =
          'eyJprivate.token.value '
          '11111111-1111-1111-1111-111111111111 '
          'customer@example.test 0550000000';
      final failures = <PlatformFailure>[
        mapper.map(const SocketException(sensitiveText)),
        mapper.map(
          const AuthException(
            sensitiveText,
            code: 'session_expired',
            statusCode: '401',
          ),
        ),
        mapper.map(
          const PostgrestException(
            message: sensitiveText,
            code: '42501',
            details: sensitiveText,
            hint: sensitiveText,
          ),
        ),
      ];

      for (final failure in failures) {
        final text = failure.toString();
        expect(text, isNot(contains('eyJprivate')));
        expect(text, isNot(contains('11111111-1111')));
        expect(text, isNot(contains('customer@example.test')));
        expect(text, isNot(contains('0550000000')));
      }
    });
  });
}
