enum InventoryMovementDirection { inbound, outbound }

class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.lotId,
    required this.direction,
    required this.amount,
    required this.reason,
    required this.createdAt,
    this.transactionId,
  });

  final String id;
  final String lotId;
  final String? transactionId;
  final InventoryMovementDirection direction;
  final int amount;
  final String reason;
  final DateTime createdAt;

  bool get isManual => transactionId == null;

  factory InventoryMovement.fromMap(Map<String, Object?> map) {
    return InventoryMovement(
      id: map['id']! as String,
      lotId: map['lot_id']! as String,
      transactionId: map['transaction_id'] as String?,
      direction: map['direction'] == 'in'
          ? InventoryMovementDirection.inbound
          : InventoryMovementDirection.outbound,
      amount: (map['amount'] as num).toInt(),
      reason: map['reason']! as String,
      createdAt: DateTime.parse(map['created_at']! as String),
    );
  }
}
