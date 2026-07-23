import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/application/common/platform_session_coordinator.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_enums.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_payment_proof.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/supabase_platform_error_mapper.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/supabase_order_actions_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/supabase_order_payment_proof_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/supabase_orders_data_source.dart';

const _orderId = '11111111-1111-4111-8111-111111111111';

void main() {
  test('proof repository exposes no storage path and recognizes PDF', () async {
    final repository = SupabaseOrderPaymentProofRepository(
      dataSource: _ProofDataSource(
        payload: <String, Object?>{
          'signed_url': 'https://project.test/storage/v1/object/sign/proof',
          'file_extension': 'pdf',
        },
      ),
      errorMapper: const SupabasePlatformErrorMapper(),
      readCoordinator: const _ReadCoordinator(),
    );

    final proof = await repository.getPaymentProof(orderId: _orderId);

    expect(proof?.kind, OrderPaymentProofKind.pdf);
    expect(proof?.uri.scheme, 'https');
    expect(proof.toString(), isNot(contains('payment_proof_path')));
  });

  test('malformed proof URLs and payloads fail closed', () async {
    for (final payload in <Map<String, Object?>>[
      <String, Object?>{
        'signed_url': 'http://project.test/proof',
        'file_extension': 'jpg',
      },
      <String, Object?>{
        'signed_url': 'https://project.test/proof',
        'file_extension': 'exe',
      },
    ]) {
      final repository = SupabaseOrderPaymentProofRepository(
        dataSource: _ProofDataSource(payload: payload),
        errorMapper: const SupabasePlatformErrorMapper(),
        readCoordinator: const _ReadCoordinator(),
      );
      await expectLater(
        repository.getPaymentProof(orderId: _orderId),
        throwsA(
          isA<PlatformFailure>().having(
            (value) => value.code,
            'code',
            PlatformFailureCode.malformedResponse,
          ),
        ),
      );
    }
  });

  test('actions map only known final statuses through mutation coordinator', (
  ) async {
    final dataSource = _ActionsDataSource();
    final coordinator = _MutationCoordinator();
    final repository = SupabaseOrderActionsRepository(
      dataSource: dataSource,
      errorMapper: const SupabasePlatformErrorMapper(),
      mutationCoordinator: coordinator,
    );

    final accepted = await repository.acceptOrder(
      orderId: _orderId,
      publicMessage: 'accepted',
    );
    final rejected = await repository.rejectOrder(
      orderId: _orderId,
      publicMessage: 'rejected',
    );

    expect(accepted.orderStatus, OrderStatus.processing);
    expect(accepted.paymentStatus, PaymentStatus.paid);
    expect(rejected.orderStatus, OrderStatus.rejected);
    expect(rejected.paymentStatus, PaymentStatus.proofRejected);
    expect(dataSource.messages, <String?>['accepted', 'rejected']);
    expect(coordinator.calls, 2);
  });

  test('invalid ids fail before proof or action network calls', () {
    final proofDataSource = _ProofDataSource(payload: null);
    final actionsDataSource = _ActionsDataSource();
    final proofRepository = SupabaseOrderPaymentProofRepository(
      dataSource: proofDataSource,
      errorMapper: const SupabasePlatformErrorMapper(),
      readCoordinator: const _ReadCoordinator(),
    );
    final actionsRepository = SupabaseOrderActionsRepository(
      dataSource: actionsDataSource,
      errorMapper: const SupabasePlatformErrorMapper(),
      mutationCoordinator: _MutationCoordinator(),
    );

    expect(
      () => proofRepository.getPaymentProof(orderId: 'invalid'),
      throwsA(isA<PlatformFailure>()),
    );
    expect(
      () => actionsRepository.acceptOrder(orderId: 'invalid'),
      throwsA(isA<PlatformFailure>()),
    );
    expect(proofDataSource.calls, 0);
    expect(actionsDataSource.calls, 0);
  });
}

class _ProofDataSource implements SupabaseOrderPaymentProofDataSource {
  _ProofDataSource({required this.payload});

  final Map<String, Object?>? payload;
  int calls = 0;

  @override
  Future<Map<String, Object?>?> getOrderPaymentProof({
    required String orderId,
  }) async {
    calls += 1;
    return payload;
  }
}

class _ActionsDataSource implements SupabaseOrderActionsDataSource {
  final messages = <String?>[];
  int calls = 0;

  @override
  Future<Map<String, Object?>> acceptOrder({
    required String orderId,
    String? publicMessage,
  }) async {
    calls += 1;
    messages.add(publicMessage);
    return <String, Object?>{
      'order_status': 'processing',
      'payment_status': 'paid',
    };
  }

  @override
  Future<Map<String, Object?>> rejectOrder({
    required String orderId,
    String? publicMessage,
  }) async {
    calls += 1;
    messages.add(publicMessage);
    return <String, Object?>{
      'order_status': 'rejected',
      'payment_status': 'proof_rejected',
    };
  }
}

class _MutationCoordinator implements PlatformMutationCoordinator {
  int calls = 0;

  @override
  Future<T> runMutation<T>(PlatformMutationOperation<T> operation) {
    calls += 1;
    return operation();
  }
}

class _ReadCoordinator implements PlatformReadCoordinator {
  const _ReadCoordinator();

  @override
  Future<T> runRead<T>(PlatformReadOperation<T> operation) => operation();
}
