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
  const orderId = '11111111-1111-1111-1111-111111111111';

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
        expect(
          page.nextCursor?.id,
          '00000000-0000-0000-0000-000000000002',
        );
      },
    );

    test('last page has no cursor and loses or duplicates no rows', () async {
      final rows = <Map<String, Object?>>[
        _listRow(
          id: '00000000-0000-0000-0000-000000000003',
          hasMore: false,
        ),
        _listRow(
          id: '00000000-0000-0000-0000-000000000002',
          hasMore: false,
        ),
        _listRow(
          id: '00000000-0000-0000-0000-000000000001',
          hasMore: false,
        ),
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
            _listRow(
              id: '00000000-0000-0000-0000-000000000002',
              hasMore: true,
            ),
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

  group('details and timeline', () {
    test('builds stable list RPC params with UTC cursor values', () {
      final params = buildListOrdersRpcParams(
        filters: OrderFilters(searchText: 'fixture'),
        cursor: OrderCursor(
          createdAt: DateTime.parse('2026-07-18T13:00:00+01:00'),
          id: orderId,
        ),
        limit: 20,
      );

      expect(params['p_search_text'], 'fixture');
      expect(params['p_cursor_created_at'], '2026-07-18T12:00:00.000Z');
      expect(params['p_cursor_id'], orderId);
      expect(params['p_limit'], 20);
    });

    test('maps one details row through PlatformReadCoordinator', () async {
      final dataSource = _DataSource(
        detailsRows: <Map<String, Object?>>[_detailsRow()],
      );
      final coordinator = _Coordinator();
      final repository = _repository(dataSource, coordinator);

      final details = await repository.getOrderDetails(orderId: orderId);

      expect(coordinator.calls, 1);
      expect(details.rewardUnitCodeSnapshot, 'diamond');
      expect(details.updatedAt.isUtc, isTrue);
      expect(details.summary.hasPaymentProof, isTrue);
    });

    test(
      'zero details rows are notFound and multiple rows are malformed',
      () async {
        for (final entry in <(List<Map<String, Object?>>, PlatformFailureCode)>[
          (<Map<String, Object?>>[], PlatformFailureCode.notFound),
          (
            <Map<String, Object?>>[_detailsRow(), _detailsRow()],
            PlatformFailureCode.malformedResponse,
          ),
        ]) {
          final repository = _repository(
            _DataSource(detailsRows: entry.$1),
          );
          await expectLater(
            repository.getOrderDetails(orderId: orderId),
            throwsA(
              isA<PlatformFailure>().having(
                (failure) => failure.code,
                'code',
                entry.$2,
              ),
            ),
          );
        }
      },
    );

    test(
      'unknown enums and malformed payloads become malformedResponse',
      () async {
        for (final row in <Map<String, Object?>>[
          _detailsRow()..['order_status'] = 'private_state',
          _detailsRow()..['has_payment_proof'] = 1,
        ]) {
          final repository = _repository(
            _DataSource(detailsRows: <Map<String, Object?>>[row]),
          );
          await expectLater(
            repository.getOrderDetails(orderId: orderId),
            throwsA(
              isA<PlatformFailure>().having(
                (failure) => failure.code,
                'code',
                PlatformFailureCode.malformedResponse,
              ),
            ),
          );
        }
      },
    );

    test('timeline is normalized to UTC and ordered oldest first', () async {
      final newer = _timelineRow(
        '2026-07-18T14:00:00+01:00',
        'payment_changed',
      );
      final older = _timelineRow('2026-07-18T11:00:00+01:00', 'created');
      final repository = _repository(
        _DataSource(timelineRows: <Map<String, Object?>>[newer, older]),
      );

      final timeline = await repository.getOrderTimeline(orderId: orderId);

      expect(
        timeline.map((event) => event.createdAt),
        orderedEquals(<DateTime>[
          DateTime.utc(2026, 7, 18, 10),
          DateTime.utc(2026, 7, 18, 13),
        ]),
      );
    });

    test('same-timestamp timeline events retain source order', () async {
      final first = _timelineRow(
        '2026-07-18T12:00:00Z',
        'created',
        publicMessage: 'first',
      );
      final second = _timelineRow(
        '2026-07-18T12:00:00Z',
        'payment_changed',
        publicMessage: 'second',
      );
      final repository = _repository(
        _DataSource(timelineRows: <Map<String, Object?>>[first, second]),
      );

      final timeline = await repository.getOrderTimeline(orderId: orderId);

      expect(
        timeline.map((event) => event.publicMessage),
        orderedEquals(<String?>['first', 'second']),
      );
    });

    test('network, unauthorized, and raw PostgREST errors are mapped', () async {
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
          await repository.getOrderDetails(orderId: orderId);
          fail('Expected a PlatformFailure.');
        } catch (error) {
          expect(error, isA<PlatformFailure>());
          expect((error as PlatformFailure).code, entry.$2);
          expect(error.toString(), isNot(contains('private payload')));
        }
      }
    });

    test('invalid order ids fail before the data source is called', () async {
      final dataSource = _DataSource();
      final repository = _repository(dataSource);

      await expectLater(
        repository.getOrderDetails(orderId: 'not-a-uuid'),
        throwsA(
          isA<PlatformFailure>().having(
            (failure) => failure.code,
            'code',
            PlatformFailureCode.validation,
          ),
        ),
      );
      expect(dataSource.detailCalls, 0);
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
  _DataSource({
    this.listRows = const <Map<String, Object?>>[],
    this.detailsRows = const <Map<String, Object?>>[],
    this.timelineRows = const <Map<String, Object?>>[],
    this.error,
  });

  final List<Map<String, Object?>> listRows;
  final List<Map<String, Object?>> detailsRows;
  final List<Map<String, Object?>> timelineRows;
  final Object? error;
  int listCalls = 0;
  int detailCalls = 0;
  int timelineCalls = 0;
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
  }) async {
    detailCalls += 1;
    if (error case final value?) throw value;
    return detailsRows;
  }

  @override
  Future<List<Map<String, Object?>>> getOrderTimeline({
    required String orderId,
  }) async {
    timelineCalls += 1;
    if (error case final value?) throw value;
    return timelineRows;
  }
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

Map<String, Object?> _detailsRow() => <String, Object?>{
  'id': '11111111-1111-1111-1111-111111111111',
  'game_name_ar_snapshot': 'لعبة',
  'game_name_fr_snapshot': 'Jeu',
  'offer_name_ar_snapshot': 'عرض',
  'offer_name_fr_snapshot': 'Offre',
  'reward_unit_code_snapshot': 'diamond',
  'reward_unit_name_ar_snapshot': 'جوهرة',
  'reward_unit_name_fr_snapshot': 'diamant',
  'customer_name_snapshot': 'Customer Fixture',
  'customer_email_snapshot': 'customer@example.test',
  'customer_phone_snapshot': '0550000000',
  'player_id': 'player-123',
  'in_game_name': null,
  'sale_price_dzd_snapshot': 350,
  'reward_quantity_snapshot': 100,
  'payment_method': 'transfer',
  'order_status': 'processing',
  'payment_status': 'under_review',
  'public_status_message': null,
  'created_at': '2026-07-18T13:00:00+01:00',
  'updated_at': '2026-07-18T14:00:00+01:00',
  'completed_at': null,
  'refund_started_at': null,
  'refunded_at': null,
  'has_payment_proof': true,
};

Map<String, Object?> _timelineRow(
  String createdAt,
  String type, {
  String? publicMessage,
}) => <String, Object?>{
  'event_type': type,
  'order_status': type == 'created' ? 'new' : 'processing',
  'payment_status': type == 'created' ? 'awaiting_payment' : 'under_review',
  'public_message': publicMessage,
  'created_at': createdAt,
};
