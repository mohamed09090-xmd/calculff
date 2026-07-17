import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_models.dart';

import 'admin_auth_test_fakes.dart';

void main() {
  group('AdminAuthController sign-in', () {
    test('successful admin sign-in trims email but not password', () async {
      final repository = FakeAdminAuthRepository(signInSession: adminSession);
      final controller = await startController(repository);
      addTearDown(controller.dispose);

      await controller.signIn(
        email: '  admin@example.test  ',
        password: '  test-password  ',
      );

      expect(repository.lastEmail, 'admin@example.test');
      expect(repository.lastPassword, '  test-password  ');
      expect(controller.state.status, AdminAuthStatus.authorized);
    });

    test('non-admin sign-in is rejected and signed out locally', () async {
      final repository = FakeAdminAuthRepository(
        signInSession: nonAdminSession,
      );
      final controller = await startController(repository);
      addTearDown(controller.dispose);

      await controller.signIn(
        email: 'user@example.test',
        password: 'test-password',
      );

      expect(repository.signOutCalls, 1);
      expect(controller.state.status, AdminAuthStatus.unauthorized);
    });

    test('invalid credentials map to a stable failure code', () async {
      final repository = FakeAdminAuthRepository(
        signInFailure: const AdminAuthFailure(
          AdminAuthFailureCode.invalidCredentials,
        ),
      );
      final controller = await startController(repository);
      addTearDown(controller.dispose);

      await controller.signIn(
        email: 'admin@example.test',
        password: 'wrong-test-password',
      );

      expect(controller.state.status, AdminAuthStatus.failure);
      expect(
        controller.state.failureCode,
        AdminAuthFailureCode.invalidCredentials,
      );
    });

    test('network failure maps to offline', () async {
      final repository = FakeAdminAuthRepository(
        signInFailure: const AdminAuthFailure(
          AdminAuthFailureCode.networkUnavailable,
        ),
      );
      final controller = await startController(repository);
      addTearDown(controller.dispose);

      await controller.signIn(
        email: 'admin@example.test',
        password: 'test-password',
      );

      expect(controller.state.status, AdminAuthStatus.offline);
    });

    test('prevents two concurrent sign-in attempts', () async {
      final completer = Completer<AdminAuthSession>();
      final repository = FakeAdminAuthRepository(signInCompleter: completer);
      final controller = await startController(repository);
      addTearDown(controller.dispose);

      final firstAttempt = controller.signIn(
        email: 'admin@example.test',
        password: 'first-test-password',
      );
      await Future<void>.delayed(Duration.zero);
      await controller.signIn(
        email: 'admin@example.test',
        password: 'second-test-password',
      );

      expect(repository.signInCalls, 1);
      expect(
        controller.state.failureCode,
        AdminAuthFailureCode.operationInProgress,
      );

      completer.complete(adminSession);
      await firstAttempt;
      expect(controller.state.status, AdminAuthStatus.authorized);
    });
  });

  group('AdminAuthController auth events', () {
    test('stream error is handled without an unhandled exception', () async {
      final repository = FakeAdminAuthRepository();
      final controller = await startController(repository);
      addTearDown(controller.dispose);

      repository.emitError(
        const AdminAuthFailure(AdminAuthFailureCode.networkUnavailable),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, AdminAuthStatus.offline);
    });

    test('signedOut event updates state', () async {
      final repository = FakeAdminAuthRepository(restoredSession: adminSession);
      final controller = await startController(repository);
      addTearDown(controller.dispose);

      repository.emit(const AdminAuthEvent(type: AdminAuthEventType.signedOut));
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, AdminAuthStatus.signedOut);
    });

    test('tokenRefreshed rechecks the admin role', () async {
      final repository = FakeAdminAuthRepository(restoredSession: adminSession);
      final controller = await startController(repository);
      addTearDown(controller.dispose);

      repository.emit(
        const AdminAuthEvent(
          type: AdminAuthEventType.tokenRefreshed,
          session: nonAdminSession,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.signOutCalls, 1);
      expect(controller.state.status, AdminAuthStatus.unauthorized);
    });

    test('dispose cancels the auth subscription', () async {
      final repository = FakeAdminAuthRepository();
      final controller = await startController(repository);

      controller.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(repository.cancelCalls, 1);
    });
  });
}
