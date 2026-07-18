import 'dart:async';

import 'package:game_credit_profit_manager/features/admin_platform/application/common/platform_session_coordinator.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_models.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/cursor_page.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/games/game.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/games/game_input.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/games/games_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/offers/public_offer.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/offers/public_offer_input.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/offers/public_offers_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/offers/supabase_offers_datasource.dart';

const activeGameId = '11111111-1111-4111-8111-111111111111';
const inactiveGameId = '22222222-2222-4222-8222-222222222222';
const offerId = '33333333-3333-4333-8333-333333333333';
const secondOfferId = '44444444-4444-4444-8444-444444444444';

final activeGame = Game(
  id: activeGameId,
  slug: 'free-fire',
  nameAr: 'فري فاير',
  nameFr: 'Free Fire',
  rewardUnitCode: 'diamonds',
  rewardUnitNameAr: 'جوهرة',
  rewardUnitNameFr: 'diamants',
  isActive: true,
  sortOrder: 0,
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

final inactiveGame = Game(
  id: inactiveGameId,
  slug: 'inactive-game',
  nameAr: 'لعبة متوقفة',
  nameFr: 'Jeu inactif',
  rewardUnitCode: 'coins',
  rewardUnitNameAr: 'قطعة',
  rewardUnitNameFr: 'pièces',
  isActive: false,
  sortOrder: 1,
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

PublicOffer sampleOffer({
  String id = offerId,
  String gameId = activeGameId,
  bool isPublished = false,
  String nameAr = 'عرض 100 جوهرة',
  String nameFr = 'Offre 100 diamants',
  int rewardQuantity = 100,
  int salePriceDzd = 350,
  int sortOrder = 0,
}) {
  final game = gameId == inactiveGameId ? inactiveGame : activeGame;
  return PublicOffer(
    id: id,
    gameId: gameId,
    gameNameAr: game.nameAr,
    gameNameFr: game.nameFr,
    rewardUnitNameAr: game.rewardUnitNameAr,
    rewardUnitNameFr: game.rewardUnitNameFr,
    nameAr: nameAr,
    nameFr: nameFr,
    rewardQuantity: rewardQuantity,
    salePriceDzd: salePriceDzd,
    isPublished: isPublished,
    sortOrder: sortOrder,
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );
}

Map<String, Object?> sampleOfferRow({
  String id = offerId,
  String gameId = activeGameId,
  bool isPublished = false,
  int rewardQuantity = 100,
  int salePriceDzd = 350,
}) {
  final game = gameId == inactiveGameId ? inactiveGame : activeGame;
  return <String, Object?>{
    'id': id,
    'game_id': gameId,
    'name_ar': 'عرض 100 جوهرة',
    'name_fr': 'Offre 100 diamants',
    'reward_quantity': rewardQuantity,
    'sale_price_dzd': salePriceDzd,
    'is_published': isPublished,
    'sort_order': 0,
    'created_at': '2026-07-01T00:00:00.000Z',
    'updated_at': '2026-07-01T00:00:00.000Z',
    'game': <String, Object?>{
      'id': game.id,
      'name_ar': game.nameAr,
      'name_fr': game.nameFr,
      'reward_unit_name_ar': game.rewardUnitNameAr,
      'reward_unit_name_fr': game.rewardUnitNameFr,
      'is_active': game.isActive,
    },
  };
}

class FakeGamesRepository implements GamesRepository {
  FakeGamesRepository({
    List<Game>? games,
    this.listFailure,
  }) : games = List<Game>.of(games ?? <Game>[activeGame, inactiveGame]);

  final List<Game> games;
  Object? listFailure;
  int listCalls = 0;

  @override
  Future<CursorPage<Game>> listGames({String? cursor, int? limit}) async {
    listCalls += 1;
    if (listFailure != null) {
      throw listFailure!;
    }
    final offset = int.tryParse(cursor ?? '0') ?? 0;
    final pageSize = limit ?? games.length;
    final end = (offset + pageSize).clamp(0, games.length).toInt();
    final pageItems = games.sublist(offset.clamp(0, games.length).toInt(), end);
    final hasMore = end < games.length;
    return CursorPage<Game>(
      items: pageItems,
      nextCursor: hasMore ? '$end' : null,
      hasMore: hasMore,
    );
  }

  @override
  Future<Game> createGame(GameInput input) {
    throw UnsupportedError('Not used by offers tests.');
  }

  @override
  Future<Game> setGameActive({
    required String gameId,
    required bool isActive,
  }) {
    throw UnsupportedError('Not used by offers tests.');
  }

  @override
  Future<Game> updateGame({
    required String gameId,
    required GameInput input,
  }) {
    throw UnsupportedError('Not used by offers tests.');
  }
}

class FakePublicOffersRepository implements PublicOffersRepository {
  FakePublicOffersRepository({
    List<PublicOffer>? offers,
    List<Game>? games,
    this.listFailure,
    this.listGate,
    this.createFailure,
    this.updateFailure,
    this.publishFailure,
    this.createGate,
    this.publishGate,
  }) : offers = List<PublicOffer>.of(offers ?? <PublicOffer>[]),
       games = List<Game>.of(games ?? <Game>[activeGame, inactiveGame]);

  final List<PublicOffer> offers;
  final List<Game> games;
  Object? listFailure;
  Completer<void>? listGate;
  Object? createFailure;
  Object? updateFailure;
  Object? publishFailure;
  Completer<void>? createGate;
  Completer<void>? publishGate;

  int listCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int publishCalls = 0;

  @override
  Future<CursorPage<PublicOffer>> listOffers({
    String? cursor,
    int? limit,
  }) async {
    listCalls += 1;
    if (listGate != null) {
      await listGate!.future;
    }
    if (listFailure != null) {
      throw listFailure!;
    }
    final offset = int.tryParse(cursor ?? '0') ?? 0;
    final pageSize = limit ?? offers.length;
    final end = (offset + pageSize).clamp(0, offers.length).toInt();
    final pageItems = offers.sublist(offset.clamp(0, offers.length).toInt(), end);
    final hasMore = end < offers.length;
    return CursorPage<PublicOffer>(
      items: pageItems,
      nextCursor: hasMore ? '$end' : null,
      hasMore: hasMore,
    );
  }

  @override
  Future<PublicOffer> createOffer(PublicOfferInput input) async {
    createCalls += 1;
    if (createGate != null) {
      await createGate!.future;
    }
    if (createFailure != null) {
      throw createFailure!;
    }
    final game = _gameById(input.gameId);
    final created = PublicOffer(
      id: secondOfferId,
      gameId: input.gameId,
      gameNameAr: game.nameAr,
      gameNameFr: game.nameFr,
      rewardUnitNameAr: game.rewardUnitNameAr,
      rewardUnitNameFr: game.rewardUnitNameFr,
      nameAr: input.nameAr,
      nameFr: input.nameFr,
      rewardQuantity: input.rewardQuantity,
      salePriceDzd: input.salePriceDzd,
      isPublished: input.isPublished,
      sortOrder: input.sortOrder,
      createdAt: DateTime.utc(2026, 7, 2),
      updatedAt: DateTime.utc(2026, 7, 2),
    );
    offers.add(created);
    return created;
  }

  @override
  Future<PublicOffer> updateOffer({
    required String offerId,
    required PublicOfferInput input,
  }) async {
    updateCalls += 1;
    if (updateFailure != null) {
      throw updateFailure!;
    }
    final index = offers.indexWhere((offer) => offer.id == offerId);
    if (index < 0) {
      throw const PlatformFailure(PlatformFailureCode.notFound);
    }
    final game = _gameById(input.gameId);
    final updated = PublicOffer(
      id: offerId,
      gameId: input.gameId,
      gameNameAr: game.nameAr,
      gameNameFr: game.nameFr,
      rewardUnitNameAr: game.rewardUnitNameAr,
      rewardUnitNameFr: game.rewardUnitNameFr,
      nameAr: input.nameAr,
      nameFr: input.nameFr,
      rewardQuantity: input.rewardQuantity,
      salePriceDzd: input.salePriceDzd,
      isPublished: input.isPublished,
      sortOrder: input.sortOrder,
      createdAt: offers[index].createdAt,
      updatedAt: DateTime.utc(2026, 7, 2),
    );
    offers[index] = updated;
    return updated;
  }

  @override
  Future<PublicOffer> setOfferPublished({
    required String offerId,
    required bool isPublished,
  }) async {
    publishCalls += 1;
    if (publishGate != null) {
      await publishGate!.future;
    }
    if (publishFailure != null) {
      throw publishFailure!;
    }
    final index = offers.indexWhere((offer) => offer.id == offerId);
    if (index < 0) {
      throw const PlatformFailure(PlatformFailureCode.notFound);
    }
    final current = offers[index];
    final updated = PublicOffer(
      id: current.id,
      gameId: current.gameId,
      gameNameAr: current.gameNameAr,
      gameNameFr: current.gameNameFr,
      rewardUnitNameAr: current.rewardUnitNameAr,
      rewardUnitNameFr: current.rewardUnitNameFr,
      nameAr: current.nameAr,
      nameFr: current.nameFr,
      rewardQuantity: current.rewardQuantity,
      salePriceDzd: current.salePriceDzd,
      isPublished: isPublished,
      sortOrder: current.sortOrder,
      createdAt: current.createdAt,
      updatedAt: DateTime.utc(2026, 7, 2),
    );
    offers[index] = updated;
    return updated;
  }

  Game _gameById(String id) {
    return games.firstWhere((game) => game.id == id);
  }
}

class FakeSupabaseOffersDataSource implements SupabaseOffersDataSource {
  FakeSupabaseOffersDataSource({
    List<Object>? listOutcomes,
    this.createOutcome,
    this.updateOutcome,
    this.publishOutcome,
  }) : listOutcomes = List<Object>.of(
         listOutcomes ?? <Object>[<Map<String, Object?>>[sampleOfferRow()]],
       );

  final List<Object> listOutcomes;
  Object? createOutcome;
  Object? updateOutcome;
  Object? publishOutcome;

  int listCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int publishCalls = 0;
  Map<String, Object>? lastCreatePayload;
  Map<String, Object>? lastUpdatePayload;
  bool? lastPublishedValue;

  @override
  Future<List<Map<String, Object?>>> listOffers({
    required int offset,
    required int limit,
  }) async {
    listCalls += 1;
    final outcome = listOutcomes.length > 1
        ? listOutcomes.removeAt(0)
        : listOutcomes.single;
    if (outcome is Error || outcome is Exception || outcome is PlatformFailure) {
      throw outcome;
    }
    return List<Map<String, Object?>>.from(outcome as List);
  }

  @override
  Future<Map<String, Object?>> createOffer({
    required Map<String, Object> payload,
  }) async {
    createCalls += 1;
    lastCreatePayload = Map<String, Object>.of(payload);
    return _resolveWriteOutcome(createOutcome ?? sampleOfferRow());
  }

  @override
  Future<Map<String, Object?>> updateOffer({
    required String offerId,
    required Map<String, Object> payload,
  }) async {
    updateCalls += 1;
    lastUpdatePayload = Map<String, Object>.of(payload);
    return _resolveWriteOutcome(updateOutcome ?? sampleOfferRow());
  }

  @override
  Future<Map<String, Object?>> setOfferPublished({
    required String offerId,
    required bool isPublished,
  }) async {
    publishCalls += 1;
    lastPublishedValue = isPublished;
    return _resolveWriteOutcome(
      publishOutcome ?? sampleOfferRow(isPublished: isPublished),
    );
  }

  Map<String, Object?> _resolveWriteOutcome(Object outcome) {
    if (outcome is Error || outcome is Exception || outcome is PlatformFailure) {
      throw outcome;
    }
    return Map<String, Object?>.from(outcome as Map);
  }
}

class ImmediateReadCoordinator implements PlatformReadCoordinator {
  const ImmediateReadCoordinator();

  @override
  Future<T> runRead<T>(PlatformReadOperation<T> operation) => operation();
}

class FakeSessionAccess implements PlatformSessionAccess {
  AdminAuthState state = const AdminAuthState.authorized();
  int refreshCalls = 0;

  @override
  AdminAuthState get currentState => state;

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
    state = const AdminAuthState.authorized();
  }
}

class FakeDataScopeSink implements PlatformDataScopeSink {
  int authorizedCalls = 0;
  final List<PlatformFailureCode> invalidations = <PlatformFailureCode>[];

  @override
  void invalidate(PlatformFailureCode reason) {
    invalidations.add(reason);
  }

  @override
  void markAuthorized() {
    authorizedCalls += 1;
  }
}
