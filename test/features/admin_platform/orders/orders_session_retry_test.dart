import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/common/platform_session_coordinator.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_models.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_filters.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/supabase_platform_error_mapper.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/supabase_customer_orders_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/supabase_orders_data_source.dart';

void main() {
  test('session expiry refreshes once and retries the list read once', () async {
    final session = _FakeSessionAccess();
    final dataScope = _FakeDataScope();
    final dataSource = _ExpiringOrdersDataSource();
    final repository = SupabaseCustomerOrdersRepository(
      dataSource: dataSource,
      errorMapper: const SupabasePlatformErrorMapper(),
      readCoordinator: PlatformSessionCoordinator(
        sessionAccess: session,
        mapError: (error) => error is PlatformFailure
            ? error
            : const PlatformFailure(PlatformFailureCode.unknown),
        dataScope: dataScope,
      ),
    );

    final page = await repository.listOrders(filters: OrderFilters());

    expect(page.items, hasLength(1));
    expect(dataSource.calls, 2);
    expect(session.refreshCalls, 1);
    expect(dataScope.invalidationCalls, 1);
    expect(dataScope.authorizedCalls, 1);
  });
}

class _FakeSessionAccess implements PlatformSessionAccess {
  int refreshCalls = 0;

  @override
  AdminAuthState get currentState => const AdminAuthState.authorized();

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
  }
}

class _FakeDataScope implements PlatformDataScopeSink {
  int authorizedCalls = 0;
  int invalidationCalls = 0;

  @override
  void invalidate(PlatformFailureCode reason) {
    invalidationCalls += 1;
  }

  @override
  void markAuthorized() {
    authorizedCalls += 1;
  }
}

class _ExpiringOrdersDataSource implements SupabaseOrdersDataSource {
  int calls = 0;

  @override
  Future<List<Map<String, Object?>>> listOrders({
    required Map<String, Object?> params,
  }) async {
    calls += 1;
    if (calls == 1) {
      throw const PlatformFailure(PlatformFailureCode.sessionExpired);
    }
    return <Map<String, Object?>>[
      <String, Object?>{
        'id': '11111111-1111-1111-1111-111111111111',
        'game_name_ar_snapshot': 'لعبة',
        'game_name_fr_snapshot': 'Jeu',
        'offer_name_ar_snapshot': 'عرض',
        'offer_name_fr_snapshot': 'Offre',
        'customer_name_snapshot': 'زبون',
        'player_id': 'player-123',
        'in_game_name': null,
        'sale_price_dzd_snapshot': 350,
        'reward_quantity_snapshot': 100,
        'reward_unit_name_ar_snapshot': 'جوهرة',
        'reward_unit_name_fr_snapshot': 'diamants',
        'payment_method': 'cash',
        'order_status': 'new',
        'payment_status': 'awaiting_payment',
        'created_at': '2026-07-17T12:00:00Z',
        'has_payment_proof': false,
        'has_more': false,
      },
    ];
  }
}
