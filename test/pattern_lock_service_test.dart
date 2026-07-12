import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/core/security/pattern_lock_service.dart';

class _MemorySecureStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  late _MemorySecureStore store;
  late PatternLockService service;

  setUp(() {
    store = _MemorySecureStore();
    service = PatternLockService(
      store: store,
      codec: const PatternSecretCodec(defaultIterations: 20),
    );
  });

  test('يفعل النمط ويتحقق منه ويوقفه', () async {
    const pattern = [0, 1, 4, 7];

    expect(await service.isEnabled(), isFalse);
    await service.enable(pattern);
    expect(await service.isEnabled(), isTrue);

    final valid = await service.verify(pattern);
    expect(valid.status, PatternVerificationStatus.success);

    final disabled = await service.disable(pattern);
    expect(disabled.status, PatternVerificationStatus.success);
    expect(await service.isEnabled(), isFalse);
  });

  test('يرفض النمط الخاطئ ثم يقفل المحاولات بعد خمس مرات', () async {
    await service.enable(const [0, 1, 4, 7]);

    for (var attempt = 1; attempt < PatternLockService.maxAttempts; attempt++) {
      final result = await service.verify(const [0, 3, 4, 5]);
      expect(result.status, PatternVerificationStatus.invalid);
      expect(result.failedAttempts, attempt);
    }

    final locked = await service.verify(const [0, 3, 4, 5]);
    expect(locked.status, PatternVerificationStatus.lockedOut);
    expect(locked.failedAttempts, PatternLockService.maxAttempts);
    expect(locked.lockedUntil, isNotNull);

    final correctWhileLocked = await service.verify(const [0, 1, 4, 7]);
    expect(correctWhileLocked.status, PatternVerificationStatus.lockedOut);
  });

  test('يغير النمط بعد التحقق من النمط الحالي', () async {
    const oldPattern = [0, 1, 4, 7];
    const newPattern = [2, 4, 6, 7];
    await service.enable(oldPattern);

    final changed = await service.change(
      currentPattern: oldPattern,
      newPattern: newPattern,
    );
    expect(changed.status, PatternVerificationStatus.success);
    expect(
      (await service.verify(oldPattern)).status,
      PatternVerificationStatus.invalid,
    );
    expect(
      (await service.verify(newPattern)).status,
      PatternVerificationStatus.success,
    );
  });

  test('لا يقبل نمطًا أقصر من أربع نقاط', () async {
    await expectLater(
      service.enable(const [0, 1, 2]),
      throwsA(isA<FormatException>()),
    );
  });
}
