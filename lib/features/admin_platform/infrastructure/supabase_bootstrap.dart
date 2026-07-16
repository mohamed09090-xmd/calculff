import 'package:supabase_flutter/supabase_flutter.dart';

import 'secure_supabase_local_storage.dart';
import 'supabase_configuration.dart';

enum SupabaseBootstrapStatus {
  available,
  unavailable,
  invalidConfiguration,
  initializationFailed,
}

class SupabaseBootstrapResult {
  const SupabaseBootstrapResult._({
    required this.status,
    this.client,
  });

  const SupabaseBootstrapResult.available(SupabaseClient client)
      : this._(
          status: SupabaseBootstrapStatus.available,
          client: client,
        );

  const SupabaseBootstrapResult.unavailable()
      : this._(status: SupabaseBootstrapStatus.unavailable);

  const SupabaseBootstrapResult.invalidConfiguration()
      : this._(status: SupabaseBootstrapStatus.invalidConfiguration);

  const SupabaseBootstrapResult.initializationFailed()
      : this._(status: SupabaseBootstrapStatus.initializationFailed);

  final SupabaseBootstrapStatus status;
  final SupabaseClient? client;
}

abstract interface class SupabaseClientInitializer {
  Future<SupabaseClient> initialize({
    required SupabaseConfiguration configuration,
    required LocalStorage localStorage,
  });
}

class FlutterSupabaseClientInitializer implements SupabaseClientInitializer {
  const FlutterSupabaseClientInitializer();

  @override
  Future<SupabaseClient> initialize({
    required SupabaseConfiguration configuration,
    required LocalStorage localStorage,
  }) async {
    final supabase = await Supabase.initialize(
      url: configuration.url,
      publishableKey: configuration.publishableKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: localStorage,
        detectSessionInUri: false,
      ),
      debug: false,
    );
    return supabase.client;
  }
}

class SupabaseBootstrap {
  const SupabaseBootstrap({
    this.initializer = const FlutterSupabaseClientInitializer(),
  });

  final SupabaseClientInitializer initializer;

  Future<SupabaseBootstrapResult> initialize({
    required SupabaseConfigurationResult configurationResult,
    required SecureSupabaseLocalStorage localStorage,
  }) async {
    switch (configurationResult.status) {
      case SupabaseConfigurationStatus.missing:
        return const SupabaseBootstrapResult.unavailable();
      case SupabaseConfigurationStatus.invalid:
        return const SupabaseBootstrapResult.invalidConfiguration();
      case SupabaseConfigurationStatus.valid:
        break;
    }

    final configuration = configurationResult.configuration;
    if (configuration == null) {
      return const SupabaseBootstrapResult.invalidConfiguration();
    }

    try {
      final client = await initializer.initialize(
        configuration: configuration,
        localStorage: localStorage,
      );
      return SupabaseBootstrapResult.available(client);
    } catch (_) {
      return const SupabaseBootstrapResult.initializationFailed();
    }
  }
}
