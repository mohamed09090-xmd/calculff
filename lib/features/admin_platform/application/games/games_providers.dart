import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/games/games_repository.dart';
import '../../infrastructure/games/supabase_games_data_source.dart';
import '../../infrastructure/games/supabase_games_repository.dart';
import '../common/platform_common_providers.dart';
import '../supabase_providers.dart';
import 'games_controller.dart';

final gamesDataSourceProvider = Provider<GamesDataSource?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return SupabaseGamesDataSource(client);
});

final gamesRepositoryProvider = Provider<GamesRepository?>((ref) {
  final dataSource = ref.watch(gamesDataSourceProvider);
  if (dataSource == null) {
    return null;
  }
  return SupabaseGamesRepository(
    dataSource: dataSource,
    readCoordinator: ref.watch(platformReadCoordinatorProvider),
    errorMapper: ref.watch(supabasePlatformErrorMapperProvider),
  );
});

final gamesControllerProvider =
    StateNotifierProvider.autoDispose<GamesController, GamesState>((ref) {
      final controller = GamesController(
        repository: ref.watch(gamesRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });
