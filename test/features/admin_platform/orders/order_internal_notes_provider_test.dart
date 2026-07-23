import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/common/platform_common_providers.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/orders/order_details_providers.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/orders/orders_providers.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_models.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/customer_order_details.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/customer_orders_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_cursor.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_filters.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_internal_note.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_page.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_timeline_event.dart';

final _authStateProvider = StateProvider<AdminAuthState>(
  (ref) => const AdminAuthState.authorized(),
);

void main() {
  const orderId = '11111111-1111-1111-1111-111111111111';

  test(
    'session invalidation clears notes and ignores a late response',
    () async {
      final repository = _CompletingNotesRepository();
      final container = ProviderContainer(
        overrides: <Override>[
          platformAdminAuthStateProvider.overrideWith((ref) {
            return ref.watch(_authStateProvider);
          }),
          customerOrdersRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final provider = orderInternalNotesProvider(orderId);
      final subscription = container.listen(provider, (_, __) {});
      addTearDown(subscription.close);
      final pendingRead = container.read(provider.future);
      expect(repository.calls, 1);

      container.read(_authStateProvider.notifier).state =
          const AdminAuthState.sessionExpired();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(provider).hasValue, isFalse);
      repository.complete(<OrderInternalNote>[
        OrderInternalNote(
          text: 'INTERNAL-SECRET-DO-NOT-LEAK',
          createdAt: DateTime.utc(2026, 7, 18),
        ),
      ]);
      try {
        await pendingRead;
      } on Object {
        // The provider's public future may switch to the invalidated generation.
      }
      await Future<void>.delayed(Duration.zero);

      final state = container.read(provider);
      expect(state.hasValue, isFalse);
      expect(state.error.toString(), isNot(contains('INTERNAL-SECRET')));
    },
  );
}

class _CompletingNotesRepository implements CustomerOrdersRepository {
  final Completer<List<OrderInternalNote>> _completer =
      Completer<List<OrderInternalNote>>();
  int calls = 0;

  @override
  Future<List<OrderInternalNote>> getOrderInternalNotes({
    required String orderId,
  }) {
    calls += 1;
    return _completer.future;
  }

  void complete(List<OrderInternalNote> notes) => _completer.complete(notes);

  @override
  Future<CustomerOrderDetails> getOrderDetails({required String orderId}) {
    throw UnsupportedError('Notes-only fake.');
  }

  @override
  Future<List<OrderTimelineEvent>> getOrderTimeline({required String orderId}) {
    throw UnsupportedError('Notes-only fake.');
  }

  @override
  Future<OrderPage> listOrders({
    required OrderFilters filters,
    OrderCursor? cursor,
    int limit = customerOrdersMaxPageSize,
  }) {
    throw UnsupportedError('Notes-only fake.');
  }
}
