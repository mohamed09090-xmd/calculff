enum InventoryLotStatus { active, depleted, expired }

class InventoryLot {
  const InventoryLot({
    required this.id,
    required this.packageId,
    required this.packageNameSnapshot,
    required this.purchasedCredit,
    required this.remainingCredit,
    required this.purchaseCost,
    required this.purchasedAt,
    required this.expiresAt,
    required this.status,
    this.sourceTransactionId,
  });

  final String id;
  final String packageId;
  final String packageNameSnapshot;
  final int purchasedCredit;
  final int remainingCredit;
  final int purchaseCost;
  final DateTime purchasedAt;
  final DateTime expiresAt;
  final InventoryLotStatus status;
  final String? sourceTransactionId;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);

  InventoryLot copyWith({int? remainingCredit, InventoryLotStatus? status}) =>
      InventoryLot(
        id: id,
        packageId: packageId,
        packageNameSnapshot: packageNameSnapshot,
        purchasedCredit: purchasedCredit,
        remainingCredit: remainingCredit ?? this.remainingCredit,
        purchaseCost: purchaseCost,
        purchasedAt: purchasedAt,
        expiresAt: expiresAt,
        status: status ?? this.status,
        sourceTransactionId: sourceTransactionId,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'package_id': packageId,
        'package_name_snapshot': packageNameSnapshot,
        'purchased_credit': purchasedCredit,
        'remaining_credit': remainingCredit,
        'purchase_cost': purchaseCost,
        'purchased_at': purchasedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'status': status.name,
        'source_transaction_id': sourceTransactionId,
      };

  factory InventoryLot.fromMap(Map<String, Object?> map) => InventoryLot(
        id: map['id']! as String,
        packageId: map['package_id']! as String,
        packageNameSnapshot: map['package_name_snapshot']! as String,
        purchasedCredit: map['purchased_credit']! as int,
        remainingCredit: map['remaining_credit']! as int,
        purchaseCost: map['purchase_cost']! as int,
        purchasedAt: DateTime.parse(map['purchased_at']! as String),
        expiresAt: DateTime.parse(map['expires_at']! as String),
        status: InventoryLotStatus.values.byName(map['status']! as String),
        sourceTransactionId: map['source_transaction_id'] as String?,
      );
}
