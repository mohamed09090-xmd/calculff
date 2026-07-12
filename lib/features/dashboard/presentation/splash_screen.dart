import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/localized_text.dart';

import '../../../core/constants/app_strings.dart';
import '../../../shared/providers/app_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _background = Color(0xFF21453B);
  static const _gold = Color(0xFFE0A02B);
  static const _cream = Color(0xFFFFF8E7);

  late final AnimationController _controller;
  bool _motionConfigured = false;
  bool _animationComplete = false;
  bool _navigationQueued = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionConfigured) return;
    _motionConfigured = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _animationComplete = true;
      return;
    }

    _controller.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _animationComplete = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _queueDashboardNavigation() {
    if (_navigationQueued) return;
    _navigationQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/dashboard');
    });
  }

  @override
  Widget build(BuildContext context) {
    final initialization = ref.watch(initializationProvider);
    final initialized = initialization.when(
      data: (_) => true,
      loading: () => false,
      error: (_, __) => false,
    );

    if (_animationComplete && initialized) {
      _queueDashboardNavigation();
    }

    const overlays = SystemUiOverlayStyle(
      statusBarColor: _background,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: _background,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: _background,
      systemNavigationBarContrastEnforced: false,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlays,
      child: Scaffold(
        backgroundColor: _background,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = _controller.value;
            final titleProgress = _interval(progress, 0.55, 0.82);
            final subtitleProgress = _interval(progress, 0.66, 0.9);
            final loaderProgress = _interval(progress, 0.72, 1);

            return Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _SplashBackdropPainter(progress: progress),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const Spacer(flex: 4),
                        RepaintBoundary(
                          child: SizedBox.square(
                            dimension: 210,
                            child: CustomPaint(
                              painter: _BrandMarkPainter(progress: progress),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        _Reveal(
                          progress: titleProgress,
                          offset: const Offset(0, 18),
                          child: const Text(
                            AppStrings.appName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _cream,
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Reveal(
                          progress: subtitleProgress,
                          offset: const Offset(0, 14),
                          child: const Text(
                            'حساب • مخزون • ربح',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _gold,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const Spacer(flex: 3),
                        initialization.when(
                          data: (_) => _LoadingFooter(
                            progress: loaderProgress,
                            label: _animationComplete
                                ? 'جاهز'
                                : 'جاري تجهيز تجربتك...',
                          ),
                          loading: () => _LoadingFooter(
                            progress: loaderProgress,
                            label: 'جاري تهيئة البيانات...',
                          ),
                          error: (error, stack) => _SplashError(
                            error: error,
                            onRetry: () =>
                                ref.invalidate(initializationProvider),
                          ),
                        ),
                        const SizedBox(height: 42),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.progress,
    required this.offset,
    required this.child,
  });

  final double progress;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(progress);
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(offset.dx * (1 - eased), offset.dy * (1 - eased)),
        child: child,
      ),
    );
  }
}

class _LoadingFooter extends StatelessWidget {
  const _LoadingFooter({required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(progress);
    return Opacity(
      opacity: eased,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 112,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: const Color(0x33FFF8E7)),
                  Align(
                    alignment: Alignment.centerRight,
                    widthFactor: 0.25 + (0.75 * eased),
                    child: Container(color: const Color(0xFFE0A02B)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xCCFFF8E7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashError extends StatelessWidget {
  const _SplashError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x18FFF8E7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x40FFF8E7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'تعذر تهيئة قاعدة البيانات',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _SplashScreenState._cream,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error.toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xB3FFF8E7), fontSize: 12),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _SplashBackdropPainter extends CustomPainter {
  const _SplashBackdropPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.43);
    final reveal = Curves.easeOutCubic.transform(_interval(progress, 0.18, 0.9));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var index = 0; index < 4; index++) {
      final radius = (115 + (index * 42)) * (0.9 + (0.1 * reveal));
      paint.color = const Color(0xFFE0A02B).withAlpha(
        ((18 - (index * 3)) * reveal).round(),
      );
      canvas.drawCircle(center, radius, paint);
    }

    final topPaint = Paint()..color = const Color(0x0DFFF8E7);
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.12),
      74 * reveal,
      topPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.82),
      110 * reveal,
      topPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final leftProgress = Curves.easeOutBack.transform(
      _interval(progress, 0.05, 0.36),
    );
    final rightProgress = Curves.easeOutBack.transform(
      _interval(progress, 0.18, 0.52),
    );
    final lineProgress = Curves.easeOutCubic.transform(
      _interval(progress, 0.42, 0.7),
    );
    final ringProgress = Curves.easeOutCubic.transform(
      _interval(progress, 0.5, 0.86),
    );
    final pulseProgress = _interval(progress, 0.76, 1);
    final pulse = 1 + (0.026 * math.sin(pulseProgress * math.pi));

    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(pulse)
      ..translate(-center.dx, -center.dy);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var index = 0; index < 3; index++) {
      glowPaint.color = const Color(0xFFE0A02B).withAlpha(
        ((54 - (index * 13)) * ringProgress).round(),
      );
      canvas.drawCircle(
        center,
        (69 + (index * 13)) * ringProgress,
        glowPaint,
      );
    }

    final baseY = size.height * 0.61;
    final goldPaint = Paint()..color = const Color(0xFFE0A02B);

    final leftPath = Path()
      ..moveTo(size.width * 0.16, baseY)
      ..lineTo(
        size.width * 0.34,
        _lerp(baseY, size.height * 0.36, leftProgress),
      )
      ..lineTo(
        size.width * 0.49,
        _lerp(baseY, size.height * 0.49, leftProgress),
      )
      ..lineTo(size.width * 0.58, baseY)
      ..close();
    canvas.drawPath(leftPath, goldPaint);

    final rightPath = Path()
      ..moveTo(size.width * 0.4, baseY)
      ..lineTo(
        size.width * 0.67,
        _lerp(baseY, size.height * 0.2, rightProgress),
      )
      ..lineTo(size.width * 0.84, baseY)
      ..close();
    canvas.drawPath(rightPath, goldPaint);

    final creamPaint = Paint()
      ..color = const Color(0xFFFFF8E7)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7;
    final halfWidth = size.width * 0.31 * lineProgress;
    canvas.drawLine(
      Offset(center.dx - halfWidth, size.height * 0.7),
      Offset(center.dx + halfWidth, size.height * 0.7),
      creamPaint,
    );
    canvas.drawLine(
      Offset(center.dx - halfWidth, size.height * 0.8),
      Offset(center.dx + halfWidth, size.height * 0.8),
      creamPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

double _interval(double value, double begin, double end) {
  if (value <= begin) return 0;
  if (value >= end) return 1;
  return (value - begin) / (end - begin);
}

double _lerp(double begin, double end, double progress) =>
    begin + ((end - begin) * progress);
