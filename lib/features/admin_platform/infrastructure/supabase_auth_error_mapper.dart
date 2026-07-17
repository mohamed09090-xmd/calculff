import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_auth_failure.dart';

class SupabaseAuthErrorMapper {
  const SupabaseAuthErrorMapper();

  AdminAuthFailure map(Object error) {
    if (error is AdminAuthFailure) {
      return error;
    }
    if (error is AuthRetryableFetchException ||
        error is SocketException ||
        error is TimeoutException) {
      return const AdminAuthFailure(
        AdminAuthFailureCode.networkUnavailable,
      );
    }
    if (error is AuthSessionMissingException) {
      return const AdminAuthFailure(AdminAuthFailureCode.sessionExpired);
    }
    if (error is AuthUnknownException) {
      final originalError = error.originalError;
      if (originalError is SocketException ||
          originalError is TimeoutException) {
        return const AdminAuthFailure(
          AdminAuthFailureCode.networkUnavailable,
        );
      }
    }
    if (error is AuthException) {
      final code = error.code?.toLowerCase();
      final message = error.message.toLowerCase();

      if (code == 'invalid_credentials' ||
          message.contains('invalid login credentials')) {
        return const AdminAuthFailure(
          AdminAuthFailureCode.invalidCredentials,
        );
      }

      const expiredSessionCodes = {
        'bad_jwt',
        'invalid_jwt',
        'session_expired',
        'session_missing',
        'session_not_found',
        'refresh_token_not_found',
        'refresh_token_already_used',
      };
      if (expiredSessionCodes.contains(code) ||
          message.contains('invalid refresh token') ||
          message.contains('refresh token not found') ||
          message.contains('refresh token already used')) {
        return const AdminAuthFailure(
          AdminAuthFailureCode.sessionExpired,
        );
      }
    }

    return const AdminAuthFailure(AdminAuthFailureCode.unknown);
  }
}
