import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/common/platform_failure.dart';
import '../../domain/common/platform_validation.dart';
import '../../domain/games/game.dart';
import '../../domain/games/games_repository.dart';
import '../../domain/offers/public_offer.dart';
import '../../domain/offers/public_offer_input.dart';
import '../../domain/offers/public_offers_repository.dart';

enum OffersViewStatus { loading, data, empty, offline, error }

enum OffersMutationStatus { success, validationFailure, failure, busy }

class OffersMutationResult {
  const OffersMutationResult._({
    required this.status,
    this.validationIssues = const <PlatformValidationIssue>[],
    this.failureCode,
    this.refreshFailureCode,
  });

  const OffersMutationResult.success({
    PlatformFailureCode? refreshFailureCode,
  }) : this._(
         status: OffersMutationStatus.success,
         refreshFailureCode: refreshFailureCode,
       );

  OffersMutationResult.validation(
    Iterable<PlatformValidationIssue> validationIssues,
  ) : this._(
        status: OffersMutationStatus.validationFailure,
        validationIssues: List<PlatformValidationIssue>.unmodifiable(
          validationIssues,
        ),
      );

  const OffersMutationResult.failure(PlatformFailureCode failureCode)
    : this._(
        status: OffersMutationStatus.failure,
        failureCode: failureCode,
      );

  const OffersMutationResult.busy()
    : this._(status: OffersMutationStatus.busy);

  final OffersMutationStatus status;
  final List<PlatformValidationIssue> validationIssues;
  final PlatformFailureCode? failureCode;
  final PlatformFailureCode? refreshFailureCode;

  bool get isSuccess => status == OffersMutationStatus.success;
}

class OffersState {
  OffersState({
    required this.status,
    required Iterable<PublicOffer> offers,
    required Iterable<Game> games,
    this.isRefreshing = false,
    this.isSubmitting = false,
    this.isStale = false,
    this.failureCode,
  }) : offers = List<PublicOffer>.unmodifiable(offers),
       games = List<Game>.unmodifiable(games);

  factory OffersState.initial() {
    return OffersState(
      status: OffersViewStatus.loading,
      offers: const <PublicOffer>[],
      games: const <Game>[],
    );
  }

  final OffersViewStatus status;
  final List<PublicOffer> offers;
  final List<Game> games;
  final bool isRefreshing;
  final bool isSubmitting;
  final bool isStale;
  final PlatformFailureCode? failureCode;

  OffersState copyWith({
    OffersViewStatus? status,
    Iterable<PublicOffer>? offers,
    Iterable<Game>? games,
    bool? isRefreshing,
    bool? isSubmitting,
    bool? isStale,
    PlatformFailureCode? failureCode,
    bool clearFailure = false,
  }) {
    return OffersState(
      status: status ?? this.status,
      offers: offers ?? this.offers,
      games: games ?? this.games,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isStale: isStale ?? this.isStale,
      failureCode: clearFailure ? null : failureCode ?? this.failureCode,
    );
  }
}

class OffersController extends StateNotifier<OffersState> {
  OffersController({
    required PublicOffersRepository? offersRepository,
    required GamesRepository? gamesRepository,
  }) : _offersRepository = offersRepository,
       _gamesRepository = gamesRepository,
       super(OffersState.initial());

  static const _pageSize = 100;
  static const _maximumPages = 20;

  final PublicOffersRepository? _offersRepository;
  final GamesRepository? _gamesRepository;

  bool _isLoading = false;

  Future<void> load() => _load(isRefresh: false);

  Future<void> refresh() => _load(isRefresh: true);

  Future<OffersMutationResult> createOffer(PublicOfferInput input) {
    return _mutateInput(
      input: input,
      operation: (repository) => repository.createOffer(input),
    );
  }

  Future<OffersMutationResult> updateOffer({
    required String offerId,
    required PublicOfferInput input,
  }) {
    return _mutateInput(
      input: input,
      operation: (repository) => repository.updateOffer(
        offerId: offerId,
        input: input,
      ),
    );
  }

  Future<OffersMutationResult> setOfferPublished({
    required String offerId,
    required bool isPublished,
  }) async {
    if (state.isSubmitting) {
      return const OffersMutationResult.busy();
    }
    final repository = _offersRepository;
    if (repository == null) {
      return const OffersMutationResult.failure(
        PlatformFailureCode.temporarilyUnavailable,
      );
    }
    final offer = _offerById(offerId);
    if (offer == null) {
      return const OffersMutationResult.failure(PlatformFailureCode.notFound);
    }
    final publicationIssue = PublicOfferPublicationPolicy.validate(
      isPublished: isPublished,
      selectedGameIsActive: _gameById(offer.gameId)?.isActive ?? false,
    );
    if (publicationIssue != null) {
      return OffersMutationResult.validation(<PlatformValidationIssue>[
        publicationIssue,
      ]);
    }

    state = state.copyWith(isSubmitting: true);
    try {
      await repository.setOfferPublished(
        offerId: offerId,
        isPublished: isPublished,
      );
      final refreshFailure = await _reloadOffersAfterMutation();
      state = state.copyWith(isSubmitting: false);
      return OffersMutationResult.success(
        refreshFailureCode: refreshFailure,
      );
    } catch (error) {
      state = state.copyWith(isSubmitting: false);
      return OffersMutationResult.failure(_failureFrom(error).code);
    }
  }

  Future<void> _load({required bool isRefresh}) async {
    if (_isLoading) {
      return;
    }
    _isLoading = true;
    final hasData = state.offers.isNotEmpty;
    state = state.copyWith(
      status: hasData ? state.status : OffersViewStatus.loading,
      isRefreshing: isRefresh && hasData,
      isStale: false,
      clearFailure: true,
    );

    try {
      final offersFuture = _loadAllOffers();
      final gamesFuture = _loadAllGames();
      final offers = await offersFuture;
      final games = await gamesFuture;
      state = state.copyWith(
        status: offers.isEmpty
            ? OffersViewStatus.empty
            : OffersViewStatus.data,
        offers: offers,
        games: games,
        isRefreshing: false,
        isStale: false,
        clearFailure: true,
      );
    } catch (error) {
      final failure = _failureFrom(error);
      if (hasData) {
        state = state.copyWith(
          status: OffersViewStatus.data,
          isRefreshing: false,
          isStale: true,
          failureCode: failure.code,
        );
      } else {
        state = state.copyWith(
          status: failure.code == PlatformFailureCode.networkUnavailable
              ? OffersViewStatus.offline
              : OffersViewStatus.error,
          isRefreshing: false,
          isStale: false,
          failureCode: failure.code,
        );
      }
    } finally {
      _isLoading = false;
    }
  }

  Future<OffersMutationResult> _mutateInput({
    required PublicOfferInput input,
    required Future<PublicOffer> Function(
      PublicOffersRepository repository,
    ) operation,
  }) async {
    if (state.isSubmitting) {
      return const OffersMutationResult.busy();
    }
    final repository = _offersRepository;
    if (repository == null) {
      return const OffersMutationResult.failure(
        PlatformFailureCode.temporarilyUnavailable,
      );
    }

    final selectedGame = _gameById(input.gameId);
    final issues = input
        .validate(selectedGameIsActive: selectedGame?.isActive ?? false)
        .toList();
    if (selectedGame == null &&
        !issues.any((issue) => issue.field == PlatformValidationField.gameId)) {
      issues.add(
        const PlatformValidationIssue(
          field: PlatformValidationField.gameId,
          code: PlatformValidationCode.required,
        ),
      );
    }
    if (issues.isNotEmpty) {
      return OffersMutationResult.validation(issues);
    }

    state = state.copyWith(isSubmitting: true);
    try {
      await operation(repository);
      final refreshFailure = await _reloadOffersAfterMutation();
      state = state.copyWith(isSubmitting: false);
      return OffersMutationResult.success(
        refreshFailureCode: refreshFailure,
      );
    } catch (error) {
      state = state.copyWith(isSubmitting: false);
      return OffersMutationResult.failure(_failureFrom(error).code);
    }
  }

  Future<PlatformFailureCode?> _reloadOffersAfterMutation() async {
    try {
      final offers = await _loadAllOffers();
      state = state.copyWith(
        status: offers.isEmpty
            ? OffersViewStatus.empty
            : OffersViewStatus.data,
        offers: offers,
        isStale: false,
        clearFailure: true,
      );
      return null;
    } catch (error) {
      final failure = _failureFrom(error);
      final status = state.offers.isNotEmpty
          ? OffersViewStatus.data
          : failure.code == PlatformFailureCode.networkUnavailable
          ? OffersViewStatus.offline
          : OffersViewStatus.error;
      state = state.copyWith(
        status: status,
        isStale: state.offers.isNotEmpty,
        failureCode: failure.code,
      );
      return failure.code;
    }
  }

  Future<List<PublicOffer>> _loadAllOffers() async {
    final repository = _offersRepository;
    if (repository == null) {
      throw const PlatformFailure(
        PlatformFailureCode.temporarilyUnavailable,
      );
    }
    final offers = <PublicOffer>[];
    String? cursor;
    for (var pageIndex = 0; pageIndex < _maximumPages; pageIndex += 1) {
      final page = await repository.listOffers(
        cursor: cursor,
        limit: _pageSize,
      );
      offers.addAll(page.items);
      if (!page.hasMore) {
        return List<PublicOffer>.unmodifiable(offers);
      }
      cursor = page.nextCursor;
      if (cursor == null) {
        throw const PlatformFailure(PlatformFailureCode.malformedResponse);
      }
    }
    throw const PlatformFailure(PlatformFailureCode.malformedResponse);
  }

  Future<List<Game>> _loadAllGames() async {
    final repository = _gamesRepository;
    if (repository == null) {
      throw const PlatformFailure(
        PlatformFailureCode.temporarilyUnavailable,
      );
    }
    final games = <Game>[];
    String? cursor;
    for (var pageIndex = 0; pageIndex < _maximumPages; pageIndex += 1) {
      final page = await repository.listGames(
        cursor: cursor,
        limit: _pageSize,
      );
      games.addAll(page.items);
      if (!page.hasMore) {
        return List<Game>.unmodifiable(games);
      }
      cursor = page.nextCursor;
      if (cursor == null) {
        throw const PlatformFailure(PlatformFailureCode.malformedResponse);
      }
    }
    throw const PlatformFailure(PlatformFailureCode.malformedResponse);
  }

  Game? _gameById(String gameId) {
    for (final game in state.games) {
      if (game.id == gameId) {
        return game;
      }
    }
    return null;
  }

  PublicOffer? _offerById(String offerId) {
    for (final offer in state.offers) {
      if (offer.id == offerId) {
        return offer;
      }
    }
    return null;
  }
}

PlatformFailure _failureFrom(Object error) {
  if (error is PlatformFailure) {
    return error;
  }
  return const PlatformFailure(PlatformFailureCode.unknown);
}
