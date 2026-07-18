import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/games/games_repository.dart';
import '../../domain/offers/public_offers_repository.dart';
import '../../infrastructure/offers/supabase_offers_datasource.dart';
import '../../infrastructure/offers/supabase_public_offers_repository.dart';
import '../common/platform_common_providers.dart';
import '../supabase_providers.dart';
import 'offers_controller.dart';

final supabaseOffersDataSourceProvider = Provider<SupabaseOffersDataSource?>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return FlutterSupabaseOffersDataSource(client);
});

final publicOffersRepositoryProvider = Provider<PublicOffersRepository?>((ref) {
  final dataSource = ref.watch(supabaseOffersDataSourceProvider);
  if (dataSource == null) {
    return null;
  }
  return SupabasePublicOffersRepository(
    dataSource: dataSource,
    errorMapper: ref.watch(supabasePlatformErrorMapperProvider),
    readCoordinator: ref.watch(platformReadCoordinatorProvider),
  );
});

final offersGamesRepositoryProvider = Provider<GamesRepository?>((ref) => null);

final offersControllerProvider =
    StateNotifierProvider.autoDispose<OffersController, OffersState>((ref) {
      final controller = OffersController(
        offersRepository: ref.watch(publicOffersRepositoryProvider),
        gamesRepository: ref.watch(offersGamesRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });
