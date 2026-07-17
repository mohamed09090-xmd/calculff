import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/admin_auth_failure.dart';
import '../domain/admin_auth_models.dart';
import '../domain/admin_auth_repository.dart';

class AdminAuthController extends StateNotifier<AdminAuthState> {
  AdminAuthController({required AdminAuthRepository? repository})
    : _repository = repository,
      super(
        repository == null
            ? const AdminAuthState.unavailable()
            : const AdminAuthState.signedOut(),
      );

  final AdminAuthRepository? _repository;

  AdminAuthListener? _listener;
  bool _started = false;
  bool _restoreInProgress = false;
  bool _signInInProgress = false;
  bool _refreshInProgress = false;
  bool _hasRestored = false;
  bool _isDisposed = false;

  Future<void> start() async {
    if (_started || _isDisposed) {
      return;
    }
    _started = true;

    final repository = _repository;
    if (repository == null) {
      _setState(const AdminAuthState.unavailable());
      return;
    }

    _restoreInProgress = true;
    _ensureAuthListener(repository);
    try {
      await _restoreCurrentSession(repository);
    } finally {
      _restoreInProgress = false;
      _hasRestored = true;
    }
  }

  Future<void> restoreSession() async {
    final repository = _repository;
    if (repository == null) {
      _setState(const AdminAuthState.unavailable());
      return;
    }
    if (_restoreInProgress || _isDisposed) {
      return;
    }

    _ensureAuthListener(repository);
    _restoreInProgress = true;
    try {
      await _restoreCurrentSession(repository);
    } finally {
      _restoreInProgress = false;
      _hasRestored = true;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    final repository = _repository;
    if (repository == null) {
      _setState(const AdminAuthState.unavailable());
      return;
    }
    if (_signInInProgress) {
      _setState(
        const AdminAuthState.failure(AdminAuthFailureCode.operationInProgress),
      );
      return;
    }

    _signInInProgress = true;
    _setState(const AdminAuthState.authenticating());
    try {
      final session = await repository.signIn(
        email: email.trim(),
        password: password,
      );
      if (session.isExpired) {
        await _safeLocalSignOut(repository);
        _setState(const AdminAuthState.sessionExpired());
      } else if (session.isAdmin) {
        _setState(const AdminAuthState.authorized());
      } else {
        await _safeLocalSignOut(repository);
        _setState(const AdminAuthState.unauthorized());
      }
    } on AdminAuthFailure catch (failure) {
      _applyFailure(failure.code);
    } catch (_) {
      _applyFailure(AdminAuthFailureCode.unknown);
    } finally {
      _signInInProgress = false;
    }
  }

  Future<void> refreshSession() async {
    final repository = _repository;
    if (repository == null) {
      _setState(const AdminAuthState.unavailable());
      return;
    }
    _setState(const AdminAuthState.restoring());
    await _refreshAndAuthorize(repository);
  }

  Future<void> signOut() async {
    final repository = _repository;
    if (repository == null) {
      _setState(const AdminAuthState.unavailable());
      return;
    }

    try {
      await repository.signOutLocal();
    } catch (_) {
      // Supabase removes the local session before contacting the server.
    } finally {
      _setState(const AdminAuthState.signedOut());
    }
  }

  Future<void> _restoreCurrentSession(AdminAuthRepository repository) async {
    _setState(const AdminAuthState.restoring());
    try {
      final session = await repository.restoreSession();
      if (session == null) {
        _setState(const AdminAuthState.signedOut());
        return;
      }
      if (session.isExpired || !session.isAdmin) {
        await _refreshAndAuthorize(repository);
        return;
      }
      _setState(const AdminAuthState.authorized());
    } on AdminAuthFailure catch (failure) {
      _applyFailure(failure.code);
    } catch (_) {
      _applyFailure(AdminAuthFailureCode.unknown);
    }
  }

  Future<void> _refreshAndAuthorize(AdminAuthRepository repository) async {
    if (_refreshInProgress || _isDisposed) {
      return;
    }
    _refreshInProgress = true;
    try {
      final session = await repository.refreshSession();
      if (session.isExpired) {
        await _safeLocalSignOut(repository);
        _setState(const AdminAuthState.sessionExpired());
      } else if (session.isAdmin) {
        _setState(const AdminAuthState.authorized());
      } else {
        await _safeLocalSignOut(repository);
        _setState(const AdminAuthState.unauthorized());
      }
    } on AdminAuthFailure catch (failure) {
      if (failure.code == AdminAuthFailureCode.sessionExpired) {
        await _safeLocalSignOut(repository);
      }
      _applyFailure(failure.code);
    } catch (_) {
      _applyFailure(AdminAuthFailureCode.unknown);
    } finally {
      _refreshInProgress = false;
    }
  }

  void _ensureAuthListener(AdminAuthRepository repository) {
    if (_listener != null || _isDisposed) {
      return;
    }
    _listener = repository.listenToAuthChanges(
      onData: (event) {
        unawaited(_handleAuthEvent(repository, event));
      },
      onError: (failure) {
        _applyFailure(failure.code);
      },
    );
  }

  Future<void> _handleAuthEvent(
    AdminAuthRepository repository,
    AdminAuthEvent event,
  ) async {
    if (_isDisposed) {
      return;
    }
    try {
      switch (event.type) {
        case AdminAuthEventType.initialSession:
          if (_restoreInProgress || _hasRestored) {
            return;
          }
          final session = event.session;
          if (session == null) {
            _setState(const AdminAuthState.signedOut());
          } else if (session.isExpired || !session.isAdmin) {
            await _refreshAndAuthorize(repository);
          } else {
            _setState(const AdminAuthState.authorized());
          }
          return;
        case AdminAuthEventType.signedOut:
          _setState(const AdminAuthState.signedOut());
          return;
        case AdminAuthEventType.signedIn:
          if (_signInInProgress) {
            return;
          }
          await _applyEventSession(repository, event.session);
          return;
        case AdminAuthEventType.tokenRefreshed:
          if (_refreshInProgress) {
            return;
          }
          await _applyEventSession(repository, event.session);
          return;
        case AdminAuthEventType.userUpdated:
          await _applyEventSession(repository, event.session);
          return;
        case AdminAuthEventType.other:
          return;
      }
    } on AdminAuthFailure catch (failure) {
      _applyFailure(failure.code);
    } catch (_) {
      _applyFailure(AdminAuthFailureCode.unknown);
    }
  }

  Future<void> _applyEventSession(
    AdminAuthRepository repository,
    AdminAuthSession? session,
  ) async {
    if (session == null) {
      _setState(const AdminAuthState.signedOut());
    } else if (session.isExpired) {
      await _safeLocalSignOut(repository);
      _setState(const AdminAuthState.sessionExpired());
    } else if (session.isAdmin) {
      _setState(const AdminAuthState.authorized());
    } else {
      await _safeLocalSignOut(repository);
      _setState(const AdminAuthState.unauthorized());
    }
  }

  Future<void> _safeLocalSignOut(AdminAuthRepository repository) async {
    try {
      await repository.signOutLocal();
    } catch (_) {
      // The local session is removed before Supabase attempts the remote call.
    }
  }

  void _applyFailure(AdminAuthFailureCode code) {
    switch (code) {
      case AdminAuthFailureCode.networkUnavailable:
        _setState(const AdminAuthState.offline());
        return;
      case AdminAuthFailureCode.sessionExpired:
        _setState(const AdminAuthState.sessionExpired());
        return;
      case AdminAuthFailureCode.unauthorized:
        _setState(const AdminAuthState.unauthorized());
        return;
      case AdminAuthFailureCode.configurationUnavailable:
        _setState(const AdminAuthState.unavailable());
        return;
      case AdminAuthFailureCode.invalidCredentials:
      case AdminAuthFailureCode.operationInProgress:
      case AdminAuthFailureCode.unknown:
        _setState(AdminAuthState.failure(code));
        return;
    }
  }

  void _setState(AdminAuthState nextState) {
    if (!_isDisposed) {
      state = nextState;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    final listener = _listener;
    _listener = null;
    if (listener != null) {
      unawaited(listener.cancel());
    }
    super.dispose();
  }
}
