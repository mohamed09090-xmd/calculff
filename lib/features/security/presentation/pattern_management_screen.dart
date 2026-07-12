import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/security/pattern_lock_service.dart';
import '../../../shared/providers/app_lock_provider.dart';
import 'pattern_lock_pad.dart';

enum PatternManagementMode { enable, change, disable }

enum _PatternStep { verifyCurrent, create, confirm }

class PatternManagementScreen extends ConsumerStatefulWidget {
  const PatternManagementScreen({super.key, required this.mode});

  final PatternManagementMode mode;

  @override
  ConsumerState<PatternManagementScreen> createState() =>
      _PatternManagementScreenState();
}

class _PatternManagementScreenState
    extends ConsumerState<PatternManagementScreen> {
  final _padController = PatternLockPadController();
  late _PatternStep _step;
  List<int>? _currentPattern;
  List<int>? _newPattern;
  PatternPadStatus _status = PatternPadStatus.idle;
  String? _message;
  bool _busy = false;
  DateTime? _lockedUntil;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _step = switch (widget.mode) {
      PatternManagementMode.enable => _PatternStep.create,
      PatternManagementMode.change => _PatternStep.verifyCurrent,
      PatternManagementMode.disable => _PatternStep.verifyCurrent,
    };
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_screenTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: Column(
                  key: ValueKey(_step),
                  children: [
                    Icon(
                      _stepIcon,
                      size: 44,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _stepTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _stepDescription,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              PatternLockPad(
                controller: _padController,
                status: _status,
                enabled: !_busy && !_isLockedOut,
                onCompleted: _handlePattern,
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isLockedOut
                    ? Container(
                        key: const ValueKey('locked'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'محاولات كثيرة. انتظر $_remainingSeconds ثانية.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _message == null
                    ? Text(
                        'يجب المرور على 4 نقاط مختلفة على الأقل.',
                        key: const ValueKey('hint'),
                        style: theme.textTheme.bodySmall,
                      )
                    : Text(
                        _message!,
                        key: ValueKey(_message),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _status == PatternPadStatus.error
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  String get _screenTitle => switch (widget.mode) {
    PatternManagementMode.enable => 'تفعيل قفل النمط',
    PatternManagementMode.change => 'تغيير نمط القفل',
    PatternManagementMode.disable => 'إيقاف قفل النمط',
  };

  IconData get _stepIcon => switch (_step) {
    _PatternStep.verifyCurrent => Icons.lock_open_outlined,
    _PatternStep.create => Icons.gesture_outlined,
    _PatternStep.confirm => Icons.verified_outlined,
  };

  String get _stepTitle => switch (_step) {
    _PatternStep.verifyCurrent => 'ارسم النمط الحالي',
    _PatternStep.create => 'أنشئ نمطًا جديدًا',
    _PatternStep.confirm => 'أعد رسم النمط للتأكيد',
  };

  String get _stepDescription => switch (_step) {
    _PatternStep.verifyCurrent =>
      widget.mode == PatternManagementMode.disable
          ? 'يجب التحقق من النمط قبل إيقاف القفل.'
          : 'تحقق من النمط الحالي قبل استبداله.',
    _PatternStep.create =>
      'مرر إصبعك بين النقاط. تجنب الأنماط السهلة والمستقيمة.',
    _PatternStep.confirm => 'ارسم النمط الجديد نفسه مرة أخرى.',
  };

  Future<void> _handlePattern(List<int> pattern) async {
    if (_busy || _isLockedOut) return;
    if (pattern.length < 4) {
      _showPadResult(
        PatternPadStatus.error,
        'النمط قصير. استخدم 4 نقاط على الأقل.',
      );
      return;
    }

    switch (_step) {
      case _PatternStep.verifyCurrent:
        await _verifyCurrent(pattern);
        return;
      case _PatternStep.create:
        _newPattern = List<int>.from(pattern);
        setState(() {
          _step = _PatternStep.confirm;
          _status = PatternPadStatus.success;
          _message = 'تم تسجيل النمط. أعد رسمه للتأكيد.';
        });
        _clearPadSoon();
        return;
      case _PatternStep.confirm:
        await _confirmNew(pattern);
        return;
    }
  }

  Future<void> _verifyCurrent(List<int> pattern) async {
    setState(() => _busy = true);
    try {
      if (widget.mode == PatternManagementMode.disable) {
        final result = await ref
            .read(appLockProvider.notifier)
            .disablePattern(pattern);
        if (!mounted) return;
        if (result.status == PatternVerificationStatus.success) {
          _showPadResult(PatternPadStatus.success, 'تم إيقاف قفل التطبيق.');
          await Future<void>.delayed(const Duration(milliseconds: 420));
          if (mounted) Navigator.pop(context, true);
        } else {
          _handleVerificationFailure(result);
        }
        return;
      }

      final result = await ref.read(patternLockServiceProvider).verify(pattern);
      if (!mounted) return;
      if (result.status == PatternVerificationStatus.success) {
        _currentPattern = List<int>.from(pattern);
        setState(() {
          _step = _PatternStep.create;
          _status = PatternPadStatus.success;
          _message = 'تم التحقق. ارسم النمط الجديد.';
        });
        _clearPadSoon();
      } else {
        _handleVerificationFailure(result);
      }
    } catch (error) {
      if (mounted) {
        _showPadResult(PatternPadStatus.error, 'تعذر التحقق: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmNew(List<int> pattern) async {
    final expected = _newPattern;
    if (expected == null || !_samePattern(expected, pattern)) {
      _showPadResult(
        PatternPadStatus.error,
        'النمطان غير متطابقين. أعد المحاولة.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      if (widget.mode == PatternManagementMode.enable) {
        await ref.read(appLockProvider.notifier).enablePattern(pattern);
      } else {
        final result = await ref
            .read(appLockProvider.notifier)
            .changePattern(
              currentPattern: _currentPattern!,
              newPattern: pattern,
            );
        if (result.status != PatternVerificationStatus.success) {
          if (mounted) _handleVerificationFailure(result);
          return;
        }
      }
      if (!mounted) return;
      _showPadResult(
        PatternPadStatus.success,
        widget.mode == PatternManagementMode.enable
            ? 'تم تفعيل قفل التطبيق.'
            : 'تم تغيير النمط بنجاح.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _showPadResult(PatternPadStatus.error, 'تعذر حفظ النمط: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handleVerificationFailure(PatternVerificationResult result) {
    if (result.status == PatternVerificationStatus.lockedOut) {
      setState(() {
        _lockedUntil = result.lockedUntil;
        _status = PatternPadStatus.error;
        _message = null;
      });
      _startLockoutTimer();
      _padController.clear();
      return;
    }
    final remaining = PatternLockService.maxAttempts - result.failedAttempts;
    _showPadResult(
      PatternPadStatus.error,
      remaining > 0
          ? 'النمط غير صحيح. بقيت $remaining محاولات.'
          : 'النمط غير صحيح.',
    );
  }

  void _startLockoutTimer() {
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
          _message = 'يمكنك المحاولة مجددًا.';
        });
      } else {
        setState(() {});
      }
    });
  }

  void _showPadResult(PatternPadStatus status, String message) {
    setState(() {
      _status = status;
      _message = message;
    });
    _clearPadSoon();
  }

  void _clearPadSoon() {
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _padController.clear();
      if (!_isLockedOut) {
        setState(() => _status = PatternPadStatus.idle);
      }
    });
  }

  bool _samePattern(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
