import 'dart:math';

abstract final class IdGenerator {
  static final Random _random = Random.secure();
  static String next(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(999999)}';
}
