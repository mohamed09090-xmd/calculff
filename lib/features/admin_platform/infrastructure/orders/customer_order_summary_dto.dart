import '../../domain/orders/customer_order_summary.dart';
import '../../domain/orders/order_enums.dart';
import '../common/platform_payload_reader.dart';
import 'order_payload_parsers.dart';

class CustomerOrderSummaryDto {
  const CustomerOrderSummaryDto({
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
    required this.createdAt,
    required this.hasPaymentProof,
  });

  factory CustomerOrderSummaryDto.fromMap(Map<String, Object?> payload) {
    final reader = PlatformPayloadReader(payload);
    return CustomerOrderSummaryDto(
      id: reader.requiredUuid('id'),
      gameNameArSnapshot: reader.requiredString('game_name_ar_snapshot'),
      gameNameFrSnapshot: reader.requiredString('game_name_fr_snapshot'),
      offerNameArSnapshot: reader.requiredString('offer_name_ar_snapshot'),
      offerNameFrSnapshot: reader.requiredString('offer_name_fr_snapshot'),
      customerName: reader.requiredString('customer_name_snapshot'),
      playerId: reader.requiredString('player_id'),
      inGameName: reader.optionalString('in_game_name'),
      salePriceDzd: reader.requiredInt('sale_price_dzd_snapshot'),
      rewardQuantity: reader.requiredInt('reward_quantity_snapshot'),
      rewardUnitNameAr: reader.requiredString('reward_unit_name_ar_snapshot'),
      rewardUnitNameFr: reader.requiredString('reward_unit_name_fr_snapshot'),
      paymentMethod: readPaymentMethod(reader, 'payment_method'),
      orderStatus: readOrderStatus(reader, 'order_status'),
      paymentStatus: readPaymentStatus(reader, 'payment_status'),
      createdAt: reader.requiredDateTime('created_at'),
      hasPaymentProof: reader.optionalString('payment_proof_path') != null,
    );
  }

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

  CustomerOrderSummary toDomain() {
    return CustomerOrderSummary(
      id: id,
      gameNameArSnapshot: gameNameArSnapshot,
      gameNameFrSnapshot: gameNameFrSnapshot,
      offerNameArSnapshot: offerNameArSnapshot,
      offerNameFrSnapshot: offerNameFrSnapshot,
      customerName: customerName,
      playerId: playerId,
      inGameName: inGameName,
      salePriceDzd: salePriceDzd,
      rewardQuantity: rewardQuantity,
      rewardUnitNameAr: rewardUnitNameAr,
      rewardUnitNameFr: rewardUnitNameFr,
      paymentMethod: paymentMethod,
      orderStatus: orderStatus,
      paymentStatus: paymentStatus,
      createdAt: createdAt,
      hasPaymentProof: hasPaymentProof,
    );
  }
}
