import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_models.dart';
import 'package:game_credit_profit_manager/features/admin_platform/presentation/admin_login_screen.dart';
import 'package:game_credit_profit_manager/features/admin_platform/presentation/customer_platform_shell.dart';

import 'admin_auth_test_fakes.dart';
import 'platform_widget_test_helpers.dart';

void main() {
  group('PlatformGate', () {
    testWidgets('unavailable configuration keeps the local app available', (
      tester,
    ) async {
      await pumpPlatformGate(tester, repository: null);

      expect(find.text('إعداد المنصة غير متوفر.'), findsOneWidget);
      expect(find.text('الرجوع إلى التطبيق'), findsOneWidget);
      expect(find.byType(AdminLoginScreen), findsNothing);
    });

    testWidgets('signedOut shows the administrator login form', (tester) async {
      await pumpPlatformGate(tester, repository: FakeAdminAuthRepository());

      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.text('تسجيل دخول المدير'), findsOneWidget);
    });

    testWidgets('restoring shows a loading state once', (tester) async {
      final repository = _PendingRestoreRepository();
      addTearDown(repository.complete);

      await pumpPlatformGate(tester, repository: repository, settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('استعادة جلسة المدير'), findsOneWidget);
    });

    testWidgets('authorized opens the customer platform shell', (tester) async {
      await pumpPlatformGate(
        tester,
        repository: FakeAdminAuthRepository(restoredSession: adminSession),
      );

      expect(find.byType(CustomerPlatformShell), findsOneWidget);
      expect(find.text('لوحة المنصة'), findsWidgets);
    });

    testWidgets('unauthorized shows a safe role message', (tester) async {
      await pumpPlatformGate(
        tester,
        repository: FakeAdminAuthRepository(
          restoredSession: nonAdminSession,
          refreshedSession: nonAdminSession,
        ),
      );

      expect(find.text('الحساب غير مخول لإدارة المنصة.'), findsOneWidget);
      expect(find.textContaining('test-user-id'), findsNothing);
      expect(find.textContaining('token'), findsNothing);
    });

    testWidgets('sessionExpired allows returning to login', (tester) async {
      final repository = FakeAdminAuthRepository(
        restoredSession: expiredAdminSession,
        refreshFailure: const AdminAuthFailure(
          AdminAuthFailureCode.sessionExpired,
        ),
      );
      await pumpPlatformGate(tester, repository: repository);

      expect(find.text('انتهت الجلسة.'), findsOneWidget);
      await tester.tap(find.text('العودة إلى تسجيل الدخول'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(repository.signOutCalls, 2);
    });

    testWidgets('offline shows retry and local-app actions', (tester) async {
      await pumpPlatformGate(
        tester,
        repository: FakeAdminAuthRepository(
          restoredSession: expiredAdminSession,
          refreshFailure: const AdminAuthFailure(
            AdminAuthFailureCode.networkUnavailable,
          ),
        ),
      );

      expect(find.text('لا يوجد اتصال بالمنصة.'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      expect(find.text('الرجوع إلى التطبيق'), findsOneWidget);
    });

    testWidgets('unknown failure never exposes a raw exception', (
      tester,
    ) async {
      await pumpPlatformGate(
        tester,
        repository: FakeAdminAuthRepository(
          restoreFailure: const AdminAuthFailure(AdminAuthFailureCode.unknown),
        ),
      );

      expect(find.text('حدث خطأ آمن. أعد المحاولة.'), findsWidgets);
      expect(find.textContaining('AuthException'), findsNothing);
      expect(find.textContaining('PostgrestException'), findsNothing);
    });

    testWidgets('successful sign-in replaces login with the shell', (
      tester,
    ) async {
      final repository = FakeAdminAuthRepository(signInSession: adminSession);
      await pumpPlatformGate(tester, repository: repository);

      await tester.enterText(
        find.byKey(const Key('platform-email-field')),
        '  admin@example.test  ',
      );
      await tester.enterText(
        find.byKey(const Key('platform-password-field')),
        ' test-password ',
      );
      await tester.tap(find.byKey(const Key('platform-sign-in-button')));
      await tester.pumpAndSettle();

      expect(repository.lastEmail, 'admin@example.test');
      expect(repository.lastPassword, ' test-password ');
      expect(find.byType(CustomerPlatformShell), findsOneWidget);
    });

    testWidgets('local logout returns the gate to login', (tester) async {
      final repository = FakeAdminAuthRepository(restoredSession: adminSession);
      await pumpPlatformGate(tester, repository: repository);

      await tester.tap(find.byKey(const Key('platform-admin-account-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('platform-sign-out-button')));
      await tester.pumpAndSettle();

      expect(repository.signOutCalls, 1);
      expect(find.byType(AdminLoginScreen), findsOneWidget);
    });
  });
}

class _PendingRestoreRepository extends FakeAdminAuthRepository {
  final Completer<void> _completer = Completer<void>();

  @override
  Future<AdminAuthSession?> restoreSession() async {
    await _completer.future;
    return null;
  }

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }
}
