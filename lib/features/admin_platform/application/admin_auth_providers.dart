import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/admin_auth_models.dart';
import '../domain/admin_auth_repository.dart';
import '../infrastructure/supabase_admin_auth_datasource.dart';
import '../infrastructure/supabase_admin_auth_repository.dart';
import '../infrastructure/supabase_auth_error_mapper.dart';
import 'admin_auth_controller.dart';
import 'supabase_providers.dart';

final supabaseAuthErrorMapperProvider = Provider<SupabaseAuthErrorMapper>(
  (ref) => const SupabaseAuthErrorMapper(),
);

final adminAuthDataSourceProvider = Provider<SupabaseAdminAuthDataSource?>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return FlutterSupabaseAdminAuthDataSource(client);
});

final adminAuthRepositoryProvider = Provider<AdminAuthRepository?>((ref) {
  final dataSource = ref.watch(adminAuthDataSourceProvider);
  if (dataSource == null) {
    return null;
  }
  return SupabaseAdminAuthRepository(
    dataSource: dataSource,
    errorMapper: ref.watch(supabaseAuthErrorMapperProvider),
  );
});

final adminAuthControllerProvider =
    StateNotifierProvider<AdminAuthController, AdminAuthState>((ref) {
      final controller = AdminAuthController(
        repository: ref.watch(adminAuthRepositoryProvider),
      );
      unawaited(controller.start());
      return controller;
    });
