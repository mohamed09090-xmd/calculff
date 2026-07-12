import '../../../core/database/app_database.dart';
import '../../../core/database/direct_sales_schema.dart';
import '../../../shared/models/report.dart';

class ReportRepository {
  ReportRepository({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<ReportSummary> getReport(ReportPeriod period, {DateTime? now}) async {
    final generatedAt = now ?? DateTime.now();
    final window = period.window(generatedAt);
    final db = await _database.database;
    await DirectSalesSchema.ensure(db);

    DateTime? reportStart = window.start;
    if (period == ReportPeriod.allTime) {
      final firstRows = await db.rawQuery('''
        SELECT MIN(created_at) AS first_created_at
        FROM sales_transactions
        WHERE COALESCE(product_id, '') NOT IN (
          '__inventory_adjustment_add__',
          '__inventory_adjustment_remove__'
        )
      ''');
      final raw = firstRows.first['first_created_at'] as String?;
      reportStart = raw == null ? null : DateTime.tryParse(raw);
    }

    final current = await _totals(
      start: window.start,
      endExclusive: window.endExclusive,
    );
    final previous = window.previousStart == null
        ? null
        : await _totals(
            start: window.previousStart,
            endExclusive: window.previousEndExclusive,
          );
    final points = await _points(
      period: period,
      start: reportStart,
      endExclusive: window.endExclusive,
      now: generatedAt,
    );
    final topProducts = await _rankings(
      groupExpression: '''
        CASE
          WHEN mode = 'directProduct' THEN
            COALESCE(NULLIF(product_name_snapshot, ''), 'منتج مباشر') || ' • منتج مباشر'
          WHEN mode = 'credit' THEN 'بيع رصيد مباشر'
          ELSE COALESCE(NULLIF(product_name_snapshot, ''), 'منتج غير مسمى')
        END
      ''',
      start: window.start,
      endExclusive: window.endExclusive,
    );
    final topCustomers = await _rankings(
      groupExpression: "COALESCE(NULLIF(customer_name, ''), 'عميل غير مسمى')",
      start: window.start,
      endExclusive: window.endExclusive,
    );

    return ReportSummary(
      period: period,
      generatedAt: generatedAt,
      start: reportStart,
      endExclusive: window.endExclusive,
      current: current,
      previous: previous,
      points: points,
      topProducts: topProducts,
      topCustomers: topCustomers,
    );
  }

  Future<ReportTotals> _totals({
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    final db = await _database.database;
    final range = _range(start: start, endExclusive: endExclusive);
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(charged_amount), 0) AS sales,
        COALESCE(SUM(credit_cost_used), 0) AS cost,
        COALESCE(SUM(cash_profit), 0) AS profit,
        COUNT(*) AS transaction_count,
        COUNT(DISTINCT COALESCE(customer_id, customer_name)) AS customer_count,
        COALESCE(SUM(required_credit), 0) AS required_credit,
        COALESCE(SUM(purchased_credit), 0) AS purchased_credit
      FROM sales_transactions
      ${range.whereClause}
    ''', range.arguments);
    final row = rows.first;
    return ReportTotals(
      sales: (row['sales'] as num).toInt(),
      cost: (row['cost'] as num).toInt(),
      profit: (row['profit'] as num).toInt(),
      transactionCount: (row['transaction_count'] as num).toInt(),
      customerCount: (row['customer_count'] as num).toInt(),
      requiredCredit: (row['required_credit'] as num).toInt(),
      purchasedCredit: (row['purchased_credit'] as num).toInt(),
    );
  }

  Future<List<ReportRankingItem>> _rankings({
    required String groupExpression,
    DateTime? start,
    DateTime? endExclusive,
  }) async {
    final db = await _database.database;
    final range = _range(start: start, endExclusive: endExclusive);
    final rows = await db.rawQuery('''
      SELECT
        $groupExpression AS label,
        COUNT(*) AS transaction_count,
        COALESCE(SUM(charged_amount), 0) AS sales,
        COALESCE(SUM(cash_profit), 0) AS profit
      FROM sales_transactions
      ${range.whereClause}
      GROUP BY $groupExpression
      ORDER BY sales DESC, transaction_count DESC, label COLLATE NOCASE
      LIMIT 5
    ''', range.arguments);
    return rows
        .map(
          (row) => ReportRankingItem(
            label: row['label']! as String,
            transactionCount: (row['transaction_count'] as num).toInt(),
            sales: (row['sales'] as num).toInt(),
            profit: (row['profit'] as num).toInt(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<ReportPoint>> _points({
    required ReportPeriod period,
    required DateTime? start,
    required DateTime? endExclusive,
    required DateTime now,
  }) async {
    if (start == null) return const [];
    final db = await _database.database;
    final monthly = period == ReportPeriod.allTime;
    final range = _range(start: start, endExclusive: endExclusive);
    final expression = monthly
        ? 'substr(created_at, 1, 7)'
        : 'substr(created_at, 1, 10)';
    final rows = await db.rawQuery('''
      SELECT
        $expression AS bucket,
        COALESCE(SUM(charged_amount), 0) AS sales,
        COALESCE(SUM(cash_profit), 0) AS profit
      FROM sales_transactions
      ${range.whereClause}
      GROUP BY $expression
      ORDER BY bucket ASC
    ''', range.arguments);

    final values = <String, ({int sales, int profit})>{
      for (final row in rows)
        row['bucket']! as String: (
          sales: (row['sales'] as num).toInt(),
          profit: (row['profit'] as num).toInt(),
        ),
    };

    if (monthly) {
      final firstMonth = DateTime(start.year, start.month);
      final lastMonth = DateTime(now.year, now.month);
      final points = <ReportPoint>[];
      for (
        var cursor = firstMonth;
        !cursor.isAfter(lastMonth);
        cursor = DateTime(cursor.year, cursor.month + 1)
      ) {
        final key = _monthKey(cursor);
        final value = values[key] ?? (sales: 0, profit: 0);
        points.add(
          ReportPoint(
            key: key,
            label: '${cursor.month}/${cursor.year}',
            sales: value.sales,
            profit: value.profit,
          ),
        );
      }
      return points;
    }

    final effectiveEnd = endExclusive ?? now.add(const Duration(days: 1));
    final points = <ReportPoint>[];
    for (
      var cursor = DateTime(start.year, start.month, start.day);
      cursor.isBefore(effectiveEnd);
      cursor = cursor.add(const Duration(days: 1))
    ) {
      final key = _dayKey(cursor);
      final value = values[key] ?? (sales: 0, profit: 0);
      points.add(
        ReportPoint(
          key: key,
          label: '${cursor.day}/${cursor.month}',
          sales: value.sales,
          profit: value.profit,
        ),
      );
    }
    return points;
  }

  _SqlRange _range({DateTime? start, DateTime? endExclusive}) {
    final conditions = <String>[
      "COALESCE(product_id, '') NOT IN ('__inventory_adjustment_add__', '__inventory_adjustment_remove__')",
    ];
    final arguments = <Object?>[];
    if (start != null) {
      conditions.add('created_at >= ?');
      arguments.add(start.toIso8601String());
    }
    if (endExclusive != null) {
      conditions.add('created_at < ?');
      arguments.add(endExclusive.toIso8601String());
    }
    return _SqlRange(
      whereClause: 'WHERE ${conditions.join(' AND ')}',
      arguments: arguments,
    );
  }

  String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _monthKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}';
}

class _SqlRange {
  const _SqlRange({required this.whereClause, required this.arguments});

  final String whereClause;
  final List<Object?> arguments;
}
