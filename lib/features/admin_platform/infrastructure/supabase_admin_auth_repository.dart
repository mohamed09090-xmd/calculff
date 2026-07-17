import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_auth_failure.dart';
import '../domain/admin_auth_models.dart';
import '../domain/admin_auth_repository.dart';
import 'supabase_admin_auth_datasource.dart';
import 'supabase_auth_error_mapper.dart';

class SupabaseAdminAuthRepository implements AdminAuthRepository {
  const SupabaseAdminAuthRepository({
    required SupabaseAdminAuthDataSource dataSource,
    SupabaseAuthErrorMapper errorMapper = const SupabaseAuthErrorMapper(),
  }) : _dataSource = dataSource,
       _errorMapper = errorMapper;

  final SupabaseAdminAuthDataSource _dataSource;
  final SupabaseAuthErrorMapper _errorMapper;

  @override
  Future<AdminAuthSession?> restoreSession() async {
    try {
      return _mapSession(_dataSource.currentSession);
    } catch (error) {
      throw _errorMapper.map(error);
    }
  }

  @override
  Future<AdminAuthSession> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dataSource.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return _requireSession(response.session);
    } catch (error) {
      throw _errorMapper.map(error);
    }
  }

  @override
  Future<AdminAuthSession> refreshSession() async {
    try {
      final response = await _dataSource.refreshSession();
      return _requireSession(response.session);
    } catch (error) {
      throw _errorMapper.map(error);
    }
  }

  @override
  AdminAuthListener listenToAuthChanges({
    required void Function(AdminAuthEvent event) onData,
    required void Function(AdminAuthFailure failure) onError,
  }) {
    final listener = _dataSource.listenToAuthStateChanges(
      onData: (state) {
        try {
          onData(_mapEvent(state));
        } catch (error) {
          onError(_errorMapper.map(error));
        }
      },
      onError: (error, stackTrace) {
        onError(_errorMapper.map(error));
      },
    );
    return _RepositoryAdminAuthListener(listener);
  }

  @override
  Future<void> signOutLocal() async {
    try {
      await _dataSource.signOut(scope: SignOutScope.local);
    } catch (error) {
      throw _errorMapper.map(error);
    }
  }

  AdminAuthSession _requireSession(Session? session) {
    final mappedSession = _mapSession(session);
    if (mappedSession == null) {
      throw const AdminAuthFailure(AdminAuthFailureCode.sessionExpired);
    }
    return mappedSession;
  }

  AdminAuthSession? _mapSession(Session? session) {
    if (session == null) {
      return null;
    }
    return AdminAuthSession(
      isAdmin: session.user.appMetadata['role'] == 'admin',
      isExpired: session.isExpired,
    );
  }

  AdminAuthEvent _mapEvent(AuthState state) {
    final type = switch (state.event) {
      AuthChangeEvent.initialSession => AdminAuthEventType.initialSession,
      AuthChangeEvent.signedIn => AdminAuthEventType.signedIn,
      AuthChangeEvent.signedOut => AdminAuthEventType.signedOut,
      AuthChangeEvent.tokenRefreshed => AdminAuthEventType.tokenRefreshed,
      AuthChangeEvent.userUpdated => AdminAuthEventType.userUpdated,
      _ => AdminAuthEventType.other,
    };
    return AdminAuthEvent(type: type, session: _mapSession(state.session));
  }
}

class _RepositoryAdminAuthListener implements AdminAuthListener {
  const _RepositoryAdminAuthListener(this._listener);

  final SupabaseAuthStateListener _listener;

  @override
  Future<void> cancel() => _listener.cancel();
}
