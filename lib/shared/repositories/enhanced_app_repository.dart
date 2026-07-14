import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/database/direct_sales_schema.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/id_generator.dart';
import '../../features/calculator/application/calculation_engine.dart';
import '../../features/calculator/application/credit_sale_pricing.dart';
import '../../features/inventory/application/fefo_allocator.dart';
import '../models/app_settings.dart';
import '../models/calculation.dart';
import '../models/credit_package.dart';
import '../models/customer.dart';
import '../models/inventory_lot.dart';
import '../models/product.dart';
import '../models/sales_transaction.dart';
import 'app_repository.dart';

class EnhancedAppRepository extends AppRepository {
  EnhancedAppRepository({
    AppDatabase? database,
    CalculationEngine? calculationEngine,
    FefoAllocator? allocator,
    bool notificationsEnabled = true,
  }) : _database = database ?? AppDatabase.instance,
       _engine = calculationEngine ?? const CalculationEngine(),
       _allocator = allocator ?? const FefoAllocator(),
       _notificationsEnabled = notificationsEnabled,
       super(
         database: database ?? AppDatabase.instance,
         calculationEngine: calculationEngine,
         allocator: allocator,
       );

  final AppDatabase _database;
  final CalculationEngine _engine;
  final FefoAllocator _allocator;
  final bool _notificationsEnabled;
  _EnhancedUndoSnapshot? _pendingEnhancedUndo;

  @override
  bool get hasPendingTransactionUndo => _pendingEnhancedUndo != null;

  @override
  String? get pendingTransactionUndoMessage =>
      switch (_pendingEnhancedUndo?.kind) {
        TransactionUndoKind.create => 'تم حفظ العملية',
        TransactionUndoKind.edit => 'تم تعديل العملية وإعادة حساب المخزون',
        TransactionUndoKind.delete => 'تم حذف العملية وإعادة حساب المخزون',
        null => null,
      };

  @override
  Future<void> initialize() async {
    final db = await _database.database;
    await DirectSalesSchema.ensure(db);
    await super.initialize();
  }

  @override
  Future<AppSettings> getSettings() async {
    final base = await super.getSettings();
    final db = await _database.database;
    final rows = await db.query(
      'app_settings',
      where: 'key IN (?, ?)',
      whereArgs: const [
        'credit_sale_reference_credit',
        'credit_sale_reference_price_dzd',
      ],
    );
    final values = <String, String>{
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
    return base.copyWith(
      creditSaleReferenceCredit: math.max(
        1,
        int.tryParse(values['credit_sale_reference_credit'] ?? '') ?? 240,
      ),
      creditSaleReferencePriceDzd: math.max(
        1,
        int.tryParse(values['credit_sale_reference_price_dzd'] ?? '') ?? 350,
      ),
    );
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    if (settings.creditSaleReferenceCredit <= 0 ||
        settings.creditSaleReferencePriceDzd <= 0) {
      throw StateError('قيم تسعير الرصيد يجب أن تكون أكبر من صفر');
    }
    await super.saveSettings(settings);
    final db = await _database.database;
    final batch = db.batch();
    batch.insert('app_settings', {
      'key': 'credit_sale_reference_credit',
      'value': '${settings.creditSaleReferenceCredit}',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    batch.insert('app_settings', {
      'key': 'credit_sale_reference_price_dzd',
      'value': '${settings.creditSaleReferencePriceDzd}',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await batch.commit(noResult: true);
  }

  @override
  Future<CalculationResult> calculate(CalculationRequest request) async {
    final packages = await getPackages(activeOnly: true);
    final settings = await getSettings();
    final lots = await getInventoryLots();
    final now = DateTime.now();
    final available = lots
        .where(
          (lot) =>
              lot.status == InventoryLotStatus.active &&
              lot.remainingCredit > 0 &&
              !lot.isExpiredAt(now),
        )
        .fold<int>(0, (total, lot) => total + lot.remainingCredit);
    final result = _engine.calculate(
      request: request,
      packages: packages,
      availableInventoryCredit: available,
      pricing: CreditSalePricing(
        referenceCredit: settings.creditSaleReferenceCredit,
        referencePriceDzd: settings.creditSaleReferencePriceDzd,
      ),
    );
    final existingCost = request.useInventory
        ? _estimateCostFromLots(lots, result.inventoryCreditUsed, now)
        : 0;
    final newLots = _virtualLots(result, now);
    final newCost = _estimateCostFromLots(
      newLots,
      result.additionalCreditRequired,
      now,
    );
    final totalCost = existingCost + newCost;
    return result.copyWith(
      creditCostUsed: totalCost,
      cashProfit: result.chargedAmount - totalCost,
    );
  }

  Future<bool> isLatestTransaction(String transactionId) async {
    final db = await _database.database;
    final latest = await db.query(
      'sales_transactions',
      columns: ['id'],
      orderBy: 'created_at DESC, id DESC',
      limit: 1,
    );
    return latest.isNotEmpty && latest.first['id'] == transactionId;
  }

  Future<int> getEditableInventoryCredit(String transactionId) async {
    final db = await _database.database;
    final rows = await db.query(
      'sales_transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('العملية غير موجودة');
    await _assertLatestTransaction(db, transactionId);
    final transaction = SalesTransaction.fromMap(rows.first);
    final totals = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(remaining_credit), 0) AS total
      FROM inventory_lots
      WHERE remaining_credit > 0
        AND expires_at > ?
        AND (source_transaction_id IS NULL OR source_transaction_id != ?)
      ''',
      [transaction.createdAt.toIso8601String(), transactionId],
    );
    return (totals.first['total'] as num).toInt() +
        transaction.inventoryCreditUsed;
  }

  @override
  Future<String> saveTransaction(
    CalculationResult result, {
    required String customerName,
    String? customerId,
  }) async {
    _validateEnhancedResult(result);
    final db = await _database.database;
    final transactionId = IdGenerator.next('txn');
    final createdAt = DateTime.now();

    await db.transaction((txn) async {
      final customer = await _resolveCustomer(
        txn,
        customerId: customerId,
        customerName: customerName,
      );
      await _insertCalculatedTransaction(
        txn,
        result: result,
        customer: customer,
        transactionId: transactionId,
        createdAt: createdAt,
      );
    });

    _pendingEnhancedUndo = _EnhancedUndoSnapshot(
      kind: TransactionUndoKind.create,
      transactionId: transactionId,
    );
    await _rescheduleAllNotifications();
    return transactionId;
  }

  @override
  Future<String> editTransaction({
    required String transactionId,
    required CalculationRequest request,
    required String customerName,
    String? customerId,
  }) async {
    final db = await _database.database;
    _EnhancedUndoSnapshot? snapshot;

    await db.transaction((txn) async {
      final transactionRows = await txn.query(
        'sales_transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );
      if (transactionRows.isEmpty) throw StateError('العملية غير موجودة');
      await _assertLatestTransaction(txn, transactionId);
      final itemRows = await txn.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );
      snapshot = _EnhancedUndoSnapshot(
        kind: TransactionUndoKind.edit,
        transactionId: transactionId,
        transaction: Map<String, Object?>.from(transactionRows.first),
        items: itemRows
            .map((row) => Map<String, Object?>.from(row))
            .toList(growable: false),
      );
      final customer = await _resolveCustomer(
        txn,
        customerId: customerId,
        customerName: customerName,
      );
      await _replayAll(
        txn,
        replacement: _TransactionReplacement(
          transactionId: transactionId,
          request: request,
          customer: customer,
        ),
      );
    });

    _pendingEnhancedUndo = snapshot;
    await _rescheduleAllNotifications();
    return transactionId;
  }

  Future<String> editTransactionResult({
    required String transactionId,
    required CalculationResult result,
    required String customerName,
    String? customerId,
  }) async {
    _validateEnhancedResult(result);
    final db = await _database.database;
    _EnhancedUndoSnapshot? snapshot;

    await db.transaction((txn) async {
      final transactionRows = await txn.query(
        'sales_transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );
      if (transactionRows.isEmpty) throw StateError('العملية غير موجودة');
      await _assertLatestTransaction(txn, transactionId);
      final itemRows = await txn.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [transactionId],
      );
      final oldTransaction = Map<String, Object?>.from(transactionRows.first);
      snapshot = _EnhancedUndoSnapshot(
        kind: TransactionUndoKind.edit,
        transactionId: transactionId,
        transaction: oldTransaction,
        items: itemRows
            .map((row) => Map<String, Object?>.from(row))
            .toList(growable: false),
      );
      final customer = await _resolveCustomer(
        txn,
        customerId: customerId,
        customerName: customerName,
      );
      final createdAt = DateTime.parse(oldTransaction['created_at']! as String);

      await txn.delete(
        'sales_transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      await _replayAll(txn);

      final available = await _availableCredit(txn, createdAt);
      if (result.inventoryCreditUsed > available) {
        throw StateError('الرصيد المستخدم من المخزون أكبر من الرصيد المتاح');
      }
      final packageRows = await txn.query(
        'packages',
        columns: ['id'],
        where: 'is_active = 1',
      );
      final registeredIds = packageRows.map((row) => row['id']).toSet();
      final selections = result.optimization?.selections ?? const [];
      if (selections.any(
        (selection) => !registeredIds.contains(selection.package.id),
      )) {
        throw StateError('يمكن استخدام الباقات المسجلة والفعالة فقط');
      }

      await _insertCalculatedTransaction(
        txn,
        result: result,
        customer: customer,
        transactionId: transactionId,
        createdAt: createdAt,
      );
    });

    _pendingEnhancedUndo = snapshot;
    await _rescheduleAllNotifications();
    return transactionId;
  }

  @override
  Future<void> deleteTransaction(String id) => deleteTransactionWithUndo(id);

  @override
  Future<void> deleteTransactionWithUndo(String id) async {
    final db = await _database.database;
    _EnhancedUndoSnapshot? snapshot;
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
      snapshot = _EnhancedUndoSnapshot(
        kind: TransactionUndoKind.delete,
        transactionId: id,
        transaction: Map<String, Object?>.from(transactionRows.first),
        items: itemRows
            .map((row) => Map<String, Object?>.from(row))
            .toList(growable: false),
      );
      await txn.delete('sales_transactions', where: 'id = ?', whereArgs: [id]);
      await _replayAll(txn);
    });
    _pendingEnhancedUndo = snapshot;
    await _rescheduleAllNotifications();
  }

  @override
  Future<TransactionUndoResult?> undoLastTransactionChange() async {
    final snapshot = _pendingEnhancedUndo;
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
      await _replayAll(txn);
    });
    _pendingEnhancedUndo = null;
    await _rescheduleAllNotifications();
    return TransactionUndoResult(
      kind: snapshot.kind,
      transactionId: snapshot.transactionId,
      transactionExistsAfterUndo: snapshot.kind != TransactionUndoKind.create,
    );
  }

  @override
  void clearPendingTransactionUndo() => _pendingEnhancedUndo = null;

  @override
  Future<void> importBackup(Map<String, Object?> payload) async {
    await super.importBackup(payload);
    final db = await _database.database;
    await DirectSalesSchema.ensure(db);
    await DirectSalesSchema.normalizeLegacyTransactions(db);
    _pendingEnhancedUndo = null;
  }

  @override
  Future<void> resetToDefaults() async {
    await super.resetToDefaults();
    final db = await _database.database;
    await DirectSalesSchema.ensure(db);
    _pendingEnhancedUndo = null;
  }

  Future<void> _insertCalculatedTransaction(
    DatabaseExecutor db, {
    required CalculationResult result,
    required Customer customer,
    required String transactionId,
    required DateTime createdAt,
  }) async {
    final product = result.request.product;
    final productName =
        product?.name ??
        (result.request.mode == CalculationMode.credit
            ? 'بيع رصيد مباشر'
            : null);
    final base = SalesTransaction(
      id: transactionId,
      createdAt: createdAt,
      customerId: customer.id,
      customerName: customer.name,
      mode: result.request.mode,
      productId: product?.id,
      productNameSnapshot: productName,
      productDescriptionSnapshot: product?.description,
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
      creditCostUsed: 0,
      cashProfit: result.chargedAmount,
    );
    await db.insert('sales_transactions', base.toMap());
    await _applyCalculatedInventory(
      db,
      result: result,
      transactionId: transactionId,
      createdAt: createdAt,
    );
  }

  Future<void> _applyCalculatedInventory(
    DatabaseExecutor db, {
    required CalculationResult result,
    required String transactionId,
    required DateTime createdAt,
  }) async {
    final requestedExisting = result.request.useInventory
        ? result.inventoryCreditUsed
        : 0;
    final existing = await _consumeCredit(
      db,
      amount: requestedExisting,
      transactionId: transactionId,
      now: createdAt,
    );

    await _insertPackageItemsAndLots(
      db,
      transactionId: transactionId,
      createdAt: createdAt,
      selections: result.optimization?.selections ?? const [],
    );

    final remainingNeed = result.requiredCredit - existing.amount;
    final newlyPurchased = await _consumeCredit(
      db,
      amount: remainingNeed,
      transactionId: transactionId,
      now: createdAt,
      sourceTransactionId: transactionId,
    );
    if (existing.amount + newlyPurchased.amount != result.requiredCredit) {
      throw StateError('الرصيد المتوفر والمقترح لا يغطي العملية كاملة');
    }
    final totalCost = existing.cost + newlyPurchased.cost;
    await db.update(
      'sales_transactions',
      {
        'inventory_credit_used': existing.amount,
        'additional_credit_required': newlyPurchased.amount,
        'credit_cost_used': totalCost,
        'cash_profit': result.chargedAmount - totalCost,
      },
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<void> _replayAll(
    DatabaseExecutor db, {
    _TransactionReplacement? replacement,
  }) async {
    final transactionRows = await db.query(
      'sales_transactions',
      orderBy: 'created_at ASC, id ASC',
    );
    final allItems = await db.query('transaction_items');
    final itemsByTransaction = <String, List<Map<String, Object?>>>{};
    for (final item in allItems) {
      final id = item['transaction_id']! as String;
      itemsByTransaction
          .putIfAbsent(id, () => [])
          .add(Map<String, Object?>.from(item));
    }
    final packageRows = await db.query(
      'packages',
      where: 'is_active = 1',
      orderBy: 'credit ASC',
    );
    final packages = packageRows.map(CreditPackage.fromMap).toList();
    final settings = await _settingsFromExecutor(db);
    final pricing = CreditSalePricing(
      referenceCredit: settings.creditSaleReferenceCredit,
      referencePriceDzd: settings.creditSaleReferencePriceDzd,
    );

    await db.delete('inventory_movements');
    await db.delete('inventory_lots');

    var replacementFound = replacement == null;
    for (final row in transactionRows) {
      final transactionId = row['id']! as String;
      final createdAt = DateTime.parse(row['created_at']! as String);
      if (replacement != null && transactionId == replacement.transactionId) {
        replacementFound = true;
        final available = await _availableCredit(db, createdAt);
        final result = _engine.calculate(
          request: replacement.request,
          packages: packages,
          availableInventoryCredit: available,
          pricing: pricing,
        );
        _validateEnhancedResult(result);
        await db.delete(
          'transaction_items',
          where: 'transaction_id = ?',
          whereArgs: [transactionId],
        );
        final product = result.request.product;
        final updated = SalesTransaction(
          id: transactionId,
          createdAt: createdAt,
          customerId: replacement.customer.id,
          customerName: replacement.customer.name,
          mode: result.request.mode,
          productId: product?.id,
          productNameSnapshot:
              product?.name ??
              (result.request.mode == CalculationMode.credit
                  ? 'بيع رصيد مباشر'
                  : null),
          productDescriptionSnapshot: product?.description,
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
          creditCostUsed: 0,
          cashProfit: result.chargedAmount,
        );
        await db.update(
          'sales_transactions',
          updated.toMap()..remove('id'),
          where: 'id = ?',
          whereArgs: [transactionId],
        );
        await _applyCalculatedInventory(
          db,
          result: result,
          transactionId: transactionId,
          createdAt: createdAt,
        );
        continue;
      }

      final transaction = SalesTransaction.fromMap(row);
      await _replayStoredTransaction(
        db,
        transaction: transaction,
        items: itemsByTransaction[transactionId] ?? const [],
      );
    }
    if (!replacementFound) {
      throw StateError('العملية المطلوب تعديلها غير موجودة');
    }
  }

  Future<void> _replayStoredTransaction(
    DatabaseExecutor db, {
    required SalesTransaction transaction,
    required List<Map<String, Object?>> items,
  }) async {
    final available = await _availableCredit(db, transaction.createdAt);
    final requestedExisting = transaction.useInventory
        ? math.min(available, transaction.requiredCredit)
        : 0;
    final existing = await _consumeCredit(
      db,
      amount: requestedExisting,
      transactionId: transaction.id,
      now: transaction.createdAt,
    );

    var purchasedCredit = 0;
    var packageCost = 0;
    var lotIndex = 0;
    for (final item in items) {
      final credit = (item['credit_snapshot'] as num).toInt();
      final price = (item['price_snapshot'] as num).toInt();
      final validity = (item['validity_hours_snapshot'] as num).toInt();
      final quantity = (item['quantity'] as num).toInt();
      purchasedCredit += credit * quantity;
      packageCost += price * quantity;
      for (var index = 0; index < quantity; index++) {
        final lot = InventoryLot(
          id: IdGenerator.next('lot'),
          packageId: item['package_id']! as String,
          packageNameSnapshot: item['package_name_snapshot']! as String,
          purchasedCredit: credit,
          remainingCredit: credit,
          purchaseCost: price,
          purchasedAt: transaction.createdAt.add(
            Duration(microseconds: lotIndex++),
          ),
          expiresAt: transaction.createdAt.add(Duration(hours: validity)),
          status: InventoryLotStatus.active,
          sourceTransactionId: transaction.id,
        );
        await _insertLot(db, lot, transaction.createdAt, transaction.id);
      }
    }

    final remainingNeed = transaction.requiredCredit - existing.amount;
    final newlyPurchased = await _consumeCredit(
      db,
      amount: remainingNeed,
      transactionId: transaction.id,
      now: transaction.createdAt,
      sourceTransactionId: transaction.id,
    );
    if (existing.amount + newlyPurchased.amount != transaction.requiredCredit) {
      throw StateError('تعذر إعادة بناء المخزون للعملية ${transaction.id}');
    }
    final totalCost = existing.cost + newlyPurchased.cost;
    await db.update(
      'sales_transactions',
      {
        'inventory_credit_used': existing.amount,
        'additional_credit_required': newlyPurchased.amount,
        'purchased_credit': purchasedCredit,
        'new_packages_cost': packageCost,
        'credit_cost_used': totalCost,
        'cash_profit': transaction.chargedAmount - totalCost,
      },
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> _insertPackageItemsAndLots(
    DatabaseExecutor db, {
    required String transactionId,
    required DateTime createdAt,
    required Iterable<dynamic> selections,
  }) async {
    var lotIndex = 0;
    for (final selection in selections) {
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
      for (var index = 0; index < selection.quantity; index++) {
        final lot = InventoryLot(
          id: IdGenerator.next('lot'),
          packageId: selection.package.id,
          packageNameSnapshot: selection.package.name,
          purchasedCredit: selection.package.credit,
          remainingCredit: selection.package.credit,
          purchaseCost: selection.package.priceDzd,
          purchasedAt: createdAt.add(Duration(microseconds: lotIndex++)),
          expiresAt: createdAt.add(
            Duration(hours: selection.package.validityHours),
          ),
          status: InventoryLotStatus.active,
          sourceTransactionId: transactionId,
        );
        await _insertLot(db, lot, createdAt, transactionId);
      }
    }
  }

  Future<void> _insertLot(
    DatabaseExecutor db,
    InventoryLot lot,
    DateTime createdAt,
    String transactionId,
  ) async {
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

  Future<_CreditConsumption> _consumeCredit(
    DatabaseExecutor db, {
    required int amount,
    required String transactionId,
    required DateTime now,
    String? sourceTransactionId,
  }) async {
    if (amount <= 0) return const _CreditConsumption();
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
    var cost = 0;
    for (final item in allocation.allocations) {
      final lot = lots.firstWhere((candidate) => candidate.id == item.lotId);
      cost += _allocatedCost(lot, item.amount);
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
    return _CreditConsumption(amount: allocation.allocatedCredit, cost: cost);
  }

  int _allocatedCost(InventoryLot lot, int amount) {
    final consumedBefore = lot.purchasedCredit - lot.remainingCredit;
    final consumedAfter = consumedBefore + amount;
    final costBefore =
        ((lot.purchaseCost * consumedBefore) / lot.purchasedCredit).round();
    final costAfter = ((lot.purchaseCost * consumedAfter) / lot.purchasedCredit)
        .round();
    return costAfter - costBefore;
  }

  int _estimateCostFromLots(List<InventoryLot> lots, int amount, DateTime now) {
    if (amount <= 0) return 0;
    final allocation = _allocator.allocate(
      requiredCredit: amount,
      lots: lots,
      now: now,
    );
    var cost = 0;
    for (final item in allocation.allocations) {
      final lot = lots.firstWhere((candidate) => candidate.id == item.lotId);
      cost += _allocatedCost(lot, item.amount);
    }
    return cost;
  }

  List<InventoryLot> _virtualLots(CalculationResult result, DateTime now) {
    final lots = <InventoryLot>[];
    var index = 0;
    for (final selection in result.optimization?.selections ?? const []) {
      for (var quantity = 0; quantity < selection.quantity; quantity++) {
        lots.add(
          InventoryLot(
            id: 'estimate_${index++}',
            packageId: selection.package.id,
            packageNameSnapshot: selection.package.name,
            purchasedCredit: selection.package.credit,
            remainingCredit: selection.package.credit,
            purchaseCost: selection.package.priceDzd,
            purchasedAt: now.add(Duration(microseconds: index)),
            expiresAt: now.add(
              Duration(hours: selection.package.validityHours),
            ),
            status: InventoryLotStatus.active,
          ),
        );
      }
    }
    return lots;
  }

  Future<void> _assertLatestTransaction(
    DatabaseExecutor db,
    String transactionId,
  ) async {
    final latest = await db.query(
      'sales_transactions',
      columns: ['id'],
      orderBy: 'created_at DESC, id DESC',
      limit: 1,
    );
    if (latest.isEmpty || latest.first['id'] != transactionId) {
      throw StateError('يمكن تعديل آخر عملية محفوظة فقط');
    }
  }

  Future<int> _availableCredit(DatabaseExecutor db, DateTime at) async {
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(remaining_credit), 0) AS total
      FROM inventory_lots
      WHERE status = ? AND remaining_credit > 0 AND expires_at > ?
    ''',
      [InventoryLotStatus.active.name, at.toIso8601String()],
    );
    return (rows.first['total'] as num).toInt();
  }

  Future<Customer> _resolveCustomer(
    DatabaseExecutor db, {
    String? customerId,
    required String customerName,
  }) async {
    final normalized = customerName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2) throw StateError('اسم العميل قصير جدًا');
    if (normalized.length > 80) {
      throw StateError('اسم العميل يجب ألا يتجاوز 80 حرفًا');
    }
    if (customerId != null) {
      final rows = await db.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (rows.isNotEmpty) return Customer.fromMap(rows.first);
    }
    final existing = await db.query(
      'customers',
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [normalized],
      limit: 1,
    );
    if (existing.isNotEmpty) return Customer.fromMap(existing.first);
    final now = DateTime.now();
    final customer = Customer(
      id: IdGenerator.next('customer'),
      name: normalized,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('customers', customer.toMap());
    return customer;
  }

  void _validateEnhancedResult(CalculationResult result) {
    if (result.requiredCredit <= 0) {
      throw StateError('لا يمكن حفظ عملية بلا رصيد مطلوب');
    }
    if (result.units < 0 ||
        result.gems < 0 ||
        result.customerPaid < 0 ||
        result.chargedAmount < 0 ||
        result.customerChange < 0 ||
        result.inventoryCreditUsed < 0 ||
        result.additionalCreditRequired < 0) {
      throw StateError('لا يمكن حفظ أرقام سالبة أو غير صالحة');
    }
    if (result.customerChange > result.customerPaid) {
      throw StateError('المبلغ المعاد أكبر من المبلغ المدفوع');
    }
    if (result.additionalCreditRequired !=
        result.requiredCredit - result.inventoryCreditUsed) {
      throw StateError('قيم المخزون والرصيد المطلوب غير متسقة');
    }
    if (result.inventoryCreditUsed > 0 && !result.request.useInventory) {
      throw StateError('تخصيص استخدام المخزون غير متسق');
    }
    if (result.purchasedCredit < result.additionalCreditRequired) {
      throw StateError('خطة الباقات لا تغطي الرصيد المطلوب');
    }
    final selections = result.optimization?.selections ?? const [];
    final packageCount = selections.fold<int>(
      0,
      (total, selection) => total + selection.quantity,
    );
    if (selections.any(
          (selection) => selection.quantity <= 0 || selection.quantity > 999,
        ) ||
        packageCount > 9999) {
      throw StateError('عدد الحزم أو الباقات غير منطقي');
    }
    if (result.request.mode == CalculationMode.gems &&
        result.gems != result.request.inputValue) {
      throw StateError(
        'عدّل عدد الجواهر إلى كمية متوافقة مع حزمة المنتج قبل الحفظ',
      );
    }
    if (result.request.mode == CalculationMode.directProduct &&
        result.request.product?.type != ProductType.direct) {
      throw StateError('اختر منتجًا مباشرًا صالحًا');
    }
  }

  Future<AppSettings> _settingsFromExecutor(DatabaseExecutor db) async {
    final rows = await db.query('app_settings');
    final values = <String, String>{
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
    return AppSettings(
      useThousands: values['use_thousands'] == 'true',
      darkMode: values['dark_mode'] == 'true',
      expiryWarningHours: math.max(
        1,
        int.tryParse(values['expiry_warning_hours'] ?? '') ?? 24,
      ),
      creditSaleReferenceCredit: math.max(
        1,
        int.tryParse(values['credit_sale_reference_credit'] ?? '') ?? 240,
      ),
      creditSaleReferencePriceDzd: math.max(
        1,
        int.tryParse(values['credit_sale_reference_price_dzd'] ?? '') ?? 350,
      ),
    );
  }

  Future<void> _rescheduleAllNotifications() async {
    if (!_notificationsEnabled) return;
    final settings = await getSettings();
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
        warningBefore: Duration(hours: settings.expiryWarningHours),
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
}

class _CreditConsumption {
  const _CreditConsumption({this.amount = 0, this.cost = 0});

  final int amount;
  final int cost;
}

class _EnhancedUndoSnapshot {
  const _EnhancedUndoSnapshot({
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

class _TransactionReplacement {
  const _TransactionReplacement({
    required this.transactionId,
    required this.request,
    required this.customer,
  });

  final String transactionId;
  final CalculationRequest request;
  final Customer customer;
}
