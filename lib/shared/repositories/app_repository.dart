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
import '../models/customer.dart';
import '../models/dashboard_summary.dart';
import '../models/inventory_lot.dart';
import '../models/product.dart';
import '../models/sales_transaction.dart';
import '../models/transaction_details.dart';

enum TransactionUndoKind { create, edit, delete }

class TransactionUndoResult {
  const TransactionUndoResult({
    required this.kind,
    required this.transactionId,
    required this.transactionExistsAfterUndo,
  });

  final TransactionUndoKind kind;
  final String transactionId;
  final bool transactionExistsAfterUndo;
}

class _TransactionUndoSnapshot {
  const _TransactionUndoSnapshot({
    required this.kind,
    required this.transactionId,
    this.transaction,
    this.items = const [],
  });

  final TransactionUndoKind kind;
  final String transactionId;
  final Map<String, Object?>? transaction;
  final List<Map<String, Object?>> items;
}

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
  _TransactionUndoSnapshot? _pendingUndo;

  bool get hasPendingTransactionUndo => _pendingUndo != null;

  String? get pendingTransactionUndoMessage => switch (_pendingUndo?.kind) {
        TransactionUndoKind.create => 'تم حفظ العملية',
        TransactionUndoKind.edit => 'تم تعديل العملية وإعادة حساب المخزون',
        TransactionUndoKind.delete => 'تم حذف العملية وإعادة حساب المخزون',
        null => null,
      };

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

  Future<List<Customer>> getCustomers({
    bool activeOnly = false,
    String? query,
  }) async {
    final db = await _database.database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (activeOnly) conditions.add('c.is_active = 1');
    final normalizedQuery = query?.trim();
    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      conditions.add('(c.name LIKE ? OR COALESCE(c.phone, \'\') LIKE ?)');
      args
        ..add('%$normalizedQuery%')
        ..add('%$normalizedQuery%');
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT
        c.*,
        COUNT(t.id) AS transaction_count,
        COALESCE(SUM(t.charged_amount), 0) AS total_spent,
        COALESCE(SUM(t.cash_profit), 0) AS total_profit,
        MAX(t.created_at) AS last_transaction_at
      FROM customers c
      LEFT JOIN sales_transactions t ON t.customer_id = c.id
      $where
      GROUP BY c.id
      ORDER BY c.is_active DESC, c.name COLLATE NOCASE
    ''', args);
    return rows.map(Customer.fromMap).toList(growable: false);
  }

  Future<Customer> saveCustomer({
    String? id,
    required String name,
    String? phone,
    String? notes,
    bool isActive = true,
  }) async {
    final normalizedName = _normalizeCustomerName(name);
    final normalizedPhone = _nullableText(phone);
    final normalizedNotes = _nullableText(notes);
    final db = await _database.database;
    final duplicate = await db.query(
      'customers',
      columns: ['id'],
      where: id == null
          ? 'LOWER(name) = LOWER(?)'
          : 'LOWER(name) = LOWER(?) AND id != ?',
      whereArgs: id == null ? [normalizedName] : [normalizedName, id],
      limit: 1,
    );
    if (duplicate.isNotEmpty) {
      throw StateError('يوجد عميل آخر بالاسم نفسه');
    }

    final now = DateTime.now();
    if (id == null) {
      final customer = Customer(
        id: IdGenerator.next('customer'),
        name: normalizedName,
        phone: normalizedPhone,
        notes: normalizedNotes,
        isActive: isActive,
        createdAt: now,
        updatedAt: now,
      );
      await db.insert('customers', customer.toMap());
      return customer;
    }

    final existing = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isEmpty) throw StateError('العميل غير موجود');
    await db.transaction((txn) async {
      await txn.update(
        'customers',
        {
          'name': normalizedName,
          'phone': normalizedPhone,
          'notes': normalizedNotes,
          'is_active': isActive ? 1 : 0,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'sales_transactions',
        {'customer_name': normalizedName},
        where: 'customer_id = ?',
        whereArgs: [id],
      );
    });
    return Customer.fromMap({
      ...existing.first,
      'name': normalizedName,
      'phone': normalizedPhone,
      'notes': normalizedNotes,
      'is_active': isActive ? 1 : 0,
      'updated_at': now.toIso8601String(),
    });
  }

  Future<void> setCustomerActive(String id, bool isActive) async {
    final db = await _database.database;
    final changed = await db.update(
      'customers',
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (changed == 0) throw StateError('العميل غير موجود');
  }

  Future<void> deleteCustomer(String id) async {
    final db = await _database.database;
    final usage = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM sales_transactions WHERE customer_id = ?',
      [id],
    );
    if ((usage.first['count'] as num).toInt() > 0) {
      throw StateError('لا يمكن حذف عميل لديه عمليات. يمكنك أرشفته بدلًا من ذلك.');
    }
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
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
    return _getActiveInventoryCredit(db, DateTime.now());
  }

  Future<int> _getActiveInventoryCredit(
    DatabaseExecutor db,
    DateTime now,
  ) async {
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(remaining_credit), 0) AS total
      FROM inventory_lots
      WHERE status = ? AND remaining_credit > 0 AND expires_at > ?
    ''', [InventoryLotStatus.active.name, now.toIso8601String()]);
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
    String? customerId,
  }) async {
    _validateSavableResult(result);
    final db = await _database.database;
    final transactionId = IdGenerator.next('txn');
    final now = DateTime.now();

    await db.transaction((txn) async {
      final customer = await _resolveCustomer(
        txn,
        customerId: customerId,
        customerName: customerName,
      );
      await _insertTransaction(
        txn,
        result: result,
        customer: customer,
        transactionId: transactionId,
        createdAt: now,
      );
    });

    _pendingUndo = _TransactionUndoSnapshot(
      kind: TransactionUndoKind.create,
      transactionId: transactionId,
    );
    await _rescheduleAllNotifications();
    return transactionId;
  }

  Future<String> editTransaction({
    required String transactionId,
    required CalculationRequest request,
    required String customerName,
    String? customerId,
  }) async {
    final db = await _database.database;
    _TransactionUndoSnapshot? undoSnapshot;

    await db.transaction((txn) async {
      final transactionRows = await txn.query(
        'sales_transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );
      if (transactionRows.isEmpty) throw StateError('العملية غير موجودة');
      final itemRows = await txn.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );
      final oldTransaction = Map<String, Object?>.from(transactionRows.first);
      undoSnapshot = _TransactionUndoSnapshot(
        kind: TransactionUndoKind.edit,
        transactionId: transactionId,
        transaction: oldTransaction,
        items: itemRows
            .map((row) => Map<String, Object?>.from(row))
            .toList(growable: false),
      );

      await txn.delete(
        'sales_transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      await _rebuildInventory(txn);

      final packageRows = await txn.query(
        'packages',
        where: 'is_active = 1',
        orderBy: 'credit ASC',
      );
      final packages = packageRows.map(CreditPackage.fromMap).toList();
      final createdAt = DateTime.parse(oldTransaction['created_at']! as String);
      final availableInventory = await _getActiveInventoryCredit(txn, createdAt);
      final result = _calculationEngine.calculate(
        request: request,
        packages: packages,
        availableInventoryCredit: availableInventory,
      );
      _validateSavableResult(result);
      final customer = await _resolveCustomer(
        txn,
        customerId: customerId,
        customerName: customerName,
      );
      await _insertTransaction(
        txn,
        result: result,
        customer: customer,
        transactionId: transactionId,
        createdAt: createdAt,
      );
    });

    _pendingUndo = undoSnapshot;
    await _rescheduleAllNotifications();
    return transactionId;
  }

  Future<void> _insertTransaction(
    DatabaseExecutor db, {
    required CalculationResult result,
    required Customer customer,
    required String transactionId,
    required DateTime createdAt,
  }) async {
    final base = SalesTransaction(
      id: transactionId,
      createdAt: createdAt,
      customerId: customer.id,
      customerName: customer.name,
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
    await db.insert('sales_transactions', base.toMap());

    final requestedFromExisting = result.request.useInventory
        ? result.inventoryCreditUsed
        : 0;
    final existingUsed = await _consumeCredit(
      db,
      amount: requestedFromExisting,
      transactionId: transactionId,
      now: createdAt,
    );

    final createdLots = <InventoryLot>[];
    for (final selection in result.optimization?.selections ?? const []) {
      await db.insert('transaction_items', {
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
          purchasedAt: createdAt.add(Duration(microseconds: createdLots.length)),
          expiresAt: createdAt.add(
            Duration(hours: selection.package.validityHours),
          ),
          status: InventoryLotStatus.active,
          sourceTransactionId: transactionId,
        );
        createdLots.add(lot);
        await db.insert('inventory_lots', lot.toMap());
        await db.insert('inventory_movements', {
          'id': IdGenerator.next('move'),
          'lot_id': lot.id,
          'transaction_id': transactionId,
          'direction': 'in',
          'amount': lot.purchasedCredit,
          'reason': 'شراء باقة ضمن العملية',
          'created_at': createdAt.toIso8601String(),
        });
      }
    }

    final remainingNeed = result.requiredCredit - existingUsed;
    final newUsed = await _consumeCredit(
      db,
      amount: remainingNeed,
      transactionId: transactionId,
      now: createdAt,
      sourceTransactionId: transactionId,
    );
    if (existingUsed + newUsed != result.requiredCredit) {
      throw StateError('الرصيد المتوفر والمقترح لا يغطي العملية كاملة');
    }
    await db.update(
      'sales_transactions',
      {
        'inventory_credit_used': existingUsed,
        'additional_credit_required': newUsed,
      },
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  void _validateSavableResult(CalculationResult result) {
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
  }

  Future<Customer> _resolveCustomer(
    DatabaseExecutor db, {
    String? customerId,
    required String customerName,
  }) async {
    final normalizedName = _normalizeCustomerName(customerName);
    if (customerId != null) {
      final selected = await db.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (selected.isNotEmpty) return Customer.fromMap(selected.first);
    }

    final existing = await db.query(
      'customers',
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [normalizedName],
      limit: 1,
    );
    if (existing.isNotEmpty) return Customer.fromMap(existing.first);

    final now = DateTime.now();
    final customer = Customer(
      id: IdGenerator.next('customer'),
      name: normalizedName,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('customers', customer.toMap());
    return customer;
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

  Future<List<SalesTransaction>> getTransactions({
    String? query,
    String? customerId,
  }) async {
    final db = await _database.database;
    final conditions = <String>[];
    final args = <Object?>[];
    final normalizedQuery = query?.trim();
    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      conditions.add('(customer_name LIKE ? OR product_name_snapshot LIKE ?)');
      args
        ..add('%$normalizedQuery%')
        ..add('%$normalizedQuery%');
    }
    if (customerId != null) {
      conditions.add('customer_id = ?');
      args.add(customerId);
    }
    final rows = await db.query(
      'sales_transactions',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: conditions.isEmpty ? null : args,
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

  Future<void> deleteTransaction(String id) => deleteTransactionWithUndo(id);

  Future<void> deleteTransactionWithUndo(String id) async {
    final db = await _database.database;
    _TransactionUndoSnapshot? undoSnapshot;
    await db.transaction((txn) async {
      final transactionRows = await txn.query(
        'sales_transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (transactionRows.isEmpty) throw StateError('العملية غير موجودة');
      final itemRows = await txn.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [id],
      );
      undoSnapshot = _TransactionUndoSnapshot(
        kind: TransactionUndoKind.delete,
        transactionId: id,
        transaction: Map<String, Object?>.from(transactionRows.first),
        items: itemRows
            .map((row) => Map<String, Object?>.from(row))
            .toList(growable: false),
      );
      await txn.delete('sales_transactions', where: 'id = ?', whereArgs: [id]);
      await _rebuildInventory(txn);
    });
    _pendingUndo = undoSnapshot;
    await _rescheduleAllNotifications();
  }

  Future<TransactionUndoResult?> undoLastTransactionChange() async {
    final snapshot = _pendingUndo;
    if (snapshot == null) return null;
    final db = await _database.database;
    await db.transaction((txn) async {
      switch (snapshot.kind) {
        case TransactionUndoKind.create:
          await txn.delete(
            'sales_transactions',
            where: 'id = ?',
            whereArgs: [snapshot.transactionId],
          );
        case TransactionUndoKind.edit:
          await txn.delete(
            'sales_transactions',
            where: 'id = ?',
            whereArgs: [snapshot.transactionId],
          );
          await txn.insert('sales_transactions', snapshot.transaction!);
          for (final item in snapshot.items) {
            await txn.insert('transaction_items', item);
          }
        case TransactionUndoKind.delete:
          await txn.insert('sales_transactions', snapshot.transaction!);
          for (final item in snapshot.items) {
            await txn.insert('transaction_items', item);
          }
      }
      await _rebuildInventory(txn);
    });
    _pendingUndo = null;
    await _rescheduleAllNotifications();
    return TransactionUndoResult(
      kind: snapshot.kind,
      transactionId: snapshot.transactionId,
      transactionExistsAfterUndo: snapshot.kind != TransactionUndoKind.create,
    );
  }

  void clearPendingTransactionUndo() => _pendingUndo = null;

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

  String _normalizeCustomerName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) throw StateError('اسم العميل مطلوب');
    if (normalized.length < 2) throw StateError('اسم العميل قصير جدًا');
    if (normalized.length > 80) {
      throw StateError('اسم العميل يجب ألا يتجاوز 80 حرفًا');
    }
    return normalized;
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Future<Map<String, Object?>> exportBackup() => _database.exportData();

  Future<void> importBackup(Map<String, Object?> payload) async {
    await _database.importData(payload);
    _pendingUndo = null;
    await refreshExpiredLots();
    await _rescheduleAllNotifications();
  }

  Future<void> resetToDefaults() async {
    await _database.resetToDefaults();
    _pendingUndo = null;
    await _rescheduleAllNotifications();
  }
}
