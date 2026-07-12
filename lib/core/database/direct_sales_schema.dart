import 'package:sqflite/sqflite.dart';

class DirectSalesSchema {
  const DirectSalesSchema._();

  static Future<void> ensure(Database db) async {
    await db.transaction((txn) async {
      await _upgradeProducts(txn);
      await _addColumnIfMissing(
        txn,
        table: 'sales_transactions',
        column: 'product_description_snapshot',
        definition: 'TEXT',
      );
      await _addColumnIfMissing(
        txn,
        table: 'sales_transactions',
        column: 'credit_cost_used',
        definition: 'INTEGER NOT NULL DEFAULT 0',
      );
      await _seedSetting(
        txn,
        key: 'credit_sale_reference_credit',
        value: '240',
      );
      await _seedSetting(
        txn,
        key: 'credit_sale_reference_price_dzd',
        value: '350',
      );
      await normalizeLegacyTransactions(txn);
    });
  }

  static Future<void> normalizeLegacyTransactions(
    DatabaseExecutor db,
  ) async {
    await db.execute('''
      UPDATE sales_transactions
      SET credit_cost_used = charged_amount - cash_profit
      WHERE credit_cost_used = 0
        AND charged_amount != cash_profit
    ''');
  }

  static Future<void> _upgradeProducts(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(products)');
    final names = columns.map((row) => row['name'] as String).toSet();
    if (names.contains('product_type') && names.contains('description')) {
      return;
    }

    await db.execute('''
      CREATE TABLE products_direct_sales_upgrade (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        product_type TEXT NOT NULL DEFAULT 'gems'
          CHECK(product_type IN ('gems', 'direct')),
        gems_per_unit INTEGER NOT NULL DEFAULT 0 CHECK(gems_per_unit >= 0),
        credit_per_unit INTEGER NOT NULL CHECK(credit_per_unit > 0),
        sale_price_dzd INTEGER NOT NULL DEFAULT 0 CHECK(sale_price_dzd >= 0),
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK(
          (product_type = 'gems' AND gems_per_unit > 0 AND sale_price_dzd > 0)
          OR
          (product_type = 'direct' AND gems_per_unit = 0 AND sale_price_dzd = 0)
        )
      )
    ''');

    await db.execute('''
      INSERT INTO products_direct_sales_upgrade (
        id,
        name,
        product_type,
        gems_per_unit,
        credit_per_unit,
        sale_price_dzd,
        description,
        is_active,
        created_at,
        updated_at
      )
      SELECT
        id,
        name,
        'gems',
        gems_per_unit,
        credit_per_unit,
        sale_price_dzd,
        NULL,
        is_active,
        created_at,
        updated_at
      FROM products
    ''');

    await db.execute('DROP TABLE products');
    await db.execute(
      'ALTER TABLE products_direct_sales_upgrade RENAME TO products',
    );
  }

  static Future<void> _addColumnIfMissing(
    DatabaseExecutor db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  static Future<void> _seedSetting(
    DatabaseExecutor db, {
    required String key,
    required String value,
  }) async {
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
