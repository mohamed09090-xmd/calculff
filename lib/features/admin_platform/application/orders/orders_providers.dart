import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/games/games_repository.dart';
import '../../domain/orders/customer_orders_repository.dart';
import '../../domain/orders/order_actions_repository.dart';
import '../../domain/orders/order_payment_proof_repository.dart';
import '../../infrastructure/orders/supabase_order_actions_repository.dart';
import '../../infrastructure/orders/supabase_order_payment_proof_repository.dart';
import '../../infrastructure/orders/supabase_customer_orders_repository.dart';
import '../../infrastructure/orders/supabase_orders_data_source.dart';
import '../common/platform_common_providers.dart';
import '../games/games_providers.dart';
import '../supabase_providers.dart';
import 'orders_controller.dart';

final supabaseOrdersDataSourceProvider = Provider<SupabaseOrdersDataSource?>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return FlutterSupabaseOrdersDataSource(client);
});

final supabaseCustomerOrdersRepositoryProvider =
    Provider<SupabaseCustomerOrdersRepository?>((ref) {
      final dataSource = ref.watch(supabaseOrdersDataSourceProvider);
      if (dataSource == null) {
        return null;
      }
      return SupabaseCustomerOrdersRepository(
        dataSource: dataSource,
        errorMapper: ref.watch(supabasePlatformErrorMapperProvider),
        readCoordinator: ref.watch(platformReadCoordinatorProvider),
      );
    });

final customerOrdersRepositoryProvider = Provider<CustomerOrdersRepository?>((
  ref,
) {
  return ref.watch(supabaseCustomerOrdersRepositoryProvider);
});

final orderPaymentProofRepositoryProvider =
    Provider<OrderPaymentProofRepository?>((ref) {
  final dataSource = ref.watch(supabaseOrdersDataSourceProvider);
  if (dataSource == null) {
    return null;
  }
  return SupabaseOrderPaymentProofRepository(
    dataSource: dataSource,
    errorMapper: ref.watch(supabasePlatformErrorMapperProvider),
    readCoordinator: ref.watch(platformReadCoordinatorProvider),
  );
});

final orderActionsRepositoryProvider = Provider<OrderActionsRepository?>((ref) {
  final dataSource = ref.watch(supabaseOrdersDataSourceProvider);
  if (dataSource == null) {
    return null;
  }
  return SupabaseOrderActionsRepository(
    dataSource: dataSource,
    errorMapper: ref.watch(supabasePlatformErrorMapperProvider),
    mutationCoordinator: ref.watch(platformMutationCoordinatorProvider),
  );
});

final ordersGamesRepositoryProvider = Provider<GamesRepository?>((ref) {
  return ref.watch(gamesRepositoryProvider);
});

final ordersControllerProvider =
    StateNotifierProvider.autoDispose<OrdersController, OrdersState>((ref) {
      ref.watch(platformDataScopeProvider.select((scope) => scope.generation));
      final controller = OrdersController(
        ordersRepository: ref.watch(customerOrdersRepositoryProvider),
        gamesRepository: ref.watch(ordersGamesRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });
