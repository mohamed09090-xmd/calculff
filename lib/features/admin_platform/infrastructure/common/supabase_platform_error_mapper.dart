import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/common/platform_failure.dart';
import 'platform_payload_reader.dart';

class SupabasePlatformErrorMapper {
  const SupabasePlatformErrorMapper();

  PlatformFailure map(Object error) {
    if (error is PlatformFailure) {
      return error;
    }
    if (error is PlatformPayloadException) {
      return const PlatformFailure(PlatformFailureCode.malformedResponse);
    }
    if (_isNetworkFailure(error)) {
      return const PlatformFailure(PlatformFailureCode.networkUnavailable);
    }
    if (error is AuthUnknownException &&
        _isNetworkFailure(error.originalError)) {
      return const PlatformFailure(PlatformFailureCode.networkUnavailable);
    }
    if (error is AuthSessionMissingException) {
      return const PlatformFailure(PlatformFailureCode.sessionExpired);
    }
    if (error is AuthException) {
      return _mapAuthException(error);
    }
    if (error is PostgrestException) {
      return _mapPostgrestException(error);
    }
    if (error is HttpException) {
      return const PlatformFailure(PlatformFailureCode.temporarilyUnavailable);
    }
    return const PlatformFailure(PlatformFailureCode.unknown);
  }

  bool _isNetworkFailure(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is HandshakeException ||
        error is AuthRetryableFetchException;
  }

  PlatformFailure _mapAuthException(AuthException error) {
    final code = error.code?.toLowerCase();
    final statusCode = error.statusCode;

    const expiredSessionCodes = <String>{
      'bad_jwt',
      'invalid_jwt',
      'session_expired',
      'session_missing',
      'session_not_found',
      'refresh_token_not_found',
      'refresh_token_already_used',
    };
    if (expiredSessionCodes.contains(code) || statusCode == '401') {
      return const PlatformFailure(PlatformFailureCode.sessionExpired);
    }

    const unauthorizedCodes = <String>{
      'not_admin',
      'no_authorization',
      'user_banned',
    };
    if (unauthorizedCodes.contains(code) || statusCode == '403') {
      return const PlatformFailure(PlatformFailureCode.unauthorized);
    }

    const temporaryStatusCodes = <String>{'408', '429', '500', '502', '503', '504'};
    if (temporaryStatusCodes.contains(statusCode)) {
      return const PlatformFailure(PlatformFailureCode.temporarilyUnavailable);
    }

    return const PlatformFailure(PlatformFailureCode.unknown);
  }

  PlatformFailure _mapPostgrestException(PostgrestException error) {
    final code = error.code?.toUpperCase();
    switch (code) {
      case '23505':
        return const PlatformFailure(PlatformFailureCode.duplicateSlug);
      case '23503':
        return const PlatformFailure(PlatformFailureCode.dependencyExists);
      case '42501':
      case 'PGRST302':
        return const PlatformFailure(PlatformFailureCode.unauthorized);
      case 'PGRST301':
        return const PlatformFailure(PlatformFailureCode.sessionExpired);
      case 'PGRST116':
        return const PlatformFailure(PlatformFailureCode.notFound);
      case 'PGRST000':
      case 'PGRST001':
      case 'PGRST002':
      case 'PGRST003':
      case '53300':
      case '53400':
      case '57P01':
      case '57P02':
      case '57P03':
        return const PlatformFailure(PlatformFailureCode.temporarilyUnavailable);
      default:
        if (code != null && code.startsWith('08')) {
          return const PlatformFailure(
            PlatformFailureCode.temporarilyUnavailable,
          );
        }
        return const PlatformFailure(PlatformFailureCode.unknown);
    }
  }
}
