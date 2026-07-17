import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/admin_auth_providers.dart';
import '../domain/admin_auth_failure.dart';
import '../domain/admin_auth_models.dart';
import 'admin_login_screen.dart';
import 'customer_platform_shell.dart';
import 'platform_ui_text.dart';

class PlatformGate extends ConsumerWidget {
  const PlatformGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(adminAuthControllerProvider);
    final controller = ref.read(adminAuthControllerProvider.notifier);

    return switch (authState.status) {
      AdminAuthStatus.unavailable => _PlatformStatusScreen(
          icon: Icons.cloud_off_outlined,
          title: 'إعداد المنصة غير متوفر.',
          message: 'يمكنك متابعة استخدام التطبيق المحلي دون تسجيل دخول.',
          primaryLabel: 'الرجوع إلى التطبيق',
          onPrimary: () => context.go('/dashboard'),
        ),
      AdminAuthStatus.restoring => const _PlatformLoadingScreen(),
      AdminAuthStatus.signedOut => AdminLoginScreen(
          authenticating: false,
          onSignIn: controller.signIn,
        ),
      AdminAuthStatus.authenticating => AdminLoginScreen(
          authenticating: true,
          onSignIn: controller.signIn,
        ),
      AdminAuthStatus.authorized => CustomerPlatformShell(
          onSignOut: controller.signOut,
        ),
      AdminAuthStatus.unauthorized => _PlatformStatusScreen(
          icon: Icons.gpp_bad_outlined,
          title: 'الحساب غير مخول لإدارة المنصة.',
          message: 'استخدم حساب مدير مخول للوصول إلى منصة الزبائن.',
          primaryLabel: 'العودة إلى تسجيل الدخول',
          onPrimary: controller.signOut,
          secondaryLabel: 'الرجوع إلى التطبيق',
          onSecondary: () => context.go('/dashboard'),
        ),
      AdminAuthStatus.sessionExpired => _PlatformStatusScreen(
          icon: Icons.schedule_outlined,
          title: 'انتهت الجلسة.',
          message: 'سجّل الدخول مجددًا للمتابعة.',
          primaryLabel: 'العودة إلى تسجيل الدخول',
          onPrimary: controller.signOut,
          secondaryLabel: 'الرجوع إلى التطبيق',
          onSecondary: () => context.go('/dashboard'),
        ),
      AdminAuthStatus.offline => _PlatformStatusScreen(
          icon: Icons.wifi_off_outlined,
          title: 'لا يوجد اتصال بالمنصة.',
          message: 'تحقق من الاتصال ثم أعد المحاولة.',
          primaryLabel: 'إعادة المحاولة',
          onPrimary: controller.restoreSession,
          secondaryLabel: 'الرجوع إلى التطبيق',
          onSecondary: () => context.go('/dashboard'),
        ),
      AdminAuthStatus.failure => _buildFailureState(
          authState,
          controller.signIn,
          controller.restoreSession,
          context,
        ),
    };
  }

  Widget _buildFailureState(
    AdminAuthState authState,
    Future<void> Function({required String email, required String password})
        onSignIn,
    Future<void> Function() onRetry,
    BuildContext context,
  ) {
    final code = authState.failureCode;
    if (code == AdminAuthFailureCode.invalidCredentials ||
        code == AdminAuthFailureCode.operationInProgress) {
      return AdminLoginScreen(
        authenticating: false,
        failureCode: code,
        onSignIn: onSignIn,
      );
    }
    return _PlatformStatusScreen(
      icon: Icons.error_outline,
      title: 'حدث خطأ آمن. أعد المحاولة.',
      message: platformFailureText(context, code),
      primaryLabel: 'إعادة المحاولة',
      onPrimary: onRetry,
      secondaryLabel: 'الرجوع إلى التطبيق',
      onSecondary: () => context.go('/dashboard'),
    );
  }
}

class _PlatformLoadingScreen extends StatelessWidget {
  const _PlatformLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(platformText(context, 'منصة الزبائن'))),
      body: SafeArea(
        child: Semantics(
          liveRegion: true,
          label: platformText(context, 'استعادة جلسة المدير'),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    platformText(context, 'استعادة جلسة المدير'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformStatusScreen extends StatelessWidget {
  const _PlatformStatusScreen({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final FutureOrVoidCallback onPrimary;
  final String? secondaryLabel;
  final FutureOrVoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(platformText(context, 'منصة الزبائن'))),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            platformText(context, title),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            platformText(context, message),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Semantics(
                            button: true,
                            label: platformText(context, primaryLabel),
                            child: FilledButton.icon(
                              key: const Key('platform-primary-action'),
                              onPressed: () {
                                onPrimary();
                              },
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                platformText(context, primaryLabel),
                              ),
                            ),
                          ),
                          if (secondaryLabel != null &&
                              onSecondary != null) ...[
                            const SizedBox(height: 8),
                            Semantics(
                              button: true,
                              label: platformText(context, secondaryLabel!),
                              child: TextButton(
                                key: const Key('platform-secondary-action'),
                                onPressed: () {
                                  onSecondary!();
                                },
                                child: Text(
                                  platformText(context, secondaryLabel!),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

typedef FutureOrVoidCallback = FutureOr<void> Function();
