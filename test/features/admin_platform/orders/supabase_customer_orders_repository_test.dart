import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/common/platform_session_coordinator.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_cursor.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_enums.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_filters.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/supabase_platform_error_mapper.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/supabase_customer_orders_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/supabase_orders_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('list regression coverage', () {
    test(
      'converts every filter and the full cursor to typed RPC params',
      () async {
        final dataSource = _DataSource(
          listRows: <Map<String, Object?>>[
            _listRow(
              id: '00000000-0000-0000-0000-000000000002',
              hasMore: false,
            ),
          ],
        );
        final repository = _repository(dataSource);
        final filters = OrderFilters(
          orderStatus: OrderStatus.processing,
          paymentStatus: PaymentStatus.underReview,
          paymentMethod: PaymentMethod.transfer,
          gameId: '10000000-0000-0000-0000-000000000001',
          dateFrom: DateTime.parse('2026-07-01T01:00:00+01:00'),
          dateToExclusive: DateTime.parse('2026-08-01T01:00:00+01:00'),
          searchText: r"عميل français %_\ 'quote' (test)",
        );
        final cursor = OrderCursor(
          createdAt: DateTime.parse('2026-07-17T13:00:00+01:00'),
          id: '00000000-0000-0000-0000-000000000001',
        );

        await repository.listOrders(
          filters: filters,
          cursor: cursor,
          limit: 25,
        );

        expect(dataSource.listCalls, 1);
        expect(dataSource.lastListParams, <String, Object?>{
          'p_order_status': 'processing',
          'p_payment_status': 'under_review',
          'p_payment_method': 'transfer',
          'p_game_id': '10000000-0000-0000-0000-000000000001',
          'p_date_from': '2026-07-01T00:00:00.000Z',
          'p_date_to_exclusive': '2026-08-01T00:00:00.000Z',
          'p_search_text': r"عميل français %_\ 'quote' (test)",
          'p_cursor_created_at': '2026-07-17T12:00:00.000Z',
          'p_cursor_id': '00000000-0000-0000-0000-000000000001',
          'p_limit': 25,
        });
      },
    );

    test(
      'uses the last row as the full cursor for same-timestamp tie breaking',
      () async {
        const timestamp = '2026-07-17T12:00:00Z';
        final dataSource = _DataSource(
          listRows: <Map<String, Object?>>[
            _listRow(
              id: '00000000-0000-0000-0000-000000000003',
              createdAt: timestamp,
              hasMore: true,
            ),
            _listRow(
              id: '00000000-0000-0000-0000-000000000002',
              createdAt: timestamp,
              hasMore: true,
            ),
          ],
        );

        final page = await _repository(
          dataSource,
        ).listOrders(filters: OrderFilters());

        expect(page.items.map((item) => item.id), <String>[
          '00000000-0000-0000-0000-000000000003',
          '00000000-0000-0000-0000-000000000002',
        ]);
        expect(page.hasMore, isTrue);
        expect(page.nextCursor?.createdAt, DateTime.utc(2026, 7, 17, 12));
        expect(page.nextCursor?.id, '00000000-0000-0000-0000-000000000002');
      },
    );

    test('last page has no cursor and loses or duplicates no rows', () async {
      final rows = <Map<String, Object?>>[
        _listRow(id: '00000000-0000-0000-0000-000000000003', hasMore: false),
        _listRow(id: '00000000-0000-0000-0000-000000000002', hasMore: false),
        _listRow(id: '00000000-0000-0000-0000-000000000001', hasMore: false),
      ];

      final page = await _repository(
        _DataSource(listRows: rows),
      ).listOrders(filters: OrderFilters());

      expect(page.items, hasLength(3));
      expect(page.items.map((item) => item.id).toSet(), hasLength(3));
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
    });

    test('rejects invalid limits before calling the data source', () {
      final dataSource = _DataSource();

      expect(
        () => _repository(
          dataSource,
        ).listOrders(filters: OrderFilters(), limit: 26),
        throwsA(
          isA<PlatformFailure>().having(
            (failure) => failure.code,
            'code',
            PlatformFailureCode.validation,
          ),
        ),
      );
      expect(dataSource.listCalls, 0);
    });

    test('rejects inconsistent has_more values as malformedResponse', () async {
      final repository = _repository(
        _DataSource(
          listRows: <Map<String, Object?>>[
            _listRow(id: '00000000-0000-0000-0000-000000000002', hasMore: true),
            _listRow(
              id: '00000000-0000-0000-0000-000000000001',
              hasMore: false,
            ),
          ],
        ),
      );

      await expectLater(
        repository.listOrders(filters: OrderFilters()),
        throwsA(
          isA<PlatformFailure>().having(
            (failure) => failure.code,
            'code',
            PlatformFailureCode.malformedResponse,
          ),
        ),
      );
    });

    test('maps list network and authorization errors safely', () async {
      final cases = <(Object, PlatformFailureCode)>[
        (
          TimeoutException('network fixture'),
          PlatformFailureCode.networkUnavailable,
        ),
        (
          const PostgrestException(
            message: 'private database message',
            code: '42501',
            details: 'private payload',
            hint: 'private hint',
          ),
          PlatformFailureCode.unauthorized,
        ),
      ];

      for (final entry in cases) {
        final repository = _repository(_DataSource(error: entry.$1));
        try {
          await repository.listOrders(filters: OrderFilters());
          fail('Expected a PlatformFailure.');
        } catch (error) {
          expect(error, isA<PlatformFailure>());
          expect((error as PlatformFailure).code, entry.$2);
          expect(error.toString(), isNot(contains('private payload')));
        }
      }
    });

    test('maps malformed list payloads to malformedResponse', () async {
      final malformed = _listRow(
        id: '00000000-0000-0000-0000-000000000001',
        hasMore: false,
      )..['has_more'] = 'false';
      final repository = _repository(
        _DataSource(listRows: <Map<String, Object?>>[malformed]),
      );

      await expectLater(
        repository.listOrders(filters: OrderFilters()),
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

SupabaseCustomerOrdersRepository _repository(
  SupabaseOrdersDataSource dataSource, [
  PlatformReadCoordinator? coordinator,
]) => SupabaseCustomerOrdersRepository(
  dataSource: dataSource,
  errorMapper: const SupabasePlatformErrorMapper(),
  readCoordinator: coordinator ?? _Coordinator(),
);

class _Coordinator implements PlatformReadCoordinator {
  int calls = 0;

  @override
  Future<T> runRead<T>(PlatformReadOperation<T> operation) {
    calls += 1;
    return operation();
  }
}

class _DataSource implements SupabaseOrdersDataSource {
  _DataSource({this.listRows = const <Map<String, Object?>>[], this.error});

  final List<Map<String, Object?>> listRows;
  final Object? error;
  int listCalls = 0;
  Map<String, Object?>? lastListParams;

  @override
  Future<List<Map<String, Object?>>> listOrders({
    required Map<String, Object?> params,
  }) async {
    listCalls += 1;
    lastListParams = params;
    if (error case final value?) throw value;
    return listRows;
  }

  @override
  Future<List<Map<String, Object?>>> getOrderDetails({
    required String orderId,
  }) async => const <Map<String, Object?>>[];

  @override
  Future<List<Map<String, Object?>>> getOrderTimeline({
    required String orderId,
  }) async => const <Map<String, Object?>>[];

  @override
  Future<List<Map<String, Object?>>> getOrderInternalNotes({
    required String orderId,
  }) async => const <Map<String, Object?>>[];
}

Map<String, Object?> _listRow({
  required String id,
  required bool hasMore,
  String createdAt = '2026-07-17T12:00:00Z',
}) {
  return <String, Object?>{
    'id': id,
    'game_name_ar_snapshot': 'لعبة',
    'game_name_fr_snapshot': 'Jeu',
    'offer_name_ar_snapshot': 'عرض',
    'offer_name_fr_snapshot': 'Offre',
    'customer_name_snapshot': 'زبون',
    'player_id': 'player-123',
    'in_game_name': 'Player',
    'sale_price_dzd_snapshot': 350,
    'reward_quantity_snapshot': 100,
    'reward_unit_name_ar_snapshot': 'جوهرة',
    'reward_unit_name_fr_snapshot': 'diamants',
    'payment_method': 'transfer',
    'order_status': 'processing',
    'payment_status': 'under_review',
    'created_at': createdAt,
    'has_payment_proof': true,
    'has_more': hasMore,
  };
}
