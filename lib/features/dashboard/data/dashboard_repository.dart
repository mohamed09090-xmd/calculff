import '../../../core/database/app_database.dart';
import '../../../core/database/direct_sales_schema.dart';
import '../../../shared/models/dashboard_summary.dart';

class DashboardRepository {
  DashboardRepository({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<DashboardSummary> getSummary() async {
    final db = await _database.database;
    await DirectSalesSchema.ensure(db);
    final now = DateTime.now();
    await db.update(
      'inventory_lots',
      {'status': 'expired'},
      where: 'remaining_credit > 0 AND expires_at <= ?',
      whereArgs: [now.toIso8601String()],
    );
    final dayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final totals = await db.rawQuery('''
      SELECT
        COALESCE(SUM(charged_amount), 0) AS total_sales,
        COALESCE(SUM(credit_cost_used), 0) AS total_cost,
        COALESCE(SUM(cash_profit), 0) AS total_profit,
        COUNT(*) AS count
      FROM sales_transactions
      WHERE COALESCE(product_id, '') NOT IN (
        '__inventory_adjustment_add__',
        '__inventory_adjustment_remove__'
      )
    ''');
    final today = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(charged_amount), 0) AS sales,
        COALESCE(SUM(cash_profit), 0) AS profit
      FROM sales_transactions
      WHERE created_at >= ?
        AND COALESCE(product_id, '') NOT IN (
          '__inventory_adjustment_add__',
          '__inventory_adjustment_remove__'
        )
    ''',
      [dayStart],
    );
    final settingRows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: const ['expiry_warning_hours'],
      limit: 1,
    );
    final warningHours = settingRows.isEmpty
        ? 24
        : int.tryParse(settingRows.first['value']! as String) ?? 24;
    final warningEnd = now.add(Duration(hours: warningHours)).toIso8601String();
    final inventory = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN status = 'active' THEN remaining_credit ELSE 0 END), 0) AS active,
        COALESCE(SUM(CASE WHEN status = 'expired' THEN remaining_credit ELSE 0 END), 0) AS expired,
        COALESCE(SUM(CASE WHEN status = 'active' AND expires_at <= ? THEN remaining_credit ELSE 0 END), 0) AS soon
      FROM inventory_lots
    ''',
      [warningEnd],
    );
    final totalRow = totals.first;
    final todayRow = today.first;
    final inventoryRow = inventory.first;
    return DashboardSummary(
      todaySales: (todayRow['sales'] as num).toInt(),
      todayProfit: (todayRow['profit'] as num).toInt(),
      totalSales: (totalRow['total_sales'] as num).toInt(),
      totalCost: (totalRow['total_cost'] as num).toInt(),
      totalProfit: (totalRow['total_profit'] as num).toInt(),
      transactionCount: (totalRow['count'] as num).toInt(),
      activeCredit: (inventoryRow['active'] as num).toInt(),
      expiredCredit: (inventoryRow['expired'] as num).toInt(),
      expiringSoonCredit: (inventoryRow['soon'] as num).toInt(),
    );
  }
}
