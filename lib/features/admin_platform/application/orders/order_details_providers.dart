import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/platform_common_providers.dart';
import 'order_details_controller.dart';
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
