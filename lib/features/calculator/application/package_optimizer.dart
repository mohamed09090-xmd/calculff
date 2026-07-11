import '../../../shared/models/credit_package.dart';
import '../../../shared/models/optimization_result.dart';

class PackageOptimizer {
  const PackageOptimizer();

  OptimizationResult optimize({
    required int requiredCredit,
    required List<CreditPackage> packages,
  }) {
    if (requiredCredit < 0) {
      throw ArgumentError.value(requiredCredit, 'requiredCredit');
    }
    if (requiredCredit == 0) {
      return const OptimizationResult(
        requiredCredit: 0,
        selections: [],
        totalCost: 0,
        totalCredit: 0,
        minimumValidityHours: 0,
      );
    }
    final active = packages
        .where((item) => item.isActive && item.credit > 0 && item.priceDzd >= 0)
        .toList(growable: false);
    if (active.isEmpty) {
      throw StateError('لا توجد باقات فعالة للاختيار منها');
    }

    final maxCredit = active
        .map((item) => item.credit)
        .reduce((left, right) => left > right ? left : right);
    final limit = requiredCredit + maxCredit - 1;
    final bestAtCredit = List<_Candidate?>.filled(limit + 1, null);
    bestAtCredit[0] = const _Candidate.empty();

    for (var total = 0; total <= limit; total++) {
      final current = bestAtCredit[total];
      if (current == null) continue;
      for (var index = 0; index < active.length; index++) {
        final package = active[index];
        final nextTotal = total + package.credit;
        if (nextTotal > limit) continue;
        final next = current.add(index, package);
        final existing = bestAtCredit[nextTotal];
        if (existing == null || _betterForExactCredit(next, existing)) {
          bestAtCredit[nextTotal] = next;
        }
      }
    }

    _Candidate? winner;
    var winnerCredit = 0;
    for (var total = requiredCredit; total <= limit; total++) {
      final candidate = bestAtCredit[total];
      if (candidate == null) continue;
      if (winner == null ||
          _betterFinal(
            candidate,
            total,
            winner,
            winnerCredit,
            requiredCredit,
          )) {
        winner = candidate;
        winnerCredit = total;
      }
    }
    if (winner == null) {
      throw StateError('تعذر تكوين الرصيد المطلوب من الباقات الحالية');
    }

    final selections = <PackageSelection>[];
    for (var index = 0; index < active.length; index++) {
      final quantity = winner.counts[index] ?? 0;
      if (quantity > 0) {
        selections.add(PackageSelection(package: active[index], quantity: quantity));
      }
    }
    selections.sort(
      (a, b) => b.package.credit.compareTo(a.package.credit),
    );
    return OptimizationResult(
      requiredCredit: requiredCredit,
      selections: selections,
      totalCost: winner.cost,
      totalCredit: winnerCredit,
      minimumValidityHours: winner.minimumValidityHours,
    );
  }

  bool _betterForExactCredit(_Candidate next, _Candidate existing) {
    if (next.cost != existing.cost) return next.cost < existing.cost;
    if (next.packageCount != existing.packageCount) {
      return next.packageCount < existing.packageCount;
    }
    if (next.minimumValidityHours != existing.minimumValidityHours) {
      return next.minimumValidityHours > existing.minimumValidityHours;
    }
    return next.validityScore > existing.validityScore;
  }

  bool _betterFinal(
    _Candidate next,
    int nextCredit,
    _Candidate existing,
    int existingCredit,
    int requiredCredit,
  ) {
    if (next.cost != existing.cost) return next.cost < existing.cost;
    final nextExcess = nextCredit - requiredCredit;
    final existingExcess = existingCredit - requiredCredit;
    if (nextExcess != existingExcess) return nextExcess < existingExcess;
    if (next.packageCount != existing.packageCount) {
      return next.packageCount < existing.packageCount;
    }
    if (next.minimumValidityHours != existing.minimumValidityHours) {
      return next.minimumValidityHours > existing.minimumValidityHours;
    }
    return next.validityScore > existing.validityScore;
  }
}

class _Candidate {
  const _Candidate({
    required this.cost,
    required this.packageCount,
    required this.minimumValidityHours,
    required this.validityScore,
    required this.counts,
  });

  const _Candidate.empty()
      : cost = 0,
        packageCount = 0,
        minimumValidityHours = 0,
        validityScore = 0,
        counts = const {};

  final int cost;
  final int packageCount;
  final int minimumValidityHours;
  final int validityScore;
  final Map<int, int> counts;

  _Candidate add(int index, CreditPackage package) {
    final nextCounts = Map<int, int>.from(counts);
    nextCounts[index] = (nextCounts[index] ?? 0) + 1;
    return _Candidate(
      cost: cost + package.priceDzd,
      packageCount: packageCount + 1,
      minimumValidityHours: packageCount == 0
          ? package.validityHours
          : (minimumValidityHours < package.validityHours
              ? minimumValidityHours
              : package.validityHours),
      validityScore: validityScore + package.validityHours,
      counts: nextCounts,
    );
  }
}
