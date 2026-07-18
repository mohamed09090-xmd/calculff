import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/common/platform_failure.dart';
import '../../domain/games/game.dart';
import '../../domain/games/game_input.dart';
import '../../domain/games/games_repository.dart';

enum GamesLoadStatus { loading, ready, offline, error }

class GamesState {
  GamesState({
    required Iterable<Game> games,
    required this.status,
    this.isRefreshing = false,
    this.isSubmitting = false,
    this.loadFailure,
    this.actionFailure,
    this.refreshedAt,
  }) : games = List<Game>.unmodifiable(games);

  factory GamesState.initial({required bool isAvailable}) {
    if (!isAvailable) {
      return GamesState(
        games: const <Game>[],
        status: GamesLoadStatus.error,
        loadFailure: const PlatformFailure(
          PlatformFailureCode.temporarilyUnavailable,
        ),
      );
    }
    return GamesState(
      games: const <Game>[],
      status: GamesLoadStatus.loading,
    );
  }

  final List<Game> games;
  final GamesLoadStatus status;
  final bool isRefreshing;
  final bool isSubmitting;
  final PlatformFailure? loadFailure;
  final PlatformFailure? actionFailure;
  final DateTime? refreshedAt;

  bool get isEmpty => status == GamesLoadStatus.ready && games.isEmpty;

  bool get hasStaleData => games.isNotEmpty && loadFailure != null;

  GamesState copyWith({
    Iterable<Game>? games,
    GamesLoadStatus? status,
    bool? isRefreshing,
    bool? isSubmitting,
    PlatformFailure? loadFailure,
    bool clearLoadFailure = false,
    PlatformFailure? actionFailure,
    bool clearActionFailure = false,
    DateTime? refreshedAt,
  }) {
    return GamesState(
      games: games ?? this.games,
      status: status ?? this.status,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      loadFailure: clearLoadFailure ? null : loadFailure ?? this.loadFailure,
      actionFailure: clearActionFailure
          ? null
          : actionFailure ?? this.actionFailure,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }
}

class GamesController extends StateNotifier<GamesState> {
  GamesController({required GamesRepository? repository})
    : _repository = repository,
      super(GamesState.initial(isAvailable: repository != null));

  final GamesRepository? _repository;

  bool _readInProgress = false;
  bool _writeInProgress = false;
  bool _isDisposed = false;

  Future<void> load() => _read(showInitialLoading: true);

  Future<void> refresh() => _read(showInitialLoading: false);

  Future<PlatformFailure?> createGame(GameInput input) {
    return _write((repository) => repository.createGame(input));
  }

  Future<PlatformFailure?> updateGame({
    required String gameId,
    required GameInput input,
  }) {
    return _write(
      (repository) => repository.updateGame(gameId: gameId, input: input),
    );
  }

  Future<PlatformFailure?> setGameActive({
    required String gameId,
    required bool isActive,
  }) {
    return _write(
      (repository) =>
          repository.setGameActive(gameId: gameId, isActive: isActive),
    );
  }

  void clearActionFailure() {
    _setState(state.copyWith(clearActionFailure: true));
  }

  Future<void> _read({required bool showInitialLoading}) async {
    final repository = _repository;
    if (repository == null) {
      _applyReadFailure(
        const PlatformFailure(PlatformFailureCode.temporarilyUnavailable),
      );
      return;
    }
    if (_readInProgress || _isDisposed) {
      return;
    }

    _readInProgress = true;
    if (showInitialLoading && state.games.isEmpty) {
      _setState(
        state.copyWith(
          status: GamesLoadStatus.loading,
          clearLoadFailure: true,
        ),
      );
    } else {
      _setState(
        state.copyWith(isRefreshing: true, clearLoadFailure: true),
      );
    }

    try {
      final page = await repository.listGames();
      _setState(
        state.copyWith(
          games: page.items,
          status: GamesLoadStatus.ready,
          isRefreshing: false,
          clearLoadFailure: true,
          refreshedAt: DateTime.now().toUtc(),
        ),
      );
    } on PlatformFailure catch (failure) {
      _applyReadFailure(failure);
    } catch (_) {
      _applyReadFailure(const PlatformFailure(PlatformFailureCode.unknown));
    } finally {
      _readInProgress = false;
    }
  }

  Future<PlatformFailure?> _write(
    Future<Game> Function(GamesRepository repository) operation,
  ) async {
    final repository = _repository;
    if (repository == null) {
      final failure = const PlatformFailure(
        PlatformFailureCode.temporarilyUnavailable,
      );
      _setState(state.copyWith(actionFailure: failure));
      return failure;
    }
    if (_writeInProgress || _isDisposed) {
      final failure = const PlatformFailure(
        PlatformFailureCode.temporarilyUnavailable,
      );
      _setState(state.copyWith(actionFailure: failure));
      return failure;
    }

    _writeInProgress = true;
    _setState(
      state.copyWith(isSubmitting: true, clearActionFailure: true),
    );
    try {
      await operation(repository);
      await _read(showInitialLoading: false);
      return null;
    } on PlatformFailure catch (failure) {
      _setState(
        state.copyWith(isSubmitting: false, actionFailure: failure),
      );
      return failure;
    } catch (_) {
      const failure = PlatformFailure(PlatformFailureCode.unknown);
      _setState(
        state.copyWith(isSubmitting: false, actionFailure: failure),
      );
      return failure;
    } finally {
      _writeInProgress = false;
      if (!_isDisposed && state.isSubmitting) {
        _setState(state.copyWith(isSubmitting: false));
      }
    }
  }

  void _applyReadFailure(PlatformFailure failure) {
    final status = failure.code == PlatformFailureCode.networkUnavailable
        ? GamesLoadStatus.offline
        : GamesLoadStatus.error;
    _setState(
      state.copyWith(
        status: status,
        isRefreshing: false,
        loadFailure: failure,
      ),
    );
  }

  void _setState(GamesState nextState) {
    if (!_isDisposed) {
      state = nextState;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
