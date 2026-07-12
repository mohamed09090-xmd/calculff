import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/core/database/app_database.dart';
import 'package:game_credit_profit_manager/features/inventory/data/inventory_adjustment_repository.dart';
import 'package:game_credit_profit_manager/shared/models/inventory_movement.dart';

import 'support/database_test_utils.dart';

void main() {
  setUpAll(initializeFfiDatabaseTests);

  late Directory directory;
  late AppDatabase database;
  late InventoryAdjustmentRepository repository;

  setUp(() async {
    directory = await createDatabaseTestDirectory('inventory_adjustment_');
    database = createTestAppDatabase(directory, 'inventory-adjustment.db');
    repository = InventoryAdjustmentRepository(
      database: database,
      scheduleNotifications: false,
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('يضيف رصيدًا يدويًا مع التكلفة والانتهاء وسجل الحركة', () async {
    final now = DateTime.now();
    final transactionId = await repository.addCredit(
      name: 'رصيد تجريبي',
      amount: 500,
      purchaseCost: 600,
      expiresAt: now.add(const Duration(days: 2)),
      note: 'إضافة اختبارية',
    );

    final db = await database.database;
    final lots = await db.query('inventory_lots');
    final transactions = await db.query(
      'sales_transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
    );

    expect(lots, hasLength(1));
    expect(lots.single['package_id'], 'manual_credit');
    expect(lots.single['purchased_credit'], 500);
    expect(lots.single['remaining_credit'], 500);
    expect(lots.single['purchase_cost'], 600);
    expect(transactions.single['product_id'],
        InventoryAdjustmentRepository.additionProductId);
    expect(transactions.single['purchased_credit'], 500);

    final movements = await repository.getMovements(lots.single['id']! as String);
    expect(movements, hasLength(1));
    expect(movements.single.direction, InventoryMovementDirection.inbound);
    expect(movements.single.amount, 500);
    expect(movements.single.reason, contains('إضافة اختبارية'));
  });

  test('يخصم الرصيد وفق FEFO ويحفظ تكلفة الجزء المحذوف', () async {
    final now = DateTime.now();
    await repository.addCredit(
      name: 'الأقرب انتهاءً',
      amount: 500,
      purchaseCost: 600,
      expiresAt: now.add(const Duration(days: 1)),
    );
    await repository.addCredit(
      name: 'الأبعد انتهاءً',
      amount: 400,
      purchaseCost: 800,
      expiresAt: now.add(const Duration(days: 5)),
    );

    final removalId = await repository.removeCredit(
      amount: 620,
      reason: 'تصحيح جرد المخزون',
    );

    final db = await database.database;
    final lots = await db.query('inventory_lots', orderBy: 'expires_at ASC');
    expect(lots[0]['remaining_credit'], 0);
    expect(lots[0]['status'], 'depleted');
    expect(lots[1]['remaining_credit'], 280);

    final removals = await db.query(
      'sales_transactions',
      where: 'id = ?',
      whereArgs: [removalId],
    );
    expect(removals.single['product_id'],
        InventoryAdjustmentRepository.removalProductId);
    expect(removals.single['inventory_credit_used'], 620);
    expect(removals.single['credit_cost_used'], 840);
    expect(removals.single['cash_profit'], -840);

    final firstMovements =
        await repository.getMovements(lots[0]['id']! as String);
    expect(
      firstMovements.any(
        (movement) =>
            movement.direction == InventoryMovementDirection.outbound &&
            movement.reason.contains('تصحيح جرد المخزون'),
      ),
      isTrue,
    );
  });

  test('يرفض خصم كمية أكبر من الرصيد الفعّال', () async {
    await repository.addCredit(
      name: 'رصيد محدود',
      amount: 100,
      purchaseCost: 100,
      expiresAt: DateTime.now().add(const Duration(days: 1)),
    );

    await expectLater(
      repository.removeCredit(
        amount: 101,
        reason: 'خصم زائد',
      ),
      throwsA(isA<StateError>()),
    );
  });
}
