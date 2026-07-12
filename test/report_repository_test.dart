import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/core/database/app_database.dart';
import 'package:game_credit_profit_manager/features/reports/data/report_repository.dart';
import 'package:game_credit_profit_manager/shared/models/report.dart';

import 'support/database_test_utils.dart';

void main() {
  setUpAll(initializeFfiDatabaseTests);

  late Directory directory;
  late AppDatabase database;

  setUp(() async {
    directory = await createDatabaseTestDirectory('game_credit_reports_');
    database = createTestAppDatabase(directory, 'reports.db');
    final db = await database.database;
    await db.insert('customers', customerRow(id: 'customer_1', name: 'محمد'));
    await db.insert('customers', customerRow(id: 'customer_2', name: 'إسلام'));

    await db.insert(
      'sales_transactions',
      transactionRow(
        id: 'current_1',
        createdAt: DateTime(2026, 7, 12, 10),
        customerId: 'customer_1',
        customerName: 'محمد',
        chargedAmount: 350,
        customerPaid: 350,
        newPackagesCost: 150,
        cashProfit: 200,
        purchasedCredit: 110,
      ),
    );
    await db.insert(
      'sales_transactions',
      transactionRow(
        id: 'current_2',
        createdAt: DateTime(2026, 7, 10, 10),
        customerId: 'customer_1',
        customerName: 'محمد',
        inputValue: 200,
        units: 2,
        gems: 200,
        customerPaid: 700,
        chargedAmount: 700,
        requiredCredit: 480,
        additionalCreditRequired: 480,
        newPackagesCost: 500,
        cashProfit: 200,
        purchasedCredit: 400,
      ),
    );
    await db.insert(
      'sales_transactions',
      transactionRow(
        id: 'current_3',
        createdAt: DateTime(2026, 7, 8, 10),
        customerId: 'customer_2',
        customerName: 'إسلام',
        productId: 'product_special',
        productName: 'منتج خاص',
        customerPaid: 500,
        chargedAmount: 500,
        newPackagesCost: 250,
        cashProfit: 250,
      ),
    );
    await db.insert(
      'sales_transactions',
      transactionRow(
        id: 'previous_1',
        createdAt: DateTime(2026, 7, 1, 10),
        customerId: 'customer_2',
        customerName: 'إسلام',
        customerPaid: 300,
        chargedAmount: 300,
        newPackagesCost: 150,
        cashProfit: 150,
      ),
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('يحسب تقرير 7 أيام والمقارنة والترتيب بدقة', () async {
    final repository = ReportRepository(database: database);
    final report = await repository.getReport(
      ReportPeriod.last7Days,
      now: DateTime(2026, 7, 12, 12),
    );

    expect(report.current.sales, 1550);
    expect(report.current.cost, 900);
    expect(report.current.profit, 650);
    expect(report.current.transactionCount, 3);
    expect(report.current.customerCount, 2);
    expect(report.previous?.sales, 300);
    expect(report.previous?.profit, 150);
    expect(report.points, hasLength(7));
    expect(report.points.first.key, '2026-07-06');
    expect(report.points.last.key, '2026-07-12');

    expect(report.topProducts.first.label, '100 جوهرة');
    expect(report.topProducts.first.sales, 1050);
    expect(report.topCustomers.first.label, 'محمد');
    expect(report.topCustomers.first.transactionCount, 2);
    expect(report.topCustomers.first.sales, 1050);
  });

  test('يجمع تقرير الكل حسب الأشهر', () async {
    final repository = ReportRepository(database: database);
    final report = await repository.getReport(
      ReportPeriod.allTime,
      now: DateTime(2026, 7, 12, 12),
    );

    expect(report.current.transactionCount, 4);
    expect(report.previous, isNull);
    expect(report.points, hasLength(1));
    expect(report.points.single.key, '2026-07');
    expect(report.points.single.sales, 1850);
  });
}
