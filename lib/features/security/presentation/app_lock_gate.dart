import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../core/localization/localized_text.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/security/pattern_lock_service.dart';
import '../../../shared/models/app_lock_state.dart';
import '../../../shared/providers/app_lock_provider.dart';
import 'pattern_lock_pad.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _backgroundedAt ??= DateTime.now();
        return;
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (backgroundedAt != null) {
          ref.read(appLockProvider.notifier).lock();
        }
        return;
      case AppLifecycleState.inactive:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    return lock.when(
      loading: () => const _LockLoadingScreen(),
      error: (error, stack) => _LockErrorScreen(
        error: error,
        onRetry: () => ref.read(appLockProvider.notifier).refresh(),
      ),
      data: (state) {
        if (state.enabled && state.locked) {
          return _PatternUnlockScreen(state: state);
        }
        return widget.child;
      },
    );
  }
}

class _PatternUnlockScreen extends ConsumerStatefulWidget {
  const _PatternUnlockScreen({required this.state});

  final AppLockState state;

  @override
  ConsumerState<_PatternUnlockScreen> createState() =>
      _PatternUnlockScreenState();
}

class _PatternUnlockScreenState extends ConsumerState<_PatternUnlockScreen> {
  final _padController = PatternLockPadController();
  PatternPadStatus _status = PatternPadStatus.idle;
  bool _verifying = false;
  String _message = 'ارسم نمط القفل لفتح التطبيق';
  DateTime? _lockedUntil;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _lockedUntil = widget.state.lockedUntil;
    if (_isLockedOut) _startTimer();
  }

  @override
  void didUpdateWidget(covariant _PatternUnlockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.lockedUntil != widget.state.lockedUntil) {
      _lockedUntil = widget.state.lockedUntil;
      if (_isLockedOut) _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _padController.dispose();
    super.dispose();
  }

  bool get _isLockedOut =>
      _lockedUntil != null && _lockedUntil!.isAfter(DateTime.now());

  int get _remainingSeconds {
    final until = _lockedUntil;
    if (until == null) return 0;
    final milliseconds = until.difference(DateTime.now()).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF21453B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0A02B),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 42,
                  color: Color(0xFF21453B),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                AppStrings.appName,
                style: TextStyle(
                  color: Color(0xFFFFF8E7),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  _isLockedOut
                      ? 'انتظر $_remainingSeconds ثانية قبل المحاولة'
                      : _message,
                  key: ValueKey('$_message-$_remainingSeconds'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _status == PatternPadStatus.error
                        ? scheme.errorContainer
                        : const Color(0xCCFFF8E7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFFE0A02B),
                    brightness: Brightness.dark,
                    surface: const Color(0xFF21453B),
                  ),
                ),
                child: PatternLockPad(
                  controller: _padController,
                  status: _status,
                  enabled: !_verifying && !_isLockedOut,
                  size: 300,
                  onCompleted: _verify,
                ),
              ),
              const Spacer(),
              if (_verifying)
                const SizedBox(
                  width: 150,
                  child: LinearProgressIndicator(),
                )
              else
                const Text(
                  'النمط محفوظ بشكل مشفر على هذا الجهاز ولا يدخل ضمن النسخ الاحتياطية.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0x99FFF8E7),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verify(List<int> pattern) async {
    if (_verifying || _isLockedOut) return;
    setState(() => _verifying = true);
    try {
      final result = await ref
          .read(appLockProvider.notifier)
          .verifyAndUnlock(pattern);
      if (!mounted) return;
      switch (result.status) {
        case PatternVerificationStatus.success:
          setState(() {
            _status = PatternPadStatus.success;
            _message = 'تم فتح التطبيق';
          });
          return;
        case PatternVerificationStatus.invalid:
          final remaining =
              PatternLockService.maxAttempts - result.failedAttempts;
          setState(() {
            _status = PatternPadStatus.error;
            _message = 'النمط غير صحيح. بقيت $remaining محاولات.';
          });
          _clearPadSoon();
          return;
        case PatternVerificationStatus.lockedOut:
          setState(() {
            _lockedUntil = result.lockedUntil;
            _status = PatternPadStatus.error;
          });
          _padController.clear();
          _startTimer();
          return;
        case PatternVerificationStatus.notEnabled:
          await ref.read(appLockProvider.notifier).refresh();
          return;
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = PatternPadStatus.error;
          _message = 'تعذر التحقق من النمط';
        });
        _clearPadSoon();
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _clearPadSoon() {
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _padController.clear();
      if (!_isLockedOut) setState(() => _status = PatternPadStatus.idle);
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 0) {
        timer.cancel();
        setState(() {
          _lockedUntil = null;
          _status = PatternPadStatus.idle;
          _message = 'يمكنك المحاولة مجددًا';
        });
      } else {
        setState(() {});
      }
    });
  }
}

class _LockLoadingScreen extends StatelessWidget {
  const _LockLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF21453B),
      child: Center(
        child: CircularProgressIndicator(color: Color(0xFFE0A02B)),
      ),
    );
  }
}

class _LockErrorScreen extends StatelessWidget {
  const _LockErrorScreen({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF21453B),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_reset_outlined,
                size: 56,
                color: Color(0xFFE0A02B),
              ),
              const SizedBox(height: 16),
              const Text(
                'تعذر قراءة إعدادات قفل التطبيق',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFFF8E7),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xB3FFF8E7)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
