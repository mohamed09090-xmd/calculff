import 'dart:async';

import 'package:game_credit_profit_manager/features/admin_platform/application/admin_auth_controller.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_models.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/supabase_admin_auth_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const adminSession = AdminAuthSession(isAdmin: true, isExpired: false);
const expiredAdminSession = AdminAuthSession(isAdmin: true, isExpired: true);
const nonAdminSession = AdminAuthSession(isAdmin: false, isExpired: false);

Future<AdminAuthController> startController(
  FakeAdminAuthRepository repository,
) async {
  final controller = AdminAuthController(repository: repository);
  await controller.start();
  return controller;
}

class FakeAdminAuthRepository implements AdminAuthRepository {
  FakeAdminAuthRepository({
    this.restoredSession,
    this.refreshedSession = adminSession,
    this.signInSession = adminSession,
    this.restoreFailure,
    this.refreshFailure,
    this.signInFailure,
    this.signInCompleter,
  });

  AdminAuthSession? restoredSession;
  AdminAuthSession refreshedSession;
  AdminAuthSession signInSession;
  AdminAuthFailure? restoreFailure;
  AdminAuthFailure? refreshFailure;
  AdminAuthFailure? signInFailure;
  Completer<AdminAuthSession>? signInCompleter;

  int restoreCalls = 0;
  int refreshCalls = 0;
  int signInCalls = 0;
  int signOutCalls = 0;
  int listenCalls = 0;
  int cancelCalls = 0;
  String? lastEmail;
  String? lastPassword;

  void Function(AdminAuthEvent event)? _onData;
  void Function(AdminAuthFailure failure)? _onError;

  @override
  Future<AdminAuthSession?> restoreSession() async {
    restoreCalls += 1;
    final failure = restoreFailure;
    if (failure != null) {
      throw failure;
    }
    return restoredSession;
  }

  @override
  Future<AdminAuthSession> refreshSession() async {
    refreshCalls += 1;
    final failure = refreshFailure;
    if (failure != null) {
      throw failure;
    }
    return refreshedSession;
  }

  @override
  Future<AdminAuthSession> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls += 1;
    lastEmail = email;
    lastPassword = password;
    final failure = signInFailure;
    if (failure != null) {
      throw failure;
    }
    final completer = signInCompleter;
    if (completer != null) {
      return completer.future;
    }
    return signInSession;
  }

  @override
  AdminAuthListener listenToAuthChanges({
    required void Function(AdminAuthEvent event) onData,
    required void Function(AdminAuthFailure failure) onError,
  }) {
    listenCalls += 1;
    _onData = onData;
    _onError = onError;
    return FakeAdminAuthListener(() async {
      cancelCalls += 1;
    });
  }

  @override
  Future<void> signOutLocal() async {
    signOutCalls += 1;
  }

  void emit(AdminAuthEvent event) => _onData?.call(event);

  void emitError(AdminAuthFailure failure) => _onError?.call(failure);
}

class FakeAdminAuthListener implements AdminAuthListener {
  const FakeAdminAuthListener(this._onCancel);

  final Future<void> Function() _onCancel;

  @override
  Future<void> cancel() => _onCancel();
}

class FakeSupabaseAdminAuthDataSource
    implements SupabaseAdminAuthDataSource {
  FakeSupabaseAdminAuthDataSource({this.currentSession});

  @override
  Session? currentSession;

  SignOutScope? lastSignOutScope;

  @override
  SupabaseAuthStateListener listenToAuthStateChanges({
    required void Function(AuthState state) onData,
    required void Function(Object error, StackTrace stackTrace) onError,
  }) {
    return const FakeSupabaseAuthStateListener();
  }

  @override
  Future<AuthResponse> refreshSession() async {
    return AuthResponse(session: currentSession);
  }

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return AuthResponse(session: currentSession);
  }

  @override
  Future<void> signOut({required SignOutScope scope}) async {
    lastSignOutScope = scope;
  }
}

class FakeSupabaseAuthStateListener implements SupabaseAuthStateListener {
  const FakeSupabaseAuthStateListener();

  @override
  Future<void> cancel() async {}
}

Session makeSupabaseSession({
  required String appRole,
  String? userMetadataRole,
  bool expired = false,
}) {
  final session = Session(
    accessToken: 'test-access-token',
    refreshToken: 'test-refresh-token',
    tokenType: 'bearer',
    user: User(
      id: 'test-user-id',
      appMetadata: {'role': appRole},
      userMetadata: {'role': userMetadataRole},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ),
  );
  session.expiresAt = DateTime.now()
          .add(expired ? const Duration(minutes: -1) : const Duration(hours: 1))
          .millisecondsSinceEpoch ~/
      1000;
  return session;
}
