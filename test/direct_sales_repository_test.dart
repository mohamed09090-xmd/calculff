import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/core/database/app_database.dart';
import 'package:game_credit_profit_manager/core/database/direct_sales_schema.dart';
import 'package:game_credit_profit_manager/shared/models/calculation.dart';
import 'package:game_credit_profit_manager/shared/models/inventory_lot.dart';
import 'package:game_credit_profit_manager/shared/models/product.dart';
import 'package:game_credit_profit_manager/shared/repositories/enhanced_app_repository.dart';

import 'support/database_test_utils.dart';

void main() {
  setUpAll(initializeFfiDatabaseTests);

  late Directory directory;
  late AppDatabase database;
  late EnhancedAppRepository repository;

  setUp(() async {
    directory = await createDatabaseTestDirectory('direct_sales_');
    database = createTestAppDatabase(directory, 'direct-sales.db');
    final db = await database.database;
    await DirectSalesSchema.ensure(db);
    repository = EnhancedAppRepository(database: database);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('يرقي جدول المنتجات ويحفظ منتجًا مباشرًا مع الوصف', () async {
    final db = await database.database;
    final columns = await db.rawQuery('PRAGMA table_info(products)');
    final names = columns.map((row) => row['name']).toSet();

    expect(names, contains('product_type'));
    expect(names, contains('description'));

    final product = Product(
      id: 'direct_weekly',
      name: 'اشتراك أسبوعي',
      type: ProductType.direct,
      gemsPerUnit: 0,
      creditPerUnit: 600,
      salePriceDzd: 0,
      description: 'اشتراك لمدة 7 أيام',
      createdAt: DateTime(2026, 7, 12),
      updatedAt: DateTime(2026, 7, 12),
    );
    await repository.saveProduct(product);

    final saved = (await repository.getProducts())
        .firstWhere((item) => item.id == product.id);
    expect(saved.type, ProductType.direct);
    expect(saved.creditPerUnit, 600);
    expect(saved.description, 'اشتراك لمدة 7 أيام');
  });

  test('يحسب بيع 240 رصيد بسعر 350 وتكلفة المخزون الأصلية', () async {
    final db = await database.database;
    final now = DateTime.now();
    final lot = InventoryLot(
      id: 'lot_known_cost',
      packageId: 'pkg_400',
      packageNameSnapshot: 'باقة 400 رصيد',
      purchasedCredit: 400,
      remainingCredit: 400,
      purchaseCost: 500,
      purchasedAt: now.subtract(const Duration(hours: 1)),
      expiresAt: now.add(const Duration(days: 7)),
      status: InventoryLotStatus.active,
    );
    await db.insert('inventory_lots', lot.toMap());

    final result = await repository.calculate(
      const CalculationRequest(
        mode: CalculationMode.credit,
        inputValue: 240,
        useInventory: true,
      ),
    );

    expect(result.chargedAmount, 350);
    expect(result.inventoryCreditUsed, 240);
    expect(result.additionalCreditRequired, 0);
    expect(result.creditCostUsed, 300);
    expect(result.cashProfit, 50);
  });

  test('يسعر المنتج المباشر من الرصيد المرجعي دون سعر خاص', () async {
    const product = Product(
      id: 'direct_600',
      name: 'منتج مباشر 600',
      type: ProductType.direct,
      gemsPerUnit: 0,
      creditPerUnit: 600,
      salePriceDzd: 0,
      description: 'وحدة واحدة جاهزة للتنفيذ',
    );

    final result = await repository.calculate(
      const CalculationRequest(
        mode: CalculationMode.directProduct,
        product: product,
        inputValue: 1,
        useInventory: false,
      ),
    );

    expect(result.requiredCredit, 600);
    expect(result.chargedAmount, 880);
    expect(result.customerPaid, 880);
    expect(result.units, 1);
    expect(result.gems, 0);
    expect(result.creditCostUsed, greaterThan(0));
    expect(result.cashProfit, 880 - result.creditCostUsed);
  });
}
