import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/common/platform_session_coordinator.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_models.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_filters.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/supabase_platform_error_mapper.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/supabase_customer_orders_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/supabase_orders_data_source.dart';

void main() {
  test(
    'session expiry refreshes once and retries the list read once',
    () async {
      final session = _SessionAccess();
      final scope = _DataScope();
      final dataSource = _ExpiringDataSource(expireListOnce: true);
      final repository = _repository(session, scope, dataSource);

      await repository.listOrders(filters: OrderFilters());

      expect(dataSource.listCalls, 2);
      expect(session.refreshCalls, 1);
      expect(scope.invalidationCalls, 1);
      expect(scope.authorizedCalls, 1);
    },
  );

  test(
    'concurrent detail and timeline expiry share one session refresh',
    () async {
      final session = _SessionAccess(blockRefresh: true);
      final scope = _DataScope();
      final dataSource = _ExpiringDataSource(
        expireDetailsOnce: true,
        expireTimelineOnce: true,
      );
      final repository = _repository(session, scope, dataSource);
      const orderId = '11111111-1111-1111-1111-111111111111';

      final reads = Future.wait<Object?>(<Future<Object?>>[
        repository.getOrderDetails(orderId: orderId),
        repository.getOrderTimeline(orderId: orderId),
      ]);
      await session.refreshStarted.future;
      session.releaseRefresh.complete();
      await reads;

      expect(dataSource.detailCalls, 2);
      expect(dataSource.timelineCalls, 2);
      expect(session.refreshCalls, 1);
      expect(session.maxConcurrentRefreshes, 1);
    },
  );

  test(
    'session expiry refreshes once and retries internal notes once',
    () async {
      final session = _SessionAccess();
      final scope = _DataScope();
      final dataSource = _ExpiringDataSource(expireNotesOnce: true);
      final repository = _repository(session, scope, dataSource);

      final notes = await repository.getOrderInternalNotes(
        orderId: '11111111-1111-1111-1111-111111111111',
      );

      expect(notes.single.text, 'Private fixture note');
      expect(dataSource.noteCalls, 2);
      expect(session.refreshCalls, 1);
      expect(scope.invalidationCalls, 1);
      expect(scope.authorizedCalls, 1);
    },
  );
}

SupabaseCustomerOrdersRepository _repository(
  _SessionAccess session,
  _DataScope scope,
  _ExpiringDataSource dataSource,
) => SupabaseCustomerOrdersRepository(
  dataSource: dataSource,
  errorMapper: const SupabasePlatformErrorMapper(),
  readCoordinator: PlatformSessionCoordinator(
    sessionAccess: session,
    mapError: (error) => error is PlatformFailure
        ? error
        : const PlatformFailure(PlatformFailureCode.unknown),
    dataScope: scope,
  ),
);

class _SessionAccess implements PlatformSessionAccess {
  _SessionAccess({this.blockRefresh = false});

  final bool blockRefresh;
  int refreshCalls = 0;
  int _activeRefreshes = 0;
  int maxConcurrentRefreshes = 0;
  final Completer<void> refreshStarted = Completer<void>();
  final Completer<void> releaseRefresh = Completer<void>();

  @override
  AdminAuthState get currentState => const AdminAuthState.authorized();

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
    _activeRefreshes += 1;
    if (_activeRefreshes > maxConcurrentRefreshes) {
      maxConcurrentRefreshes = _activeRefreshes;
    }
    if (blockRefresh) {
      if (!refreshStarted.isCompleted) {
        refreshStarted.complete();
      }
      await releaseRefresh.future;
    }
    _activeRefreshes -= 1;
  }
}

class _DataScope implements PlatformDataScopeSink {
  int authorizedCalls = 0;
  int invalidationCalls = 0;

  @override
  void invalidate(PlatformFailureCode reason) => invalidationCalls += 1;

  @override
  void markAuthorized() => authorizedCalls += 1;
}

class _ExpiringDataSource implements SupabaseOrdersDataSource {
  _ExpiringDataSource({
    this.expireListOnce = false,
    this.expireDetailsOnce = false,
    this.expireTimelineOnce = false,
    this.expireNotesOnce = false,
  });

  final bool expireListOnce;
  final bool expireDetailsOnce;
  final bool expireTimelineOnce;
  final bool expireNotesOnce;
  int listCalls = 0;
  int detailCalls = 0;
  int timelineCalls = 0;
  int noteCalls = 0;

  @override
  Future<List<Map<String, Object?>>> listOrders({
    required Map<String, Object?> params,
  }) async {
    listCalls += 1;
    if (expireListOnce && listCalls == 1) {
      throw const PlatformFailure(PlatformFailureCode.sessionExpired);
    }
    return const <Map<String, Object?>>[];
  }

  @override
  Future<List<Map<String, Object?>>> getOrderDetails({
    required String orderId,
  }) async {
    detailCalls += 1;
    if (expireDetailsOnce && detailCalls == 1) {
      throw const PlatformFailure(PlatformFailureCode.sessionExpired);
    }
    return <Map<String, Object?>>[_detailsRow()];
  }

  @override
  Future<List<Map<String, Object?>>> getOrderTimeline({
    required String orderId,
  }) async {
    timelineCalls += 1;
    if (expireTimelineOnce && timelineCalls == 1) {
      throw const PlatformFailure(PlatformFailureCode.sessionExpired);
    }
    return const <Map<String, Object?>>[];
  }

  @override
  Future<List<Map<String, Object?>>> getOrderInternalNotes({
    required String orderId,
  }) async {
    noteCalls += 1;
    if (expireNotesOnce && noteCalls == 1) {
      throw const PlatformFailure(PlatformFailureCode.sessionExpired);
    }
    return <Map<String, Object?>>[
      <String, Object?>{
        'id': 1,
        'order_id': orderId,
        'author_user_id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'note': 'Private fixture note',
        'created_at': '2026-07-18T12:00:00Z',
      },
    ];
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
  'created_at': '2026-07-18T12:00:00Z',
  'updated_at': '2026-07-18T13:00:00Z',
  'completed_at': null,
  'refund_started_at': null,
  'refunded_at': null,
  'has_payment_proof': true,
};
