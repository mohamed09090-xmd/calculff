import '../../../shared/models/inventory_lot.dart';

class InventoryAllocation {
  const InventoryAllocation({required this.lotId, required this.amount});
  final String lotId;
  final int amount;
}

class FefoAllocationResult {
  const FefoAllocationResult({
    required this.allocations,
    required this.allocatedCredit,
    required this.uncoveredCredit,
  });

  final List<InventoryAllocation> allocations;
  final int allocatedCredit;
  final int uncoveredCredit;
}

class FefoAllocator {
  const FefoAllocator();

  FefoAllocationResult allocate({
    required int requiredCredit,
    required List<InventoryLot> lots,
    DateTime? now,
  }) {
    if (requiredCredit < 0) {
      throw ArgumentError.value(requiredCredit, 'requiredCredit');
    }
    final effectiveNow = now ?? DateTime.now();
    final eligible =
        lots
            .where(
              (lot) =>
                  lot.remainingCredit > 0 &&
                  lot.status == InventoryLotStatus.active &&
                  !lot.isExpiredAt(effectiveNow),
            )
            .toList()
          ..sort((a, b) {
            final expiry = a.expiresAt.compareTo(b.expiresAt);
            return expiry != 0
                ? expiry
                : a.purchasedAt.compareTo(b.purchasedAt);
          });

    var remaining = requiredCredit;
    final allocations = <InventoryAllocation>[];
    for (final lot in eligible) {
      if (remaining == 0) break;
      final take = lot.remainingCredit < remaining
          ? lot.remainingCredit
          : remaining;
      allocations.add(InventoryAllocation(lotId: lot.id, amount: take));
      remaining -= take;
    }
    return FefoAllocationResult(
      allocations: allocations,
      allocatedCredit: requiredCredit - remaining,
      uncoveredCredit: remaining,
    );
  }

  List<InventoryLot> applyAllocations({
    required List<InventoryLot> lots,
    required List<InventoryAllocation> allocations,
  }) {
    final byId = {for (final item in allocations) item.lotId: item.amount};
    return lots
        .map((lot) {
          final consumed = byId[lot.id] ?? 0;
          if (consumed == 0) return lot;
          if (consumed > lot.remainingCredit) {
            throw StateError('الاستهلاك أكبر من رصيد الرزمة ${lot.id}');
          }
          final remaining = lot.remainingCredit - consumed;
          return lot.copyWith(
            remainingCredit: remaining,
            status: remaining == 0
                ? InventoryLotStatus.depleted
                : InventoryLotStatus.active,
          );
        })
        .toList(growable: false);
  }

  List<InventoryLot> restoreAllocations({
    required List<InventoryLot> lots,
    required List<InventoryAllocation> allocations,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final byId = {for (final item in allocations) item.lotId: item.amount};
    return lots
        .map((lot) {
          final restored = byId[lot.id] ?? 0;
          if (restored == 0) return lot;
          final remaining = (lot.remainingCredit + restored)
              .clamp(0, lot.purchasedCredit)
              .toInt();
          return lot.copyWith(
            remainingCredit: remaining,
            status: lot.isExpiredAt(effectiveNow)
                ? InventoryLotStatus.expired
                : InventoryLotStatus.active,
          );
        })
        .toList(growable: false);
  }
}
