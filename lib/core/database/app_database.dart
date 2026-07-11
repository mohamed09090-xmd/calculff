import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  static const int schemaVersion = 1;

  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final base = await getDatabasesPath();
    return openDatabase(
      p.join(base, 'game_credit_profit_manager.db'),
      version: schemaVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seedDefaults(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (var version = oldVersion + 1; version <= newVersion; version++) {
          await _migrate(db, version);
        }
      },
    );
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE packages (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price_dzd INTEGER NOT NULL CHECK(price_dzd >= 0),
        credit INTEGER NOT NULL CHECK(credit > 0),
        validity_hours INTEGER NOT NULL CHECK(validity_hours > 0),
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        gems_per_unit INTEGER NOT NULL CHECK(gems_per_unit > 0),
        credit_per_unit INTEGER NOT NULL CHECK(credit_per_unit > 0),
        sale_price_dzd INTEGER NOT NULL CHECK(sale_price_dzd > 0),
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sales_transactions (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        mode TEXT NOT NULL,
        product_id TEXT,
        product_name_snapshot TEXT,
        input_value INTEGER NOT NULL,
        use_inventory INTEGER NOT NULL DEFAULT 1,
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
        quantity INTEGER NOT NULL CHECK(quantity > 0),
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
        amount INTEGER NOT NULL CHECK(amount > 0),
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
    await db.execute(
      'CREATE INDEX idx_lots_expiry ON inventory_lots(status, expires_at)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_created ON sales_transactions(created_at DESC)',
    );
  }

  Future<void> _seedDefaults(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();
    final packages = <Map<String, Object?>>[
      {
        'id': 'pkg_110',
        'name': 'باقة 110 رصيد',
        'price_dzd': 150,
        'credit': 110,
        'validity_hours': 24,
      },
      {
        'id': 'pkg_200',
        'name': 'باقة 200 رصيد',
        'price_dzd': 250,
        'credit': 200,
        'validity_hours': 24,
      },
      {
        'id': 'pkg_400',
        'name': 'باقة 400 رصيد',
        'price_dzd': 500,
        'credit': 400,
        'validity_hours': 168,
      },
      {
        'id': 'pkg_900',
        'name': 'باقة 900 رصيد',
        'price_dzd': 1000,
        'credit': 900,
        'validity_hours': 168,
      },
      {
        'id': 'pkg_2000',
        'name': 'باقة 2000 رصيد',
        'price_dzd': 2000,
        'credit': 2000,
        'validity_hours': 360,
      },
      {
        'id': 'pkg_3000',
        'name': 'باقة 3000 رصيد',
        'price_dzd': 3000,
        'credit': 3000,
        'validity_hours': 720,
      },
    ];
    for (final item in packages) {
      await db.insert('packages', {
        ...item,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
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
    await db.insert('app_settings', {'key': 'use_thousands', 'value': 'false'});
    await db.insert('app_settings', {'key': 'dark_mode', 'value': 'false'});
    await db.insert('app_settings', {'key': 'expiry_warning_hours', 'value': '24'});
  }

  Future<void> _migrate(Database db, int version) async {
    switch (version) {
      case 1:
        return;
      default:
        throw StateError('لا توجد migration معروفة للإصدار $version');
    }
  }

  static const backupTables = <String>[
    'packages',
    'products',
    'sales_transactions',
    'transaction_items',
    'inventory_lots',
    'inventory_movements',
    'app_settings',
  ];

  Future<Map<String, Object?>> exportData() async {
    final db = await database;
    final data = <String, Object?>{
      'version': schemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
    };
    for (final table in backupTables) {
      data[table] = await db.query(table);
    }
    return data;
  }

  Future<void> importData(Map<String, Object?> payload) async {
    if (payload['version'] != schemaVersion) {
      throw const FormatException('إصدار النسخة الاحتياطية غير مدعوم');
    }
    for (final table in backupTables) {
      if (payload[table] is! List) {
        throw FormatException('الجدول $table مفقود أو تالف');
      }
    }
    final db = await database;
    await db.transaction((txn) async {
      await txn.execute('PRAGMA defer_foreign_keys = ON');
      for (final table in backupTables.reversed) {
        await txn.delete(table);
      }
      for (final table in backupTables) {
        final rows = (payload[table]! as List).cast<Map>();
        for (final raw in rows) {
          await txn.insert(table, raw.cast<String, Object?>());
        }
      }
    });
  }

  Future<void> resetToDefaults() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in backupTables.reversed) {
        await txn.delete(table);
      }
      await _seedDefaults(txn);
    });
  }

  static String encodeBackup(Map<String, Object?> data) =>
      const JsonEncoder.withIndent('  ').convert(data);

  static Map<String, Object?> decodeBackup(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('ملف JSON غير صالح');
    }
    return decoded;
  }
}
