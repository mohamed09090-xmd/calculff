import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/platform_payload_reader.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/dashboard/platform_dashboard_summary_dto.dart';

void main() {
  group('PlatformDashboardSummaryDto', () {
    test('maps only the approved counters', () {
      final summary = PlatformDashboardSummaryDto.fromMap(
        _dashboardPayload(),
      ).toDomain();

      expect(summary.newOrdersCount, 2);
      expect(summary.processingOrdersCount, 3);
      expect(summary.paymentsUnderReviewCount, 4);
      expect(summary.completedOrdersCount, 5);
      expect(summary.publishedOffersCount, 6);
      expect(summary.activeGamesCount, 7);
      expect(summary.refreshedAt, DateTime.utc(2026, 7, 17, 11));
    });

    test('rejects each negative counter safely', () {
      for (final field in <String>[
        'new_orders_count',
        'processing_orders_count',
        'payments_under_review_count',
        'completed_orders_count',
        'published_offers_count',
        'active_games_count',
      ]) {
        final payload = _dashboardPayload()..[field] = -1;

        expect(
          () => PlatformDashboardSummaryDto.fromMap(payload),
          throwsA(
            isA<PlatformPayloadException>()
                .having((error) => error.field, 'field', field)
                .having(
                  (error) => error.reason,
                  'reason',
                  PlatformPayloadFailureReason.invalidValue,
                ),
          ),
        );
      }
    });

    test('normalizes refreshedAt to UTC', () {
      final dto = PlatformDashboardSummaryDto.fromMap(_dashboardPayload());

      expect(dto.refreshedAt.isUtc, isTrue);
      expect(dto.refreshedAt, DateTime.utc(2026, 7, 17, 11));
    });

    test('does not merge an accepted counter into processing', () {
      final payload = _dashboardPayload()..['accepted_orders_count'] = 99;
      final summary = PlatformDashboardSummaryDto.fromMap(
        payload,
      ).toDomain();

      expect(summary.processingOrdersCount, 3);
    });
  });
}

Map<String, Object?> _dashboardPayload() {
  return <String, Object?>{
    'new_orders_count': 2,
    'processing_orders_count': 3,
    'payments_under_review_count': 4,
    'completed_orders_count': 5,
    'published_offers_count': 6,
    'active_games_count': 7,
    'refreshed_at': '2026-07-17T12:00:00+01:00',
  };
}
