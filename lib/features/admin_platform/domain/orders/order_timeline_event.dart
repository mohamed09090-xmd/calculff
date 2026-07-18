import 'order_enums.dart';

class OrderTimelineEvent {
  OrderTimelineEvent({
    required this.eventType,
    required this.orderStatus,
    required this.paymentStatus,
    required this.publicMessage,
    required DateTime createdAt,
  }) : createdAt = createdAt.toUtc();

  final OrderTimelineEventType eventType;
  final OrderStatus orderStatus;
  final PaymentStatus paymentStatus;
  final String? publicMessage;
  final DateTime createdAt;

  @override
  String toString() {
    return 'OrderTimelineEvent(eventType: ${eventType.wireValue}, '
        'orderStatus: ${orderStatus.wireValue}, '
        'paymentStatus: ${paymentStatus.wireValue})';
  }
}
