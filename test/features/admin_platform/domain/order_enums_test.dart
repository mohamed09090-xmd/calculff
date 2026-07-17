import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_enums.dart';

void main() {
  group('OrderStatus', () {
    test('contains all six PostgreSQL values', () {
      expect(OrderStatus.values, <OrderStatus>[
        OrderStatus.newOrder,
        OrderStatus.accepted,
        OrderStatus.processing,
        OrderStatus.completed,
        OrderStatus.rejected,
        OrderStatus.cancelled,
      ]);
      expect(OrderStatus.newOrder.wireValue, 'new');
      expect(OrderStatus.accepted.wireValue, 'accepted');
      expect(OrderStatus.processing.wireValue, 'processing');
      expect(OrderStatus.completed.wireValue, 'completed');
      expect(OrderStatus.rejected.wireValue, 'rejected');
      expect(OrderStatus.cancelled.wireValue, 'cancelled');
    });

    test('parses known values and safely rejects unknown values', () {
      for (final status in OrderStatus.values) {
        expect(OrderStatus.tryParse(status.wireValue), status);
      }
      expect(OrderStatus.tryParse('unknown'), isNull);
      expect(OrderStatus.tryParse(null), isNull);
    });
  });

  group('PaymentStatus', () {
    test('contains all six PostgreSQL values', () {
      expect(PaymentStatus.values, <PaymentStatus>[
        PaymentStatus.awaitingPayment,
        PaymentStatus.underReview,
        PaymentStatus.paid,
        PaymentStatus.proofRejected,
        PaymentStatus.refundPending,
        PaymentStatus.refunded,
      ]);
      expect(PaymentStatus.awaitingPayment.wireValue, 'awaiting_payment');
      expect(PaymentStatus.underReview.wireValue, 'under_review');
      expect(PaymentStatus.paid.wireValue, 'paid');
      expect(PaymentStatus.proofRejected.wireValue, 'proof_rejected');
      expect(PaymentStatus.refundPending.wireValue, 'refund_pending');
      expect(PaymentStatus.refunded.wireValue, 'refunded');
    });

    test('parses known values and safely rejects unknown values', () {
      for (final status in PaymentStatus.values) {
        expect(PaymentStatus.tryParse(status.wireValue), status);
      }
      expect(PaymentStatus.tryParse('unknown'), isNull);
      expect(PaymentStatus.tryParse(null), isNull);
    });
  });

  group('PaymentMethod', () {
    test('contains both PostgreSQL values', () {
      expect(PaymentMethod.values, <PaymentMethod>[
        PaymentMethod.cash,
        PaymentMethod.transfer,
      ]);
      expect(PaymentMethod.cash.wireValue, 'cash');
      expect(PaymentMethod.transfer.wireValue, 'transfer');
    });

    test('parses known values and safely rejects unknown values', () {
      for (final method in PaymentMethod.values) {
        expect(PaymentMethod.tryParse(method.wireValue), method);
      }
      expect(PaymentMethod.tryParse('unknown'), isNull);
      expect(PaymentMethod.tryParse(null), isNull);
    });
  });

  group('OrderTimelineEventType', () {
    test('contains all six PostgreSQL values', () {
      expect(OrderTimelineEventType.values, <OrderTimelineEventType>[
        OrderTimelineEventType.created,
        OrderTimelineEventType.orderChanged,
        OrderTimelineEventType.paymentChanged,
        OrderTimelineEventType.proofAttached,
        OrderTimelineEventType.refundStarted,
        OrderTimelineEventType.refunded,
      ]);
      expect(OrderTimelineEventType.created.wireValue, 'created');
      expect(OrderTimelineEventType.orderChanged.wireValue, 'order_changed');
      expect(
        OrderTimelineEventType.paymentChanged.wireValue,
        'payment_changed',
      );
      expect(OrderTimelineEventType.proofAttached.wireValue, 'proof_attached');
      expect(OrderTimelineEventType.refundStarted.wireValue, 'refund_started');
      expect(OrderTimelineEventType.refunded.wireValue, 'refunded');
    });

    test('parses known values and safely rejects unknown values', () {
      for (final eventType in OrderTimelineEventType.values) {
        expect(OrderTimelineEventType.tryParse(eventType.wireValue), eventType);
      }
      expect(OrderTimelineEventType.tryParse('unknown'), isNull);
      expect(OrderTimelineEventType.tryParse(null), isNull);
    });
  });
}
