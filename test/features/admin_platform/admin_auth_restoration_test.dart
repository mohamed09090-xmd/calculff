import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/admin_auth_controller.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/admin_auth_providers.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_models.dart';

import 'admin_auth_test_fakes.dart';

void main() {
  group('AdminAuthController restoration', () {
    test('missing Supabase configuration produces unavailable', () async {
      final controller = AdminAuthController(repository: null);
      addTearDown(controller.dispose);

      await controller.start();

      expect(controller.state.status, AdminAuthStatus.unavailable);
      expect(
        controller.state.failureCode,
        AdminAuthFailureCode.configurationUnavailable,
      );
    });

    test('Riverpod exposes unavailable without dart-defines', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(adminAuthControllerProvider.notifier);
      await controller.start();

      expect(
        container.read(adminAuthControllerProvider).status,
        AdminAuthStatus.unavailable,
      );
    });

    test('no restored session produces signedOut', () async {
      final repository = FakeAdminAuthRepository();
      final controller = await startController(repository);
      addTearDown(controller.dispose);

      expect(controller.state.status, AdminAuthStatus.signedOut);
      expect(repository.refreshCalls, 0);
    });

    test('valid restored admin session produces authorized', () async {
      final repository = FakeAdminAuthRepository(restoredSession: adminSession);
      final controller = await startController(repository);
      addTearDown(controller.dispose);

      expect(controller.state.status, AdminAuthStatus.authorized);
      expect(repository.refreshCalls, 0);
    });

    test('expired admin session refreshes once then authorizes', () async {
      final repository = FakeAdminAuthRepository(
        restoredSession: expiredAdminSession,
        refreshedSession: adminSession,
      );
      final controller = await startController(repository);
      addTearDown(controller.dispose);

      expect(repository.refreshCalls, 1);
      expect(controller.state.status, AdminAuthStatus.authorized);
    });

    test('restored session without admin claim refreshes once', () async {
      final repository = FakeAdminAuthRepository(
        restoredSession: nonAdminSession,
        refreshedSession: adminSession,
      );
      final controller = await startController(repository);
      addTearDown(controller.dispose);

      expect(repository.refreshCalls, 1);
      expect(controller.state.status, AdminAuthStatus.authorized);
    });

    test(
      'non-admin after refresh is rejected and signed out locally',
      () async {
        final repository = FakeAdminAuthRepository(
          restoredSession: nonAdminSession,
          refreshedSession: nonAdminSession,
        );
        final controller = await startController(repository);
        addTearDown(controller.dispose);

        expect(repository.refreshCalls, 1);
        expect(repository.signOutCalls, 1);
        expect(controller.state.status, AdminAuthStatus.unauthorized);
      },
    );

    test('invalid refresh token produces sessionExpired and cleanup', () async {
      final repository = FakeAdminAuthRepository(
        restoredSession: expiredAdminSession,
        refreshFailure: const AdminAuthFailure(
          AdminAuthFailureCode.sessionExpired,
        ),
      );
      final controller = await startController(repository);
      addTearDown(controller.dispose);

      expect(repository.refreshCalls, 1);
      expect(repository.signOutCalls, 1);
      expect(controller.state.status, AdminAuthStatus.sessionExpired);
    });

    test('network failure during refresh produces offline', () async {
      final repository = FakeAdminAuthRepository(
        restoredSession: expiredAdminSession,
        refreshFailure: const AdminAuthFailure(
          AdminAuthFailureCode.networkUnavailable,
        ),
      );
      final controller = await startController(repository);
      addTearDown(controller.dispose);

      expect(repository.signOutCalls, 0);
      expect(controller.state.status, AdminAuthStatus.offline);
    });
  });
}
