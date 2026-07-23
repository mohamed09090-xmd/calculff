import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/common/platform_session_coordinator.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_cursor.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_filters.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/supabase_platform_error_mapper.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/supabase_customer_orders_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/supabase_orders_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const orderId = '11111111-1111-1111-1111-111111111111';

  group('Supabase orders data source', () {
    test('uses exact detail RPC name with p_order_id only', () async {
      late String name;
      late Map<String, Object?> params;
      final dataSource = FlutterSupabaseOrdersDataSource.withRpcCall((
        rpc,
        input,
      ) async {
        name = rpc;
        params = input;
        return <Object?>[];
      });

      await dataSource.getOrderDetails(orderId: orderId);

      expect(name, 'admin_get_order_details');
      expect(params, <String, Object?>{'p_order_id': orderId});
    });

    test('uses exact timeline RPC name with p_order_id only', () async {
      late String name;
      late Map<String, Object?> params;
      final dataSource = FlutterSupabaseOrdersDataSource.withRpcCall((
        rpc,
        input,
      ) async {
        name = rpc;
        params = input;
        return <Object?>[];
      });

      await dataSource.getOrderTimeline(orderId: orderId);

      expect(name, 'admin_get_order_timeline');
      expect(params, <String, Object?>{'p_order_id': orderId});
    });

    test('uses exact internal notes RPC name with p_order_id only', () async {
      late String name;
      late Map<String, Object?> params;
      final dataSource = FlutterSupabaseOrdersDataSource.withRpcCall((
        rpc,
        input,
      ) async {
        name = rpc;
        params = input;
        return <Object?>[];
      });

      await dataSource.getOrderInternalNotes(orderId: orderId);

      expect(name, 'admin_list_order_internal_notes');
      expect(params, <String, Object?>{'p_order_id': orderId});
    });

    test('signs only the validated proof path for sixty seconds', () async {
      late String rpcName;
      late Map<String, Object?> rpcParams;
      late String bucket;
      late String path;
      late int expiresIn;
      final dataSource = FlutterSupabaseOrdersDataSource.withRpcCall(
        (rpc, input) async {
          rpcName = rpc;
          rpcParams = input;
          return <Object?>[
            <String, Object?>{
              'payment_proof_path': 'user/order/proof_aaaaaaaaaaaaaaaa.jpg',
            },
          ];
        },
        signedUrlCall: (inputBucket, inputPath, inputExpiry) async {
          bucket = inputBucket;
          path = inputPath;
          expiresIn = inputExpiry;
          return 'https://project.test/storage/signed-proof';
        },
      );

      final payload = await dataSource.getOrderPaymentProof(orderId: orderId);

      expect(rpcName, 'admin_get_order_payment_proof_path');
      expect(rpcParams, <String, Object?>{'p_order_id': orderId});
      expect(bucket, 'payment-proofs');
      expect(path, 'user/order/proof_aaaaaaaaaaaaaaaa.jpg');
      expect(expiresIn, 60);
      expect(payload, <String, Object?>{
        'signed_url': 'https://project.test/storage/signed-proof',
        'file_extension': 'jpg',
      });
      expect(payload.toString(), isNot(contains('proof_aaaaaaaaaaaaaaaa')));
    });

    test('uses atomic accept and reject RPC contracts', () async {
      final calls = <(String, Map<String, Object?>)>[];
      final dataSource = FlutterSupabaseOrdersDataSource.withRpcCall((
        rpc,
        input,
      ) async {
        calls.add((rpc, input));
        return <Object?>[
          <String, Object?>{
            'order_status': rpc == 'admin_accept_order'
                ? 'processing'
                : 'rejected',
            'payment_status': rpc == 'admin_accept_order'
                ? 'paid'
                : 'proof_rejected',
          },
        ];
      });

      await dataSource.acceptOrder(orderId: orderId, publicMessage: 'accepted');
      await dataSource.rejectOrder(orderId: orderId, publicMessage: 'rejected');

      expect(calls, <(String, Map<String, Object?>)>[
        (
          'admin_accept_order',
          <String, Object?>{
            'p_order_id': orderId,
            'p_public_message': 'accepted',
          },
        ),
        (
          'admin_reject_order',
          <String, Object?>{
            'p_order_id': orderId,
            'p_public_message': 'rejected',
          },
        ),
      ]);
    });

    test(
      'strictly rejects non-list, non-map, and non-string-key payloads',
      () async {
        for (final payload in <Object?>[
          <String, Object?>{},
          <Object?>['row'],
          <Object?>[
            <Object?, Object?>{1: 'value'},
          ],
        ]) {
          final dataSource = FlutterSupabaseOrdersDataSource.withRpcCall(
            (_, __) async => payload,
          );
          expect(
            () => dataSource.getOrderDetails(orderId: orderId),
            throwsA(isA<FormatException>()),
          );
        }
      },
    );
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
      final dataSource = _RepositoryDataSource(
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
            _RepositoryDataSource(detailsRows: entry.$1),
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
            _RepositoryDataSource(detailsRows: <Map<String, Object?>>[row]),
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
        _RepositoryDataSource(
          timelineRows: <Map<String, Object?>>[newer, older],
        ),
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
        _RepositoryDataSource(
          timelineRows: <Map<String, Object?>>[first, second],
        ),
      );

      final timeline = await repository.getOrderTimeline(orderId: orderId);

      expect(
        timeline.map((event) => event.publicMessage),
        orderedEquals(<String?>['first', 'second']),
      );
    });

    test(
      'internal notes are ordered by UTC timestamp then backend id',
      () async {
        final repository = _repository(
          _RepositoryDataSource(
            noteRows: <Map<String, Object?>>[
              _noteRow(id: 12, text: 'second tie'),
              _noteRow(
                id: 10,
                text: 'older',
                createdAt: '2026-07-18T10:00:00+01:00',
              ),
              _noteRow(id: 11, text: 'first tie'),
            ],
          ),
        );

        final notes = await repository.getOrderInternalNotes(orderId: orderId);

        expect(
          notes.map((note) => note.text),
          orderedEquals(<String>['older', 'first tie', 'second tie']),
        );
        expect(notes.every((note) => note.createdAt.isUtc), isTrue);
        expect(() => notes.add(notes.first), throwsUnsupportedError);
      },
    );

    test('cross-order and malformed internal note rows are rejected', () async {
      for (final row in <Map<String, Object?>>[
        _noteRow(orderId: '22222222-2222-2222-2222-222222222222'),
        _noteRow(id: 0),
        _noteRow(text: ' padded '),
        _noteRow(text: List<String>.filled(2001, 'x').join()),
      ]) {
        final repository = _repository(
          _RepositoryDataSource(noteRows: <Map<String, Object?>>[row]),
        );
        await expectLater(
          repository.getOrderInternalNotes(orderId: orderId),
          throwsA(
            isA<PlatformFailure>().having(
              (failure) => failure.code,
              'code',
              PlatformFailureCode.malformedResponse,
            ),
          ),
        );
      }
    });

    test(
      'network, unauthorized, and raw PostgREST errors are mapped',
      () async {
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
          final repository = _repository(
            _RepositoryDataSource(error: entry.$1),
          );
          try {
            await repository.getOrderDetails(orderId: orderId);
            fail('Expected a PlatformFailure.');
          } catch (error) {
            expect(error, isA<PlatformFailure>());
            expect((error as PlatformFailure).code, entry.$2);
            expect(error.toString(), isNot(contains('private payload')));
          }
        }
      },
    );

    test('invalid order ids fail before the data source is called', () {
      final dataSource = _RepositoryDataSource();
      final repository = _repository(dataSource);

      expect(
        () => repository.getOrderDetails(orderId: 'not-a-uuid'),
        throwsA(
          isA<PlatformFailure>().having(
            (failure) => failure.code,
            'code',
            PlatformFailureCode.validation,
          ),
        ),
      );
      expect(dataSource.detailCalls, 0);
      expect(
        () => repository.getOrderInternalNotes(orderId: 'not-a-uuid'),
        throwsA(
          isA<PlatformFailure>().having(
            (failure) => failure.code,
            'code',
            PlatformFailureCode.validation,
          ),
        ),
      );
      expect(dataSource.noteCalls, 0);
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

class _RepositoryDataSource implements SupabaseOrdersDataSource {
  _RepositoryDataSource({
    this.detailsRows = const <Map<String, Object?>>[],
    this.timelineRows = const <Map<String, Object?>>[],
    this.noteRows = const <Map<String, Object?>>[],
    this.error,
  });

  final List<Map<String, Object?>> detailsRows;
  final List<Map<String, Object?>> timelineRows;
  final List<Map<String, Object?>> noteRows;
  final Object? error;
  int detailCalls = 0;
  int noteCalls = 0;

  @override
  Future<List<Map<String, Object?>>> listOrders({
    required Map<String, Object?> params,
  }) async => const <Map<String, Object?>>[];

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
    if (error case final value?) throw value;
    return timelineRows;
  }

  @override
  Future<List<Map<String, Object?>>> getOrderInternalNotes({
    required String orderId,
  }) async {
    noteCalls += 1;
    if (error case final value?) throw value;
    return noteRows;
  }
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

Map<String, Object?> _noteRow({
  int id = 11,
  String orderId = '11111111-1111-1111-1111-111111111111',
  String text = 'Private fixture note',
  String createdAt = '2026-07-18T11:00:00Z',
}) => <String, Object?>{
  'id': id,
  'order_id': orderId,
  'author_user_id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'note': text,
  'created_at': createdAt,
};
