import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/common/platform_failure.dart';
import '../../domain/games/game.dart';
import '../../domain/games/games_repository.dart';
import '../../domain/orders/customer_order_summary.dart';
import '../../domain/orders/customer_orders_repository.dart';
import '../../domain/orders/order_cursor.dart';
import '../../domain/orders/order_filters.dart';

const Object _unsetOrdersValue = Object();

enum OrdersViewStatus { loading, data, empty, offline, error }

class OrdersState {
  OrdersState({
    required this.status,
    required Iterable<CustomerOrderSummary> orders,
    required Iterable<Game> games,
    required this.filters,
    this.nextCursor,
    this.hasMore = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isStale = false,
    this.failureCode,
  }) : orders = List<CustomerOrderSummary>.unmodifiable(orders),
       games = List<Game>.unmodifiable(games);

  factory OrdersState.initial() {
    return OrdersState(
      status: OrdersViewStatus.loading,
      orders: const [],
      games: const [],
      filters: OrderFilters(),
    );
  }

  final OrdersViewStatus status;
  final List<CustomerOrderSummary> orders;
  final List<Game> games;
  final OrderFilters filters;
  final OrderCursor? nextCursor;
  final bool hasMore;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isStale;
  final PlatformFailureCode? failureCode;

  OrdersState copyWith({
    OrdersViewStatus? status,
    Iterable<CustomerOrderSummary>? orders,
    Iterable<Game>? games,
    OrderFilters? filters,
    Object? nextCursor = _unsetOrdersValue,
    bool? hasMore,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isStale,
    Object? failureCode = _unsetOrdersValue,
  }) {
    return OrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      games: games ?? this.games,
      filters: filters ?? this.filters,
      nextCursor: identical(nextCursor, _unsetOrdersValue)
          ? this.nextCursor
          : nextCursor as OrderCursor?,
      hasMore: hasMore ?? this.hasMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isStale: isStale ?? this.isStale,
      failureCode: identical(failureCode, _unsetOrdersValue)
          ? this.failureCode
          : failureCode as PlatformFailureCode?,
    );
  }
}

class OrdersController extends StateNotifier<OrdersState> {
  OrdersController({
    required CustomerOrdersRepository? ordersRepository,
    required GamesRepository? gamesRepository,
  }) : _ordersRepository = ordersRepository,
       _gamesRepository = gamesRepository,
       super(OrdersState.initial());

  static const pageSize = customerOrdersMaxPageSize;
  static const _gamesPageSize = 100;
  static const _maximumGamePages = 20;

  final CustomerOrdersRepository? _ordersRepository;
  final GamesRepository? _gamesRepository;

  final Set<String> _seenIds = <String>{};
  int _generation = 0;
  bool _firstPageInFlight = false;
  bool _loadMoreInFlight = false;

  Future<void> load() => _loadFirstPage(preserveExisting: false);

  Future<void> refresh() => _loadFirstPage(preserveExisting: true);

  Future<void> updateFilters(OrderFilters filters) async {
    if (_sameFilters(state.filters, filters)) {
      return;
    }
    _generation += 1;
    _seenIds.clear();
    state = OrdersState(
      status: OrdersViewStatus.loading,
      orders: const [],
      games: state.games,
      filters: filters,
    );
    await _loadFirstPage(preserveExisting: false, incrementGeneration: false);
  }

  Future<void> clearFilters() => updateFilters(OrderFilters());

  Future<void> loadMore() async {
    if (_loadMoreInFlight ||
        _firstPageInFlight ||
        !state.hasMore ||
        state.nextCursor == null) {
      return;
    }
    final repository = _ordersRepository;
    if (repository == null) {
      return;
    }

    _loadMoreInFlight = true;
    final requestGeneration = _generation;
    final cursor = state.nextCursor;
    state = state.copyWith(isLoadingMore: true, failureCode: null);
    try {
      final page = await repository.listOrders(
        filters: state.filters,
        cursor: cursor,
        limit: pageSize,
      );
      if (requestGeneration != _generation) {
        return;
      }
      final merged = <CustomerOrderSummary>[...state.orders];
      for (final order in page.items) {
        if (_seenIds.add(order.id)) {
          merged.add(order);
        }
      }
      state = state.copyWith(
        status: merged.isEmpty ? OrdersViewStatus.empty : OrdersViewStatus.data,
        orders: merged,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        isLoadingMore: false,
        isStale: false,
        failureCode: null,
      );
    } catch (error) {
      if (requestGeneration == _generation) {
        final failure = _failureFrom(error);
        state = state.copyWith(
          isLoadingMore: false,
          isStale: state.orders.isNotEmpty,
          failureCode: failure.code,
        );
      }
    } finally {
      _loadMoreInFlight = false;
    }
  }

  Future<void> _loadFirstPage({
    required bool preserveExisting,
    bool incrementGeneration = true,
  }) async {
    if (_firstPageInFlight && !incrementGeneration) {
      return;
    }
    if (incrementGeneration) {
      _generation += 1;
    }
    final requestGeneration = _generation;
    final hasExisting = preserveExisting && state.orders.isNotEmpty;
    _firstPageInFlight = true;
    state = state.copyWith(
      status: hasExisting ? OrdersViewStatus.data : OrdersViewStatus.loading,
      isRefreshing: hasExisting,
      isLoadingMore: false,
      isStale: false,
      failureCode: null,
      nextCursor: hasExisting ? state.nextCursor : null,
      hasMore: hasExisting && state.hasMore,
      orders: hasExisting ? state.orders : const [],
    );

    try {
      final repository = _ordersRepository;
      if (repository == null) {
        throw const PlatformFailure(PlatformFailureCode.temporarilyUnavailable);
      }
      final ordersFuture = repository.listOrders(
        filters: state.filters,
        limit: pageSize,
      );
      final gamesFuture = _loadGames();
      final page = await ordersFuture;
      final games = await gamesFuture;
      if (requestGeneration != _generation) {
        return;
      }

      _seenIds
        ..clear()
        ..addAll(page.items.map((order) => order.id));
      state = state.copyWith(
        status: page.items.isEmpty
            ? OrdersViewStatus.empty
            : OrdersViewStatus.data,
        orders: page.items,
        games: games,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        isRefreshing: false,
        isLoadingMore: false,
        isStale: false,
        failureCode: null,
      );
    } catch (error) {
      if (requestGeneration != _generation) {
        return;
      }
      final failure = _failureFrom(error);
      if (hasExisting) {
        state = state.copyWith(
          status: OrdersViewStatus.data,
          isRefreshing: false,
          isStale: true,
          failureCode: failure.code,
        );
      } else {
        state = state.copyWith(
          status: failure.code == PlatformFailureCode.networkUnavailable
              ? OrdersViewStatus.offline
              : OrdersViewStatus.error,
          isRefreshing: false,
          isStale: false,
          failureCode: failure.code,
        );
      }
    } finally {
      if (requestGeneration == _generation) {
        _firstPageInFlight = false;
      }
    }
  }

  Future<List<Game>> _loadGames() async {
    final repository = _gamesRepository;
    if (repository == null) {
      return state.games;
    }
    final games = <Game>[];
    String? cursor;
    for (var index = 0; index < _maximumGamePages; index += 1) {
      final page = await repository.listGames(
        cursor: cursor,
        limit: _gamesPageSize,
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
}

bool _sameFilters(OrderFilters left, OrderFilters right) {
  return left.orderStatus == right.orderStatus &&
      left.paymentStatus == right.paymentStatus &&
      left.paymentMethod == right.paymentMethod &&
      left.gameId == right.gameId &&
      left.dateFrom == right.dateFrom &&
      left.dateToExclusive == right.dateToExclusive &&
      left.searchText == right.searchText;
}

PlatformFailure _failureFrom(Object error) {
  if (error is PlatformFailure) {
    return error;
  }
  return const PlatformFailure(PlatformFailureCode.unknown);
}
