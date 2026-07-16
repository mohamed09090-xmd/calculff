import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../infrastructure/secure_supabase_local_storage.dart';
import '../infrastructure/supabase_bootstrap.dart';
import '../infrastructure/supabase_configuration.dart';

final supabaseConfigurationProvider = Provider<SupabaseConfigurationResult>(
  (ref) => SupabaseBuildConfiguration.current,
);

final supabaseLocalStorageProvider = Provider<SecureSupabaseLocalStorage>(
  (ref) => SecureSupabaseLocalStorage(),
);

final supabaseClientInitializerProvider = Provider<SupabaseClientInitializer>(
  (ref) => const FlutterSupabaseClientInitializer(),
);

final supabaseBootstrapProvider = FutureProvider<SupabaseBootstrapResult>(
  (ref) {
    final bootstrap = SupabaseBootstrap(
      initializer: ref.watch(supabaseClientInitializerProvider),
    );
    return bootstrap.initialize(
      configurationResult: ref.watch(supabaseConfigurationProvider),
      localStorage: ref.watch(supabaseLocalStorageProvider),
    );
  },
);

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  return ref.watch(supabaseBootstrapProvider).asData?.value.client;
});
