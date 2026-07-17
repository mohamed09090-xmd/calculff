import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/common/platform_common_providers.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/common/platform_data_scope.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/common/platform_session_coordinator.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_models.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/supabase_platform_error_mapper.dart';

final _testAdminAuthStateProvider = StateProvider<AdminAuthState>(
  (ref) => const AdminAuthState.authorized(),
);

final _sensitivePlatformDataProvider = Provider.autoDispose<_SensitiveData?>((
  ref,
) {
  final scope = ref.watch(platformDataScopeProvider);
  if (!scope.isAuthorized) {
    return null;
  }
  return const _SensitiveData('customer@example.test');
});

void main() {
  group('Platform common providers', () {
    test('dependencies can be overridden with fakes', () {
      final fakeMapper = FakeSupabasePlatformErrorMapper();
      final fakeAccess = FakePlatformSessionAccess();
      final fakeCoordinator = FakePlatformReadCoordinator();
      final container = ProviderContainer(
        overrides: [
          supabasePlatformErrorMapperProvider.overrideWithValue(fakeMapper),
          platformSessionAccessProvider.overrideWithValue(fakeAccess),
          platformReadCoordinatorProvider.overrideWithValue(fakeCoordinator),
        ],
      );
      addTearDown(container.dispose);

      expect(
        identical(
          container.read(supabasePlatformErrorMapperProvider),
          fakeMapper,
        ),
        isTrue,
      );
      expect(
        identical(container.read(platformSessionAccessProvider), fakeAccess),
        isTrue,
      );
      expect(
        identical(
          container.read(platformReadCoordinatorProvider),
          fakeCoordinator,
        ),
        isTrue,
      );
    });

    test(
      'missing Supabase configuration does not execute a platform read',
      () async {
        final container = ProviderContainer(
          overrides: [
            platformAdminAuthStateProvider.overrideWithValue(
              const AdminAuthState.unavailable(),
            ),
          ],
        );
        addTearDown(container.dispose);
        var readCalls = 0;

        await expectLater(
          container.read(platformReadCoordinatorProvider).runRead<void>(
            () async {
              readCalls += 1;
            },
          ),
          throwsA(_failureCode(PlatformFailureCode.temporarilyUnavailable)),
        );

        expect(readCalls, 0);
      },
    );

    test('authorized session allows a read', () async {
      final container = _authorizedContainer();
      addTearDown(container.dispose);
      var readCalls = 0;

      final result = await container
          .read(platformReadCoordinatorProvider)
          .runRead(() async {
            readCalls += 1;
            return 7;
          });

      expect(result, 7);
      expect(readCalls, 1);
      expect(container.read(platformDataScopeProvider).isAuthorized, isTrue);
    });

    for (final testCase
        in <({String name, AdminAuthState state, PlatformFailureCode reason})>[
          (
            name: 'logout',
            state: const AdminAuthState.signedOut(),
            reason: PlatformFailureCode.sessionExpired,
          ),
          (
            name: 'session expiry',
            state: const AdminAuthState.sessionExpired(),
            reason: PlatformFailureCode.sessionExpired,
          ),
          (
            name: 'unauthorized state',
            state: const AdminAuthState.unauthorized(),
            reason: PlatformFailureCode.unauthorized,
          ),
        ]) {
      test('${testCase.name} invalidates the platform data scope', () async {
        final container = _authorizedContainer();
        addTearDown(container.dispose);
        final subscription = container.listen<PlatformDataScopeState>(
          platformDataScopeProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        final initialGeneration = subscription.read().generation;

        container.read(_testAdminAuthStateProvider.notifier).state =
            testCase.state;
        await Future<void>.delayed(Duration.zero);

        final scope = subscription.read();
        expect(scope.isAuthorized, isFalse);
        expect(scope.generation, initialGeneration + 1);
        expect(scope.invalidationReason, testCase.reason);
      });
    }

    test('logout removes the PII-bearing provider object', () async {
      final container = _authorizedContainer();
      addTearDown(container.dispose);
      final subscription = container.listen<_SensitiveData?>(
        _sensitivePlatformDataProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      expect(subscription.read()?.value, 'customer@example.test');

      container.read(_testAdminAuthStateProvider.notifier).state =
          const AdminAuthState.signedOut();
      await Future<void>.delayed(Duration.zero);

      expect(subscription.read(), isNull);
      expect(
        container.read(platformDataScopeProvider).invalidationReason,
        PlatformFailureCode.sessionExpired,
      );
    });
  });
}

ProviderContainer _authorizedContainer() {
  return ProviderContainer(
    overrides: [
      platformAdminAuthStateProvider.overrideWith((ref) {
        return ref.watch(_testAdminAuthStateProvider);
      }),
    ],
  );
}

Matcher _failureCode(PlatformFailureCode code) {
  return isA<PlatformFailure>().having((failure) => failure.code, 'code', code);
}

class FakeSupabasePlatformErrorMapper implements SupabasePlatformErrorMapper {
  @override
  PlatformFailure map(Object error) {
    return const PlatformFailure(PlatformFailureCode.unknown);
  }
}

class FakePlatformSessionAccess implements PlatformSessionAccess {
  @override
  AdminAuthState get currentState => const AdminAuthState.authorized();

  @override
  Future<void> refresh() async {}
}

class FakePlatformReadCoordinator implements PlatformReadCoordinator {
  @override
  Future<T> runRead<T>(PlatformReadOperation<T> operation) {
    return operation();
  }
}

class _SensitiveData {
  const _SensitiveData(this.value);

  final String value;
}
