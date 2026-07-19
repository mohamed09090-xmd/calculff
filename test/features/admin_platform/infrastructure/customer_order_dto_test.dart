import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_enums.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/platform_payload_reader.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/customer_order_details_dto.dart';

void main() {
  test('maps a valid details payload and normalizes dates to UTC', () {
    final dto = CustomerOrderDetailsDto.fromMap(_detailsPayload());
    final details = dto.toDomain();

    expect(details.summary.orderStatus, OrderStatus.processing);
    expect(details.summary.paymentStatus, PaymentStatus.underReview);
    expect(details.rewardUnitCodeSnapshot, 'diamond');
    expect(details.summary.hasPaymentProof, isTrue);
    expect(details.summary.createdAt.isUtc, isTrue);
    expect(details.updatedAt.isUtc, isTrue);
    expect(details.completedAt, isNull);
    expect(details.publicStatusMessage, isNull);
  });

  test('requires has_payment_proof to be a Boolean', () {
    final payload = _detailsPayload()..['has_payment_proof'] = 'true';

    expect(
      () => CustomerOrderDetailsDto.fromMap(payload),
      throwsA(isA<PlatformPayloadException>()),
    );
  });

  test('requires the reward unit code snapshot', () {
    final payload = _detailsPayload()..remove('reward_unit_code_snapshot');

    expect(
      () => CustomerOrderDetailsDto.fromMap(payload),
      throwsA(isA<PlatformPayloadException>()),
    );
  });

  test('rejects unknown enums and malformed payloads', () {
    final unknown = _detailsPayload()..['order_status'] = 'hidden';
    final malformed = _detailsPayload()..['sale_price_dzd_snapshot'] = 1.5;

    expect(
      () => CustomerOrderDetailsDto.fromMap(unknown),
      throwsA(isA<PlatformPayloadException>()),
    );
    expect(
      () => CustomerOrderDetailsDto.fromMap(malformed),
      throwsA(isA<PlatformPayloadException>()),
    );
  });

  test('safe representations do not leak contact or player data', () {
    final dto = CustomerOrderDetailsDto.fromMap(_detailsPayload());
    final dtoText = dto.toString();
    final domainText = dto.toDomain().toString();

    for (final privateValue in <String>[
      'customer@example.test',
      '0550000000',
      'player-123',
      '11111111-1111-1111-1111-111111111111',
    ]) {
      expect(dtoText, isNot(contains(privateValue)));
      expect(domainText, isNot(contains(privateValue)));
    }
  });
}

Map<String, Object?> _detailsPayload() => <String, Object?>{
  'id': '11111111-1111-1111-1111-111111111111',
  'game_name_ar_snapshot': 'لعبة',
  'game_name_fr_snapshot': 'Jeu',
  'offer_name_ar_snapshot': 'عرض',
  'offer_name_fr_snapshot': 'Offre',
  'reward_unit_code_snapshot': 'diamond',
  'reward_unit_name_ar_snapshot': 'جوهرة',
  'reward_unit_name_fr_snapshot': 'diamant',
  'customer_name_snapshot': 'Customer Fixture',
  'customer_email_snapshot': 'customer@example.test',
  'customer_phone_snapshot': '0550000000',
  'player_id': 'player-123',
  'in_game_name': null,
  'sale_price_dzd_snapshot': 350,
  'reward_quantity_snapshot': 100,
  'payment_method': 'transfer',
  'order_status': 'processing',
  'payment_status': 'under_review',
  'public_status_message': null,
  'created_at': '2026-07-18T13:00:00+01:00',
  'updated_at': '2026-07-18T14:00:00+01:00',
  'completed_at': null,
  'refund_started_at': null,
  'refunded_at': null,
  'has_payment_proof': true,
};
