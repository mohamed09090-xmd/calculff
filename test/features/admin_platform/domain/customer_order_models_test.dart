import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/customer_order_details.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/customer_order_summary.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_enums.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_timeline_event.dart';

void main() {
  group('CustomerOrderSummary', () {
    test('keeps only the required list fields', () {
      final summary = _summary();

      expect(summary.gameNameArSnapshot, 'Game AR');
      expect(summary.gameNameFrSnapshot, 'Game FR');
      expect(summary.offerNameArSnapshot, 'Offer AR');
      expect(summary.offerNameFrSnapshot, 'Offer FR');
      expect(summary.customerName, 'Customer Name');
      expect(summary.playerId, 'player-123');
      expect(summary.salePriceDzd, 350);
      expect(summary.rewardQuantity, 100);
      expect(summary.rewardUnitNameAr, 'Unit AR');
      expect(summary.rewardUnitNameFr, 'Unit FR');
      expect(summary.paymentMethod, PaymentMethod.transfer);
      expect(summary.orderStatus, OrderStatus.processing);
      expect(summary.paymentStatus, PaymentStatus.underReview);
      expect(summary.createdAt.isUtc, isTrue);
      expect(summary.hasPaymentProof, isTrue);
    });

    test('allows a nullable in-game name', () {
      expect(_summary(inGameName: null).inGameName, isNull);
      expect(_summary(inGameName: 'Player Name').inGameName, 'Player Name');
    });

    test('derives an eight-character display id from a valid UUID', () {
      final summary = _summary(id: 'ABCDEF12-3456-7890-ABCD-EF1234567890');

      expect(summary.displayId, 'abcdef12');
    });

    test('handles an invalid id without crashing or exposing it', () {
      final summary = _summary(id: 'not-a-valid-uuid');

      expect(summary.displayId, '--------');
      expect(summary.toString(), isNot(contains('not-a-valid-uuid')));
    });

    test('exposes payment proof presence as a boolean only', () {
      expect(_summary(hasPaymentProof: true).hasPaymentProof, isTrue);
      expect(_summary(hasPaymentProof: false).hasPaymentProof, isFalse);
    });

    test('safe representation omits full UUID and personal data', () {
      final summary = _summary();
      final text = summary.toString();

      expect(text, isNot(contains(summary.id)));
      expect(text, isNot(contains(summary.customerName)));
      expect(text, isNot(contains(summary.playerId)));
    });
  });

  group('CustomerOrderDetails', () {
    test('contains detail-only contact and lifecycle fields', () {
      final details = CustomerOrderDetails(
        summary: _summary(),
        customerEmail: 'customer@example.test',
        customerPhone: '0550000000',
        publicStatusMessage: 'Public update',
        updatedAt: DateTime.parse('2026-07-17T12:00:00+01:00'),
        completedAt: DateTime.utc(2026, 7, 18),
        refundStartedAt: DateTime.utc(2026, 7, 19),
        refundedAt: DateTime.utc(2026, 7, 20),
      );

      expect(details.customerEmail, 'customer@example.test');
      expect(details.customerPhone, '0550000000');
      expect(details.publicStatusMessage, 'Public update');
      expect(details.updatedAt.isUtc, isTrue);
      expect(details.completedAt, DateTime.utc(2026, 7, 18));
      expect(details.refundStartedAt, DateTime.utc(2026, 7, 19));
      expect(details.refundedAt, DateTime.utc(2026, 7, 20));
    });

    test('allows nullable public message and lifecycle timestamps', () {
      final details = CustomerOrderDetails(
        summary: _summary(),
        customerEmail: 'customer@example.test',
        customerPhone: '0550000000',
        publicStatusMessage: null,
        updatedAt: DateTime.utc(2026, 7, 17),
        completedAt: null,
        refundStartedAt: null,
        refundedAt: null,
      );

      expect(details.publicStatusMessage, isNull);
      expect(details.completedAt, isNull);
      expect(details.refundStartedAt, isNull);
      expect(details.refundedAt, isNull);
    });

    test('safe representation omits email and phone', () {
      final details = CustomerOrderDetails(
        summary: _summary(),
        customerEmail: 'customer@example.test',
        customerPhone: '0550000000',
        publicStatusMessage: null,
        updatedAt: DateTime.utc(2026, 7, 17),
        completedAt: null,
        refundStartedAt: null,
        refundedAt: null,
      );
      final text = details.toString();

      expect(text, isNot(contains(details.customerEmail)));
      expect(text, isNot(contains(details.customerPhone)));
      expect(text, isNot(contains(details.summary.id)));
    });
  });

  group('OrderTimelineEvent', () {
    test('supports every public timeline event type', () {
      for (final eventType in OrderTimelineEventType.values) {
        final event = OrderTimelineEvent(
          eventType: eventType,
          orderStatus: OrderStatus.processing,
          paymentStatus: PaymentStatus.underReview,
          publicMessage: 'Public update',
          createdAt: DateTime.parse('2026-07-17T12:00:00+01:00'),
        );

        expect(event.eventType, eventType);
        expect(event.createdAt.isUtc, isTrue);
      }
    });

    test('allows a nullable public message', () {
      final event = OrderTimelineEvent(
        eventType: OrderTimelineEventType.created,
        orderStatus: OrderStatus.newOrder,
        paymentStatus: PaymentStatus.awaitingPayment,
        publicMessage: null,
        createdAt: DateTime.utc(2026, 7, 17),
      );

      expect(event.publicMessage, isNull);
    });

    test('safe representation contains no manager UUID', () {
      const managerId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
      final event = OrderTimelineEvent(
        eventType: OrderTimelineEventType.orderChanged,
        orderStatus: OrderStatus.accepted,
        paymentStatus: PaymentStatus.paid,
        publicMessage: 'Public update',
        createdAt: DateTime.utc(2026, 7, 17),
      );

      expect(event.toString(), isNot(contains(managerId)));
    });
  });
}

CustomerOrderSummary _summary({
  String id = '11111111-1111-1111-1111-111111111111',
  String? inGameName = 'Player Name',
  bool hasPaymentProof = true,
}) {
  return CustomerOrderSummary(
    id: id,
    gameNameArSnapshot: 'Game AR',
    gameNameFrSnapshot: 'Game FR',
    offerNameArSnapshot: 'Offer AR',
    offerNameFrSnapshot: 'Offer FR',
    customerName: 'Customer Name',
    playerId: 'player-123',
    inGameName: inGameName,
    salePriceDzd: 350,
    rewardQuantity: 100,
    rewardUnitNameAr: 'Unit AR',
    rewardUnitNameFr: 'Unit FR',
    paymentMethod: PaymentMethod.transfer,
    orderStatus: OrderStatus.processing,
    paymentStatus: PaymentStatus.underReview,
    createdAt: DateTime.parse('2026-07-17T12:00:00+01:00'),
    hasPaymentProof: hasPaymentProof,
  );
}
