import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class SupabaseAuthStateListener {
  Future<void> cancel();
}

abstract interface class SupabaseAdminAuthDataSource {
  Session? get currentSession;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  });

  Future<AuthResponse> refreshSession();

  SupabaseAuthStateListener listenToAuthStateChanges({
    required void Function(AuthState state) onData,
    required void Function(Object error, StackTrace stackTrace) onError,
  });

  Future<void> signOut({required SignOutScope scope});
}

class FlutterSupabaseAdminAuthDataSource
    implements SupabaseAdminAuthDataSource {
  const FlutterSupabaseAdminAuthDataSource(this._client);

  final SupabaseClient _client;

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<AuthResponse> refreshSession() {
    return _client.auth.refreshSession();
  }

  @override
  SupabaseAuthStateListener listenToAuthStateChanges({
    required void Function(AuthState state) onData,
    required void Function(Object error, StackTrace stackTrace) onError,
  }) {
    final subscription = _client.auth.onAuthStateChange.listen(
      onData,
      onError: (Object error, StackTrace stackTrace) {
        onError(error, stackTrace);
      },
    );
    return _StreamSupabaseAuthStateListener(subscription);
  }

  @override
  Future<void> signOut({required SignOutScope scope}) {
    return _client.auth.signOut(scope: scope);
  }
}

class _StreamSupabaseAuthStateListener implements SupabaseAuthStateListener {
  const _StreamSupabaseAuthStateListener(this._subscription);

  final StreamSubscription<AuthState> _subscription;

  @override
  Future<void> cancel() => _subscription.cancel();
}
