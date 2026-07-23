import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/platform_common_providers.dart';
import '../../domain/common/platform_failure.dart';
import '../../domain/orders/order_internal_note.dart';
import 'order_details_controller.dart';
import 'order_actions_controller.dart';
import 'order_payment_proof_provider.dart';
import 'orders_providers.dart';

final orderDetailsControllerProvider = StateNotifierProvider.autoDispose
    .family<OrderDetailsController, OrderDetailsState, String>((ref, orderId) {
      final scope = ref.watch(
        platformDataScopeProvider.select(
          (value) =>
              (value.generation, value.isAuthorized, value.invalidationReason),
        ),
      );
      final controller = OrderDetailsController(
        repository: scope.$2
            ? ref.watch(customerOrdersRepositoryProvider)
            : null,
        orderId: orderId,
        initialFailureCode: scope.$2 ? null : scope.$3,
      );
      if (scope.$2) {
        unawaited(controller.load());
      }
      return controller;
    });

final orderInternalNotesProvider = FutureProvider.autoDispose
    .family<List<OrderInternalNote>, String>((ref, orderId) async {
      final scope = ref.watch(
        platformDataScopeProvider.select(
          (value) =>
              (value.generation, value.isAuthorized, value.invalidationReason),
        ),
      );
      if (!scope.$2) {
        throw PlatformFailure(scope.$3 ?? PlatformFailureCode.sessionExpired);
      }
      final repository = ref.watch(customerOrdersRepositoryProvider);
      if (repository == null) {
        throw const PlatformFailure(PlatformFailureCode.temporarilyUnavailable);
      }
      return repository.getOrderInternalNotes(orderId: orderId);
    });

final orderActionsControllerProvider = StateNotifierProvider.autoDispose
    .family<OrderActionsController, OrderActionState, String>((ref, orderId) {
      final scope = ref.watch(
        platformDataScopeProvider.select(
          (value) =>
              (value.generation, value.isAuthorized, value.invalidationReason),
        ),
      );
      return OrderActionsController(
        repository: scope.$2 ? ref.watch(orderActionsRepositoryProvider) : null,
        orderId: orderId,
        onChanged: () async {
          ref.invalidate(orderPaymentProofProvider(orderId));
          ref.invalidate(orderInternalNotesProvider(orderId));
          ref.invalidate(orderDetailsControllerProvider(orderId));
          ref.invalidate(ordersControllerProvider);
        },
      );
    });
