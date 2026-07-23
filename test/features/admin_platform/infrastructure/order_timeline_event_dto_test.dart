import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_enums.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/platform_payload_reader.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/order_timeline_event_dto.dart';

void main() {
  group('OrderTimelineEventDto', () {
    test('maps every supported event type', () {
      for (final eventType in OrderTimelineEventType.values) {
        final payload = _payload()..['event_type'] = eventType.wireValue;

        expect(OrderTimelineEventDto.fromMap(payload).eventType, eventType);
      }
    });

    test('maps the public payload and normalizes the timestamp to UTC', () {
      final dto = OrderTimelineEventDto.fromMap(_payload());
      final event = dto.toDomain();

      expect(event.eventType, OrderTimelineEventType.paymentChanged);
      expect(event.orderStatus, OrderStatus.processing);
      expect(event.paymentStatus, PaymentStatus.underReview);
      expect(event.publicMessage, 'Public fixture update');
      expect(event.createdAt, DateTime.utc(2026, 7, 18, 11));
      expect(event.createdAt.isUtc, isTrue);
    });

    test('accepts a nullable public message', () {
      final dto = OrderTimelineEventDto.fromMap(
        _payload()..['public_message'] = null,
      );

      expect(dto.publicMessage, isNull);
      expect(dto.toDomain().publicMessage, isNull);
    });

    test('rejects unknown event, order, and payment enum values', () {
      for (final entry in <(String, String)>[
        ('event_type', 'private_note'),
        ('order_status', 'private_state'),
        ('payment_status', 'private_payment'),
      ]) {
        final payload = _payload()..[entry.$1] = entry.$2;
        expect(
          () => OrderTimelineEventDto.fromMap(payload),
          throwsA(
            isA<PlatformPayloadException>()
                .having((error) => error.field, 'field', entry.$1)
                .having(
                  (error) => error.reason,
                  'reason',
                  PlatformPayloadFailureReason.invalidValue,
                ),
          ),
        );
      }
    });

    test('rejects malformed timestamps and missing required fields', () {
      expect(
        () => OrderTimelineEventDto.fromMap(
          _payload()..['created_at'] = 'not-a-date',
        ),
        throwsA(isA<PlatformPayloadException>()),
      );
      expect(
        () =>
            OrderTimelineEventDto.fromMap(_payload()..remove('payment_status')),
        throwsA(isA<PlatformPayloadException>()),
      );
    });

    test(
      'safe representations omit public messages and ignored identifiers',
      () {
        final dto = OrderTimelineEventDto.fromMap(_payload());
        for (final forbidden in <String>[
          'Public fixture update',
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
          'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        ]) {
          expect(dto.toString(), isNot(contains(forbidden)));
          expect(dto.toDomain().toString(), isNot(contains(forbidden)));
        }
      },
    );
  });
}

Map<String, Object?> _payload() {
  return <String, Object?>{
    'event_type': 'payment_changed',
    'order_status': 'processing',
    'payment_status': 'under_review',
    'public_message': 'Public fixture update',
    'created_at': '2026-07-18T12:00:00+01:00',
    'changed_by': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'order_id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'internal_note': 'ignored fixture value',
  };
}
