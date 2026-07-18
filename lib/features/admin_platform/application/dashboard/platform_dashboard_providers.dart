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

final platformDashboardControllerProvider = StateNotifierProvider.autoDispose<
  PlatformDashboardController,
  PlatformDashboardState
>((ref) {
  final scope = ref.watch(platformDataScopeProvider);
  final controller = PlatformDashboardController(
    repository: ref.watch(platformDashboardRepositoryProvider),
  );
  ref.listen(platformDataScopeProvider, (previous, next) {
    if (!next.isAuthorized || previous?.generation != next.generation) {
      controller.invalidate();
    }
  });
  if (scope.isAuthorized) {
    unawaited(controller.load());
  }
  return controller;
});
