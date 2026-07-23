import '../../application/common/platform_session_coordinator.dart';
import '../../domain/common/platform_failure.dart';
import '../../domain/orders/order_action_result.dart';
import '../../domain/orders/order_actions_repository.dart';
import '../../domain/orders/order_enums.dart';
import '../common/platform_payload_reader.dart';
import '../common/supabase_platform_error_mapper.dart';
import 'supabase_customer_orders_repository.dart';
import 'supabase_orders_data_source.dart';

class SupabaseOrderActionsRepository implements OrderActionsRepository {
  const SupabaseOrderActionsRepository({
    required SupabaseOrderActionsDataSource dataSource,
    required SupabasePlatformErrorMapper errorMapper,
    required PlatformMutationCoordinator mutationCoordinator,
  }) : _dataSource = dataSource,
       _errorMapper = errorMapper,
       _mutationCoordinator = mutationCoordinator;

  final SupabaseOrderActionsDataSource _dataSource;
  final SupabasePlatformErrorMapper _errorMapper;
  final PlatformMutationCoordinator _mutationCoordinator;

  @override
  Future<OrderActionResult> acceptOrder({
    required String orderId,
    String? publicMessage,
  }) {
    return _run(
      orderId: orderId,
      operation: () => _dataSource.acceptOrder(
        orderId: orderId,
        publicMessage: publicMessage,
      ),
    );
  }

  @override
  Future<OrderActionResult> rejectOrder({
    required String orderId,
    String? publicMessage,
  }) {
    return _run(
      orderId: orderId,
      operation: () => _dataSource.rejectOrder(
        orderId: orderId,
        publicMessage: publicMessage,
      ),
    );
  }

  Future<OrderActionResult> _run({
    required String orderId,
    required Future<Map<String, Object?>> Function() operation,
  }) {
    validateCustomerOrderId(orderId);
    return _mutationCoordinator.runMutation(() async {
      try {
        final reader = PlatformPayloadReader(await operation());
        final orderStatus = OrderStatus.tryParse(
          reader.requiredString('order_status'),
        );
        final paymentStatus = PaymentStatus.tryParse(
          reader.requiredString('payment_status'),
        );
        if (orderStatus == null || paymentStatus == null) {
          throw const PlatformPayloadException(
            field: 'order_action',
            reason: PlatformPayloadFailureReason.invalidValue,
          );
        }
        return OrderActionResult(
          orderStatus: orderStatus,
          paymentStatus: paymentStatus,
        );
      } catch (error) {
        if (error is FormatException || error is PlatformPayloadException) {
          throw const PlatformFailure(PlatformFailureCode.malformedResponse);
        }
        throw _errorMapper.map(error);
      }
    });
  }
}
