import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_enums.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/platform_payload_reader.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/order_timeline_event_dto.dart';

void main() {
  group('OrderTimelineEventDto', () {
    test('maps every supported event type', () {
      for (final eventType in OrderTimelineEventType.values) {
        final payload = _timelinePayload()
          ..['event_type'] = eventType.wireValue;

        expect(OrderTimelineEventDto.fromMap(payload).eventType, eventType);
      }
    });

    test('maps only the public timeline fields in their domain roles', () {
      final event = OrderTimelineEventDto.fromMap(
        _timelinePayload(),
      ).toDomain();

      expect(event.eventType, OrderTimelineEventType.paymentChanged);
      expect(event.orderStatus, OrderStatus.processing);
      expect(event.paymentStatus, PaymentStatus.underReview);
      expect(event.publicMessage, 'Payment is under review');
      expect(event.createdAt, DateTime.utc(2026, 7, 17, 11));
    });

    test('supports a nullable public message', () {
      final payload = _timelinePayload()..['public_message'] = null;

      expect(OrderTimelineEventDto.fromMap(payload).publicMessage, isNull);
    });

    test('rejects an unknown event type safely', () {
      final payload = _timelinePayload()..['event_type'] = 'private_note';

      expect(
        () => OrderTimelineEventDto.fromMap(payload),
        throwsA(
          isA<PlatformPayloadException>()
              .having((error) => error.field, 'field', 'event_type')
              .having(
                (error) => error.reason,
                'reason',
                PlatformPayloadFailureReason.invalidValue,
              ),
        ),
      );
    });

    test('safe representations do not expose ignored identifiers', () {
      final dto = OrderTimelineEventDto.fromMap(_timelinePayload());
      const managerId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
      const orderId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

      expect(dto.toString(), isNot(contains(managerId)));
      expect(dto.toString(), isNot(contains(orderId)));
      expect(dto.toDomain().toString(), isNot(contains(managerId)));
      expect(dto.toDomain().toString(), isNot(contains(orderId)));
    });
  });
}

Map<String, Object?> _timelinePayload() {
  return <String, Object?>{
    'event_type': 'payment_changed',
    'order_status': 'processing',
    'payment_status': 'under_review',
    'public_message': 'Payment is under review',
    'created_at': '2026-07-17T12:00:00+01:00',
    'changed_by': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'order_id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'internal_note': 'must never be mapped',
  };
}
