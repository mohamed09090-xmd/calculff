import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/supabase_providers.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/secure_supabase_local_storage.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/supabase_bootstrap.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/supabase_configuration.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Supabase build configuration', () {
    test('accepts the approved HTTPS project URL', () {
      final result = SupabaseBuildConfiguration.validate(
        url: 'https://${SupabaseConfiguration.approvedHost}',
        publishableKey: 'test-publishable-key',
      );

      expect(result.status, SupabaseConfigurationStatus.valid);
      expect(
        result.configuration?.url,
        'https://${SupabaseConfiguration.approvedHost}',
      );
    });

    test('missing URL or key disables only Supabase', () {
      final missingUrl = SupabaseBuildConfiguration.validate(
        url: '',
        publishableKey: 'test-publishable-key',
      );
      final missingKey = SupabaseBuildConfiguration.validate(
        url: 'https://${SupabaseConfiguration.approvedHost}',
        publishableKey: '',
      );

      expect(missingUrl.status, SupabaseConfigurationStatus.missing);
      expect(missingKey.status, SupabaseConfigurationStatus.missing);
    });

    test('rejects a non-HTTPS URL', () {
      final result = SupabaseBuildConfiguration.validate(
        url: 'http://${SupabaseConfiguration.approvedHost}',
        publishableKey: 'test-publishable-key',
      );

      expect(result.status, SupabaseConfigurationStatus.invalid);
      expect(result.issue, SupabaseConfigurationIssue.insecureUrl);
    });

    test('rejects another Supabase project', () {
      final result = SupabaseBuildConfiguration.validate(
        url: 'https://another-project.supabase.co',
        publishableKey: 'test-publishable-key',
      );

      expect(result.status, SupabaseConfigurationStatus.invalid);
      expect(result.issue, SupabaseConfigurationIssue.unexpectedHost);
    });

    test('explicitly rejects the forbidden project reference', () {
      final result = SupabaseBuildConfiguration.validate(
        url: 'https://${SupabaseConfiguration.forbiddenProjectRef}.supabase.co',
        publishableKey: 'test-publishable-key',
      );

      expect(result.status, SupabaseConfigurationStatus.invalid);
      expect(result.issue, SupabaseConfigurationIssue.forbiddenProject);
    });
  });

  group('Supabase bootstrap', () {
    test('initialization failure returns a safe local-app status', () async {
      final initializer = FakeSupabaseClientInitializer(shouldFail: true);
      final bootstrap = SupabaseBootstrap(initializer: initializer);
      final result = await bootstrap.initialize(
        configurationResult: validConfiguration,
        localStorage: SecureSupabaseLocalStorage(
          storage: FakeSecureStorageBackend(),
        ),
      );

      expect(result.status, SupabaseBootstrapStatus.initializationFailed);
      expect(result.client, isNull);
      expect(initializer.calls, 1);
    });

    test('does not initialize with missing or invalid configuration', () async {
      final initializer = FakeSupabaseClientInitializer();
      final bootstrap = SupabaseBootstrap(initializer: initializer);
      final localStorage = SecureSupabaseLocalStorage(
        storage: FakeSecureStorageBackend(),
      );
      final missing = await bootstrap.initialize(
        configurationResult: SupabaseBuildConfiguration.validate(
          url: '',
          publishableKey: '',
        ),
        localStorage: localStorage,
      );
      final invalid = await bootstrap.initialize(
        configurationResult: SupabaseBuildConfiguration.validate(
          url: 'https://unexpected.example',
          publishableKey: 'test-publishable-key',
        ),
        localStorage: localStorage,
      );

      expect(missing.status, SupabaseBootstrapStatus.unavailable);
      expect(invalid.status, SupabaseBootstrapStatus.invalidConfiguration);
      expect(initializer.calls, 0);
    });

    test('Riverpod exposes no client without dart-defines', () async {
      final initializer = FakeSupabaseClientInitializer();
      final container = ProviderContainer(
        overrides: [
          supabaseClientInitializerProvider.overrideWithValue(initializer),
          supabaseLocalStorageProvider.overrideWithValue(
            SecureSupabaseLocalStorage(storage: FakeSecureStorageBackend()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(supabaseBootstrapProvider.future);

      expect(result.status, SupabaseBootstrapStatus.unavailable);
      expect(container.read(supabaseClientProvider), isNull);
      expect(initializer.calls, 0);
    });
  });

  group('Secure Supabase local storage', () {
    test('writes, reads, and removes the persisted session', () async {
      final backend = FakeSecureStorageBackend();
      final storage = SecureSupabaseLocalStorage(storage: backend);
      const fakeSession = '{"session":"fake"}';

      await storage.initialize();
      await storage.persistSession(fakeSession);

      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.accessToken(), fakeSession);

      await storage.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);
    });

    test('refuses to persist a password field', () async {
      final backend = FakeSecureStorageBackend();
      final storage = SecureSupabaseLocalStorage(storage: backend);

      await storage.initialize();

      expect(
        () => storage.persistSession('{"password":"not-a-real-password"}'),
        throwsFormatException,
      );
      expect(backend.values, isEmpty);
    });
  });
}

final validConfiguration = SupabaseBuildConfiguration.validate(
  url: 'https://${SupabaseConfiguration.approvedHost}',
  publishableKey: 'test-publishable-key',
);

class FakeSupabaseClientInitializer implements SupabaseClientInitializer {
  FakeSupabaseClientInitializer({this.shouldFail = false});

  final bool shouldFail;
  int calls = 0;

  @override
  Future<SupabaseClient> initialize({
    required SupabaseConfiguration configuration,
    required LocalStorage localStorage,
  }) async {
    calls += 1;
    if (shouldFail) {
      throw StateError('simulated initialization failure');
    }
    return SupabaseClient(configuration.url, configuration.publishableKey);
  }
}

class FakeSecureStorageBackend implements SecureStorageBackend {
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
