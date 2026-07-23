import 'order_enums.dart';

class OrderActionResult {
  const OrderActionResult({
    required this.orderStatus,
    required this.paymentStatus,
  });

  final OrderStatus orderStatus;
  final PaymentStatus paymentStatus;
}
