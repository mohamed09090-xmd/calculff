import 'customer_order_summary.dart';

class CustomerOrderDetails {
  CustomerOrderDetails({
    required this.summary,
    required this.customerEmail,
    required this.customerPhone,
    required this.publicStatusMessage,
    required DateTime updatedAt,
    required DateTime? completedAt,
    required DateTime? refundStartedAt,
    required DateTime? refundedAt,
  }) : updatedAt = updatedAt.toUtc(),
       completedAt = completedAt?.toUtc(),
       refundStartedAt = refundStartedAt?.toUtc(),
       refundedAt = refundedAt?.toUtc();

  final CustomerOrderSummary summary;
  final String customerEmail;
  final String customerPhone;
  final String? publicStatusMessage;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? refundStartedAt;
  final DateTime? refundedAt;

  @override
  String toString() {
    return 'CustomerOrderDetails(displayId: ${summary.displayId}, '
        'orderStatus: ${summary.orderStatus.wireValue}, '
        'paymentStatus: ${summary.paymentStatus.wireValue})';
  }
}
