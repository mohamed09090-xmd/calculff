import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_enums.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/platform_payload_reader.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/customer_order_details_dto.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/customer_order_summary_dto.dart';

void main() {
  group('CustomerOrderSummaryDto', () {
    test('maps every supported order status', () {
      for (final status in OrderStatus.values) {
        final payload = _summaryPayload()..['order_status'] = status.wireValue;

        expect(CustomerOrderSummaryDto.fromMap(payload).orderStatus, status);
      }
    });

    test('maps every supported payment status', () {
      for (final status in PaymentStatus.values) {
        final payload = _summaryPayload()
          ..['payment_status'] = status.wireValue;

        expect(CustomerOrderSummaryDto.fromMap(payload).paymentStatus, status);
      }
    });

    test('maps both payment methods', () {
      for (final method in PaymentMethod.values) {
        final payload = _summaryPayload()
          ..['payment_method'] = method.wireValue;

        expect(CustomerOrderSummaryDto.fromMap(payload).paymentMethod, method);
      }
    });

    test('maps nullable fields and normalizes createdAt to UTC', () {
      final payload = _summaryPayload()..['in_game_name'] = null;
      final summary = CustomerOrderSummaryDto.fromMap(payload).toDomain();

      expect(summary.inGameName, isNull);
      expect(summary.createdAt, DateTime.utc(2026, 7, 17, 11));
    });

    test('converts proof path presence directly to a boolean', () {
      final withProof = CustomerOrderSummaryDto.fromMap(_summaryPayload());
      final withoutProofPayload = _summaryPayload()
        ..['payment_proof_path'] = null;
      final withoutProof = CustomerOrderSummaryDto.fromMap(withoutProofPayload);

      expect(withProof.hasPaymentProof, isTrue);
      expect(withProof.toDomain().hasPaymentProof, isTrue);
      expect(withoutProof.hasPaymentProof, isFalse);
      expect(withoutProof.toDomain().hasPaymentProof, isFalse);
    });

    test('rejects malformed payloads and unknown enum values', () {
      final missingField = _summaryPayload()..remove('player_id');
      final unknownOrderStatus = _summaryPayload()
        ..['order_status'] = 'future_status';
      final unknownPaymentStatus = _summaryPayload()
        ..['payment_status'] = 'future_payment';
      final unknownPaymentMethod = _summaryPayload()
        ..['payment_method'] = 'card';

      expect(
        () => CustomerOrderSummaryDto.fromMap(missingField),
        throwsA(
          isA<PlatformPayloadException>().having(
            (error) => error.field,
            'field',
            'player_id',
          ),
        ),
      );
      expect(
        () => CustomerOrderSummaryDto.fromMap(unknownOrderStatus),
        throwsA(_invalidField('order_status')),
      );
      expect(
        () => CustomerOrderSummaryDto.fromMap(unknownPaymentStatus),
        throwsA(_invalidField('payment_status')),
      );
      expect(
        () => CustomerOrderSummaryDto.fromMap(unknownPaymentMethod),
        throwsA(_invalidField('payment_method')),
      );
    });

    test('safe representations do not expose UUID or customer PII', () {
      final dto = CustomerOrderSummaryDto.fromMap(_summaryPayload());
      final dtoText = dto.toString();
      final domainText = dto.toDomain().toString();

      for (final sensitiveValue in <String>[
        '11111111-1111-1111-1111-111111111111',
        'Customer Name',
        'player-123',
        'customer@example.test',
        '0550000000',
        'private/proofs/proof.jpg',
      ]) {
        expect(dtoText, isNot(contains(sensitiveValue)));
        expect(domainText, isNot(contains(sensitiveValue)));
      }
    });
  });

  group('CustomerOrderDetailsDto', () {
    test('adds contact details only to the details model', () {
      final details = CustomerOrderDetailsDto.fromMap(
        _detailsPayload(),
      ).toDomain();

      expect(details.customerEmail, 'customer@example.test');
      expect(details.customerPhone, '0550000000');
      expect(details.publicStatusMessage, 'Payment is under review');
      expect(details.updatedAt, DateTime.utc(2026, 7, 17, 12));
      expect(details.completedAt, DateTime.utc(2026, 7, 18));
      expect(details.refundStartedAt, DateTime.utc(2026, 7, 19));
      expect(details.refundedAt, DateTime.utc(2026, 7, 20));
    });

    test('supports nullable public and lifecycle fields', () {
      final payload = _detailsPayload()
        ..['public_status_message'] = null
        ..['completed_at'] = null
        ..['refund_started_at'] = null
        ..['refunded_at'] = null;
      final details = CustomerOrderDetailsDto.fromMap(payload).toDomain();

      expect(details.publicStatusMessage, isNull);
      expect(details.completedAt, isNull);
      expect(details.refundStartedAt, isNull);
      expect(details.refundedAt, isNull);
    });

    test('safe representation omits email, phone, and full UUID', () {
      final dto = CustomerOrderDetailsDto.fromMap(_detailsPayload());
      final dtoText = dto.toString();
      final domainText = dto.toDomain().toString();

      expect(dtoText, isNot(contains('customer@example.test')));
      expect(dtoText, isNot(contains('0550000000')));
      expect(dtoText, isNot(contains(dto.summary.id)));
      expect(domainText, isNot(contains('customer@example.test')));
      expect(domainText, isNot(contains('0550000000')));
      expect(domainText, isNot(contains(dto.summary.id)));
    });
  });
}

Matcher _invalidField(String field) {
  return isA<PlatformPayloadException>()
      .having((error) => error.field, 'field', field)
      .having(
        (error) => error.reason,
        'reason',
        PlatformPayloadFailureReason.invalidValue,
      );
}

Map<String, Object?> _summaryPayload() {
  return <String, Object?>{
    'id': '11111111-1111-1111-1111-111111111111',
    'game_name_ar_snapshot': 'Game AR',
    'game_name_fr_snapshot': 'Game FR',
    'offer_name_ar_snapshot': 'Offer AR',
    'offer_name_fr_snapshot': 'Offer FR',
    'customer_name_snapshot': 'Customer Name',
    'player_id': 'player-123',
    'in_game_name': 'Player Name',
    'sale_price_dzd_snapshot': 350,
    'reward_quantity_snapshot': 100,
    'reward_unit_name_ar_snapshot': 'Unit AR',
    'reward_unit_name_fr_snapshot': 'Unit FR',
    'payment_method': 'transfer',
    'order_status': 'processing',
    'payment_status': 'under_review',
    'created_at': '2026-07-17T12:00:00+01:00',
    'payment_proof_path': 'private/proofs/proof.jpg',
    'customer_email_snapshot': 'customer@example.test',
    'customer_phone_snapshot': '0550000000',
    'user_id': '22222222-2222-2222-2222-222222222222',
    'client_request_id': '33333333-3333-3333-3333-333333333333',
    'changed_by': '44444444-4444-4444-4444-444444444444',
  };
}

Map<String, Object?> _detailsPayload() {
  return _summaryPayload()..addAll(<String, Object?>{
    'customer_email_snapshot': 'customer@example.test',
    'customer_phone_snapshot': '0550000000',
    'public_status_message': 'Payment is under review',
    'updated_at': '2026-07-17T13:00:00+01:00',
    'completed_at': '2026-07-18T00:00:00Z',
    'refund_started_at': '2026-07-19T00:00:00Z',
    'refunded_at': '2026-07-20T00:00:00Z',
    'internal_note': 'must never be mapped',
  });
}
