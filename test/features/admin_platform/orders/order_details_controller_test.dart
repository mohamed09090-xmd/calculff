import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/orders/order_details_controller.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/customer_order_details.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/customer_order_summary.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/customer_orders_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_cursor.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_enums.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_filters.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_page.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_timeline_event.dart';

void main() {
  const orderId = '11111111-1111-1111-1111-111111111111';

  test('loads details then timeline and publishes them atomically', () async {
    final repository = _QueueRepository();
    final controller = OrderDetailsController(
      repository: repository,
      orderId: orderId,
    );

    await controller.load();

    expect(repository.calls, <String>['details', 'timeline']);
    expect(controller.state.status, OrderDetailsViewStatus.data);
    expect(controller.state.details?.customerEmail, 'customer@example.test');
    expect(controller.state.timeline, hasLength(1));
  });

  test('does not retain partial details when timeline fails', () async {
    final repository = _QueueRepository(
      timelineFailure: const PlatformFailure(
        PlatformFailureCode.networkUnavailable,
      ),
    );
    final controller = OrderDetailsController(
      repository: repository,
      orderId: orderId,
    );

    await controller.load();

    expect(controller.state.status, OrderDetailsViewStatus.offline);
    expect(controller.state.details, isNull);
    expect(controller.state.timeline, isEmpty);
  });

  test('prevents concurrent retries', () async {
    final repository = _CompletingRepository();
    final controller = OrderDetailsController(
      repository: repository,
      orderId: orderId,
    );

    final first = controller.load();
    final second = controller.retry();
    expect(repository.detailCalls, 1);
    repository.completeDetails(_details());
    await Future<void>.delayed(Duration.zero);
    repository.completeTimeline(<OrderTimelineEvent>[_event()]);
    await Future.wait(<Future<void>>[first, second]);

    expect(repository.detailCalls, 1);
    expect(repository.timelineCalls, 1);
  });

  test('invalidation clears PII and ignores a late response', () async {
    final repository = _CompletingRepository();
    final controller = OrderDetailsController(
      repository: repository,
      orderId: orderId,
    );

    final request = controller.load();
    controller.invalidate(PlatformFailureCode.sessionExpired);
    repository.completeDetails(_details());
    await request;

    expect(controller.state.containsPersonalData, isFalse);
    expect(controller.state.failureCode, PlatformFailureCode.sessionExpired);
    expect(repository.timelineCalls, 0);
  });

  test('retry succeeds after an ordinary failure', () async {
    final repository = _QueueRepository(
      detailFailures: <PlatformFailure>[
        const PlatformFailure(PlatformFailureCode.unknown),
      ],
    );
    final controller = OrderDetailsController(
      repository: repository,
      orderId: orderId,
    );

    await controller.load();
    expect(controller.state.status, OrderDetailsViewStatus.error);
    await controller.retry();
    expect(controller.state.status, OrderDetailsViewStatus.data);
  });
}

class _QueueRepository implements CustomerOrdersRepository {
  _QueueRepository({
    this.timelineFailure,
    List<PlatformFailure>? detailFailures,
  }) : detailFailures = detailFailures ?? <PlatformFailure>[];

  final PlatformFailure? timelineFailure;
  final List<PlatformFailure> detailFailures;
  final List<String> calls = <String>[];

  @override
  Future<CustomerOrderDetails> getOrderDetails({
    required String orderId,
  }) async {
    calls.add('details');
    if (detailFailures.isNotEmpty) throw detailFailures.removeAt(0);
    return _details();
  }

  @override
  Future<List<OrderTimelineEvent>> getOrderTimeline({
    required String orderId,
  }) async {
    calls.add('timeline');
    if (timelineFailure case final failure?) throw failure;
    return <OrderTimelineEvent>[_event()];
  }

  @override
  Future<OrderPage> listOrders({
    required OrderFilters filters,
    OrderCursor? cursor,
    int limit = customerOrdersMaxPageSize,
  }) {
    throw UnimplementedError();
  }
}

class _CompletingRepository implements CustomerOrdersRepository {
  final Completer<CustomerOrderDetails> _detailsCompleter =
      Completer<CustomerOrderDetails>();
  final Completer<List<OrderTimelineEvent>> _timelineCompleter =
      Completer<List<OrderTimelineEvent>>();
  int detailCalls = 0;
  int timelineCalls = 0;

  @override
  Future<CustomerOrderDetails> getOrderDetails({required String orderId}) {
    detailCalls += 1;
    return _detailsCompleter.future;
  }

  @override
  Future<List<OrderTimelineEvent>> getOrderTimeline({required String orderId}) {
    timelineCalls += 1;
    return _timelineCompleter.future;
  }

  void completeDetails(CustomerOrderDetails value) =>
      _detailsCompleter.complete(value);
  void completeTimeline(List<OrderTimelineEvent> value) =>
      _timelineCompleter.complete(value);

  @override
  Future<OrderPage> listOrders({
    required OrderFilters filters,
    OrderCursor? cursor,
    int limit = customerOrdersMaxPageSize,
  }) {
    throw UnimplementedError();
  }
}

CustomerOrderDetails _details() => CustomerOrderDetails(
  summary: CustomerOrderSummary(
    id: '11111111-1111-1111-1111-111111111111',
    gameNameArSnapshot: 'لعبة',
    gameNameFrSnapshot: 'Jeu',
    offerNameArSnapshot: 'عرض',
    offerNameFrSnapshot: 'Offre',
    customerName: 'Customer Fixture',
    playerId: 'player-123',
    inGameName: null,
    salePriceDzd: 350,
    rewardQuantity: 100,
    rewardUnitNameAr: 'جوهرة',
    rewardUnitNameFr: 'diamant',
    paymentMethod: PaymentMethod.transfer,
    orderStatus: OrderStatus.processing,
    paymentStatus: PaymentStatus.underReview,
    createdAt: DateTime.utc(2026, 7, 18),
    hasPaymentProof: true,
  ),
  rewardUnitCodeSnapshot: 'diamond',
  customerEmail: 'customer@example.test',
  customerPhone: '0550000000',
  publicStatusMessage: null,
  updatedAt: DateTime.utc(2026, 7, 18, 1),
  completedAt: null,
  refundStartedAt: null,
  refundedAt: null,
);

OrderTimelineEvent _event() => OrderTimelineEvent(
  eventType: OrderTimelineEventType.created,
  orderStatus: OrderStatus.newOrder,
  paymentStatus: PaymentStatus.awaitingPayment,
  publicMessage: null,
  createdAt: DateTime.utc(2026, 7, 18),
);
