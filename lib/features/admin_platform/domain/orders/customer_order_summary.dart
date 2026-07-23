import 'order_enums.dart';

final RegExp _hyphenatedUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
final RegExp _compactUuidPattern = RegExp(r'^[0-9a-f]{32}$');

String customerOrderDisplayId(String id) {
  final normalized = id.toLowerCase();
  if (!_hyphenatedUuidPattern.hasMatch(normalized) &&
      !_compactUuidPattern.hasMatch(normalized)) {
    return '--------';
  }
  return normalized.replaceAll('-', '').substring(0, 8);
}

class CustomerOrderSummary {
  CustomerOrderSummary({
    required this.id,
    required this.gameNameArSnapshot,
    required this.gameNameFrSnapshot,
    required this.offerNameArSnapshot,
    required this.offerNameFrSnapshot,
    required this.customerName,
    required this.playerId,
    required this.inGameName,
    required this.salePriceDzd,
    required this.rewardQuantity,
    required this.rewardUnitNameAr,
    required this.rewardUnitNameFr,
    required this.paymentMethod,
    required this.orderStatus,
    required this.paymentStatus,
    required DateTime createdAt,
    required this.hasPaymentProof,
  }) : createdAt = createdAt.toUtc();

  final String id;
  final String gameNameArSnapshot;
  final String gameNameFrSnapshot;
  final String offerNameArSnapshot;
  final String offerNameFrSnapshot;
  final String customerName;
  final String playerId;
  final String? inGameName;
  final int salePriceDzd;
  final int rewardQuantity;
  final String rewardUnitNameAr;
  final String rewardUnitNameFr;
  final PaymentMethod paymentMethod;
  final OrderStatus orderStatus;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final bool hasPaymentProof;

  String get displayId => customerOrderDisplayId(id);

  @override
  String toString() {
    return 'CustomerOrderSummary(displayId: $displayId, '
        'orderStatus: ${orderStatus.wireValue}, '
        'paymentStatus: ${paymentStatus.wireValue})';
  }
}
