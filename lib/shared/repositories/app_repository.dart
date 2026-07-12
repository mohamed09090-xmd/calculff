import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/id_generator.dart';
import '../../features/calculator/application/calculation_engine.dart';
import '../../features/inventory/application/fefo_allocator.dart';
import '../models/app_settings.dart';
import '../models/calculation.dart';
import '../models/credit_package.dart';
import '../models/dashboard_summary.dart';
import '../models/inventory_lot.dart';
import '../models/product.dart';
import '../models/sales_transaction.dart';
import '../models/transaction_details.dart';

class AppRepository {
  AppRepository({
    AppDatabase? database,
    CalculationEngine? calculationEngine,
    FefoAllocator? allocator,
  })  : _database = database ?? AppDatabase.instance,
        _calculationEngine = calculationEngine ?? const CalculationEngine(),
        _allocator = allocator ?? const FefoAllocator();

  final AppDatabase _database;
  final CalculationEngine _calculationEngine;
  final FefoAllocator _allocator;

  Future<void> initialize() async {
    await _database.database;
    await refreshExpiredLots();
    await _rescheduleAllNotifications();
  }

  Future<List<CreditPackage>> getPackages({bool activeOnly = false}) async {
    final db = await _database.database;
    final rows = await db.query(
      'packages',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'credit ASC',
    );
    return rows.map(CreditPackage.fromMap).toList(growable: false);
  }

  Future<void> savePackage(CreditPackage package) async {
    final db = await _database.database;
    await db.insert(
      'packages',
      package.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Product>> getProducts({bool activeOnly = false}) async {
    final db = await _database.database;
    final rows = await db.query(
      'products',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Product.fromMap).toList(growable: false);
  }

  Future<void> saveProduct(Product product) async {
    final db = await _database.database;
    await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> refreshExpiredLots({DateTime? now}) async {
    final db = await _database.database;
    final timestamp = (now ?? DateTime.now()).toIso8601String();
    await db.update(
      'inventory_lots',
      {'status': InventoryLotStatus.expired.name},
      where: 'remaining_credit > 0 AND expires_at <= ?',
      whereArgs: [timestamp],
    );
  }

  Future<List<InventoryLot>> getInventoryLots() async {
    await refreshExpiredLots();
    final db = await _database.database;
    final rows = await db.query(
      'inventory_lots',
      orderBy: 'expires_at ASC, purchased_at ASC',
    );
    return rows.map(InventoryLot.fromMap).toList(growable: false);
  }

  Future<int> getActiveInventoryCredit() async {
    await refreshExpiredLots();
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(remaining_credit), 0) AS total
      FROM inventory_lots
      WHERE status = ? AND remaining_credit > 0 AND expires_at > ?
    ''', [InventoryLotStatus.active.name, DateTime.now().toIso8601String()]);
    return (rows.first['total'] as num).toInt();
  }

  Future<CalculationResult> calculate(CalculationRequest request) async {
    final packages = await getPackages(activeOnly: true);
    final inventory = await getActiveInventoryCredit();
    return _calculationEngine.calculate(
      request: request,
      packages: packages,
      availableInventoryCredit: inventory,
    );
  }

  Future<String> saveTransaction(
    CalculationResult result, {
    required String customerName,
  }) async {
    final normalizedCustomerName = customerName.trim().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
    if (normalizedCustomerName.isEmpty) {
      throw StateError('اسم العميل مطلوب قبل حفظ العملية');
    }
    if (normalizedCustomerName.length > 80) {
      throw StateError('اسم العميل يجب ألا يتجاوز 80 حرفًا');
    }
    if (result.requiredCredit <= 0) {
      throw StateError('لا يمكن حفظ عملية بلا رصيد مطلوب');
    }
    if (result.request.mode == CalculationMode.credit) {
      throw StateError('وضع حساب الرصيد مخصص للتخطيط ولا يُحفظ كعملية بيع');
    }
    if (result.request.mode == CalculationMode.gems &&
        result.gems != result.request.inputValue) {
      throw StateError('عدّل عدد الجواهر إلى كمية متوافقة مع حزمة المنتج قبل الحفظ');
    }
    final db = await _database.database;
    final now = DateTime.now();
    final transactionId = IdGenerator.next('txn');
    final createdLots = <InventoryLot>[];

    await db.transaction((txn) async {
      final base = SalesTransaction(
        id: transactionId,
        createdAt: now,
        customerName: normalizedCustomerName,
        mode: result.request.mode,
        productId: result.request.product?.id,
        productNameSnapshot: result.request.product?.name,
        inputValue: result.request.inputValue,
        useInventory: result.request.useInventory,
        units: result.units,
        gems: result.gems,
        customerPaid: result.customerPaid,
        chargedAmount: result.chargedAmount,
        customerChange: result.customerChange,
        requiredCredit: result.requiredCredit,
        inventoryCreditUsed: 0,
        additionalCreditRequired: result.requiredCredit,
        purchasedCredit: result.purchasedCredit,
        newPackagesCost: result.newPackagesCost,
        cashProfit: result.chargedAmount - result.newPackagesCost,
      );
      await txn.insert('sales_transactions', base.toMap());

      final requestedFromExisting = result.request.useInventory
          ? result.inventoryCreditUsed
          : 0;
      final existingUsed = await _consumeCredit(
        txn,
        amount: requestedFromExisting,
        transactionId: transactionId,
        now: now,
      );

      for (final selection in result.optimization?.selections ?? const []) {
        await txn.insert('transaction_items', {
          'id': IdGenerator.next('item'),
          'transaction_id': transactionId,
          'package_id': selection.package.id,
          'package_name_snapshot': selection.package.name,
          'credit_snapshot': selection.package.credit,
          'price_snapshot': selection.package.priceDzd,
          'validity_hours_snapshot': selection.package.validityHours,
          'quantity': selection.quantity,
        });
        for (var i = 0; i < selection.quantity; i++) {
          final lot = InventoryLot(
            id: IdGenerator.next('lot'),
            packageId: selection.package.id,
            packageNameSnapshot: selection.package.name,
            purchasedCredit: selection.package.credit,
            remainingCredit: selection.package.credit,
            purchaseCost: selection.package.priceDzd,
            purchasedAt: now.add(Duration(microseconds: createdLots.length)),
            expiresAt: now.add(Duration(hours: selection.package.validityHours)),
            status: InventoryLotStatus.active,
            sourceTransactionId: transactionId,
          );
          createdLots.add(lot);
          await txn.insert('inventory_lots', lot.toMap());
          await txn.insert('inventory_movements', {
            'id': IdGenerator.next('move'),
            'lot_id': lot.id,
            'transaction_id': transactionId,
            'direction': 'in',
            'amount': lot.purchasedCredit,
            'reason': 'شراء باقة ضمن العملية',
            'created_at': now.toIso8601String(),
          });
        }
      }

      final remainingNeed = result.requiredCredit - existingUsed;
      final newUsed = await _consumeCredit(
        txn,
        amount: remainingNeed,
        transactionId: transactionId,
        now: now,
        sourceTransactionId: transactionId,
      );
      if (existingUsed + newUsed != result.requiredCredit) {
        throw StateError('الرصيد المتوفر والمقترح لا يغطي العملية كاملة');
      }
      await txn.update(
        'sales_transactions',
        {
          'inventory_credit_used': existingUsed,
          'additional_credit_required': newUsed,
        },
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });

    final settings = await getSettings();
    for (final lot in createdLots) {
      await NotificationService.instance.scheduleExpiryWarning(
        notificationId: _notificationId(lot.id),
        lotName: lot.packageNameSnapshot,
        expiresAt: lot.expiresAt,
        warningBefore: Duration(hours: settings.expiryWarningHours),
      );
    }
    return transactionId;
  }

  Future<int> _consumeCredit(
    DatabaseExecutor db, {
    required int amount,
    required String transactionId,
    required DateTime now,
    String? sourceTransactionId,
  }) async {
    if (amount <= 0) return 0;
    final where = StringBuffer(
      'remaining_credit > 0 AND status = ? AND expires_at > ?',
    );
    final args = <Object?>[
      InventoryLotStatus.active.name,
      now.toIso8601String(),
    ];
    if (sourceTransactionId != null) {
      where.write(' AND source_transaction_id = ?');
      args.add(sourceTransactionId);
    } else {
      where.write(' AND (source_transaction_id IS NULL OR source_transaction_id != ?)');
      args.add(transactionId);
    }
    final rows = await db.query(
      'inventory_lots',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'expires_at ASC, purchased_at ASC',
    );
    final lots = rows.map(InventoryLot.fromMap).toList(growable: false);
    final allocation = _allocator.allocate(
      requiredCredit: amount,
      lots: lots,
      now: now,
    );
    for (final item in allocation.allocations) {
      final lot = lots.firstWhere((candidate) => candidate.id == item.lotId);
      final remaining = lot.remainingCredit - item.amount;
      await db.update(
        'inventory_lots',
        {
          'remaining_credit': remaining,
          'status': remaining == 0
              ? InventoryLotStatus.depleted.name
              : InventoryLotStatus.active.name,
        },
        where: 'id = ?',
        whereArgs: [lot.id],
      );
      await db.insert('inventory_movements', {
        'id': IdGenerator.next('move'),
        'lot_id': lot.id,
        'transaction_id': transactionId,
        'direction': 'out',
        'amount': item.amount,
        'reason': 'استهلاك عملية بيع وفق FEFO',
        'created_at': now.toIso8601String(),
      });
    }
    return allocation.allocatedCredit;
  }

  Future<List<SalesTransaction>> getTransactions({String? query}) async {
    final db = await _database.database;
    final normalizedQuery = query?.trim();
    final hasQuery = normalizedQuery != null && normalizedQuery.isNotEmpty;
    final rows = await db.query(
      'sales_transactions',
      where: hasQuery
          ? '(customer_name LIKE ? OR product_name_snapshot LIKE ?)'
          : null,
      whereArgs: hasQuery
          ? ['%$normalizedQuery%', '%$normalizedQuery%']
          : null,
      orderBy: 'created_at DESC',
    );
    return rows.map(SalesTransaction.fromMap).toList(growable: false);
  }

  Future<TransactionDetails> getTransactionDetails(String id) async {
    final db = await _database.database;
    final transactionRows = await db.query(
      'sales_transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (transactionRows.isEmpty) throw StateError('العملية غير موجودة');
    final itemRows = await db.query(
      'transaction_items',
      where: 'transaction_id = ?',
      whereArgs: [id],
      orderBy: 'credit_snapshot DESC',
    );
    return TransactionDetails(
      transaction: SalesTransaction.fromMap(transactionRows.first),
      items: itemRows.map(TransactionPackageItem.fromMap).toList(growable: false),
    );
  }

  Future<void> deleteTransaction(String id) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.delete('sales_transactions', where: 'id = ?', whereArgs: [id]);
      await _rebuildInventory(txn);
    });
    await _rescheduleAllNotifications();
  }

  Future<void> _rebuildInventory(DatabaseExecutor db) async {
    await db.delete('inventory_movements');
    await db.delete('inventory_lots');
    final transactionRows = await db.query(
      'sales_transactions',
      orderBy: 'created_at ASC',
    );
    for (final row in transactionRows) {
      final transaction = SalesTransaction.fromMap(row);
      final now = transaction.createdAt;
      final existingUsed = await _consumeCredit(
        db,
        amount: transaction.useInventory ? transaction.requiredCredit : 0,
        transactionId: transaction.id,
        now: now,
      );
      final itemRows = await db.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [transaction.id],
      );
      var purchasedCredit = 0;
      var purchaseCost = 0;
      for (final row in itemRows) {
        final item = TransactionPackageItem.fromMap(row);
        purchasedCredit += item.creditSnapshot * item.quantity;
        purchaseCost += item.priceSnapshot * item.quantity;
        for (var index = 0; index < item.quantity; index++) {
          final lot = InventoryLot(
            id: IdGenerator.next('lot'),
            packageId: item.packageId,
            packageNameSnapshot: item.packageNameSnapshot,
            purchasedCredit: item.creditSnapshot,
            remainingCredit: item.creditSnapshot,
            purchaseCost: item.priceSnapshot,
            purchasedAt: now.add(Duration(microseconds: index)),
            expiresAt: now.add(Duration(hours: item.validityHoursSnapshot)),
            status: InventoryLotStatus.active,
            sourceTransactionId: transaction.id,
          );
          await db.insert('inventory_lots', lot.toMap());
          await db.insert('inventory_movements', {
            'id': IdGenerator.next('move'),
            'lot_id': lot.id,
            'transaction_id': transaction.id,
            'direction': 'in',
            'amount': lot.purchasedCredit,
            'reason': 'إعادة بناء شراء الباقة',
            'created_at': now.toIso8601String(),
          });
        }
      }
      final stillNeeded = transaction.requiredCredit - existingUsed;
      final newUsed = await _consumeCredit(
        db,
        amount: stillNeeded,
        transactionId: transaction.id,
        now: now,
        sourceTransactionId: transaction.id,
      );
      if (existingUsed + newUsed < transaction.requiredCredit) {
        throw StateError('تعذر إعادة بناء المخزون للعملية ${transaction.id}');
      }
      await db.update(
        'sales_transactions',
        {
          'inventory_credit_used': existingUsed,
          'additional_credit_required': newUsed,
          'purchased_credit': purchasedCredit,
          'new_packages_cost': purchaseCost,
          'cash_profit': transaction.chargedAmount - purchaseCost,
        },
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
    }
    await db.update(
      'inventory_lots',
      {'status': InventoryLotStatus.expired.name},
      where: 'remaining_credit > 0 AND expires_at <= ?',
      whereArgs: [DateTime.now().toIso8601String()],
    );
  }

  Future<DashboardSummary> getDashboardSummary() async {
    await refreshExpiredLots();
    final db = await _database.database;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final totals = await db.rawQuery('''
      SELECT
        COALESCE(SUM(charged_amount), 0) AS total_sales,
        COALESCE(SUM(new_packages_cost), 0) AS total_cost,
        COALESCE(SUM(cash_profit), 0) AS total_profit,
        COUNT(*) AS count
      FROM sales_transactions
    ''');
    final today = await db.rawQuery('''
      SELECT
        COALESCE(SUM(charged_amount), 0) AS sales,
        COALESCE(SUM(cash_profit), 0) AS profit
      FROM sales_transactions
      WHERE created_at >= ?
    ''', [dayStart]);
    final warningHours = (await getSettings()).expiryWarningHours;
    final warningEnd = now.add(Duration(hours: warningHours)).toIso8601String();
    final inventory = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN status = 'active' THEN remaining_credit ELSE 0 END), 0) AS active,
        COALESCE(SUM(CASE WHEN status = 'expired' THEN remaining_credit ELSE 0 END), 0) AS expired,
        COALESCE(SUM(CASE WHEN status = 'active' AND expires_at <= ? THEN remaining_credit ELSE 0 END), 0) AS soon
      FROM inventory_lots
    ''', [warningEnd]);
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

  Future<AppSettings> getSettings() async {
    final db = await _database.database;
    final rows = await db.query('app_settings');
    final values = <String, String>{
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
    return AppSettings(
      useThousands: values['use_thousands'] == 'true',
      darkMode: values['dark_mode'] == 'true',
      expiryWarningHours:
          math.max(1, int.tryParse(values['expiry_warning_hours'] ?? '') ?? 24),
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final db = await _database.database;
    final values = {
      'use_thousands': settings.useThousands.toString(),
      'dark_mode': settings.darkMode.toString(),
      'expiry_warning_hours': settings.expiryWarningHours.toString(),
    };
    final batch = db.batch();
    for (final entry in values.entries) {
      batch.insert(
        'app_settings',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    await _rescheduleAllNotifications(settings: settings);
  }

  Future<void> _rescheduleAllNotifications({AppSettings? settings}) async {
    final effectiveSettings = settings ?? await getSettings();
    final lots = await getInventoryLots();
    await NotificationService.instance.cancelAll();
    for (final lot in lots) {
      if (lot.status != InventoryLotStatus.active ||
          lot.remainingCredit <= 0 ||
          !lot.expiresAt.isAfter(DateTime.now())) {
        continue;
      }
      await NotificationService.instance.scheduleExpiryWarning(
        notificationId: _notificationId(lot.id),
        lotName: lot.packageNameSnapshot,
        expiresAt: lot.expiresAt,
        warningBefore: Duration(hours: effectiveSettings.expiryWarningHours),
      );
    }
  }

  int _notificationId(String value) {
    var hash = 17;
    for (final unit in value.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return hash;
  }

  Future<Map<String, Object?>> exportBackup() => _database.exportData();

  Future<void> importBackup(Map<String, Object?> payload) async {
    await _database.importData(payload);
    await refreshExpiredLots();
    await _rescheduleAllNotifications();
  }

  Future<void> resetToDefaults() async {
    await _database.resetToDefaults();
    await _rescheduleAllNotifications();
  }
}
