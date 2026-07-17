import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/dashboard/platform_dashboard_summary.dart';

void main() {
  group('PlatformDashboardSummary', () {
    test('keeps the approved read-only counters', () {
      final summary = _summary();

      expect(summary.newOrdersCount, 2);
      expect(summary.processingOrdersCount, 3);
      expect(summary.paymentsUnderReviewCount, 4);
      expect(summary.completedOrdersCount, 5);
      expect(summary.publishedOffersCount, 6);
      expect(summary.activeGamesCount, 7);
    });

    test('rejects every negative counter', () {
      final factories = <PlatformDashboardSummary Function()>[
        () => _summary(newOrdersCount: -1),
        () => _summary(processingOrdersCount: -1),
        () => _summary(paymentsUnderReviewCount: -1),
        () => _summary(completedOrdersCount: -1),
        () => _summary(publishedOffersCount: -1),
        () => _summary(activeGamesCount: -1),
      ];

      for (final factory in factories) {
        expect(factory, throwsArgumentError);
      }
    });

    test('normalizes the successful refresh time to UTC', () {
      final summary = _summary(
        refreshedAt: DateTime.parse('2026-07-17T12:00:00+01:00'),
      );

      expect(summary.refreshedAt, DateTime.utc(2026, 7, 17, 11));
      expect(summary.refreshedAt.isUtc, isTrue);
    });
  });
}

PlatformDashboardSummary _summary({
  int newOrdersCount = 2,
  int processingOrdersCount = 3,
  int paymentsUnderReviewCount = 4,
  int completedOrdersCount = 5,
  int publishedOffersCount = 6,
  int activeGamesCount = 7,
  DateTime? refreshedAt,
}) {
  return PlatformDashboardSummary(
    newOrdersCount: newOrdersCount,
    processingOrdersCount: processingOrdersCount,
    paymentsUnderReviewCount: paymentsUnderReviewCount,
    completedOrdersCount: completedOrdersCount,
    publishedOffersCount: publishedOffersCount,
    activeGamesCount: activeGamesCount,
    refreshedAt: refreshedAt ?? DateTime.utc(2026, 7, 17),
  );
}
