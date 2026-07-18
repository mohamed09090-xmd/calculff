import '../common/cursor_page.dart';
import 'game.dart';
import 'game_input.dart';

abstract interface class GamesRepository {
  Future<CursorPage<Game>> listGames({String? cursor, int? limit});

  Future<Game> createGame(GameInput input);

  Future<Game> updateGame({required String gameId, required GameInput input});

  Future<Game> setGameActive({required String gameId, required bool isActive});
}
