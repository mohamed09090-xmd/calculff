import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/common/platform_failure.dart';
import '../../domain/orders/order_payment_proof.dart';
import '../common/platform_common_providers.dart';
import 'orders_providers.dart';

final orderPaymentProofProvider = FutureProvider.autoDispose
    .family<OrderPaymentProof?, String>((ref, orderId) async {
      final scope = ref.watch(
        platformDataScopeProvider.select(
          (value) =>
              (value.generation, value.isAuthorized, value.invalidationReason),
        ),
      );
      if (!scope.$2) {
        throw PlatformFailure(
          scope.$3 ?? PlatformFailureCode.sessionExpired,
        );
      }
      final repository = ref.watch(orderPaymentProofRepositoryProvider);
      if (repository == null) {
        throw const PlatformFailure(
          PlatformFailureCode.temporarilyUnavailable,
        );
      }
      return repository.getPaymentProof(orderId: orderId);
    });
