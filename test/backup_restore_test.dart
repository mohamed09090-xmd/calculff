import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/core/database/app_database.dart';

import 'support/database_test_utils.dart';

void main() {
  setUpAll(initializeFfiDatabaseTests);

  late Directory directory;
  final databases = <AppDatabase>[];

  setUp(() async {
    directory = await createDatabaseTestDirectory('game_credit_backup_');
  });

  tearDown(() async {
    for (final database in databases) {
      await database.close();
    }
    databases.clear();
    await directory.delete(recursive: true);
  });

  AppDatabase createDatabase(String name) {
    final database = createTestAppDatabase(directory, name);
    databases.add(database);
    return database;
  }

  Future<Map<String, Object?>> createSourceBackup() async {
    final source = createDatabase('source.db');
    final db = await source.database;
    await db.insert('customers', customerRow(id: 'customer_1', name: 'محمد'));
    await db.insert(
      'sales_transactions',
      transactionRow(
        id: 'transaction_1',
        createdAt: DateTime(2026, 7, 12, 10),
        customerId: 'customer_1',
        customerName: 'محمد',
        newPackagesCost: 150,
        cashProfit: 200,
        purchasedCredit: 110,
      ),
    );
    await db.insert('transaction_items', {
      'id': 'item_1',
      'transaction_id': 'transaction_1',
      'package_id': 'pkg_110',
      'package_name_snapshot': 'باقة 110 رصيد',
      'credit_snapshot': 110,
      'price_snapshot': 150,
      'validity_hours_snapshot': 24,
      'quantity': 1,
    });
    return source.exportData();
  }

  test('يصدّر ويستعيد نسخة كاملة مع العملاء وروابط العمليات', () async {
    final payload = await createSourceBackup();
    final preview = AppDatabase.inspectBackup(payload);

    expect(preview.version, AppDatabase.schemaVersion);
    expect(preview.customerCount, 1);
    expect(preview.transactionCount, 1);
    expect(preview.packageCount, greaterThan(0));
    expect(preview.isLegacy, isFalse);

    final encoded = AppDatabase.encodeBackup(payload);
    final decoded = AppDatabase.decodeBackup(encoded);
    final target = createDatabase('target.db');
    await target.importData(decoded);

    final db = await target.database;
    final customers = await db.query('customers');
    final transactions = await db.query('sales_transactions');
    final items = await db.query('transaction_items');

    expect(customers, hasLength(1));
    expect(customers.single['name'], 'محمد');
    expect(transactions, hasLength(1));
    expect(transactions.single['customer_id'], 'customer_1');
    expect(transactions.single['cash_profit'], 200);
    expect(items.single['transaction_id'], 'transaction_1');
  });

  test('يستورد نسخة إصدار 2 وينشئ سجلات العملاء تلقائيًا', () async {
    final current = await createSourceBackup();
    final legacy = Map<String, Object?>.from(current)
      ..remove('format')
      ..['version'] = 2
      ..remove('customers');
    final legacyTransactions = (legacy['sales_transactions']! as List)
        .map(
          (raw) =>
              Map<String, Object?>.from((raw as Map).cast<String, Object?>())
                ..remove('customer_id'),
        )
        .toList(growable: false);
    legacy['sales_transactions'] = legacyTransactions;

    final preview = AppDatabase.inspectBackup(legacy);
    expect(preview.isLegacy, isTrue);
    expect(preview.customerCount, 1);

    final target = createDatabase('legacy-target.db');
    await target.importData(legacy);
    final db = await target.database;
    final customers = await db.query('customers');
    final transactions = await db.query('sales_transactions');

    expect(customers, hasLength(1));
    expect(customers.single['name'], 'محمد');
    expect(transactions.single['customer_id'], customers.single['id']);
  });

  test('يرفض نسخة تالفة ويُبقي البيانات الحالية دون تغيير', () async {
    final payload = await createSourceBackup();
    payload['transaction_items'] = 'قيمة تالفة بدل قائمة';

    final target = createDatabase('validation-target.db');
    final targetDb = await target.database;
    await targetDb.insert(
      'customers',
      customerRow(id: 'sentinel_customer', name: 'بيانات أصلية'),
    );

    await expectLater(
      target.importData(payload),
      throwsA(isA<FormatException>()),
    );

    final customers = await targetDb.query('customers');
    expect(customers, hasLength(1));
    expect(customers.single['id'], 'sentinel_customer');
    expect(customers.single['name'], 'بيانات أصلية');
  });

  test('يرفض الملفات التي تحمل صيغة تطبيق مختلفة', () {
    final payload = <String, Object?>{
      'format': 'different_app',
      'version': AppDatabase.schemaVersion,
    };

    expect(
      () => AppDatabase.inspectBackup(payload),
      throwsA(isA<FormatException>()),
    );
  });
}
