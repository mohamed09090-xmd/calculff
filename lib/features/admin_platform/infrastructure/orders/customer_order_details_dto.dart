import '../../domain/orders/customer_order_details.dart';
import '../common/platform_payload_reader.dart';
import 'customer_order_summary_dto.dart';

class CustomerOrderDetailsDto {
  const CustomerOrderDetailsDto({
    required this.summary,
    required this.rewardUnitCodeSnapshot,
    required this.customerEmail,
    required this.customerPhone,
    required this.publicStatusMessage,
    required this.updatedAt,
    required this.completedAt,
    required this.refundStartedAt,
    required this.refundedAt,
  });

  factory CustomerOrderDetailsDto.fromMap(Map<String, Object?> payload) {
    final reader = PlatformPayloadReader(payload);
    return CustomerOrderDetailsDto(
      summary: CustomerOrderSummaryDto.fromMap(payload),
      rewardUnitCodeSnapshot: reader.requiredString(
        'reward_unit_code_snapshot',
      ),
      customerEmail: reader.requiredString('customer_email_snapshot'),
      customerPhone: reader.requiredString('customer_phone_snapshot'),
      publicStatusMessage: reader.optionalString('public_status_message'),
      updatedAt: reader.requiredDateTime('updated_at'),
      completedAt: reader.optionalDateTime('completed_at'),
      refundStartedAt: reader.optionalDateTime('refund_started_at'),
      refundedAt: reader.optionalDateTime('refunded_at'),
    );
  }

  final CustomerOrderSummaryDto summary;
  final String rewardUnitCodeSnapshot;
  final String customerEmail;
  final String customerPhone;
  final String? publicStatusMessage;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? refundStartedAt;
  final DateTime? refundedAt;

  CustomerOrderDetails toDomain() {
    return CustomerOrderDetails(
      summary: summary.toDomain(),
      rewardUnitCodeSnapshot: rewardUnitCodeSnapshot,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      publicStatusMessage: publicStatusMessage,
      updatedAt: updatedAt,
      completedAt: completedAt,
      refundStartedAt: refundStartedAt,
      refundedAt: refundedAt,
    );
  }

  @override
  String toString() {
    return 'CustomerOrderDetailsDto(displayId: ${summary.toDomain().displayId}, '
        'orderStatus: ${summary.orderStatus.wireValue}, '
        'paymentStatus: ${summary.paymentStatus.wireValue})';
  }
}
