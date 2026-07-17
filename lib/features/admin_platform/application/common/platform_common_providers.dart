import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/admin_auth_models.dart';
import '../../infrastructure/common/supabase_platform_error_mapper.dart';
import '../admin_auth_providers.dart';
import 'platform_data_scope.dart';
import 'platform_session_coordinator.dart';

final platformAdminAuthStateProvider = Provider<AdminAuthState>((ref) {
  return ref.watch(adminAuthControllerProvider);
});

final supabasePlatformErrorMapperProvider =
    Provider<SupabasePlatformErrorMapper>((ref) {
      return const SupabasePlatformErrorMapper();
    });

final platformSessionAccessProvider = Provider<PlatformSessionAccess>((ref) {
  return CallbackPlatformSessionAccess(
    readState: () => ref.read(platformAdminAuthStateProvider),
    refresh: () => ref.read(adminAuthControllerProvider.notifier).refreshSession(),
  );
});

final platformDataScopeProvider =
    StateNotifierProvider<PlatformDataScopeController, PlatformDataScopeState>((
      ref,
    ) {
      final controller = PlatformDataScopeController(
        ref.read(platformAdminAuthStateProvider),
      );
      ref.listen<AdminAuthState>(platformAdminAuthStateProvider, (
        previous,
        next,
      ) {
        controller.syncAuthState(next);
      });
      return controller;
    });

final platformReadCoordinatorProvider = Provider<PlatformReadCoordinator>((ref) {
  final errorMapper = ref.watch(supabasePlatformErrorMapperProvider);
  return PlatformSessionCoordinator(
    sessionAccess: ref.watch(platformSessionAccessProvider),
    mapError: errorMapper.map,
    dataScope: ref.read(platformDataScopeProvider.notifier),
  );
});
