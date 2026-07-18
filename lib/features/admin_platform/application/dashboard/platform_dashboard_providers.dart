import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/dashboard/platform_dashboard_repository.dart';
import '../../infrastructure/dashboard/supabase_platform_dashboard_data_source.dart';
import '../../infrastructure/dashboard/supabase_platform_dashboard_repository.dart';
import '../common/platform_common_providers.dart';
import '../supabase_providers.dart';
import 'platform_dashboard_controller.dart';

final platformDashboardDataSourceProvider =
    Provider<PlatformDashboardDataSource?>((ref) {
      final client = ref.watch(supabaseClientProvider);
      if (client == null) {
        return null;
      }
      return SupabasePlatformDashboardDataSource(client);
    });

final platformDashboardRepositoryProvider =
    Provider<PlatformDashboardRepository?>((ref) {
      final dataSource = ref.watch(platformDashboardDataSourceProvider);
      if (dataSource == null) {
        return null;
      }
      return SupabasePlatformDashboardRepository(
        dataSource: dataSource,
        readCoordinator: ref.watch(platformReadCoordinatorProvider),
        errorMapper: ref.watch(supabasePlatformErrorMapperProvider),
      );
    });

final platformDashboardControllerProvider =
    StateNotifierProvider.autoDispose<
      PlatformDashboardController,
      PlatformDashboardState
    >((ref) {
      ref.watch(
        platformDataScopeProvider.select(
          (scope) => (scope.generation, scope.isAuthorized),
        ),
      );
      final controller = PlatformDashboardController(
        repository: ref.watch(platformDashboardRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });
