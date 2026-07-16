import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'features/admin_platform/application/supabase_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();

  final providerContainer = ProviderContainer();
  await providerContainer.read(supabaseBootstrapProvider.future);

  runApp(
    UncontrolledProviderScope(
      container: providerContainer,
      child: const GameCreditApp(),
    ),
  );
}
