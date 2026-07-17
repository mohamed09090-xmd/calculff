class PlatformDashboardSummary {
  PlatformDashboardSummary({
    required this.newOrdersCount,
    required this.processingOrdersCount,
    required this.paymentsUnderReviewCount,
    required this.completedOrdersCount,
    required this.publishedOffersCount,
    required this.activeGamesCount,
    required DateTime refreshedAt,
  }) : refreshedAt = refreshedAt.toUtc() {
    _requireNonNegative('newOrdersCount', newOrdersCount);
    _requireNonNegative('processingOrdersCount', processingOrdersCount);
    _requireNonNegative(
      'paymentsUnderReviewCount',
      paymentsUnderReviewCount,
    );
    _requireNonNegative('completedOrdersCount', completedOrdersCount);
    _requireNonNegative('publishedOffersCount', publishedOffersCount);
    _requireNonNegative('activeGamesCount', activeGamesCount);
  }

  final int newOrdersCount;
  final int processingOrdersCount;
  final int paymentsUnderReviewCount;
  final int completedOrdersCount;
  final int publishedOffersCount;
  final int activeGamesCount;
  final DateTime refreshedAt;
}

void _requireNonNegative(String fieldName, int value) {
  if (value < 0) {
    throw ArgumentError.value(value, fieldName, 'Must not be negative.');
  }
}
