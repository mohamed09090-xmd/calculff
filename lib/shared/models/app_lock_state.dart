class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.locked,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  const AppLockState.disabled()
      : enabled = false,
        locked = false,
        failedAttempts = 0,
        lockedUntil = null;

  final bool enabled;
  final bool locked;
  final int failedAttempts;
  final DateTime? lockedUntil;

  AppLockState copyWith({
    bool? enabled,
    bool? locked,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
  }) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      locked: locked ?? this.locked,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: clearLockedUntil ? null : lockedUntil ?? this.lockedUntil,
    );
  }
}
