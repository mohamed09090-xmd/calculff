import '../../domain/orders/order_enums.dart';
import '../common/platform_payload_reader.dart';

OrderStatus readOrderStatus(PlatformPayloadReader reader, String field) {
  final parsed = OrderStatus.tryParse(reader.requiredString(field));
  if (parsed == null) {
    throw PlatformPayloadException(
      field: field,
      reason: PlatformPayloadFailureReason.invalidValue,
    );
  }
  return parsed;
}

PaymentStatus readPaymentStatus(PlatformPayloadReader reader, String field) {
  final parsed = PaymentStatus.tryParse(reader.requiredString(field));
  if (parsed == null) {
    throw PlatformPayloadException(
      field: field,
      reason: PlatformPayloadFailureReason.invalidValue,
    );
  }
  return parsed;
}

PaymentMethod readPaymentMethod(PlatformPayloadReader reader, String field) {
  final parsed = PaymentMethod.tryParse(reader.requiredString(field));
  if (parsed == null) {
    throw PlatformPayloadException(
      field: field,
      reason: PlatformPayloadFailureReason.invalidValue,
    );
  }
  return parsed;
}

OrderTimelineEventType readTimelineEventType(
  PlatformPayloadReader reader,
  String field,
) {
  final parsed = OrderTimelineEventType.tryParse(reader.requiredString(field));
  if (parsed == null) {
    throw PlatformPayloadException(
      field: field,
      reason: PlatformPayloadFailureReason.invalidValue,
    );
  }
  return parsed;
}
