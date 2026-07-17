import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/admin_auth_models.dart';
import '../../domain/common/platform_failure.dart';
import 'platform_session_coordinator.dart';

class PlatformDataScopeState {
  const PlatformDataScopeState({
    required this.generation,
    required this.isAuthorized,
    this.invalidationReason,
  });

  final int generation;
  final bool isAuthorized;
  final PlatformFailureCode? invalidationReason;

  @override
  String toString() {
    return 'PlatformDataScopeState(generation: $generation, '
        'isAuthorized: $isAuthorized, '
        'invalidationReason: ${invalidationReason?.name})';
  }
}

class PlatformDataScopeController extends StateNotifier<PlatformDataScopeState>
    implements PlatformDataScopeSink {
  PlatformDataScopeController(AdminAuthState initialState)
    : _lastStatus = initialState.status,
      super(_initialScope(initialState));

  AdminAuthStatus _lastStatus;

  void syncAuthState(AdminAuthState nextState) {
    final previousStatus = _lastStatus;
    _lastStatus = nextState.status;

    if (nextState.status == AdminAuthStatus.authorized) {
      markAuthorized();
      return;
    }

    final reason = _invalidationReasonFor(nextState);
    if (reason == null) {
      return;
    }

    if (state.isAuthorized || previousStatus == AdminAuthStatus.authorized) {
      invalidate(reason);
      return;
    }

    if (state.invalidationReason != reason) {
      state = PlatformDataScopeState(
        generation: state.generation,
        isAuthorized: false,
        invalidationReason: reason,
      );
    }
  }

  @override
  void markAuthorized() {
    if (state.isAuthorized && state.invalidationReason == null) {
      return;
    }
    state = PlatformDataScopeState(
      generation: state.generation,
      isAuthorized: true,
    );
  }

  @override
  void invalidate(PlatformFailureCode reason) {
    state = PlatformDataScopeState(
      generation: state.generation + 1,
      isAuthorized: false,
      invalidationReason: reason,
    );
  }
}

PlatformDataScopeState _initialScope(AdminAuthState state) {
  final reason = _invalidationReasonFor(state);
  return PlatformDataScopeState(
    generation: 0,
    isAuthorized: state.status == AdminAuthStatus.authorized,
    invalidationReason: reason,
  );
}

PlatformFailureCode? _invalidationReasonFor(AdminAuthState state) {
  switch (state.status) {
    case AdminAuthStatus.signedOut:
    case AdminAuthStatus.sessionExpired:
      return PlatformFailureCode.sessionExpired;
    case AdminAuthStatus.unauthorized:
      return PlatformFailureCode.unauthorized;
    case AdminAuthStatus.unavailable:
    case AdminAuthStatus.restoring:
    case AdminAuthStatus.authenticating:
    case AdminAuthStatus.authorized:
    case AdminAuthStatus.offline:
    case AdminAuthStatus.failure:
      return null;
  }
}
