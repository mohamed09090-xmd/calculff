import '../../domain/orders/order_enums.dart';
import '../../domain/orders/order_timeline_event.dart';
import '../common/platform_payload_reader.dart';
import 'order_payload_parsers.dart';

class OrderTimelineEventDto {
  const OrderTimelineEventDto({
    required this.eventType,
    required this.orderStatus,
    required this.paymentStatus,
    required this.publicMessage,
    required this.createdAt,
  });

  factory OrderTimelineEventDto.fromMap(Map<String, Object?> payload) {
    final reader = PlatformPayloadReader(payload);
    return OrderTimelineEventDto(
      eventType: readTimelineEventType(reader, 'event_type'),
      orderStatus: readOrderStatus(reader, 'order_status'),
      paymentStatus: readPaymentStatus(reader, 'payment_status'),
      publicMessage: reader.optionalString('public_message'),
      createdAt: reader.requiredDateTime('created_at'),
    );
  }

  final OrderTimelineEventType eventType;
  final OrderStatus orderStatus;
  final PaymentStatus paymentStatus;
  final String? publicMessage;
  final DateTime createdAt;

  OrderTimelineEvent toDomain() {
    return OrderTimelineEvent(
      eventType: eventType,
      orderStatus: orderStatus,
      paymentStatus: paymentStatus,
      publicMessage: publicMessage,
      createdAt: createdAt,
    );
  }
}
