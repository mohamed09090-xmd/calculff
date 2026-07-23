import '../../domain/admin_auth_failure.dart';
import '../../domain/admin_auth_models.dart';
import '../../domain/common/platform_failure.dart';

typedef PlatformReadOperation<T> = Future<T> Function();
typedef PlatformErrorMapper = PlatformFailure Function(Object error);

abstract interface class PlatformSessionAccess {
  AdminAuthState get currentState;

  Future<void> refresh();
}

class CallbackPlatformSessionAccess implements PlatformSessionAccess {
  const CallbackPlatformSessionAccess({
    required AdminAuthState Function() readState,
    required Future<void> Function() refresh,
  }) : _readState = readState,
       _refresh = refresh;

  final AdminAuthState Function() _readState;
  final Future<void> Function() _refresh;

  @override
  AdminAuthState get currentState => _readState();

  @override
  Future<void> refresh() => _refresh();
}

abstract interface class PlatformDataScopeSink {
  void markAuthorized();

  void invalidate(PlatformFailureCode reason);
}

abstract interface class PlatformReadCoordinator {
  Future<T> runRead<T>(PlatformReadOperation<T> operation);
}

class PlatformSessionCoordinator implements PlatformReadCoordinator {
  PlatformSessionCoordinator({
    required PlatformSessionAccess sessionAccess,
    required PlatformErrorMapper mapError,
    required PlatformDataScopeSink dataScope,
  }) : _sessionAccess = sessionAccess,
       _mapError = mapError,
       _dataScope = dataScope;

  final PlatformSessionAccess _sessionAccess;
  final PlatformErrorMapper _mapError;
  final PlatformDataScopeSink _dataScope;
  Future<void>? _refreshInFlight;

  @override
  Future<T> runRead<T>(PlatformReadOperation<T> operation) async {
    final preflightFailure = _failureForState(_sessionAccess.currentState);
    if (preflightFailure != null) {
      _applySessionBoundary(preflightFailure);
      throw preflightFailure;
    }

    try {
      final result = await operation();
      _dataScope.markAuthorized();
      return result;
    } catch (error) {
      final failure = _mapError(error);
      if (failure.code != PlatformFailureCode.sessionExpired) {
        _applySessionBoundary(failure);
        throw failure;
      }
      _dataScope.invalidate(PlatformFailureCode.sessionExpired);
    }

    try {
      await _refreshSessionOnce();
    } catch (error) {
      final failure = _mapError(error);
      _applySessionBoundary(failure);
      throw failure;
    }

    final refreshedFailure = _failureForState(_sessionAccess.currentState);
    if (refreshedFailure != null) {
      _applySessionBoundary(refreshedFailure);
      throw refreshedFailure;
    }

    try {
      final result = await operation();
      _dataScope.markAuthorized();
      return result;
    } catch (error) {
      final failure = _mapError(error);
      _applySessionBoundary(failure);
      throw failure;
    }
  }

  Future<void> _refreshSessionOnce() {
    final existing = _refreshInFlight;
    if (existing != null) {
      return existing;
    }

    late final Future<void> refresh;
    refresh = Future<void>.sync(_sessionAccess.refresh).whenComplete(() {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    });
    _refreshInFlight = refresh;
    return refresh;
  }

  void _applySessionBoundary(PlatformFailure failure) {
    if (failure.code == PlatformFailureCode.sessionExpired ||
        failure.code == PlatformFailureCode.unauthorized) {
      _dataScope.invalidate(failure.code);
    }
  }
}

PlatformFailure? _failureForState(AdminAuthState state) {
  switch (state.status) {
    case AdminAuthStatus.authorized:
      return null;
    case AdminAuthStatus.signedOut:
    case AdminAuthStatus.sessionExpired:
      return const PlatformFailure(PlatformFailureCode.sessionExpired);
    case AdminAuthStatus.unauthorized:
      return const PlatformFailure(PlatformFailureCode.unauthorized);
    case AdminAuthStatus.offline:
      return const PlatformFailure(PlatformFailureCode.networkUnavailable);
    case AdminAuthStatus.unavailable:
    case AdminAuthStatus.restoring:
    case AdminAuthStatus.authenticating:
      return const PlatformFailure(PlatformFailureCode.temporarilyUnavailable);
    case AdminAuthStatus.failure:
      return _failureForAuthCode(state.failureCode);
  }
}

PlatformFailure _failureForAuthCode(AdminAuthFailureCode? code) {
  switch (code) {
    case AdminAuthFailureCode.networkUnavailable:
      return const PlatformFailure(PlatformFailureCode.networkUnavailable);
    case AdminAuthFailureCode.sessionExpired:
      return const PlatformFailure(PlatformFailureCode.sessionExpired);
    case AdminAuthFailureCode.unauthorized:
      return const PlatformFailure(PlatformFailureCode.unauthorized);
    case AdminAuthFailureCode.configurationUnavailable:
      return const PlatformFailure(PlatformFailureCode.temporarilyUnavailable);
    case AdminAuthFailureCode.invalidCredentials:
    case AdminAuthFailureCode.operationInProgress:
    case AdminAuthFailureCode.unknown:
    case null:
      return const PlatformFailure(PlatformFailureCode.unknown);
  }
}
