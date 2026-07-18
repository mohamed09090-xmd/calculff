import 'customer_order_summary.dart';
import 'order_cursor.dart';

class OrderPage {
  OrderPage({
    required Iterable<CustomerOrderSummary> items,
    required this.nextCursor,
    required this.hasMore,
  }) : items = List<CustomerOrderSummary>.unmodifiable(items) {
    if (hasMore && nextCursor == null) {
      throw ArgumentError('nextCursor is required when hasMore is true.');
    }
  }

  final List<CustomerOrderSummary> items;
  final OrderCursor? nextCursor;
  final bool hasMore;
}
