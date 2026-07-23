import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/common/platform_failure.dart';
import '../../domain/orders/customer_order_details.dart';
import '../../domain/orders/customer_orders_repository.dart';
import '../../domain/orders/order_timeline_event.dart';

enum OrderDetailsViewStatus { loading, data, offline, notFound, error }

class OrderDetailsState {
  OrderDetailsState({
    required this.status,
    this.details,
    Iterable<OrderTimelineEvent> timeline = const <OrderTimelineEvent>[],
    this.failureCode,
  }) : timeline = List<OrderTimelineEvent>.unmodifiable(timeline);

  factory OrderDetailsState.loading() {
    return OrderDetailsState(status: OrderDetailsViewStatus.loading);
  }

  factory OrderDetailsState.failure(PlatformFailureCode code) {
    return OrderDetailsState(
      status: switch (code) {
        PlatformFailureCode.networkUnavailable =>
          OrderDetailsViewStatus.offline,
        PlatformFailureCode.notFound => OrderDetailsViewStatus.notFound,
        _ => OrderDetailsViewStatus.error,
      },
      failureCode: code,
    );
  }

  final OrderDetailsViewStatus status;
  final CustomerOrderDetails? details;
  final List<OrderTimelineEvent> timeline;
  final PlatformFailureCode? failureCode;

  bool get containsPersonalData => details != null;
}

class OrderDetailsController extends StateNotifier<OrderDetailsState> {
  OrderDetailsController({
    required CustomerOrdersRepository? repository,
    required String orderId,
    PlatformFailureCode? initialFailureCode,
  }) : _repository = repository,
       _orderId = orderId,
       super(
         initialFailureCode == null
             ? OrderDetailsState.loading()
             : OrderDetailsState.failure(initialFailureCode),
       );

  final CustomerOrdersRepository? _repository;
  final String _orderId;

  int _generation = 0;
  bool _requestInFlight = false;
  bool _disposed = false;

  Future<void> load() => _load();

  Future<void> retry() => _load();

  void invalidate(PlatformFailureCode reason) {
    _generation += 1;
    if (!_disposed) {
      state = OrderDetailsState.failure(reason);
    }
  }

  Future<void> _load() async {
    if (_requestInFlight || _disposed) {
      return;
    }

    final requestGeneration = ++_generation;
    _requestInFlight = true;
    state = OrderDetailsState.loading();

    try {
      final repository = _repository;
      if (repository == null) {
        throw const PlatformFailure(PlatformFailureCode.temporarilyUnavailable);
      }

      final timeline = await repository.getOrderTimeline(orderId: _orderId);
      if (!_isCurrent(requestGeneration)) {
        return;
      }
      final details = await repository.getOrderDetails(orderId: _orderId);
      if (!_isCurrent(requestGeneration)) {
        return;
      }

      state = OrderDetailsState(
        status: OrderDetailsViewStatus.data,
        details: details,
        timeline: timeline,
      );
    } catch (error) {
      if (!_isCurrent(requestGeneration)) {
        return;
      }
      final failure = error is PlatformFailure
          ? error
          : const PlatformFailure(PlatformFailureCode.unknown);
      state = OrderDetailsState.failure(failure.code);
    } finally {
      if (_isCurrent(requestGeneration)) {
        _requestInFlight = false;
      }
    }
  }

  bool _isCurrent(int requestGeneration) {
    return !_disposed && requestGeneration == _generation;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    _requestInFlight = false;
    super.dispose();
  }
}
