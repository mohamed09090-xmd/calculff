import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/common/platform_failure.dart';
import '../../domain/orders/order_actions_repository.dart';

enum OrderActionStatus { idle, submitting, succeeded, failed }

class OrderActionState {
  const OrderActionState({
    this.status = OrderActionStatus.idle,
    this.failureCode,
  });

  final OrderActionStatus status;
  final PlatformFailureCode? failureCode;

  bool get isSubmitting => status == OrderActionStatus.submitting;
}

class OrderActionsController extends StateNotifier<OrderActionState> {
  OrderActionsController({
    required OrderActionsRepository? repository,
    required String orderId,
    required Future<void> Function() onChanged,
  }) : _repository = repository,
       _orderId = orderId,
       _onChanged = onChanged,
       super(const OrderActionState());

  final OrderActionsRepository? _repository;
  final String _orderId;
  final Future<void> Function() _onChanged;
  bool _disposed = false;

  Future<bool> accept({String? publicMessage}) {
    return _run(
      (repository) => repository.acceptOrder(
        orderId: _orderId,
        publicMessage: publicMessage,
      ),
    );
  }

  Future<bool> reject({String? publicMessage}) {
    return _run(
      (repository) => repository.rejectOrder(
        orderId: _orderId,
        publicMessage: publicMessage,
      ),
    );
  }

  Future<bool> _run(
    Future<Object?> Function(OrderActionsRepository repository) operation,
  ) async {
    if (_disposed || state.isSubmitting) return false;
    final repository = _repository;
    if (repository == null) {
      state = const OrderActionState(
        status: OrderActionStatus.failed,
        failureCode: PlatformFailureCode.temporarilyUnavailable,
      );
      return false;
    }

    state = const OrderActionState(status: OrderActionStatus.submitting);
    try {
      await operation(repository);
      if (_disposed) return false;
      state = const OrderActionState(status: OrderActionStatus.succeeded);
      await _onChanged();
      if (_disposed) return false;
      state = const OrderActionState();
      return true;
    } catch (error) {
      if (_disposed) return false;
      final failure = error is PlatformFailure
          ? error
          : const PlatformFailure(PlatformFailureCode.unknown);
      state = OrderActionState(
        status: OrderActionStatus.failed,
        failureCode: failure.code,
      );
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
