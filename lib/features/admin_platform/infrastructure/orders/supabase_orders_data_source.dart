import 'package:supabase_flutter/supabase_flutter.dart';

typedef OrdersRpcCall =
    Future<Object?> Function(String rpcName, Map<String, Object?> params);

abstract interface class SupabaseOrdersDataSource {
  Future<List<Map<String, Object?>>> listOrders({
    required Map<String, Object?> params,
  });

  Future<List<Map<String, Object?>>> getOrderDetails({required String orderId});

  Future<List<Map<String, Object?>>> getOrderTimeline({
    required String orderId,
  });

  Future<List<Map<String, Object?>>> getOrderInternalNotes({
    required String orderId,
  });
}

class FlutterSupabaseOrdersDataSource implements SupabaseOrdersDataSource {
  FlutterSupabaseOrdersDataSource(SupabaseClient client)
    : _rpcCall = _SupabaseOrdersRpcCall(client).call;

  FlutterSupabaseOrdersDataSource.withRpcCall(OrdersRpcCall rpcCall)
    : _rpcCall = rpcCall;

  static const listOrdersRpcName = 'admin_list_orders';
  static const orderDetailsRpcName = 'admin_get_order_details';
  static const orderTimelineRpcName = 'admin_get_order_timeline';
  static const orderInternalNotesRpcName = 'admin_list_order_internal_notes';
  static const rpcName = listOrdersRpcName;

  final OrdersRpcCall _rpcCall;

  @override
  Future<List<Map<String, Object?>>> listOrders({
    required Map<String, Object?> params,
  }) {
    return _readRows(rpcName: listOrdersRpcName, params: params);
  }

  @override
  Future<List<Map<String, Object?>>> getOrderDetails({
    required String orderId,
  }) {
    return _readRows(
      rpcName: orderDetailsRpcName,
      params: <String, Object?>{'p_order_id': orderId},
    );
  }

  @override
  Future<List<Map<String, Object?>>> getOrderTimeline({
    required String orderId,
  }) {
    return _readRows(
      rpcName: orderTimelineRpcName,
      params: <String, Object?>{'p_order_id': orderId},
    );
  }

  @override
  Future<List<Map<String, Object?>>> getOrderInternalNotes({
    required String orderId,
  }) {
    return _readRows(
      rpcName: orderInternalNotesRpcName,
      params: <String, Object?>{'p_order_id': orderId},
    );
  }

  Future<List<Map<String, Object?>>> _readRows({
    required String rpcName,
    required Map<String, Object?> params,
  }) async {
    final response = await _rpcCall(
      rpcName,
      Map<String, Object?>.unmodifiable(params),
    );
    if (response is! List) {
      throw const FormatException('Unexpected orders RPC payload.');
    }
    return response
        .map<Map<String, Object?>>((row) {
          if (row is! Map) {
            throw const FormatException('Unexpected orders RPC row.');
          }
          final mapped = <String, Object?>{};
          for (final entry in row.entries) {
            if (entry.key is! String) {
              throw const FormatException('Unexpected orders RPC field.');
            }
            mapped[entry.key as String] = entry.value;
          }
          return Map<String, Object?>.unmodifiable(mapped);
        })
        .toList(growable: false);
  }
}

class _SupabaseOrdersRpcCall {
  const _SupabaseOrdersRpcCall(this._client);

  final SupabaseClient _client;

  Future<Object?> call(String rpcName, Map<String, Object?> rpcParams) {
    return _client.rpc(rpcName, params: rpcParams);
  }
}
