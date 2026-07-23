import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/common/platform_payload_reader.dart';
import 'package:game_credit_profit_manager/features/admin_platform/infrastructure/orders/order_internal_note_dto.dart';

void main() {
  test('maps an internal note, normalizes UTC, and drops identifiers', () {
    final dto = OrderInternalNoteDto.fromMap(
      _row(createdAt: '2026-07-18T12:00:00+01:00'),
    );
    final note = dto.toDomain();

    expect(dto.id, 10);
    expect(dto.orderId, '11111111-1111-1111-1111-111111111111');
    expect(note.text, 'ملاحظة داخلية آمنة');
    expect(note.createdAt, DateTime.utc(2026, 7, 18, 11));
    expect(note.createdAt.isUtc, isTrue);
  });

  test('accepts exactly 2000 characters and preserves mixed content', () {
    final text = '${List<String>.filled(1980, 'x').join()}\nملاحظة note';
    final padded = text.padRight(2000, 'y');

    expect(padded.length, 2000);
    expect(OrderInternalNoteDto.fromMap(_row(note: padded)).text, padded);
  });

  test('rejects malformed identifiers, note text, id, and date', () {
    final cases = <Map<String, Object?>>[
      _row()..['id'] = 0,
      _row()..['order_id'] = 'not-a-uuid',
      _row()..['author_user_id'] = 'not-a-uuid',
      _row()..['note'] = '   ',
      _row()..['note'] = ' padded ',
      _row()..['note'] = List<String>.filled(2001, 'x').join(),
      _row()..['created_at'] = 'not-a-date',
    ];

    for (final row in cases) {
      expect(
        () => OrderInternalNoteDto.fromMap(row),
        throwsA(isA<PlatformPayloadException>()),
      );
    }
  });

  test('safe string representations omit text and identifiers', () {
    const secret = 'INTERNAL-SECRET-DO-NOT-LEAK';
    final dto = OrderInternalNoteDto.fromMap(_row(note: secret));
    final domain = dto.toDomain();

    for (final value in <String>[dto.toString(), domain.toString()]) {
      expect(value, isNot(contains(secret)));
      expect(value, isNot(contains(dto.orderId)));
      expect(value, isNot(contains('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')));
    }
  });
}

Map<String, Object?> _row({
  String note = 'ملاحظة داخلية آمنة',
  String createdAt = '2026-07-18T12:00:00Z',
}) => <String, Object?>{
  'id': 10,
  'order_id': '11111111-1111-1111-1111-111111111111',
  'author_user_id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'note': note,
  'created_at': createdAt,
  'payment_proof_path': 'must-not-cross-the-domain-boundary',
};
