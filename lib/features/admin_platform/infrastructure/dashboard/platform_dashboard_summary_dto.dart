import '../../domain/dashboard/platform_dashboard_summary.dart';
import '../common/platform_payload_reader.dart';

class PlatformDashboardSummaryDto {
  const PlatformDashboardSummaryDto({
    required this.newOrdersCount,
    required this.processingOrdersCount,
    required this.paymentsUnderReviewCount,
    required this.completedOrdersCount,
    required this.publishedOffersCount,
    required this.activeGamesCount,
    required this.refreshedAt,
  });

  factory PlatformDashboardSummaryDto.fromMap(Map<String, Object?> payload) {
    final reader = PlatformPayloadReader(payload);
    return PlatformDashboardSummaryDto(
      newOrdersCount: _readNonNegative(reader, 'new_orders_count'),
      processingOrdersCount: _readNonNegative(
        reader,
        'processing_orders_count',
      ),
      paymentsUnderReviewCount: _readNonNegative(
        reader,
        'payments_under_review_count',
      ),
      completedOrdersCount: _readNonNegative(reader, 'completed_orders_count'),
      publishedOffersCount: _readNonNegative(reader, 'published_offers_count'),
      activeGamesCount: _readNonNegative(reader, 'active_games_count'),
      refreshedAt: reader.requiredDateTime('refreshed_at'),
    );
  }

  final int newOrdersCount;
  final int processingOrdersCount;
  final int paymentsUnderReviewCount;
  final int completedOrdersCount;
  final int publishedOffersCount;
  final int activeGamesCount;
  final DateTime refreshedAt;

  PlatformDashboardSummary toDomain() {
    return PlatformDashboardSummary(
      newOrdersCount: newOrdersCount,
      processingOrdersCount: processingOrdersCount,
      paymentsUnderReviewCount: paymentsUnderReviewCount,
      completedOrdersCount: completedOrdersCount,
      publishedOffersCount: publishedOffersCount,
      activeGamesCount: activeGamesCount,
      refreshedAt: refreshedAt,
    );
  }
}

int _readNonNegative(PlatformPayloadReader reader, String field) {
  final value = reader.requiredInt(field);
  if (value < 0) {
    throw PlatformPayloadException(
      field: field,
      reason: PlatformPayloadFailureReason.invalidValue,
    );
  }
  return value;
}
