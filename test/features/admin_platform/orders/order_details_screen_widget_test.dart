import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/common/platform_common_providers.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/orders/orders_providers.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_models.dart';
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
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_internal_note.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_page.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_timeline_event.dart';
import 'package:game_credit_profit_manager/features/admin_platform/presentation/orders/customer_orders_screen.dart';
import 'package:game_credit_profit_manager/features/admin_platform/presentation/orders/order_details_screen.dart';

final _testAuthStateProvider = StateProvider<AdminAuthState>(
  (ref) => const AdminAuthState.authorized(),
);

void main() {
  testWidgets(
    'card opens details while contact PII remains absent from the list',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pumpOrders(tester);

        expect(find.textContaining('customer@example.test'), findsNothing);
        expect(find.textContaining('0550000000'), findsNothing);
        expect(find.textContaining('Private fixture note'), findsNothing);
        expect(
          find.bySemanticsLabel(
            RegExp(
              r'customer@example\.test|0550000000|player-123|Player Fixture',
            ),
          ),
          findsNothing,
        );
        expect(
          find.bySemanticsLabel(RegExp('طلب 11111111.*فتح تفاصيل الطلب')),
          findsOneWidget,
        );

        await _openDetails(tester);

        expect(find.byType(OrderDetailsScreen), findsOneWidget);
        expect(find.text('#11111111'), findsOneWidget);
        expect(
          find.textContaining('11111111-1111-1111-1111-111111111111'),
          findsNothing,
        );
        expect(find.textContaining('customer@example.test'), findsOneWidget);
        expect(find.textContaining('0550000000'), findsOneWidget);
        expect(find.byType(SelectableText), findsNWidgets(3));
        expect(find.bySemanticsLabel('معلومات الاتصال'), findsWidgets);
        expect(find.text('البريد الإلكتروني:'), findsOneWidget);
        expect(find.text('رقم الهاتف:'), findsOneWidget);
        expect(
          tester
              .widget<SelectableText>(
                find.widgetWithText(SelectableText, 'customer@example.test'),
              )
              .textDirection,
          TextDirection.ltr,
        );
        expect(
          tester
              .widget<SelectableText>(
                find.widgetWithText(SelectableText, '0550000000'),
              )
              .textDirection,
          TextDirection.ltr,
        );
        expect(
          find.bySemanticsLabel(RegExp(r'customer@example\.test|0550000000')),
          findsWidgets,
        );

        final detailsList = find.byKey(const Key('order-details-list'));
        await tester.scrollUntilVisible(
          find.byKey(const Key('order-details-internal-notes')),
          300,
          scrollable: _detailsScrollable(detailsList),
        );
        await tester.pumpAndSettle();
        expect(find.text('الملاحظات الداخلية'), findsOneWidget);
        expect(find.text('Private fixture note'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('timeline is displayed oldest to newest with Arabic RTL', (
    tester,
  ) async {
    await _pumpOrders(tester);
    await _openDetails(tester);
    final detailsList = find.byKey(const Key('order-details-list'));
    final detailsScrollable = _detailsScrollable(detailsList);
    expect(detailsScrollable, findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('order-details-timeline')),
      500,
      scrollable: detailsScrollable,
    );
    await tester.pumpAndSettle();

    final first = find.text('First public event');
    final second = find.text('Second public event');
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy));
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );
  });

  testWidgets('French details are LTR and localized', (tester) async {
    await _pumpOrders(tester, locale: const Locale('fr', 'FR'));
    await _openDetails(tester);

    expect(find.text('Résumé de la commande'), findsOneWidget);
    expect(find.text('Coordonnées'), findsOneWidget);
    expect(find.textContaining('Free Fire'), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.ltr,
    );
    final detailsList = find.byKey(const Key('order-details-list'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('order-details-internal-notes')),
      300,
      scrollable: _detailsScrollable(detailsList),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notes internes'), findsOneWidget);
  });

  testWidgets('empty internal notes use the localized safe state', (
    tester,
  ) async {
    await _pumpOrders(tester, includeInternalNotes: false);
    await _openDetails(tester);

    final detailsList = find.byKey(const Key('order-details-list'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('order-details-internal-notes')),
      300,
      scrollable: _detailsScrollable(detailsList),
    );
    await tester.pumpAndSettle();

    expect(find.text('لا توجد ملاحظات داخلية.'), findsOneWidget);
    expect(find.text('Private fixture note'), findsNothing);
  });

  testWidgets('details support 320 by 640 and 200 percent text scale', (
    tester,
  ) async {
    await _pumpOrders(
      tester,
      size: const Size(320, 640),
      textScaler: const TextScaler.linear(2),
    );
    await _openDetails(tester);

    expect(find.byKey(const Key('order-details-list')), findsOneWidget);
    final detailsList = find.byKey(const Key('order-details-list'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('order-details-internal-notes')),
      300,
      scrollable: _detailsScrollable(detailsList),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private fixture note'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('order-details-timeline')),
      300,
      scrollable: _detailsScrollable(detailsList),
    );
    await tester.pumpAndSettle();
    expect(find.text('Second public event'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('session expiry removes PII before returning to a safe screen', (
    tester,
  ) async {
    await _pumpOrders(tester);
    await _openDetails(tester);
    expect(find.textContaining('customer@example.test'), findsOneWidget);
    final detailsList = find.byKey(const Key('order-details-list'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('order-details-internal-notes')),
      300,
      scrollable: _detailsScrollable(detailsList),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private fixture note'), findsOneWidget);

    final context = tester.element(find.byType(OrderDetailsScreen));
    final container = ProviderScope.containerOf(context);
    container.read(_testAuthStateProvider.notifier).state =
        const AdminAuthState.sessionExpired();
    await tester.pump();

    expect(find.textContaining('customer@example.test'), findsNothing);
    expect(find.textContaining('0550000000'), findsNothing);
    expect(find.textContaining('Private fixture note'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byType(OrderDetailsScreen), findsNothing);
    expect(find.byKey(const Key('orders-list')), findsOneWidget);
  });
}

Finder _detailsScrollable(Finder detailsList) {
  return find
      .descendant(of: detailsList, matching: find.byType(Scrollable))
      .first;
}

Future<void> _pumpOrders(
  WidgetTester tester, {
  Locale locale = const Locale('ar', 'DZ'),
  Size size = const Size(390, 800),
  TextScaler textScaler = TextScaler.noScaling,
  bool includeInternalNotes = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        platformAdminAuthStateProvider.overrideWith((ref) {
          return ref.watch(_testAuthStateProvider);
        }),
        customerOrdersRepositoryProvider.overrideWithValue(
          _OrdersRepository(includeInternalNotes: includeInternalNotes),
        ),
        ordersGamesRepositoryProvider.overrideWithValue(
          const _GamesRepository(),
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

Future<void> _openDetails(WidgetTester tester) async {
  final card = find.byKey(const Key('order-card-open-11111111'));
  expect(card, findsOneWidget);
  await tester.tapAt(tester.getTopLeft(card) + const Offset(24, 24));
  await tester.pumpAndSettle();
}

class _OrdersRepository implements CustomerOrdersRepository {
  const _OrdersRepository({this.includeInternalNotes = true});

  final bool includeInternalNotes;

  @override
  Future<OrderPage> listOrders({
    required OrderFilters filters,
    OrderCursor? cursor,
    int limit = customerOrdersMaxPageSize,
  }) async {
    return OrderPage(
      items: <CustomerOrderSummary>[_summary()],
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<CustomerOrderDetails> getOrderDetails({
    required String orderId,
  }) async {
    return CustomerOrderDetails(
      summary: _summary(),
      rewardUnitCodeSnapshot: 'diamond',
      customerEmail: 'customer@example.test',
      customerPhone: '0550000000',
      publicStatusMessage: 'Public fixture status',
      updatedAt: DateTime.utc(2026, 7, 18, 13),
      completedAt: null,
      refundStartedAt: null,
      refundedAt: null,
    );
  }

  @override
  Future<List<OrderTimelineEvent>> getOrderTimeline({
    required String orderId,
  }) async {
    return <OrderTimelineEvent>[
      OrderTimelineEvent(
        eventType: OrderTimelineEventType.created,
        orderStatus: OrderStatus.newOrder,
        paymentStatus: PaymentStatus.awaitingPayment,
        publicMessage: 'First public event',
        createdAt: DateTime.utc(2026, 7, 18, 10),
      ),
      OrderTimelineEvent(
        eventType: OrderTimelineEventType.paymentChanged,
        orderStatus: OrderStatus.processing,
        paymentStatus: PaymentStatus.underReview,
        publicMessage: 'Second public event',
        createdAt: DateTime.utc(2026, 7, 18, 11),
      ),
    ];
  }

  @override
  Future<List<OrderInternalNote>> getOrderInternalNotes({
    required String orderId,
  }) async {
    if (!includeInternalNotes) return const <OrderInternalNote>[];
    return <OrderInternalNote>[
      OrderInternalNote(
        text: 'Private fixture note',
        createdAt: DateTime.utc(2026, 7, 18, 10, 30),
      ),
    ];
  }
}

class _GamesRepository implements GamesRepository {
  const _GamesRepository();

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
    throw UnsupportedError('Read-only fixture.');
  }

  @override
  Future<Game> setGameActive({required String gameId, required bool isActive}) {
    throw UnsupportedError('Read-only fixture.');
  }

  @override
  Future<Game> updateGame({required String gameId, required GameInput input}) {
    throw UnsupportedError('Read-only fixture.');
  }
}

CustomerOrderSummary _summary() {
  return CustomerOrderSummary(
    id: '11111111-1111-1111-1111-111111111111',
    gameNameArSnapshot: 'فري فاير',
    gameNameFrSnapshot: 'Free Fire',
    offerNameArSnapshot: 'عرض 100 جوهرة',
    offerNameFrSnapshot: 'Offre 100 diamants',
    customerName: 'Customer Fixture',
    playerId: 'player-123',
    inGameName: 'Player Fixture',
    salePriceDzd: 350,
    rewardQuantity: 100,
    rewardUnitNameAr: 'جوهرة',
    rewardUnitNameFr: 'diamants',
    paymentMethod: PaymentMethod.transfer,
    orderStatus: OrderStatus.processing,
    paymentStatus: PaymentStatus.underReview,
    createdAt: DateTime.utc(2026, 7, 18, 12),
    hasPaymentProof: true,
  );
}
