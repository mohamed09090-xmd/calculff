import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/common/platform_session_coordinator.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_models.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/supabase_platform_error_mapper.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/dashboard/supabase_platform_dashboard_data_source.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/dashboard/supabase_platform_dashboard_repository.dart';

void main() {
  test('starts all six counts before waiting for completion', () async {
    final dataSource = _ControlledDataSource();
    final coordinator = _CountingReadCoordinator();
    final repository = SupabasePlatformDashboardRepository(
      dataSource: dataSource,
      readCoordinator: coordinator,
      errorMapper: const SupabasePlatformErrorMapper(),
      now: () => DateTime.utc(2026, 7, 18, 12),
    );

    final future = repository.loadDashboardSummary();
    await Future<void>.delayed(Duration.zero);

    expect(dataSource.started, 6);
    expect(coordinator.calls, 1);
    dataSource.completeAll();
    final summary = await future;

    expect(summary.newOrdersCount, 1);
    expect(summary.activeGamesCount, 6);
  });

  test(
    'session expiry refreshes once and retries the whole batch once',
    () async {
      final session = _FakeSessionAccess();
      final dataScope = _FakeDataScope();
      final dataSource = _ExpiringDataSource();
      final repository = SupabasePlatformDashboardRepository(
        dataSource: dataSource,
        errorMapper: const SupabasePlatformErrorMapper(),
        readCoordinator: PlatformSessionCoordinator(
          sessionAccess: session,
          mapError: (error) => error is PlatformFailure
              ? error
              : const PlatformFailure(PlatformFailureCode.unknown),
          dataScope: dataScope,
        ),
      );

      final summary = await repository.loadDashboardSummary();

      expect(summary.completedOrdersCount, 4);
      expect(dataSource.newOrdersCalls, 2);
      expect(dataSource.totalCalls, 12);
      expect(session.refreshCalls, 1);
      expect(dataScope.invalidationCalls, 1);
      expect(dataScope.authorizedCalls, 1);
    },
  );
}

class _CountingReadCoordinator implements PlatformReadCoordinator {
  int calls = 0;

  @override
  Future<T> runRead<T>(PlatformReadOperation<T> operation) {
    calls += 1;
    return operation();
  }
}

class _ControlledDataSource implements PlatformDashboardDataSource {
  final List<Completer<int>> _completers = [];
  int started = 0;

  Future<int> _count(int value) {
    started += 1;
    final completer = Completer<int>();
    _completers.add(completer);
    return completer.future.then((_) => value);
  }

  void completeAll() {
    for (final completer in _completers) {
      completer.complete(0);
    }
  }

  @override
  Future<int> countNewOrders() => _count(1);
  @override
  Future<int> countProcessingOrders() => _count(2);
  @override
  Future<int> countPaymentsUnderReview() => _count(3);
  @override
  Future<int> countCompletedOrders() => _count(4);
  @override
  Future<int> countPublishedOffers() => _count(5);
  @override
  Future<int> countActiveGames() => _count(6);
}

class _FakeSessionAccess implements PlatformSessionAccess {
  int refreshCalls = 0;

  @override
  AdminAuthState get currentState => const AdminAuthState.authorized();

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
  }
}

class _FakeDataScope implements PlatformDataScopeSink {
  int authorizedCalls = 0;
  int invalidationCalls = 0;

  @override
  void invalidate(PlatformFailureCode reason) {
    invalidationCalls += 1;
  }

  @override
  void markAuthorized() {
    authorizedCalls += 1;
  }
}

class _ExpiringDataSource implements PlatformDashboardDataSource {
  int totalCalls = 0;
  int newOrdersCalls = 0;
  bool _expired = false;

  Future<int> _value(int value) async {
    totalCalls += 1;
    return value;
  }

  @override
  Future<int> countNewOrders() async {
    totalCalls += 1;
    newOrdersCalls += 1;
    if (!_expired) {
      _expired = true;
      throw const PlatformFailure(PlatformFailureCode.sessionExpired);
    }
    return 1;
  }

  @override
  Future<int> countProcessingOrders() => _value(2);
  @override
  Future<int> countPaymentsUnderReview() => _value(3);
  @override
  Future<int> countCompletedOrders() => _value(4);
  @override
  Future<int> countPublishedOffers() => _value(5);
  @override
  Future<int> countActiveGames() => _value(6);
}
