import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/pattern_lock_service.dart';
import '../models/app_lock_state.dart';

final patternLockServiceProvider = Provider<PatternLockService>(
  (ref) => PatternLockService(),
);

class AppLockController extends AsyncNotifier<AppLockState> {
  PatternLockService get _service => ref.read(patternLockServiceProvider);

  @override
  Future<AppLockState> build() async {
    final enabled = await _service.isEnabled();
    return AppLockState(
      enabled: enabled,
      locked: enabled,
    );
  }

  Future<void> enablePattern(List<int> pattern) async {
    await _service.enable(pattern);
    state = const AsyncData(
      AppLockState(enabled: true, locked: false),
    );
  }

  Future<PatternVerificationResult> verifyAndUnlock(
    List<int> pattern,
  ) async {
    final result = await _service.verify(pattern);
    final current = state.valueOrNull ?? const AppLockState.disabled();
    state = AsyncData(
      current.copyWith(
        locked: result.status != PatternVerificationStatus.success,
        failedAttempts: result.failedAttempts,
        lockedUntil: result.lockedUntil,
        clearLockedUntil:
            result.status == PatternVerificationStatus.success,
      ),
    );
    return result;
  }

  Future<PatternVerificationResult> disablePattern(
    List<int> currentPattern,
  ) async {
    final result = await _service.disable(currentPattern);
    if (result.status == PatternVerificationStatus.success) {
      state = const AsyncData(AppLockState.disabled());
      return result;
    }
    final current = state.valueOrNull ?? const AppLockState.disabled();
    state = AsyncData(
      current.copyWith(
        failedAttempts: result.failedAttempts,
        lockedUntil: result.lockedUntil,
      ),
    );
    return result;
  }

  Future<PatternVerificationResult> changePattern({
    required List<int> currentPattern,
    required List<int> newPattern,
  }) async {
    final result = await _service.change(
      currentPattern: currentPattern,
      newPattern: newPattern,
    );
    if (result.status == PatternVerificationStatus.success) {
      state = const AsyncData(
        AppLockState(enabled: true, locked: false),
      );
      return result;
    }
    final current = state.valueOrNull ?? const AppLockState.disabled();
    state = AsyncData(
      current.copyWith(
        failedAttempts: result.failedAttempts,
        lockedUntil: result.lockedUntil,
      ),
    );
    return result;
  }

  void lock() {
    final current = state.valueOrNull;
    if (current == null || !current.enabled || current.locked) return;
    state = AsyncData(current.copyWith(locked: true));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final appLockProvider =
    AsyncNotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);
