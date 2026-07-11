class DashboardSummary {
  const DashboardSummary({
    required this.todaySales,
    required this.todayProfit,
    required this.totalSales,
    required this.totalCost,
    required this.totalProfit,
    required this.transactionCount,
    required this.activeCredit,
    required this.expiredCredit,
    required this.expiringSoonCredit,
  });

  final int todaySales;
  final int todayProfit;
  final int totalSales;
  final int totalCost;
  final int totalProfit;
  final int transactionCount;
  final int activeCredit;
  final int expiredCredit;
  final int expiringSoonCredit;
}
