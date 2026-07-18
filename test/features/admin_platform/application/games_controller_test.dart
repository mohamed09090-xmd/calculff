import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/games/games_controller.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/cursor_page.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/games/game.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/games/game_input.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/games/games_repository.dart';

void main() {
  group('GamesController', () {
    test('loads games and exposes ready state', () async {
      final repository = _FakeGamesRepository()
        ..listResults.add(
          CursorPage<Game>(items: [_game], nextCursor: null, hasMore: false),
        );
      final controller = GamesController(repository: repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.status, GamesLoadStatus.ready);
      expect(controller.state.games.single.slug, 'free-fire');
      expect(controller.state.loadFailure, isNull);
    });

    test('exposes offline state when no cached data exists', () async {
      final repository = _FakeGamesRepository()
        ..listResults.add(
          const PlatformFailure(PlatformFailureCode.networkUnavailable),
        );
      final controller = GamesController(repository: repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.status, GamesLoadStatus.offline);
      expect(controller.state.games, isEmpty);
      expect(
        controller.state.loadFailure?.code,
        PlatformFailureCode.networkUnavailable,
      );
    });

    test('keeps stale games after an offline refresh failure', () async {
      final repository = _FakeGamesRepository()
        ..listResults.add(
          CursorPage<Game>(items: [_game], nextCursor: null, hasMore: false),
        )
        ..listResults.add(
          const PlatformFailure(PlatformFailureCode.networkUnavailable),
        );
      final controller = GamesController(repository: repository);
      addTearDown(controller.dispose);

      await controller.load();
      await controller.refresh();

      expect(controller.state.games, hasLength(1));
      expect(controller.state.status, GamesLoadStatus.offline);
      expect(controller.state.hasStaleData, isTrue);
    });

    test(
      'surfaces session expiry without retrying at controller level',
      () async {
        final repository = _FakeGamesRepository()
          ..listResults.add(
            const PlatformFailure(PlatformFailureCode.sessionExpired),
          );
        final controller = GamesController(repository: repository);
        addTearDown(controller.dispose);

        await controller.load();

        expect(repository.listCalls, 1);
        expect(controller.state.status, GamesLoadStatus.error);
        expect(
          controller.state.loadFailure?.code,
          PlatformFailureCode.sessionExpired,
        );
      },
    );

    test(
      'prevents duplicate writes and refetches only after success',
      () async {
        final createCompleter = Completer<Game>();
        final repository = _FakeGamesRepository()
          ..listResults.add(
            CursorPage<Game>(items: [_game], nextCursor: null, hasMore: false),
          )
          ..listResults.add(
            CursorPage<Game>(
              items: [_secondGame],
              nextCursor: null,
              hasMore: false,
            ),
          )
          ..createCompleter = createCompleter;
        final controller = GamesController(repository: repository);
        addTearDown(controller.dispose);
        await controller.load();

        final firstWrite = controller.createGame(_input);
        final repeatedWrite = await controller.createGame(_input);

        expect(repository.createCalls, 1);
        expect(repeatedWrite?.code, PlatformFailureCode.temporarilyUnavailable);
        expect(controller.state.games.single.id, _game.id);
        expect(controller.state.isSubmitting, isTrue);

        createCompleter.complete(_secondGame);
        expect(await firstWrite, isNull);
        expect(repository.listCalls, 2);
        expect(controller.state.games.single.id, _secondGame.id);
        expect(controller.state.isSubmitting, isFalse);
      },
    );

    test('keeps list unchanged when duplicate slug write fails', () async {
      final repository = _FakeGamesRepository()
        ..listResults.add(
          CursorPage<Game>(items: [_game], nextCursor: null, hasMore: false),
        )
        ..createFailure = const PlatformFailure(
          PlatformFailureCode.duplicateSlug,
        );
      final controller = GamesController(repository: repository);
      addTearDown(controller.dispose);
      await controller.load();

      final failure = await controller.createGame(_input);

      expect(failure?.code, PlatformFailureCode.duplicateSlug);
      expect(repository.createCalls, 1);
      expect(repository.listCalls, 1);
      expect(controller.state.games.single.id, _game.id);
    });
  });
}

final _game = Game(
  id: '11111111-1111-1111-1111-111111111111',
  slug: 'free-fire',
  nameAr: 'فري فاير',
  nameFr: 'Free Fire',
  rewardUnitCode: 'diamonds',
  rewardUnitNameAr: 'جوهرة',
  rewardUnitNameFr: 'Diamant',
  isActive: true,
  sortOrder: 1,
  createdAt: DateTime.utc(2026, 7, 18, 10),
  updatedAt: DateTime.utc(2026, 7, 18, 11),
);

final _secondGame = Game(
  id: '22222222-2222-2222-2222-222222222222',
  slug: 'pubg-mobile',
  nameAr: 'ببجي موبايل',
  nameFr: 'PUBG Mobile',
  rewardUnitCode: 'uc',
  rewardUnitNameAr: 'شدة',
  rewardUnitNameFr: 'UC',
  isActive: false,
  sortOrder: 2,
  createdAt: DateTime.utc(2026, 7, 18, 12),
  updatedAt: DateTime.utc(2026, 7, 18, 12),
);

final _input = GameInput(
  slug: 'pubg-mobile',
  nameAr: 'ببجي موبايل',
  nameFr: 'PUBG Mobile',
  rewardUnitCode: 'uc',
  rewardUnitNameAr: 'شدة',
  rewardUnitNameFr: 'UC',
  sortOrder: 2,
);

class _FakeGamesRepository implements GamesRepository {
  final List<Object> listResults = <Object>[];
  int listCalls = 0;
  int createCalls = 0;
  Completer<Game>? createCompleter;
  PlatformFailure? createFailure;

  @override
  Future<CursorPage<Game>> listGames({String? cursor, int? limit}) async {
    final result = listResults[listCalls++];
    if (result is CursorPage<Game>) return result;
    throw result;
  }

  @override
  Future<Game> createGame(GameInput input) {
    createCalls += 1;
    final failure = createFailure;
    if (failure != null) return Future<Game>.error(failure);
    return createCompleter?.future ?? Future<Game>.value(_secondGame);
  }

  @override
  Future<Game> setGameActive({required String gameId, required bool isActive}) {
    return Future<Game>.value(_game);
  }

  @override
  Future<Game> updateGame({required String gameId, required GameInput input}) {
    return Future<Game>.value(_game);
  }
}
