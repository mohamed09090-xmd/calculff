import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/core/security/pattern_path.dart';

void main() {
  group('قواعد مسار النمط', () {
    test('يضيف النقطة الوسطى عند العبور أفقيًا', () {
      final first = appendPatternNode(const [], 0);
      final result = appendPatternNode(first, 2);

      expect(result, [0, 1, 2]);
    });

    test('يضيف النقطة الوسطى عند العبور قطريًا', () {
      final first = appendPatternNode(const [], 0);
      final result = appendPatternNode(first, 8);

      expect(result, [0, 4, 8]);
    });

    test('لا يكرر النقطة الوسطى إذا كانت محددة مسبقًا', () {
      var pattern = appendPatternNode(const [], 0);
      pattern = appendPatternNode(pattern, 4);
      pattern = appendPatternNode(pattern, 8);

      expect(pattern, [0, 4, 8]);
    });

    test('يتجاهل النقاط المكررة وغير الصالحة', () {
      final pattern = appendPatternNode(const [0, 1], 1);
      final invalid = appendPatternNode(pattern, 9);

      expect(pattern, [0, 1]);
      expect(invalid, [0, 1]);
    });
  });
}
