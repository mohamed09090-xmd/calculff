import 'order_payment_proof.dart';

abstract interface class OrderPaymentProofRepository {
  Future<OrderPaymentProof?> getPaymentProof({required String orderId});
}
