import '../../domain/orders/order_internal_note.dart';
import '../common/platform_payload_reader.dart';

const int orderInternalNoteMaxLength = 2000;

class OrderInternalNoteDto {
  const OrderInternalNoteDto({
    required this.id,
    required this.orderId,
    required this.text,
    required this.createdAt,
  });

  factory OrderInternalNoteDto.fromMap(Map<String, Object?> payload) {
    final reader = PlatformPayloadReader(payload);
    final id = reader.requiredInt('id');
    if (id <= 0) {
      throw const PlatformPayloadException(
        field: 'id',
        reason: PlatformPayloadFailureReason.invalidValue,
      );
    }

    final text = reader.requiredString('note');
    if (text != text.trim() ||
        text.runes.length > orderInternalNoteMaxLength) {
      throw const PlatformPayloadException(
        field: 'note',
        reason: PlatformPayloadFailureReason.invalidValue,
      );
    }

    reader.requiredUuid('author_user_id');
    return OrderInternalNoteDto(
      id: id,
      orderId: reader.requiredUuid('order_id'),
      text: text,
      createdAt: reader.requiredDateTime('created_at'),
    );
  }

  final int id;
  final String orderId;
  final String text;
  final DateTime createdAt;

  OrderInternalNote toDomain() {
    return OrderInternalNote(text: text, createdAt: createdAt);
  }

  @override
  String toString() => 'OrderInternalNoteDto(createdAt: $createdAt)';
}
