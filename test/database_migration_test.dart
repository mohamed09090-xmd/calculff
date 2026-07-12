import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/core/database/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/database_test_utils.dart';

void main() {
  setUpAll(initializeFfiDatabaseTests);

  late Directory directory;
  AppDatabase? appDatabase;

  setUp(() async {
    directory = await createDatabaseTestDirectory('game_credit_migration_');
  });

  tearDown(() async {
    await appDatabase?.close();
    await directory.delete(recursive: true);
  });

  test('يرقي قاعدة الإصدار 2 إلى 3 دون فقدان العمليات والمخزون', () async {
    final path = p.join(directory.path, 'migration-v2.db');
    await createVersion2Database(path);
    appDatabase = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: path,
    );

    final db = await appDatabase!.database;

    expect(await db.getVersion(), AppDatabase.schemaVersion);

    final customers = await db.query('customers');
    expect(customers, hasLength(1));
    expect(customers.single['name'], 'Mohamed');

    final transactions = await db.query(
      'sales_transactions',
      orderBy: 'created_at ASC',
    );
    expect(transactions, hasLength(2));
    expect(transactions.first['customer_name'], 'Mohamed');
    expect(transactions.last['customer_name'], 'mohamed');
    expect(transactions.first['customer_id'], customers.single['id']);
    expect(transactions.last['customer_id'], customers.single['id']);

    final lots = await db.query('inventory_lots');
    expect(lots, hasLength(1));
    expect(lots.single['remaining_credit'], 70);
    expect(lots.single['source_transaction_id'], 'legacy_tx_1');

    final settings = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['expiry_warning_hours'],
    );
    expect(settings.single['value'], '48');

    final indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
      ['idx_transactions_customer_id'],
    );
    expect(indexes, hasLength(1));
  });
}
