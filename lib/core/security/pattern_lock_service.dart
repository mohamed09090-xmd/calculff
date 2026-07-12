import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum PatternVerificationStatus { success, invalid, lockedOut, notEnabled }

class PatternVerificationResult {
  const PatternVerificationResult({
    required this.status,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  final PatternVerificationStatus status;
  final int failedAttempts;
  final DateTime? lockedUntil;

  Duration get retryAfter {
    final until = lockedUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(migrateWithBackup: true),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class PatternSecretCodec {
  const PatternSecretCodec({this.defaultIterations = 45000});

  final int defaultIterations;

  Future<PatternSecret> create(List<int> pattern) async {
    final random = Random.secure();
    final saltBytes = List<int>.generate(24, (_) => random.nextInt(256));
    final salt = base64UrlEncode(saltBytes);
    final hash = await derive(
      pattern: pattern,
      salt: salt,
      iterations: defaultIterations,
    );
    return PatternSecret(
      version: 1,
      salt: salt,
      hash: hash,
      iterations: defaultIterations,
    );
  }

  Future<bool> verify(List<int> pattern, PatternSecret secret) async {
    final candidate = await derive(
      pattern: pattern,
      salt: secret.salt,
      iterations: secret.iterations,
    );
    return _constantTimeEquals(candidate, secret.hash);
  }

  Future<String> derive({
    required List<int> pattern,
    required String salt,
    required int iterations,
  }) {
    final canonical = canonicalPattern(pattern);
    return Isolate.run(() {
      List<int> bytes = utf8.encode('$salt|$canonical');
      for (var index = 0; index < iterations; index++) {
        bytes = sha256.convert(bytes).bytes;
      }
      return base64UrlEncode(bytes);
    });
  }

  static String canonicalPattern(List<int> pattern) {
    validatePattern(pattern);
    return pattern.join('-');
  }

  static void validatePattern(List<int> pattern) {
    if (pattern.length < 4) {
      throw const FormatException('يجب أن يحتوي النمط على 4 نقاط على الأقل');
    }
    if (pattern.any((node) => node < 0 || node > 8)) {
      throw const FormatException('النمط يحتوي على نقطة غير صالحة');
    }
    if (pattern.toSet().length != pattern.length) {
      throw const FormatException('لا يمكن تكرار النقطة في النمط نفسه');
    }
  }

  bool _constantTimeEquals(String first, String second) {
    final firstBytes = utf8.encode(first);
    final secondBytes = utf8.encode(second);
    var difference = firstBytes.length ^ secondBytes.length;
    final length = firstBytes.length < secondBytes.length
        ? firstBytes.length
        : secondBytes.length;
    for (var index = 0; index < length; index++) {
      difference |= firstBytes[index] ^ secondBytes[index];
    }
    return difference == 0;
  }
}

class PatternSecret {
  const PatternSecret({
    required this.version,
    required this.salt,
    required this.hash,
    required this.iterations,
  });

  final int version;
  final String salt;
  final String hash;
  final int iterations;

  Map<String, Object?> toJson() => {
    'version': version,
    'salt': salt,
    'hash': hash,
    'iterations': iterations,
  };

  factory PatternSecret.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    final salt = json['salt'];
    final hash = json['hash'];
    final iterations = json['iterations'];
    if (version is! int ||
        version != 1 ||
        salt is! String ||
        hash is! String ||
        iterations is! int ||
        iterations < 1) {
      throw const FormatException('بيانات قفل التطبيق تالفة');
    }
    return PatternSecret(
      version: version,
      salt: salt,
      hash: hash,
      iterations: iterations,
    );
  }
}

class PatternLockService {
  PatternLockService({SecureKeyValueStore? store, PatternSecretCodec? codec})
    : _store = store ?? FlutterSecureKeyValueStore(),
      _codec = codec ?? const PatternSecretCodec();

  static const _enabledKey = 'app_lock.pattern.enabled.v1';
  static const _secretKey = 'app_lock.pattern.secret.v1';
  static const _failuresKey = 'app_lock.pattern.failures.v1';
  static const _lockedUntilKey = 'app_lock.pattern.locked_until.v1';
  static const maxAttempts = 5;
  static const lockoutDuration = Duration(seconds: 30);

  final SecureKeyValueStore _store;
  final PatternSecretCodec _codec;

  Future<bool> isEnabled() async {
    final enabled = await _store.read(_enabledKey) == 'true';
    final secret = await _store.read(_secretKey);
    return enabled && secret != null;
  }

  Future<void> enable(List<int> pattern) async {
    PatternSecretCodec.validatePattern(pattern);
    final secret = await _codec.create(pattern);
    await _store.write(_secretKey, jsonEncode(secret.toJson()));
    await _store.write(_enabledKey, 'true');
    await _resetFailures();
  }

  Future<PatternVerificationResult> verify(List<int> pattern) async {
    if (!await isEnabled()) {
      return const PatternVerificationResult(
        status: PatternVerificationStatus.notEnabled,
      );
    }

    final lockedUntil = await _readLockedUntil();
    if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
      return PatternVerificationResult(
        status: PatternVerificationStatus.lockedOut,
        failedAttempts: await _readFailures(),
        lockedUntil: lockedUntil,
      );
    }
    if (lockedUntil != null) await _resetFailures();

    try {
      PatternSecretCodec.validatePattern(pattern);
    } on FormatException {
      return _recordFailure();
    }

    final raw = await _store.read(_secretKey);
    if (raw == null) {
      return const PatternVerificationResult(
        status: PatternVerificationStatus.notEnabled,
      );
    }

    final secret = PatternSecret.fromJson(
      (jsonDecode(raw) as Map).cast<String, Object?>(),
    );
    if (await _codec.verify(pattern, secret)) {
      await _resetFailures();
      return const PatternVerificationResult(
        status: PatternVerificationStatus.success,
      );
    }
    return _recordFailure();
  }

  Future<PatternVerificationResult> disable(List<int> currentPattern) async {
    final verification = await verify(currentPattern);
    if (verification.status != PatternVerificationStatus.success) {
      return verification;
    }
    await _store.delete(_enabledKey);
    await _store.delete(_secretKey);
    await _resetFailures();
    return const PatternVerificationResult(
      status: PatternVerificationStatus.success,
    );
  }

  Future<PatternVerificationResult> change({
    required List<int> currentPattern,
    required List<int> newPattern,
  }) async {
    final verification = await verify(currentPattern);
    if (verification.status != PatternVerificationStatus.success) {
      return verification;
    }
    await enable(newPattern);
    return const PatternVerificationResult(
      status: PatternVerificationStatus.success,
    );
  }

  Future<PatternVerificationResult> _recordFailure() async {
    final failures = await _readFailures() + 1;
    await _store.write(_failuresKey, '$failures');
    if (failures < maxAttempts) {
      return PatternVerificationResult(
        status: PatternVerificationStatus.invalid,
        failedAttempts: failures,
      );
    }

    final lockedUntil = DateTime.now().add(lockoutDuration);
    await _store.write(_lockedUntilKey, lockedUntil.toIso8601String());
    return PatternVerificationResult(
      status: PatternVerificationStatus.lockedOut,
      failedAttempts: failures,
      lockedUntil: lockedUntil,
    );
  }

  Future<int> _readFailures() async =>
      int.tryParse(await _store.read(_failuresKey) ?? '') ?? 0;

  Future<DateTime?> _readLockedUntil() async {
    final raw = await _store.read(_lockedUntilKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> _resetFailures() async {
    await _store.delete(_failuresKey);
    await _store.delete(_lockedUntilKey);
  }
}
