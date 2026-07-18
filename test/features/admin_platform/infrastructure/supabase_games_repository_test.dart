import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/common/platform_session_coordinator.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_models.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/games/game_input.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/platform_payload_reader.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/supabase_platform_error_mapper.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/games/game_dto.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/games/supabase_games_data_source.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/games/supabase_games_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseGamesRepository', () {
    test('lists games through the read coordinator', () async {
      final dataSource = _FakeGamesDataSource()
        ..listResults.add(<GameDto>[_dto]);
      final coordinator = _RecordingReadCoordinator();
      final repository = SupabaseGamesRepository(
        dataSource: dataSource,
        readCoordinator: coordinator,
        errorMapper: const SupabasePlatformErrorMapper(),
      );

      final page = await repository.listGames();

      expect(coordinator.calls, 1);
      expect(dataSource.listCalls, 1);
      expect(page.items.single.slug, 'free-fire');
      expect(page.hasMore, isFalse);
    });

    test('refreshes once and retries one read after session expiry', () async {
      final dataSource = _FakeGamesDataSource()
        ..listResults.add(
          const PostgrestException(message: 'private', code: 'PGRST301'),
        )
        ..listResults.add(<GameDto>[_dto]);
      final access = _SessionAccess();
      final coordinator = PlatformSessionCoordinator(
        sessionAccess: access,
        mapError: const SupabasePlatformErrorMapper().map,
        dataScope: _DataScopeSink(),
      );
      final repository = SupabaseGamesRepository(
        dataSource: dataSource,
        readCoordinator: coordinator,
        errorMapper: const SupabasePlatformErrorMapper(),
      );

      final page = await repository.listGames();

      expect(page.items, hasLength(1));
      expect(dataSource.listCalls, 2);
      expect(access.refreshCalls, 1);
    });

    test('does not retry a write when the session expires', () async {
      final dataSource = _FakeGamesDataSource()
        ..createError = const PostgrestException(
          message: 'private',
          code: 'PGRST301',
        );
      final access = _SessionAccess();
      final repository = SupabaseGamesRepository(
        dataSource: dataSource,
        readCoordinator: PlatformSessionCoordinator(
          sessionAccess: access,
          mapError: const SupabasePlatformErrorMapper().map,
          dataScope: _DataScopeSink(),
        ),
        errorMapper: const SupabasePlatformErrorMapper(),
      );

      await expectLater(
        repository.createGame(_input),
        throwsA(
          isA<PlatformFailure>().having(
            (failure) => failure.code,
            'code',
            PlatformFailureCode.sessionExpired,
          ),
        ),
      );
      expect(dataSource.createCalls, 1);
      expect(access.refreshCalls, 0);
    });

    test('maps duplicate slug without exposing the database message', () async {
      final dataSource = _FakeGamesDataSource()
        ..createError = const PostgrestException(
          message: 'private duplicate payload',
          code: '23505',
        );
      final repository = SupabaseGamesRepository(
        dataSource: dataSource,
        readCoordinator: _RecordingReadCoordinator(),
        errorMapper: const SupabasePlatformErrorMapper(),
      );

      try {
        await repository.createGame(_input);
        fail('Expected duplicate slug failure.');
      } on PlatformFailure catch (failure) {
        expect(failure.code, PlatformFailureCode.duplicateSlug);
        expect(failure.toString(), isNot(contains('private duplicate')));
      }
      expect(dataSource.createCalls, 1);
    });

    test('maps malformed responses to malformedResponse', () async {
      final dataSource = _FakeGamesDataSource()
        ..listResults.add(
          const PlatformPayloadException(
            field: 'games',
            reason: PlatformPayloadFailureReason.wrongType,
          ),
        );
      final repository = SupabaseGamesRepository(
        dataSource: dataSource,
        readCoordinator: _RecordingReadCoordinator(),
        errorMapper: const SupabasePlatformErrorMapper(),
      );

      await expectLater(
        repository.listGames(),
        throwsA(
          isA<PlatformFailure>().having(
            (failure) => failure.code,
            'code',
            PlatformFailureCode.malformedResponse,
          ),
        ),
      );
    });
  });
}

final _dto = GameDto(
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

final _input = GameInput(
  slug: 'free-fire',
  nameAr: 'فري فاير',
  nameFr: 'Free Fire',
  rewardUnitCode: 'diamonds',
  rewardUnitNameAr: 'جوهرة',
  rewardUnitNameFr: 'Diamant',
  isActive: true,
  sortOrder: 1,
);

class _FakeGamesDataSource implements GamesDataSource {
  final List<Object> listResults = <Object>[];
  Object? createError;
  int listCalls = 0;
  int createCalls = 0;

  @override
  Future<List<GameDto>> listGames({int? limit}) async {
    final result = listResults[listCalls++];
    if (result is List<GameDto>) return result;
    throw result;
  }

  @override
  Future<GameDto> createGame(Map<String, Object> payload) async {
    createCalls += 1;
    if (createError case final Object error) throw error;
    return _dto;
  }

  @override
  Future<GameDto> setGameActive({
    required String gameId,
    required bool isActive,
  }) async => _dto;

  @override
  Future<GameDto> updateGame({
    required String gameId,
    required Map<String, Object> payload,
  }) async => _dto;
}

class _RecordingReadCoordinator implements PlatformReadCoordinator {
  int calls = 0;

  @override
  Future<T> runRead<T>(PlatformReadOperation<T> operation) {
    calls += 1;
    return operation();
  }
}

class _SessionAccess implements PlatformSessionAccess {
  int refreshCalls = 0;

  @override
  AdminAuthState get currentState => const AdminAuthState.authorized();

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
  }
}

class _DataScopeSink implements PlatformDataScopeSink {
  @override
  void invalidate(PlatformFailureCode reason) {}

  @override
  void markAuthorized() {}
}
