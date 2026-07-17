import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/cursor_page.dart';

void main() {
  group('CursorPage', () {
    test('supports an empty terminal page', () {
      final page = CursorPage<int>(
        items: const <int>[],
        nextCursor: null,
        hasMore: false,
      );

      expect(page.items, isEmpty);
      expect(page.nextCursor, isNull);
      expect(page.hasMore, isFalse);
    });

    test('keeps an opaque next cursor for a following page', () {
      final page = CursorPage<int>(
        items: const <int>[1, 2],
        nextCursor: 'opaque-cursor',
        hasMore: true,
      );

      expect(page.items, <int>[1, 2]);
      expect(page.nextCursor, 'opaque-cursor');
      expect(page.hasMore, isTrue);
    });

    test('copies and exposes an unmodifiable item list', () {
      final source = <int>[1];
      final page = CursorPage<int>(
        items: source,
        nextCursor: null,
        hasMore: false,
      );

      source.add(2);

      expect(page.items, <int>[1]);
      expect(() => page.items.add(3), throwsUnsupportedError);
    });
  });
}
