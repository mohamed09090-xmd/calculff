enum OrderStatus {
  newOrder('new'),
  accepted('accepted'),
  processing('processing'),
  completed('completed'),
  rejected('rejected'),
  cancelled('cancelled');

  const OrderStatus(this.wireValue);

  final String wireValue;

  static OrderStatus? tryParse(String? value) {
    for (final status in values) {
      if (status.wireValue == value) {
        return status;
      }
    }
    return null;
  }
}

enum PaymentStatus {
  awaitingPayment('awaiting_payment'),
  underReview('under_review'),
  paid('paid'),
  proofRejected('proof_rejected'),
  refundPending('refund_pending'),
  refunded('refunded');

  const PaymentStatus(this.wireValue);

  final String wireValue;

  static PaymentStatus? tryParse(String? value) {
    for (final status in values) {
      if (status.wireValue == value) {
        return status;
      }
    }
    return null;
  }
}

enum PaymentMethod {
  cash('cash'),
  transfer('transfer');

  const PaymentMethod(this.wireValue);

  final String wireValue;

  static PaymentMethod? tryParse(String? value) {
    for (final method in values) {
      if (method.wireValue == value) {
        return method;
      }
    }
    return null;
  }
}

enum OrderTimelineEventType {
  created('created'),
  orderChanged('order_changed'),
  paymentChanged('payment_changed'),
  proofAttached('proof_attached'),
  refundStarted('refund_started'),
  refunded('refunded');

  const OrderTimelineEventType(this.wireValue);

  final String wireValue;

  static OrderTimelineEventType? tryParse(String? value) {
    for (final eventType in values) {
      if (eventType.wireValue == value) {
        return eventType;
      }
    }
    return null;
  }
}
