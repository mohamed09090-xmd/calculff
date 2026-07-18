import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class SupabaseOrdersDataSource {
  Future<List<Map<String, Object?>>> listOrders({
    required Map<String, Object?> params,
  });
}

class FlutterSupabaseOrdersDataSource implements SupabaseOrdersDataSource {
  const FlutterSupabaseOrdersDataSource(this._client);

  static const rpcName = 'admin_list_orders';

  final SupabaseClient _client;

  @override
  Future<List<Map<String, Object?>>> listOrders({
    required Map<String, Object?> params,
  }) async {
    final response = await _client.rpc(rpcName, params: params);
    if (response is! List) {
      throw const FormatException('Unexpected orders RPC payload.');
    }
    return response.map<Map<String, Object?>>((row) {
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
    }).toList(growable: false);
  }
}
