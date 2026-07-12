enum ReportPeriod { today, last7Days, thisMonth, last30Days, allTime }

extension ReportPeriodX on ReportPeriod {
  String get label => switch (this) {
        ReportPeriod.today => 'اليوم',
        ReportPeriod.last7Days => '7 أيام',
        ReportPeriod.thisMonth => 'هذا الشهر',
        ReportPeriod.last30Days => '30 يومًا',
        ReportPeriod.allTime => 'الكل',
      };

  ReportWindow window(DateTime now) {
    final dayStart = DateTime(now.year, now.month, now.day);
    final tomorrow = dayStart.add(const Duration(days: 1));
    final monthStart = DateTime(now.year, now.month);
    final previousMonthStart = DateTime(now.year, now.month - 1);
    final elapsedMonthDays = tomorrow.difference(monthStart).inDays;
    final previousMonthEnd = DateTime(now.year, now.month);
    final previousComparableEnd = previousMonthStart.add(
      Duration(days: elapsedMonthDays),
    );

    return switch (this) {
      ReportPeriod.today => ReportWindow(
          start: dayStart,
          endExclusive: tomorrow,
          previousStart: dayStart.subtract(const Duration(days: 1)),
          previousEndExclusive: dayStart,
        ),
      ReportPeriod.last7Days => ReportWindow(
          start: dayStart.subtract(const Duration(days: 6)),
          endExclusive: tomorrow,
          previousStart: dayStart.subtract(const Duration(days: 13)),
          previousEndExclusive: dayStart.subtract(const Duration(days: 6)),
        ),
      ReportPeriod.thisMonth => ReportWindow(
          start: monthStart,
          endExclusive: tomorrow,
          previousStart: previousMonthStart,
          previousEndExclusive: previousComparableEnd.isAfter(previousMonthEnd)
              ? previousMonthEnd
              : previousComparableEnd,
        ),
      ReportPeriod.last30Days => ReportWindow(
          start: dayStart.subtract(const Duration(days: 29)),
          endExclusive: tomorrow,
          previousStart: dayStart.subtract(const Duration(days: 59)),
          previousEndExclusive: dayStart.subtract(const Duration(days: 29)),
        ),
      ReportPeriod.allTime => const ReportWindow(),
    };
  }
}

class ReportWindow {
  const ReportWindow({
    this.start,
    this.endExclusive,
    this.previousStart,
    this.previousEndExclusive,
  });

  final DateTime? start;
  final DateTime? endExclusive;
  final DateTime? previousStart;
  final DateTime? previousEndExclusive;
}

class ReportTotals {
  const ReportTotals({
    required this.sales,
    required this.cost,
    required this.profit,
    required this.transactionCount,
    required this.customerCount,
    required this.requiredCredit,
    required this.purchasedCredit,
  });

  const ReportTotals.zero()
      : sales = 0,
        cost = 0,
        profit = 0,
        transactionCount = 0,
        customerCount = 0,
        requiredCredit = 0,
        purchasedCredit = 0;

  final int sales;
  final int cost;
  final int profit;
  final int transactionCount;
  final int customerCount;
  final int requiredCredit;
  final int purchasedCredit;

  int get averageSale =>
      transactionCount == 0 ? 0 : (sales / transactionCount).round();

  int get averageProfit =>
      transactionCount == 0 ? 0 : (profit / transactionCount).round();
}

class ReportPoint {
  const ReportPoint({
    required this.key,
    required this.label,
    required this.sales,
    required this.profit,
  });

  final String key;
  final String label;
  final int sales;
  final int profit;
}

class ReportRankingItem {
  const ReportRankingItem({
    required this.label,
    required this.transactionCount,
    required this.sales,
    required this.profit,
  });

  final String label;
  final int transactionCount;
  final int sales;
  final int profit;
}

class ReportSummary {
  const ReportSummary({
    required this.period,
    required this.generatedAt,
    required this.start,
    required this.endExclusive,
    required this.current,
    required this.previous,
    required this.points,
    required this.topProducts,
    required this.topCustomers,
  });

  final ReportPeriod period;
  final DateTime generatedAt;
  final DateTime? start;
  final DateTime? endExclusive;
  final ReportTotals current;
  final ReportTotals? previous;
  final List<ReportPoint> points;
  final List<ReportRankingItem> topProducts;
  final List<ReportRankingItem> topCustomers;

  bool get hasData => current.transactionCount > 0;

  double? get salesChangePercent => _change(current.sales, previous?.sales);
  double? get profitChangePercent => _change(current.profit, previous?.profit);
  double? get transactionChangePercent =>
      _change(current.transactionCount, previous?.transactionCount);

  static double? _change(int currentValue, int? previousValue) {
    if (previousValue == null || previousValue == 0) return null;
    return ((currentValue - previousValue) / previousValue) * 100;
  }
}
