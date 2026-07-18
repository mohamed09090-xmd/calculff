import '../../application/common/platform_session_coordinator.dart';
import '../../domain/common/cursor_page.dart';
import '../../domain/common/platform_failure.dart';
import '../../domain/games/game.dart';
import '../../domain/games/game_input.dart';
import '../../domain/games/games_repository.dart';
import '../common/supabase_platform_error_mapper.dart';
import 'game_input_mapper.dart';
import 'supabase_games_data_source.dart';

class SupabaseGamesRepository implements GamesRepository {
  const SupabaseGamesRepository({
    required GamesDataSource dataSource,
    required PlatformReadCoordinator readCoordinator,
    required SupabasePlatformErrorMapper errorMapper,
  }) : _dataSource = dataSource,
       _readCoordinator = readCoordinator,
       _errorMapper = errorMapper;

  final GamesDataSource _dataSource;
  final PlatformReadCoordinator _readCoordinator;
  final SupabasePlatformErrorMapper _errorMapper;

  @override
  Future<CursorPage<Game>> listGames({String? cursor, int? limit}) {
    return _readCoordinator.runRead(() async {
      try {
        final games = await _dataSource.listGames(limit: limit);
        return CursorPage<Game>(
          items: games.map((game) => game.toDomain()),
          nextCursor: null,
          hasMore: false,
        );
      } catch (error) {
        throw _errorMapper.map(error);
      }
    });
  }

  @override
  Future<Game> createGame(GameInput input) async {
    _validate(input);
    try {
      final game = await _dataSource.createGame(
        GameInputMapper.toWritePayload(input),
      );
      return game.toDomain();
    } catch (error) {
      throw _errorMapper.map(error);
    }
  }

  @override
  Future<Game> updateGame({
    required String gameId,
    required GameInput input,
  }) async {
    _validate(input);
    try {
      final game = await _dataSource.updateGame(
        gameId: gameId,
        payload: GameInputMapper.toWritePayload(input),
      );
      return game.toDomain();
    } catch (error) {
      throw _errorMapper.map(error);
    }
  }

  @override
  Future<Game> setGameActive({
    required String gameId,
    required bool isActive,
  }) async {
    try {
      final game = await _dataSource.setGameActive(
        gameId: gameId,
        isActive: isActive,
      );
      return game.toDomain();
    } catch (error) {
      throw _errorMapper.map(error);
    }
  }
}

void _validate(GameInput input) {
  final issues = input.validate();
  if (issues.isNotEmpty) {
    throw PlatformFailure(
      PlatformFailureCode.validation,
      validationIssue: issues.first,
    );
  }
}
