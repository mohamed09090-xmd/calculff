import '../../application/common/platform_session_coordinator.dart';
import '../../domain/common/platform_failure.dart';
import '../../domain/orders/customer_order_details.dart';
import '../../domain/orders/customer_orders_repository.dart';
import '../../domain/orders/order_cursor.dart';
import '../../domain/orders/order_filters.dart';
import '../../domain/orders/order_page.dart';
import '../../domain/orders/order_timeline_event.dart';
import '../common/platform_payload_reader.dart';
import '../common/supabase_platform_error_mapper.dart';
import 'customer_order_summary_dto.dart';
import 'supabase_orders_data_source.dart';

class SupabaseCustomerOrdersRepository implements CustomerOrdersRepository {
  const SupabaseCustomerOrdersRepository({
    required SupabaseOrdersDataSource dataSource,
    required SupabasePlatformErrorMapper errorMapper,
    required PlatformReadCoordinator readCoordinator,
  }) : _dataSource = dataSource,
       _errorMapper = errorMapper,
       _readCoordinator = readCoordinator;

  final SupabaseOrdersDataSource _dataSource;
  final SupabasePlatformErrorMapper _errorMapper;
  final PlatformReadCoordinator _readCoordinator;

  @override
  Future<OrderPage> listOrders({
    required OrderFilters filters,
    OrderCursor? cursor,
    int limit = customerOrdersMaxPageSize,
  }) {
    if (!isValidCustomerOrdersPageLimit(limit) || !filters.isValid) {
      throw const PlatformFailure(PlatformFailureCode.validation);
    }

    return _readCoordinator.runRead(() async {
      try {
        final rows = await _dataSource.listOrders(
          params: buildListOrdersRpcParams(
            filters: filters,
            cursor: cursor,
            limit: limit,
          ),
        );
        if (rows.isEmpty) {
          return OrderPage(items: const [], nextCursor: null, hasMore: false);
        }

        final items = <CustomerOrderSummaryDto>[];
        bool? hasMore;
        for (final row in rows) {
          final rowHasMore = PlatformPayloadReader(
            row,
          ).requiredBool('has_more');
          hasMore ??= rowHasMore;
          if (hasMore != rowHasMore) {
            throw const PlatformPayloadException(
              field: 'has_more',
              reason: PlatformPayloadFailureReason.invalidValue,
            );
          }
          items.add(CustomerOrderSummaryDto.fromMap(row));
        }

        final domains = items
            .map((item) => item.toDomain())
            .toList(growable: false);
        final last = domains.last;
        final pageHasMore = hasMore ?? false;
        return OrderPage(
          items: domains,
          nextCursor: pageHasMore
              ? OrderCursor(createdAt: last.createdAt, id: last.id)
              : null,
          hasMore: pageHasMore,
        );
      } catch (error) {
        if (error is FormatException || error is PlatformPayloadException) {
          throw const PlatformFailure(PlatformFailureCode.malformedResponse);
        }
        throw _errorMapper.map(error);
      }
    });
  }

  @override
  Future<CustomerOrderDetails> getOrderDetails({required String orderId}) {
    throw const PlatformFailure(PlatformFailureCode.temporarilyUnavailable);
  }

  @override
  Future<List<OrderTimelineEvent>> getOrderTimeline({required String orderId}) {
    throw const PlatformFailure(PlatformFailureCode.temporarilyUnavailable);
  }
}

Map<String, Object?> buildListOrdersRpcParams({
  required OrderFilters filters,
  required OrderCursor? cursor,
  required int limit,
}) {
  return Map<String, Object?>.unmodifiable(<String, Object?>{
    'p_order_status': filters.orderStatus?.wireValue,
    'p_payment_status': filters.paymentStatus?.wireValue,
    'p_payment_method': filters.paymentMethod?.wireValue,
    'p_game_id': filters.gameId,
    'p_date_from': filters.dateFrom?.toUtc().toIso8601String(),
    'p_date_to_exclusive': filters.dateToExclusive?.toUtc().toIso8601String(),
    'p_search_text': filters.searchText,
    'p_cursor_created_at': cursor?.createdAt.toUtc().toIso8601String(),
    'p_cursor_id': cursor?.id,
    'p_limit': limit,
  });
}
