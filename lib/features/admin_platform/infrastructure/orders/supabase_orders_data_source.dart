import 'package:supabase_flutter/supabase_flutter.dart';

typedef OrdersRpcCall =
    Future<Object?> Function(String rpcName, Map<String, Object?> params);
typedef OrdersSignedUrlCall =
    Future<String> Function(String bucket, String path, int expiresIn);

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

abstract interface class SupabaseOrderPaymentProofDataSource {
  Future<Map<String, Object?>?> getOrderPaymentProof({required String orderId});
}

abstract interface class SupabaseOrderActionsDataSource {
  Future<Map<String, Object?>> acceptOrder({
    required String orderId,
    String? publicMessage,
  });

  Future<Map<String, Object?>> rejectOrder({
    required String orderId,
    String? publicMessage,
  });
}

class FlutterSupabaseOrdersDataSource
    implements
        SupabaseOrdersDataSource,
        SupabaseOrderPaymentProofDataSource,
        SupabaseOrderActionsDataSource {
  FlutterSupabaseOrdersDataSource(SupabaseClient client)
    : _rpcCall = _SupabaseOrdersRpcCall(client).call,
      _signedUrlCall = _SupabaseOrdersSignedUrlCall(client).call;

  FlutterSupabaseOrdersDataSource.withRpcCall(
    OrdersRpcCall rpcCall, {
    OrdersSignedUrlCall? signedUrlCall,
  }) : _rpcCall = rpcCall,
       _signedUrlCall = signedUrlCall ?? _unsupportedSignedUrlCall;

  static const listOrdersRpcName = 'admin_list_orders';
  static const orderDetailsRpcName = 'admin_get_order_details';
  static const orderTimelineRpcName = 'admin_get_order_timeline';
  static const orderInternalNotesRpcName = 'admin_list_order_internal_notes';
  static const orderPaymentProofRpcName = 'admin_get_order_payment_proof_path';
  static const acceptOrderRpcName = 'admin_accept_order';
  static const rejectOrderRpcName = 'admin_reject_order';
  static const paymentProofBucket = 'payment-proofs';
  static const paymentProofSignedUrlLifetimeSeconds = 60;
  static const rpcName = listOrdersRpcName;

  final OrdersRpcCall _rpcCall;
  final OrdersSignedUrlCall _signedUrlCall;

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

  @override
  Future<Map<String, Object?>?> getOrderPaymentProof({
    required String orderId,
  }) async {
    final rows = await _readRows(
      rpcName: orderPaymentProofRpcName,
      params: <String, Object?>{'p_order_id': orderId},
    );
    if (rows.isEmpty) return null;
    if (rows.length != 1) {
      throw const FormatException('Unexpected payment proof row count.');
    }
    final row = rows.single;
    if (row.length != 1 || row['payment_proof_path'] is! String) {
      throw const FormatException('Unexpected payment proof payload.');
    }
    final path = row['payment_proof_path']! as String;
    final extension = path.split('.').last.toLowerCase();
    if (!const <String>{'jpg', 'jpeg', 'png', 'pdf'}.contains(extension)) {
      throw const FormatException('Unexpected payment proof extension.');
    }
    final signedUrl = await _signedUrlCall(
      paymentProofBucket,
      path,
      paymentProofSignedUrlLifetimeSeconds,
    );
    return Map<String, Object?>.unmodifiable(<String, Object?>{
      'signed_url': signedUrl,
      'file_extension': extension,
    });
  }

  @override
  Future<Map<String, Object?>> acceptOrder({
    required String orderId,
    String? publicMessage,
  }) {
    return _runAction(
      rpcName: acceptOrderRpcName,
      orderId: orderId,
      publicMessage: publicMessage,
    );
  }

  @override
  Future<Map<String, Object?>> rejectOrder({
    required String orderId,
    String? publicMessage,
  }) {
    return _runAction(
      rpcName: rejectOrderRpcName,
      orderId: orderId,
      publicMessage: publicMessage,
    );
  }

  Future<Map<String, Object?>> _runAction({
    required String rpcName,
    required String orderId,
    required String? publicMessage,
  }) async {
    final rows = await _readRows(
      rpcName: rpcName,
      params: <String, Object?>{
        'p_order_id': orderId,
        'p_public_message': publicMessage,
      },
    );
    if (rows.length != 1 || rows.single.length != 2) {
      throw const FormatException('Unexpected order action payload.');
    }
    return rows.single;
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

Future<String> _unsupportedSignedUrlCall(
  String bucket,
  String path,
  int expiresIn,
) {
  throw UnsupportedError('Signed URL calls are unavailable.');
}

class _SupabaseOrdersRpcCall {
  const _SupabaseOrdersRpcCall(this._client);

  final SupabaseClient _client;

  Future<Object?> call(String rpcName, Map<String, Object?> rpcParams) {
    return _client.rpc(rpcName, params: rpcParams);
  }
}

class _SupabaseOrdersSignedUrlCall {
  const _SupabaseOrdersSignedUrlCall(this._client);

  final SupabaseClient _client;

  Future<String> call(String bucket, String path, int expiresIn) {
    return _client.storage.from(bucket).createSignedUrl(path, expiresIn);
  }
}
