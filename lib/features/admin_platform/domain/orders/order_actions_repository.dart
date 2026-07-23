import 'order_action_result.dart';

abstract interface class OrderActionsRepository {
  Future<OrderActionResult> acceptOrder({
    required String orderId,
    String? publicMessage,
  });

  Future<OrderActionResult> rejectOrder({
    required String orderId,
    String? publicMessage,
  });
}
