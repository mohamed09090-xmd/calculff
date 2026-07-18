import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/orders/orders_controller.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/cursor_page.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/games/game.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/games/game_input.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/games/games_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/customer_order_details.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/customer_order_summary.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/customer_orders_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_cursor.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_enums.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_filters.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_page.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_timeline_event.dart';

void main() {
  group('OrdersController', () {
    test('loads pages, prevents duplicate load more, and removes duplicates', () async {
      final loadMoreCompleter = Completer<OrderPage>();
      final repository = _FakeOrdersRepository(<Future<OrderPage> Function()>[
        () async => OrderPage(
          items: <CustomerOrderSummary>[_order(1), _order(2)],
          nextCursor: OrderCursor(
            createdAt: _order(2).createdAt,
            id: _order(2).id,
          ),
          hasMore: true,
        ),
        () => loadMoreCompleter.future,
      ]);
      final controller = OrdersController(
        ordersRepository: repository,
        gamesRepository: const _FakeGamesRepository(),
      );

      await controller.load();
      final first = controller.loadMore();
      final duplicate = controller.loadMore();
      await Future<void>.delayed(Duration.zero);

      expect(repository.calls, 2);
      expect(repository.maximumConcurrentCalls, 1);

      loadMoreCompleter.complete(
        OrderPage(
          items: <CustomerOrderSummary>[_order(2), _order(3)],
          nextCursor: null,
          hasMore: false,
        ),
      );
      await Future.wait(<Future<void>>[first, duplicate]);

      expect(controller.state.orders.map((order) => order.displayId), <String>[
        _order(1).displayId,
        _order(2).displayId,
        _order(3).displayId,
      ]);
      expect(controller.state.hasMore, isFalse);
      expect(controller.state.isLoadingMore, isFalse);
    });

    test('resets on filter changes and ignores the old response', () async {
      final oldResponse = Completer<OrderPage>();
      final newResponse = Completer<OrderPage>();
      final repository = _FakeOrdersRepository(<Future<OrderPage> Function()>[
        () => oldResponse.future,
        () => newResponse.future,
      ]);
      final controller = OrdersController(
        ordersRepository: repository,
        gamesRepository: const _FakeGamesRepository(),
      );

      final initialLoad = controller.load();
      await Future<void>.delayed(Duration.zero);
      final filteredLoad = controller.updateFilters(
        OrderFilters(searchText: 'français'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.orders, isEmpty);
      expect(controller.state.filters.searchText, 'français');

      newResponse.complete(
        OrderPage(
          items: <CustomerOrderSummary>[_order(9)],
          nextCursor: null,
          hasMore: false,
        ),
      );
      await filteredLoad;
      oldResponse.complete(
        OrderPage(
          items: <CustomerOrderSummary>[_order(1)],
          nextCursor: null,
          hasMore: false,
        ),
      );
      await initialLoad;

      expect(controller.state.orders.single.displayId, _order(9).displayId);
      expect(controller.state.filters.searchText, 'français');
    });

    test('keeps stale data when refresh fails offline', () async {
      final repository = _FakeOrdersRepository(<Future<OrderPage> Function()>[
        () async => OrderPage(
          items: <CustomerOrderSummary>[_order(1)],
          nextCursor: null,
          hasMore: false,
        ),
        () async => throw const PlatformFailure(
          PlatformFailureCode.networkUnavailable,
        ),
      ]);
      final controller = OrdersController(
        ordersRepository: repository,
        gamesRepository: const _FakeGamesRepository(),
      );

      await controller.load();
      await controller.refresh();

      expect(controller.state.status, OrdersViewStatus.data);
      expect(controller.state.orders.single.displayId, _order(1).displayId);
      expect(controller.state.isStale, isTrue);
      expect(
        controller.state.failureCode,
        PlatformFailureCode.networkUnavailable,
      );
    });
  });
}

class _FakeOrdersRepository implements CustomerOrdersRepository {
  _FakeOrdersRepository(this.responses);

  final List<Future<OrderPage> Function()> responses;
  int calls = 0;
  int _activeCalls = 0;
  int maximumConcurrentCalls = 0;

  @override
  Future<OrderPage> listOrders({
    required OrderFilters filters,
    OrderCursor? cursor,
    int limit = customerOrdersMaxPageSize,
  }) async {
    final index = calls;
    calls += 1;
    _activeCalls += 1;
    if (_activeCalls > maximumConcurrentCalls) {
      maximumConcurrentCalls = _activeCalls;
    }
    try {
      return await responses[index]();
    } finally {
      _activeCalls -= 1;
    }
  }

  @override
  Future<CustomerOrderDetails> getOrderDetails({required String orderId}) {
    throw UnsupportedError('Not used by list tests.');
  }

  @override
  Future<List<OrderTimelineEvent>> getOrderTimeline({required String orderId}) {
    throw UnsupportedError('Not used by list tests.');
  }
}

class _FakeGamesRepository implements GamesRepository {
  const _FakeGamesRepository();

  @override
  Future<CursorPage<Game>> listGames({String? cursor, int? limit}) async {
    return const CursorPage<Game>(items: <Game>[], hasMore: false);
  }

  @override
  Future<Game> createGame(GameInput input) {
    throw UnsupportedError('Read-only fake.');
  }

  @override
  Future<Game> setGameActive({
    required String gameId,
    required bool isActive,
  }) {
    throw UnsupportedError('Read-only fake.');
  }

  @override
  Future<Game> updateGame({
    required String gameId,
    required GameInput input,
  }) {
    throw UnsupportedError('Read-only fake.');
  }
}

CustomerOrderSummary _order(int suffix) {
  final tail = suffix.toString().padLeft(12, '0');
  return CustomerOrderSummary(
    id: '00000000-0000-0000-0000-$tail',
    gameNameArSnapshot: 'لعبة',
    gameNameFrSnapshot: 'Jeu',
    offerNameArSnapshot: 'عرض',
    offerNameFrSnapshot: 'Offre',
    customerName: 'زبون $suffix',
    playerId: 'player-$suffix',
    inGameName: 'Player $suffix',
    salePriceDzd: 350,
    rewardQuantity: 100,
    rewardUnitNameAr: 'جوهرة',
    rewardUnitNameFr: 'diamants',
    paymentMethod: PaymentMethod.transfer,
    orderStatus: OrderStatus.processing,
    paymentStatus: PaymentStatus.underReview,
    createdAt: DateTime.utc(2026, 7, 17, 12, 0, suffix),
    hasPaymentProof: suffix.isEven,
  );
}
