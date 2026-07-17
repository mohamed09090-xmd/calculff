import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_models.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/supabase_admin_auth_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/supabase_auth_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_auth_test_fakes.dart';

void main() {
  group('Supabase admin auth infrastructure', () {
    test('repository checks app_metadata.role only', () async {
      final dataSource = FakeSupabaseAdminAuthDataSource(
        currentSession: makeSupabaseSession(
          appRole: 'member',
          userMetadataRole: 'admin',
        ),
      );
      final repository = SupabaseAdminAuthRepository(dataSource: dataSource);

      final session = await repository.restoreSession();

      expect(session?.isAdmin, isFalse);
    });

    test('repository signs out with SignOutScope.local', () async {
      final dataSource = FakeSupabaseAdminAuthDataSource();
      final repository = SupabaseAdminAuthRepository(dataSource: dataSource);

      await repository.signOutLocal();

      expect(dataSource.lastSignOutScope, SignOutScope.local);
    });

    test('maps invalid credentials without exposing raw errors', () {
      const mapper = SupabaseAuthErrorMapper();

      final failure = mapper.map(
        const AuthApiException(
          'test authentication failure',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      );

      expect(failure.code, AdminAuthFailureCode.invalidCredentials);
    });

    test('maps retryable fetch errors to networkUnavailable', () {
      const mapper = SupabaseAuthErrorMapper();

      final failure = mapper.map(AuthRetryableFetchException());

      expect(failure.code, AdminAuthFailureCode.networkUnavailable);
    });

    test('maps missing sessions to sessionExpired', () {
      const mapper = SupabaseAuthErrorMapper();

      final failure = mapper.map(AuthSessionMissingException());

      expect(failure.code, AdminAuthFailureCode.sessionExpired);
    });
  });

  group('Authentication architecture guards', () {
    test('state does not serialize credentials or tokens', () {
      const state = AdminAuthState.failure(
        AdminAuthFailureCode.invalidCredentials,
      );
      final text = state.toString().toLowerCase();

      expect(text, isNot(contains('test-password')));
      expect(text, isNot(contains('test-access-token')));
      expect(text, isNot(contains('test-refresh-token')));
      expect(text, isNot(contains('admin@example.test')));
    });

    test('admin auth layers do not import SQLite repositories', () {
      final files = Directory('lib/features/admin_platform')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in files) {
        final content = file.readAsStringSync().toLowerCase();
        expect(content, isNot(contains('package:sqflite')));
        expect(content, isNot(contains('apprepository')));
        expect(content, isNot(contains('databasehelper')));
      }
    });
  });
}
