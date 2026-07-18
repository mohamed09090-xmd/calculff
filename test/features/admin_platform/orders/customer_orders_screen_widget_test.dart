import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/orders/orders_providers.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/cursor_page.dart';
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
import 'package:game_credit_profit_manager/features/admin_platform/presentation/orders/customer_orders_screen.dart';

void main() {
  testWidgets('Arabic list is RTL and exposes only approved summary fields', (
    tester,
  ) async {
    await _pumpOrders(tester);

    expect(find.byKey(const Key('orders-list')), findsOneWidget);
    expect(find.text('قائمة الطلبات'), findsOneWidget);
    expect(find.text('#11111111'), findsOneWidget);
    expect(find.textContaining('لعبة فري فاير'), findsOneWidget);
    expect(find.textContaining('عرض 100 جوهرة'), findsOneWidget);
    expect(find.textContaining('زبون تجريبي'), findsWidgets);
    expect(find.textContaining('player-123'), findsOneWidget);
    expect(find.textContaining('Player One'), findsOneWidget);
    expect(find.textContaining('350 دج'), findsOneWidget);
    expect(
      find.textContaining('11111111-1111-1111-1111-111111111111'),
      findsNothing,
    );
    expect(find.textContaining('customer@example.test'), findsNothing);
    expect(find.textContaining('0550000000'), findsNothing);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );
  });

  testWidgets('French list is LTR and localized', (tester) async {
    await _pumpOrders(tester, locale: const Locale('fr', 'FR'));

    expect(find.text('Liste des commandes'), findsOneWidget);
    expect(find.textContaining('Free Fire'), findsOneWidget);
    expect(find.textContaining('Offre 100 diamants'), findsOneWidget);
    expect(find.textContaining('Virement'), findsWidgets);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('320 by 640 with text scale 2 has no overflow', (tester) async {
    await _pumpOrders(
      tester,
      size: const Size(320, 640),
      textScaler: const TextScaler.linear(2),
    );

    expect(find.byKey(const Key('orders-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh, filters, cards, and proof indicator expose semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await _pumpOrders(tester);

      expect(find.bySemanticsLabel('تحديث الطلبات'), findsWidgets);
      expect(find.bySemanticsLabel('الفلاتر'), findsWidgets);
      expect(
        find.bySemanticsLabel(RegExp('طلب 11111111.*زبون تجريبي')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('يوجد إثبات دفع'), findsWidgets);
    } finally {
      handle.dispose();
    }
  });
}

Future<void> _pumpOrders(
  WidgetTester tester, {
  Locale locale = const Locale('ar', 'DZ'),
  Size size = const Size(390, 800),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        customerOrdersRepositoryProvider.overrideWithValue(
          _FakeOrdersRepository(),
        ),
        ordersGamesRepositoryProvider.overrideWithValue(
          const _FakeGamesRepository(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const <Locale>[
          Locale('ar', 'DZ'),
          Locale('fr', 'FR'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const CustomerOrdersScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeOrdersRepository implements CustomerOrdersRepository {
  @override
  Future<OrderPage> listOrders({
    required OrderFilters filters,
    OrderCursor? cursor,
    int limit = customerOrdersMaxPageSize,
  }) async {
    return OrderPage(
      items: <CustomerOrderSummary>[_sampleOrder()],
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<CustomerOrderDetails> getOrderDetails({required String orderId}) {
    throw UnsupportedError('List-only fake.');
  }

  @override
  Future<List<OrderTimelineEvent>> getOrderTimeline({required String orderId}) {
    throw UnsupportedError('List-only fake.');
  }
}

class _FakeGamesRepository implements GamesRepository {
  const _FakeGamesRepository();

  @override
  Future<CursorPage<Game>> listGames({String? cursor, int? limit}) async {
    return CursorPage<Game>(
      items: const <Game>[],
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<Game> createGame(GameInput input) {
    throw UnsupportedError('Read-only fake.');
  }

  @override
  Future<Game> setGameActive({required String gameId, required bool isActive}) {
    throw UnsupportedError('Read-only fake.');
  }

  @override
  Future<Game> updateGame({required String gameId, required GameInput input}) {
    throw UnsupportedError('Read-only fake.');
  }
}

CustomerOrderSummary _sampleOrder() {
  return CustomerOrderSummary(
    id: '11111111-1111-1111-1111-111111111111',
    gameNameArSnapshot: 'لعبة فري فاير',
    gameNameFrSnapshot: 'Free Fire',
    offerNameArSnapshot: 'عرض 100 جوهرة',
    offerNameFrSnapshot: 'Offre 100 diamants',
    customerName: 'زبون تجريبي',
    playerId: 'player-123',
    inGameName: 'Player One',
    salePriceDzd: 350,
    rewardQuantity: 100,
    rewardUnitNameAr: 'جوهرة',
    rewardUnitNameFr: 'diamants',
    paymentMethod: PaymentMethod.transfer,
    orderStatus: OrderStatus.processing,
    paymentStatus: PaymentStatus.underReview,
    createdAt: DateTime.utc(2026, 7, 17, 12),
    hasPaymentProof: true,
  );
}
