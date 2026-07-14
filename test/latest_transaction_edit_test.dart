import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/core/database/app_database.dart';
import 'package:game_credit_profit_manager/core/database/direct_sales_schema.dart';
import 'package:game_credit_profit_manager/shared/models/calculation.dart';
import 'package:game_credit_profit_manager/shared/models/credit_package.dart';
import 'package:game_credit_profit_manager/shared/models/inventory_lot.dart';
import 'package:game_credit_profit_manager/shared/models/optimization_result.dart';
import 'package:game_credit_profit_manager/shared/repositories/enhanced_app_repository.dart';

import 'support/database_test_utils.dart';

void main() {
  setUpAll(initializeFfiDatabaseTests);

  late Directory directory;
  late AppDatabase database;
  late EnhancedAppRepository repository;

  setUp(() async {
    directory = await createDatabaseTestDirectory('latest_edit_');
    database = createTestAppDatabase(directory, 'latest-edit.db');
    repository = EnhancedAppRepository(
      database: database,
      notificationsEnabled: false,
    );
    await _seedTwoTransactions(database);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('only the latest transaction is editable', () async {
    expect(await repository.isLatestTransaction('tx_old'), isFalse);
    expect(await repository.isLatestTransaction('tx_latest'), isTrue);
    expect(await repository.getEditableInventoryCredit('tx_latest'), 900);

    await expectLater(
      repository.editTransactionResult(
        transactionId: 'tx_old',
        result: _inventoryOnlyResult(requiredCredit: 400, inventoryUsed: 400),
        customerName: 'Client',
        customerId: 'customer_1',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('آخر عملية'),
        ),
      ),
    );
  });

  test('editing the latest transaction applies inventory exactly once', () async {
    await repository.editTransactionResult(
      transactionId: 'tx_latest',
      result: _inventoryOnlyResult(requiredCredit: 400, inventoryUsed: 400),
      customerName: 'Client',
      customerId: 'customer_1',
    );

    final db = await database.database;
    final inventory = await db.rawQuery(
      'SELECT COALESCE(SUM(remaining_credit), 0) AS total FROM inventory_lots',
    );
    final movements = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS total FROM inventory_movements WHERE transaction_id = ? AND direction = 'out'",
      ['tx_latest'],
    );
    final details = await repository.getTransactionDetails('tx_latest');

    expect((inventory.first['total'] as num).toInt(), 500);
    expect((movements.first['total'] as num).toInt(), 400);
    expect(details.transaction.inventoryCreditUsed, 400);
    expect(details.transaction.requiredCredit, 400);
    expect((await repository.getTransactions()).length, 2);
  });

  test('an error rolls back the old operation and its inventory effect', () async {
    final invalid = CalculationResult(
      request: const CalculationRequest(
        mode: CalculationMode.credit,
        inputValue: 1000,
        useInventory: true,
      ),
      units: 1,
      gems: 0,
      customerPaid: 1460,
      chargedAmount: 1460,
      customerChange: 0,
      requiredCredit: 1000,
      inventoryCreditUsed: 901,
      additionalCreditRequired: 99,
      optimization: OptimizationResult(
        requiredCredit: 99,
        selections: [
          PackageSelection(
            package: const CreditPackage(
              id: 'pkg_110',
              name: 'باقة 110 رصيد',
              priceDzd: 150,
              credit: 110,
              validityHours: 24,
            ),
            quantity: 1,
          ),
        ],
        totalCost: 150,
        totalCredit: 110,
        minimumValidityHours: 24,
      ),
      creditCostUsed: 0,
      cashProfit: 1460,
    );

    await expectLater(
      repository.editTransactionResult(
        transactionId: 'tx_latest',
        result: invalid,
        customerName: 'Client',
        customerId: 'customer_1',
      ),
      throwsA(isA<StateError>()),
    );

    final db = await database.database;
    final details = await repository.getTransactionDetails('tx_latest');
    final inventory = await db.rawQuery(
      'SELECT COALESCE(SUM(remaining_credit), 0) AS total FROM inventory_lots',
    );
    final movements = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) AS total FROM inventory_movements WHERE transaction_id = ? AND direction = 'out'",
      ['tx_latest'],
    );

    expect(details.transaction.requiredCredit, 240);
    expect(details.transaction.inventoryCreditUsed, 240);
    expect((inventory.first['total'] as num).toInt(), 660);
    expect((movements.first['total'] as num).toInt(), 240);
  });
}

CalculationResult _inventoryOnlyResult({
  required int requiredCredit,
  required int inventoryUsed,
}) {
  final price = ((requiredCredit * 350 + 1200) ~/ 2400) * 10;
  return CalculationResult(
    request: CalculationRequest(
      mode: CalculationMode.credit,
      inputValue: requiredCredit,
      useInventory: inventoryUsed > 0,
    ),
    units: 1,
    gems: 0,
    customerPaid: price,
    chargedAmount: price,
    customerChange: 0,
    requiredCredit: requiredCredit,
    inventoryCreditUsed: inventoryUsed,
    additionalCreditRequired: requiredCredit - inventoryUsed,
    optimization: null,
    creditCostUsed: 0,
    cashProfit: price,
  );
}

Future<void> _seedTwoTransactions(AppDatabase database) async {
  final db = await database.database;
  await DirectSalesSchema.ensure(db);
  final now = DateTime.now();
  final oldTime = now.subtract(const Duration(hours: 2));
  final latestTime = now.subtract(const Duration(hours: 1));

  await db.insert('customers', customerRow(id: 'customer_1', name: 'Client'));

  final old =
      transactionRow(
        id: 'tx_old',
        createdAt: oldTime,
        customerId: 'customer_1',
        customerName: 'Client',
      )..addAll({
        'mode': 'credit',
        'product_id': null,
        'product_name_snapshot': 'بيع رصيد مباشر',
        'input_value': 0,
        'use_inventory': 0,
        'units': 1,
        'gems': 0,
        'customer_paid': 0,
        'charged_amount': 0,
        'customer_change': 0,
        'required_credit': 0,
        'inventory_credit_used': 0,
        'additional_credit_required': 0,
        'purchased_credit': 900,
        'new_packages_cost': 1000,
        'credit_cost_used': 0,
        'cash_profit': 0,
      });
  await db.insert('sales_transactions', old);
  await db.insert('transaction_items', {
    'id': 'item_old',
    'transaction_id': 'tx_old',
    'package_id': 'pkg_900',
    'package_name_snapshot': 'باقة 900 رصيد',
    'credit_snapshot': 900,
    'price_snapshot': 1000,
    'validity_hours_snapshot': 168,
    'quantity': 1,
  });

  final latest =
      transactionRow(
        id: 'tx_latest',
        createdAt: latestTime,
        customerId: 'customer_1',
        customerName: 'Client',
        inputValue: 240,
        units: 1,
        gems: 0,
        customerPaid: 350,
        chargedAmount: 350,
        requiredCredit: 240,
        inventoryCreditUsed: 240,
        additionalCreditRequired: 0,
        purchasedCredit: 0,
        newPackagesCost: 0,
        cashProfit: 83,
      )..addAll({
        'mode': 'credit',
        'product_id': null,
        'product_name_snapshot': 'بيع رصيد مباشر',
        'credit_cost_used': 267,
      });
  await db.insert('sales_transactions', latest);

  final lot = InventoryLot(
    id: 'lot_old',
    packageId: 'pkg_900',
    packageNameSnapshot: 'باقة 900 رصيد',
    purchasedCredit: 900,
    remainingCredit: 660,
    purchaseCost: 1000,
    purchasedAt: oldTime,
    expiresAt: oldTime.add(const Duration(hours: 168)),
    status: InventoryLotStatus.active,
    sourceTransactionId: 'tx_old',
  );
  await db.insert('inventory_lots', lot.toMap());
  await db.insert('inventory_movements', {
    'id': 'move_in',
    'lot_id': 'lot_old',
    'transaction_id': 'tx_old',
    'direction': 'in',
    'amount': 900,
    'reason': 'اختبار شراء',
    'created_at': oldTime.toIso8601String(),
  });
  await db.insert('inventory_movements', {
    'id': 'move_out',
    'lot_id': 'lot_old',
    'transaction_id': 'tx_latest',
    'direction': 'out',
    'amount': 240,
    'reason': 'اختبار استهلاك',
    'created_at': latestTime.toIso8601String(),
  });
}
