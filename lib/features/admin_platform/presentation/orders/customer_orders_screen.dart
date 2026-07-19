import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/orders/orders_controller.dart';
import '../../application/orders/orders_providers.dart';
import '../../domain/common/platform_failure.dart';
import '../../domain/orders/order_filters.dart';
import '../platform_ui_text.dart';
import 'order_details_screen.dart';
import 'order_filters_sheet.dart';
import 'order_widgets.dart';
import 'orders_ui_text.dart';

class CustomerOrdersScreen extends ConsumerWidget {
  const CustomerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ordersControllerProvider);
    final controller = ref.read(ordersControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(orderText(context, 'قائمة الطلبات')),
        actions: [
          Semantics(
            button: true,
            label: orderText(context, 'الفلاتر'),
            child: IconButton(
              key: const Key('orders-filters-button'),
              tooltip: orderText(context, 'الفلاتر'),
              onPressed: () => _openFilters(context, state, controller),
              icon: Badge(
                isLabelVisible: !state.filters.isEmpty,
                child: const Icon(Icons.filter_alt_outlined),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: orderText(context, 'تحديث الطلبات'),
            child: IconButton(
              key: const Key('orders-refresh-button'),
              tooltip: orderText(context, 'تحديث الطلبات'),
              onPressed: state.isRefreshing ? null : controller.refresh,
              icon: state.isRefreshing
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _OrdersBody(
          state: state,
          controller: controller,
          onOpenDetails: (orderId) => _openDetails(context, orderId),
        ),
      ),
    );
  }

  Future<void> _openFilters(
    BuildContext context,
    OrdersState state,
    OrdersController controller,
  ) async {
    final filters = await showModalBottomSheet<OrderFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          OrderFiltersSheet(initialFilters: state.filters, games: state.games),
    );
    if (filters != null) {
      await controller.updateFilters(filters);
    }
  }

  Future<void> _openDetails(BuildContext context, String orderId) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailsScreen(orderId: orderId),
      ),
    );
  }
}

class _OrdersBody extends StatelessWidget {
  const _OrdersBody({
    required this.state,
    required this.controller,
    required this.onOpenDetails,
  });

  final OrdersState state;
  final OrdersController controller;
  final ValueChanged<String> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case OrdersViewStatus.loading:
        return Center(
          child: Semantics(
            label: orderText(context, 'قائمة الطلبات'),
            child: const CircularProgressIndicator(),
          ),
        );
      case OrdersViewStatus.empty:
        return OrdersStateMessage(
          key: const Key('orders-empty-state'),
          icon: Icons.receipt_long_outlined,
          title: orderText(context, 'لا توجد طلبات.'),
          message: state.filters.isEmpty
              ? orderText(context, 'لا توجد طلبات.')
              : orderText(context, 'لا توجد نتائج مطابقة للفلاتر الحالية.'),
          onRefresh: controller.refresh,
        );
      case OrdersViewStatus.offline:
        return OrdersStateMessage(
          key: const Key('orders-offline-state'),
          icon: Icons.cloud_off_outlined,
          title: orderText(context, 'لا يوجد اتصال بالمنصة.'),
          message: platformDataFailureText(
            context,
            const PlatformFailure(PlatformFailureCode.networkUnavailable),
          ),
          onRefresh: controller.refresh,
          actionLabel: orderText(context, 'إعادة المحاولة'),
        );
      case OrdersViewStatus.error:
        return OrdersStateMessage(
          key: const Key('orders-error-state'),
          icon: Icons.error_outline,
          title: orderText(context, 'تعذر تحميل الطلبات.'),
          message: platformDataFailureText(
            context,
            PlatformFailure(state.failureCode ?? PlatformFailureCode.unknown),
          ),
          onRefresh: controller.refresh,
          actionLabel: orderText(context, 'إعادة المحاولة'),
        );
      case OrdersViewStatus.data:
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView.builder(
            key: const Key('orders-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 32),
            itemCount:
                state.orders.length +
                (state.isStale ? 1 : 0) +
                (state.hasMore || state.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              var currentIndex = index;
              if (state.isStale) {
                if (currentIndex == 0) {
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 10),
                    child: OrdersStaleBanner(failureCode: state.failureCode),
                  );
                }
                currentIndex -= 1;
              }
              if (currentIndex < state.orders.length) {
                final order = state.orders[currentIndex];
                return Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 10),
                  child: CustomerOrderCard(
                    order: order,
                    onTap: () => onOpenDetails(order.id),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: state.isLoadingMore
                      ? const CircularProgressIndicator()
                      : Semantics(
                          button: true,
                          label: orderText(context, 'تحميل المزيد'),
                          child: FilledButton.tonalIcon(
                            key: const Key('orders-load-more-button'),
                            onPressed: controller.loadMore,
                            icon: const Icon(Icons.expand_more),
                            label: Text(orderText(context, 'تحميل المزيد')),
                          ),
                        ),
                ),
              );
            },
          ),
        );
    }
  }
}
