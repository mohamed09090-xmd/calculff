import 'dart:math' as math;

import '../../../core/database/app_database.dart';
import '../../../core/database/direct_sales_schema.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/id_generator.dart';
import '../../../shared/models/calculation.dart';
import '../../../shared/models/inventory_lot.dart';
import '../../../shared/models/inventory_movement.dart';
import '../../../shared/models/sales_transaction.dart';
import '../application/fefo_allocator.dart';

class InventoryAdjustmentRepository {
  InventoryAdjustmentRepository({
    AppDatabase? database,
    FefoAllocator? allocator,
    NotificationService? notificationService,
    bool scheduleNotifications = true,
  }) : _database = database ?? AppDatabase.instance,
       _allocator = allocator ?? const FefoAllocator(),
       _notificationService = scheduleNotifications
           ? (notificationService ?? NotificationService.instance)
           : null;

  static const additionProductId = '__inventory_adjustment_add__';
  static const removalProductId = '__inventory_adjustment_remove__';

  final AppDatabase _database;
  final FefoAllocator _allocator;
  final NotificationService? _notificationService;

  Future<String> addCredit({
    required String name,
    required int amount,
    required int purchaseCost,
    required DateTime expiresAt,
    String? note,
  }) async {
    final normalizedName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    final normalizedNote = note?.trim().replaceAll(RegExp(r'\s+'), ' ');
    final now = DateTime.now();

    if (normalizedName.length < 2 || normalizedName.length > 80) {
      throw StateError('اسم الرصيد يجب أن يكون بين حرفين و80 حرفًا');
    }
    if (amount <= 0) throw StateError('كمية الرصيد يجب أن تكون أكبر من صفر');
    if (purchaseCost < 0)
      throw StateError('تكلفة الشراء لا يمكن أن تكون سالبة');
    if (!expiresAt.isAfter(now)) {
      throw StateError('تاريخ الانتهاء يجب أن يكون بعد الوقت الحالي');
    }

    final db = await _database.database;
    await DirectSalesSchema.ensure(db);
    final transactionId = IdGenerator.next('inventory_add');
    final lotId = IdGenerator.next('lot');
    final validityMinutes = expiresAt.difference(now).inMinutes;
    final validityHours = math.max(1, (validityMinutes + 59) ~/ 60);
    final reason = normalizedNote == null || normalizedNote.isEmpty
        ? 'إضافة رصيد يدويًا'
        : 'إضافة رصيد يدويًا: $normalizedNote';

    await db.transaction((txn) async {
      final transaction = SalesTransaction(
        id: transactionId,
        createdAt: now,
        customerId: null,
        customerName: 'تعديل مخزون',
        mode: CalculationMode.credit,
        productId: additionProductId,
        productNameSnapshot: normalizedName,
        productDescriptionSnapshot: normalizedNote,
        inputValue: amount,
        useInventory: false,
        units: 1,
        gems: 0,
        customerPaid: 0,
        chargedAmount: 0,
        customerChange: 0,
        requiredCredit: 0,
        inventoryCreditUsed: 0,
        additionalCreditRequired: 0,
        purchasedCredit: amount,
        newPackagesCost: purchaseCost,
        creditCostUsed: 0,
        cashProfit: 0,
      );
      await txn.insert('sales_transactions', transaction.toMap());
      await txn.insert('transaction_items', {
        'id': IdGenerator.next('item'),
        'transaction_id': transactionId,
        'package_id': 'manual_credit',
        'package_name_snapshot': normalizedName,
        'credit_snapshot': amount,
        'price_snapshot': purchaseCost,
        'validity_hours_snapshot': validityHours,
        'quantity': 1,
      });

      final lot = InventoryLot(
        id: lotId,
        packageId: 'manual_credit',
        packageNameSnapshot: normalizedName,
        purchasedCredit: amount,
        remainingCredit: amount,
        purchaseCost: purchaseCost,
        purchasedAt: now,
        expiresAt: expiresAt,
        status: InventoryLotStatus.active,
        sourceTransactionId: transactionId,
      );
      await txn.insert('inventory_lots', lot.toMap());
      await txn.insert('inventory_movements', {
        'id': IdGenerator.next('move'),
        'lot_id': lotId,
        'transaction_id': transactionId,
        'direction': 'in',
        'amount': amount,
        'reason': reason,
        'created_at': now.toIso8601String(),
      });
    });

    await _rescheduleNotifications();
    return transactionId;
  }

  Future<String> removeCredit({
    required int amount,
    required String reason,
  }) async {
    final normalizedReason = reason.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (amount <= 0) throw StateError('كمية الخصم يجب أن تكون أكبر من صفر');
    if (normalizedReason.length < 2 || normalizedReason.length > 160) {
      throw StateError('اكتب سببًا واضحًا بين حرفين و160 حرفًا');
    }

    final db = await _database.database;
    await DirectSalesSchema.ensure(db);
    final now = DateTime.now();
    final rows = await db.query(
      'inventory_lots',
      where: 'remaining_credit > 0 AND status = ? AND expires_at > ?',
      whereArgs: [InventoryLotStatus.active.name, now.toIso8601String()],
      orderBy: 'expires_at ASC, purchased_at ASC',
    );
    final lots = rows.map(InventoryLot.fromMap).toList(growable: false);
    final allocation = _allocator.allocate(
      requiredCredit: amount,
      lots: lots,
      now: now,
    );
    if (allocation.allocatedCredit != amount) {
      throw StateError(
        'الرصيد الفعّال غير كافٍ. المتاح حاليًا ${allocation.allocatedCredit} فقط.',
      );
    }

    final transactionId = IdGenerator.next('inventory_remove');
    var creditCost = 0;
    await db.transaction((txn) async {
      final transaction = SalesTransaction(
        id: transactionId,
        createdAt: now,
        customerId: null,
        customerName: 'تعديل مخزون',
        mode: CalculationMode.credit,
        productId: removalProductId,
        productNameSnapshot: 'خصم يدوي من المخزون',
        productDescriptionSnapshot: normalizedReason,
        inputValue: amount,
        useInventory: true,
        units: 1,
        gems: 0,
        customerPaid: 0,
        chargedAmount: 0,
        customerChange: 0,
        requiredCredit: amount,
        inventoryCreditUsed: amount,
        additionalCreditRequired: 0,
        purchasedCredit: 0,
        newPackagesCost: 0,
        creditCostUsed: 0,
        cashProfit: 0,
      );
      await txn.insert('sales_transactions', transaction.toMap());

      for (final item in allocation.allocations) {
        final lot = lots.firstWhere((candidate) => candidate.id == item.lotId);
        creditCost += _allocatedCost(lot, item.amount);
        final remaining = lot.remainingCredit - item.amount;
        await txn.update(
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
        await txn.insert('inventory_movements', {
          'id': IdGenerator.next('move'),
          'lot_id': lot.id,
          'transaction_id': transactionId,
          'direction': 'out',
          'amount': item.amount,
          'reason': 'خصم يدوي: $normalizedReason',
          'created_at': now.toIso8601String(),
        });
      }

      await txn.update(
        'sales_transactions',
        {'credit_cost_used': creditCost, 'cash_profit': -creditCost},
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });

    await _rescheduleNotifications();
    return transactionId;
  }

  Future<List<InventoryMovement>> getMovements(String lotId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        m.id,
        m.lot_id,
        m.transaction_id,
        m.direction,
        m.amount,
        CASE
          WHEN t.product_id = ? THEN
            'إضافة رصيد يدويًا' ||
            CASE
              WHEN COALESCE(t.product_description_snapshot, '') = '' THEN ''
              ELSE ': ' || t.product_description_snapshot
            END
          WHEN t.product_id = ? THEN
            'خصم يدوي: ' || COALESCE(t.product_description_snapshot, 'بدون سبب')
          ELSE m.reason
        END AS reason,
        m.created_at
      FROM inventory_movements m
      LEFT JOIN sales_transactions t ON t.id = m.transaction_id
      WHERE m.lot_id = ?
      ORDER BY m.created_at DESC, m.id DESC
    ''',
      [additionProductId, removalProductId, lotId],
    );
    return rows.map(InventoryMovement.fromMap).toList(growable: false);
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

  Future<void> _rescheduleNotifications() async {
    final service = _notificationService;
    if (service == null) return;
    final db = await _database.database;
    final settingRows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: const ['expiry_warning_hours'],
      limit: 1,
    );
    final warningHours = settingRows.isEmpty
        ? 24
        : int.tryParse(settingRows.first['value']! as String) ?? 24;
    final now = DateTime.now();
    final rows = await db.query(
      'inventory_lots',
      where: 'status = ? AND remaining_credit > 0 AND expires_at > ?',
      whereArgs: [InventoryLotStatus.active.name, now.toIso8601String()],
    );

    await service.cancelAll();
    for (final row in rows) {
      final lot = InventoryLot.fromMap(row);
      await service.scheduleExpiryWarning(
        notificationId: _notificationId(lot.id),
        lotName: lot.packageNameSnapshot,
        expiresAt: lot.expiresAt,
        warningBefore: Duration(hours: warningHours),
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
