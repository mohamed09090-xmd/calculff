import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/dashboard/platform_dashboard_controller.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/dashboard/platform_dashboard_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/dashboard/platform_dashboard_summary.dart';

void main() {
  test('starts loading and exposes successful data including zeros', () async {
    final repository = _QueueRepository([_summary(newOrders: 0)]);
    final controller = PlatformDashboardController(repository: repository);

    expect(controller.state.status, PlatformDashboardStatus.loading);
    await controller.load();

    expect(controller.state.status, PlatformDashboardStatus.data);
    expect(controller.state.summary?.newOrdersCount, 0);
    expect(controller.state.isStale, isFalse);
  });

  test('keeps the last in-memory snapshot stale when refresh fails', () async {
    final repository = _QueueRepository([
      _summary(newOrders: 4),
      const PlatformFailure(PlatformFailureCode.networkUnavailable),
    ]);
    final controller = PlatformDashboardController(repository: repository);

    await controller.load();
    await controller.refresh();

    expect(controller.state.status, PlatformDashboardStatus.data);
    expect(controller.state.summary?.newOrdersCount, 4);
    expect(controller.state.isStale, isTrue);
    expect(
      controller.state.failureCode,
      PlatformFailureCode.networkUnavailable,
    );
  });

  test('ignores repeated refresh while a request is in flight', () async {
    final repository = _CompletingRepository();
    final controller = PlatformDashboardController(repository: repository);

    final first = controller.load();
    final second = controller.refresh();
    expect(repository.calls, 1);

    repository.complete(_summary(newOrders: 7));
    await Future.wait([first, second]);
    expect(controller.state.summary?.newOrdersCount, 7);
  });

  test(
    'invalidation immediately clears data and ignores late results',
    () async {
      final repository = _CompletingRepository();
      final controller = PlatformDashboardController(repository: repository);

      final request = controller.load();
      controller.invalidate();
      repository.complete(_summary(newOrders: 9));
      await request;

      expect(controller.state.status, PlatformDashboardStatus.loading);
      expect(controller.state.summary, isNull);
    },
  );
}

PlatformDashboardSummary _summary({required int newOrders}) {
  return PlatformDashboardSummary(
    newOrdersCount: newOrders,
    processingOrdersCount: 0,
    paymentsUnderReviewCount: 0,
    completedOrdersCount: 0,
    publishedOffersCount: 0,
    activeGamesCount: 0,
    refreshedAt: DateTime.utc(2026, 7, 18, 12),
  );
}

class _QueueRepository implements PlatformDashboardRepository {
  _QueueRepository(this.results);

  final List<Object> results;
  int index = 0;

  @override
  Future<PlatformDashboardSummary> loadDashboardSummary() async {
    final result = results[index++];
    if (result is PlatformFailure) {
      throw result;
    }
    return result as PlatformDashboardSummary;
  }
}

class _CompletingRepository implements PlatformDashboardRepository {
  final Completer<PlatformDashboardSummary> _completer = Completer();
  int calls = 0;

  @override
  Future<PlatformDashboardSummary> loadDashboardSummary() {
    calls += 1;
    return _completer.future;
  }

  void complete(PlatformDashboardSummary summary) {
    _completer.complete(summary);
  }
}
