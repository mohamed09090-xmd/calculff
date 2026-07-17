import '../common/cursor_page.dart';
import 'customer_order_details.dart';
import 'customer_order_summary.dart';
import 'order_cursor.dart';
import 'order_filters.dart';
import 'order_timeline_event.dart';

const int customerOrdersMaxPageSize = 25;

bool isValidCustomerOrdersPageLimit(int limit) {
  return limit > 0 && limit <= customerOrdersMaxPageSize;
}

abstract interface class CustomerOrdersRepository {
  Future<CursorPage<CustomerOrderSummary>> listOrders({
    required OrderFilters filters,
    OrderCursor? cursor,
    int limit = customerOrdersMaxPageSize,
  });

  Future<CustomerOrderDetails> getOrderDetails({required String orderId});

  Future<List<OrderTimelineEvent>> getOrderTimeline({required String orderId});
}
