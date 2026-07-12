import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/inventory/application/fefo_allocator.dart';
import 'package:game_credit_profit_manager/shared/models/inventory_lot.dart';

void main() {
  const allocator = FefoAllocator();
  final now = DateTime(2026, 7, 11, 12);

  InventoryLot lot({
    required String id,
    required int remaining,
    required DateTime expiresAt,
    InventoryLotStatus status = InventoryLotStatus.active,
  }) => InventoryLot(
    id: id,
    packageId: 'package_$id',
    packageNameSnapshot: 'رزمة $id',
    purchasedCredit: 100,
    remainingCredit: remaining,
    purchaseCost: 100,
    purchasedAt: now.subtract(const Duration(hours: 2)),
    expiresAt: expiresAt,
    status: status,
  );

  test('يتجاهل الرصيد المنتهي حتى إن كانت حالته active قديمة', () {
    final result = allocator.allocate(
      requiredCredit: 80,
      now: now,
      lots: [
        lot(
          id: 'expired',
          remaining: 100,
          expiresAt: now.subtract(const Duration(minutes: 1)),
        ),
        lot(
          id: 'valid',
          remaining: 100,
          expiresAt: now.add(const Duration(days: 1)),
        ),
      ],
    );

    expect(result.allocations.single.lotId, 'valid');
    expect(result.allocatedCredit, 80);
  });

  test('يستهلك الأقرب انتهاءً أولًا FEFO', () {
    final result = allocator.allocate(
      requiredCredit: 120,
      now: now,
      lots: [
        lot(
          id: 'late',
          remaining: 100,
          expiresAt: now.add(const Duration(days: 3)),
        ),
        lot(
          id: 'soon',
          remaining: 100,
          expiresAt: now.add(const Duration(hours: 3)),
        ),
      ],
    );

    expect(result.allocations.first.lotId, 'soon');
    expect(result.allocations.first.amount, 100);
    expect(result.allocations.last.lotId, 'late');
    expect(result.allocations.last.amount, 20);
  });

  test('إعادة المخزون عند حذف عملية تعيد أرصدة الرزم', () {
    final original = [
      lot(
        id: 'first',
        remaining: 100,
        expiresAt: now.add(const Duration(hours: 2)),
      ),
      lot(
        id: 'second',
        remaining: 100,
        expiresAt: now.add(const Duration(hours: 4)),
      ),
    ];
    final allocation = allocator.allocate(
      requiredCredit: 120,
      lots: original,
      now: now,
    );
    final consumed = allocator.applyAllocations(
      lots: original,
      allocations: allocation.allocations,
    );
    final restored = allocator.restoreAllocations(
      lots: consumed,
      allocations: allocation.allocations,
      now: now,
    );

    expect(consumed[0].remainingCredit, 0);
    expect(consumed[1].remainingCredit, 80);
    expect(restored[0].remainingCredit, 100);
    expect(restored[1].remainingCredit, 100);
    expect(
      restored.every((item) => item.status == InventoryLotStatus.active),
      isTrue,
    );
  });
}
