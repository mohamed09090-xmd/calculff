import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/supabase_orders_data_source.dart';

void main() {
  const orderId = '11111111-1111-1111-1111-111111111111';

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
}
