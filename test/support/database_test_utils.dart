import 'dart:io';

import 'package:game_credit_profit_manager/core/database/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void initializeFfiDatabaseTests() {
  sqfliteFfiInit();
}

Future<Directory> createDatabaseTestDirectory(String prefix) =>
    Directory.systemTemp.createTemp(prefix);

AppDatabase createTestAppDatabase(Directory directory, String fileName) {
  return AppDatabase.forTesting(
    factory: databaseFactoryFfi,
    databasePath: p.join(directory.path, fileName),
  );
}

Map<String, Object?> transactionRow({
  required String id,
  required DateTime createdAt,
  String? customerId,
  required String customerName,
  String productId = 'product_100_gems',
  String productName = '100 جوهرة',
  int inputValue = 100,
  int units = 1,
  int gems = 100,
  int customerPaid = 350,
  int chargedAmount = 350,
  int customerChange = 0,
  int requiredCredit = 240,
  int inventoryCreditUsed = 0,
  int additionalCreditRequired = 240,
  int purchasedCredit = 0,
  int newPackagesCost = 0,
  int cashProfit = 350,
}) {
  return {
    'id': id,
    'created_at': createdAt.toIso8601String(),
    if (customerId != null) 'customer_id': customerId,
    'customer_name': customerName,
    'mode': 'gems',
    'product_id': productId,
    'product_name_snapshot': productName,
    'input_value': inputValue,
    'use_inventory': 1,
    'units': units,
    'gems': gems,
    'customer_paid': customerPaid,
    'charged_amount': chargedAmount,
    'customer_change': customerChange,
    'required_credit': requiredCredit,
    'inventory_credit_used': inventoryCreditUsed,
    'additional_credit_required': additionalCreditRequired,
    'purchased_credit': purchasedCredit,
    'new_packages_cost': newPackagesCost,
    'cash_profit': cashProfit,
  };
}

Map<String, Object?> customerRow({
  required String id,
  required String name,
  String? phone,
}) {
  final now = DateTime(2026, 7, 1).toIso8601String();
  return {
    'id': id,
    'name': name,
    'phone': phone,
    'notes': null,
    'is_active': 1,
    'created_at': now,
    'updated_at': now,
  };
}

Future<void> createVersion2Database(String path) async {
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 2,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE packages (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            price_dzd INTEGER NOT NULL,
            credit INTEGER NOT NULL,
            validity_hours INTEGER NOT NULL,
            is_active INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE products (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            gems_per_unit INTEGER NOT NULL,
            credit_per_unit INTEGER NOT NULL,
            sale_price_dzd INTEGER NOT NULL,
            is_active INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sales_transactions (
            id TEXT PRIMARY KEY,
            created_at TEXT NOT NULL,
            customer_name TEXT NOT NULL,
            mode TEXT NOT NULL,
            product_id TEXT,
            product_name_snapshot TEXT,
            input_value INTEGER NOT NULL,
            use_inventory INTEGER NOT NULL,
            units INTEGER NOT NULL,
            gems INTEGER NOT NULL,
            customer_paid INTEGER NOT NULL,
            charged_amount INTEGER NOT NULL,
            customer_change INTEGER NOT NULL,
            required_credit INTEGER NOT NULL,
            inventory_credit_used INTEGER NOT NULL,
            additional_credit_required INTEGER NOT NULL,
            purchased_credit INTEGER NOT NULL,
            new_packages_cost INTEGER NOT NULL,
            cash_profit INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE transaction_items (
            id TEXT PRIMARY KEY,
            transaction_id TEXT NOT NULL,
            package_id TEXT NOT NULL,
            package_name_snapshot TEXT NOT NULL,
            credit_snapshot INTEGER NOT NULL,
            price_snapshot INTEGER NOT NULL,
            validity_hours_snapshot INTEGER NOT NULL,
            quantity INTEGER NOT NULL,
            FOREIGN KEY(transaction_id) REFERENCES sales_transactions(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE inventory_lots (
            id TEXT PRIMARY KEY,
            package_id TEXT NOT NULL,
            package_name_snapshot TEXT NOT NULL,
            purchased_credit INTEGER NOT NULL,
            remaining_credit INTEGER NOT NULL,
            purchase_cost INTEGER NOT NULL,
            purchased_at TEXT NOT NULL,
            expires_at TEXT NOT NULL,
            status TEXT NOT NULL,
            source_transaction_id TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE inventory_movements (
            id TEXT PRIMARY KEY,
            lot_id TEXT NOT NULL,
            transaction_id TEXT,
            direction TEXT NOT NULL,
            amount INTEGER NOT NULL,
            reason TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY(lot_id) REFERENCES inventory_lots(id) ON DELETE CASCADE,
            FOREIGN KEY(transaction_id) REFERENCES sales_transactions(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    ),
  );

  final now = DateTime(2026, 7, 1).toIso8601String();
  await db.insert('packages', {
    'id': 'pkg_110',
    'name': 'باقة 110',
    'price_dzd': 150,
    'credit': 110,
    'validity_hours': 24,
    'is_active': 1,
    'created_at': now,
    'updated_at': now,
  });
  await db.insert('products', {
    'id': 'product_100_gems',
    'name': '100 جوهرة',
    'gems_per_unit': 100,
    'credit_per_unit': 240,
    'sale_price_dzd': 350,
    'is_active': 1,
    'created_at': now,
    'updated_at': now,
  });
  await db.insert(
    'sales_transactions',
    transactionRow(
      id: 'legacy_tx_1',
      createdAt: DateTime(2026, 7, 1, 10),
      customerName: '  Mohamed  ',
    )..remove('customer_id'),
  );
  await db.insert(
    'sales_transactions',
    transactionRow(
      id: 'legacy_tx_2',
      createdAt: DateTime(2026, 7, 2, 10),
      customerName: 'mohamed',
    )..remove('customer_id'),
  );
  await db.insert('inventory_lots', {
    'id': 'legacy_lot_1',
    'package_id': 'pkg_110',
    'package_name_snapshot': 'باقة 110',
    'purchased_credit': 110,
    'remaining_credit': 70,
    'purchase_cost': 150,
    'purchased_at': DateTime(2026, 7, 1, 10).toIso8601String(),
    'expires_at': DateTime(2026, 7, 2, 10).toIso8601String(),
    'status': 'active',
    'source_transaction_id': 'legacy_tx_1',
  });
  await db.insert('app_settings', {
    'key': 'expiry_warning_hours',
    'value': '48',
  });
  await db.close();
}
