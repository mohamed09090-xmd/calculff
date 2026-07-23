import '../../application/common/platform_session_coordinator.dart';
import '../../domain/common/platform_failure.dart';
import '../../domain/orders/order_payment_proof.dart';
import '../../domain/orders/order_payment_proof_repository.dart';
import '../common/platform_payload_reader.dart';
import '../common/supabase_platform_error_mapper.dart';
import 'supabase_customer_orders_repository.dart';
import 'supabase_orders_data_source.dart';

class SupabaseOrderPaymentProofRepository
    implements OrderPaymentProofRepository {
  const SupabaseOrderPaymentProofRepository({
    required SupabaseOrderPaymentProofDataSource dataSource,
    required SupabasePlatformErrorMapper errorMapper,
    required PlatformReadCoordinator readCoordinator,
  }) : _dataSource = dataSource,
       _errorMapper = errorMapper,
       _readCoordinator = readCoordinator;

  final SupabaseOrderPaymentProofDataSource _dataSource;
  final SupabasePlatformErrorMapper _errorMapper;
  final PlatformReadCoordinator _readCoordinator;

  @override
  Future<OrderPaymentProof?> getPaymentProof({required String orderId}) {
    validateCustomerOrderId(orderId);
    return _readCoordinator.runRead(() async {
      try {
        final payload = await _dataSource.getOrderPaymentProof(
          orderId: orderId,
        );
        if (payload == null) return null;
        final reader = PlatformPayloadReader(payload);
        final rawUrl = reader.requiredString('signed_url');
        final extension = reader.requiredString('file_extension');
        final uri = Uri.tryParse(rawUrl);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty) {
          throw const PlatformPayloadException(
            field: 'signed_url',
            reason: PlatformPayloadFailureReason.invalidValue,
          );
        }
        final kind = switch (extension) {
          'jpg' || 'jpeg' || 'png' => OrderPaymentProofKind.image,
          'pdf' => OrderPaymentProofKind.pdf,
          _ => throw const PlatformPayloadException(
            field: 'file_extension',
            reason: PlatformPayloadFailureReason.invalidValue,
          ),
        };
        return OrderPaymentProof(uri: uri, kind: kind);
      } catch (error) {
        if (error is FormatException || error is PlatformPayloadException) {
          throw const PlatformFailure(PlatformFailureCode.malformedResponse);
        }
        throw _errorMapper.map(error);
      }
    });
  }
}
