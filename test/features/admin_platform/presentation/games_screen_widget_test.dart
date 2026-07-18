import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/games/games_providers.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/cursor_page.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/games/game.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/games/game_input.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/games/games_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/presentation/games/games_screen.dart';

void main() {
  testWidgets('shows loading then empty state', (tester) async {
    final completer = Completer<CursorPage<Game>>();
    final repository = _FakeGamesRepository()
      ..listResults.add(completer.future);

    await _pumpGames(tester, repository: repository, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(_page(const <Game>[]));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد ألعاب بعد.'), findsOneWidget);
    expect(find.byKey(const Key('empty-add-game-button')), findsOneWidget);
  });

  testWidgets('shows offline state and retry action', (tester) async {
    final repository = _FakeGamesRepository()
      ..listResults.add(
        const PlatformFailure(PlatformFailureCode.networkUnavailable),
      );

    await _pumpGames(tester, repository: repository);

    expect(find.text('لا يوجد اتصال بالمنصة.'), findsOneWidget);
    expect(find.byKey(const Key('games-retry-button')), findsOneWidget);
  });

  testWidgets('keeps stale data after refresh fails offline', (tester) async {
    final repository = _FakeGamesRepository()
      ..listResults.add(_page(<Game>[_game]))
      ..listResults.add(
        const PlatformFailure(PlatformFailureCode.networkUnavailable),
      );

    await _pumpGames(tester, repository: repository);
    expect(find.text('فري فاير'), findsOneWidget);

    await tester.tap(find.byKey(const Key('refresh-games-button')));
    await tester.pumpAndSettle();

    expect(find.text('فري فاير'), findsOneWidget);
    expect(find.textContaining('البيانات المعروضة قديمة.'), findsOneWidget);
  });

  testWidgets('opens add form with all fields and no delete action', (
    tester,
  ) async {
    final repository = _FakeGamesRepository()
      ..listResults.add(_page(const <Game>[]));
    await _pumpGames(tester, repository: repository);

    await tester.tap(find.byKey(const Key('add-game-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('game-slug-field')), findsOneWidget);
    expect(find.byKey(const Key('game-name-ar-field')), findsOneWidget);
    expect(find.byKey(const Key('game-name-fr-field')), findsOneWidget);
    expect(find.byKey(const Key('game-reward-code-field')), findsOneWidget);
    expect(find.byKey(const Key('game-sort-order-field')), findsOneWidget);
    expect(find.byKey(const Key('save-game-button')), findsOneWidget);
    expect(find.text('حذف'), findsNothing);
  });

  testWidgets('Arabic is RTL and French is LTR with translated labels', (
    tester,
  ) async {
    final arabicRepository = _FakeGamesRepository()
      ..listResults.add(_page(<Game>[_game]));
    await _pumpGames(tester, repository: arabicRepository);
    expect(_directionOf(tester), TextDirection.rtl);
    expect(find.text('إدارة الألعاب'), findsOneWidget);

    final frenchRepository = _FakeGamesRepository()
      ..listResults.add(_page(<Game>[_game]));
    await _pumpGames(
      tester,
      repository: frenchRepository,
      locale: const Locale('fr', 'FR'),
    );
    expect(_directionOf(tester), TextDirection.ltr);
    expect(find.text('Gestion des jeux'), findsOneWidget);
    expect(find.text('Free Fire'), findsOneWidget);
    expect(find.byTooltip('Actualiser les jeux'), findsOneWidget);
  });

  testWidgets('320x640 at text scale 2.0 has no overflow', (tester) async {
    final repository = _FakeGamesRepository()
      ..listResults.add(_page(<Game>[_game]));

    await _pumpGames(
      tester,
      repository: repository,
      size: const Size(320, 640),
      textScaler: const TextScaler.linear(2),
    );

    expect(find.byKey(const Key('games-list-view')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes refresh, add, edit, and toggle semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = _FakeGamesRepository()
      ..listResults.add(_page(<Game>[_game]));

    await _pumpGames(tester, repository: repository);

    expect(find.bySemanticsLabel(RegExp('تحديث الألعاب')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('إضافة لعبة')), findsWidgets);
    expect(
      find.bySemanticsLabel(RegExp('تعديل اللعبة فري فاير')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('تعطيل اللعبة فري فاير')),
      findsOneWidget,
    );
    semantics.dispose();
  });
}

Future<void> _pumpGames(
  WidgetTester tester, {
  required GamesRepository repository,
  Locale locale = const Locale('ar', 'DZ'),
  Size size = const Size(390, 800),
  TextScaler textScaler = TextScaler.noScaling,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [gamesRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('ar', 'DZ'), Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const GamesScreen(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

TextDirection _directionOf(WidgetTester tester) {
  return tester
      .widget<Directionality>(find.byType(Directionality).first)
      .textDirection;
}

CursorPage<Game> _page(Iterable<Game> games) =>
    CursorPage<Game>(items: games, nextCursor: null, hasMore: false);

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

class _FakeGamesRepository implements GamesRepository {
  final List<Object> listResults = <Object>[];
  int listCalls = 0;

  @override
  Future<CursorPage<Game>> listGames({String? cursor, int? limit}) async {
    final result = listResults[listCalls++];
    if (result is CursorPage<Game>) return result;
    if (result is Future<CursorPage<Game>>) return result;
    throw result;
  }

  @override
  Future<Game> createGame(GameInput input) async => _game;

  @override
  Future<Game> setGameActive({
    required String gameId,
    required bool isActive,
  }) async {
    return _game;
  }

  @override
  Future<Game> updateGame({
    required String gameId,
    required GameInput input,
  }) async {
    return _game;
  }
}
