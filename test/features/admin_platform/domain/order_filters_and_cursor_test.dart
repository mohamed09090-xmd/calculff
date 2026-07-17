import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_validation.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/customer_orders_repository.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_cursor.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_enums.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/orders/order_filters.dart';

void main() {
  group('OrderFilters', () {
    test('starts empty when all filters are omitted', () {
      final filters = OrderFilters();

      expect(filters.isEmpty, isTrue);
      expect(filters.searchText, isNull);
      expect(filters.validate(), isEmpty);
    });

    test('trims search text and converts blank input to null', () {
      expect(OrderFilters(searchText: '  player  ').searchText, 'player');
      expect(OrderFilters(searchText: '   ').searchText, isNull);
    });

    test('accepts Arabic, French, numbers, and punctuation', () {
      for (final value in <String>[
        'محمد 123',
        'Joueur numéro 42',
        'Player (42), serveur.1',
      ]) {
        expect(OrderFilters(searchText: value).isValid, isTrue);
      }
    });

    test('enforces the documented 100 character limit', () {
      expect(
        OrderFilters(searchText: 'a'.padRight(100, 'a')).isValid,
        isTrue,
      );
      expect(
        OrderFilters(searchText: 'a'.padRight(101, 'a')).validate(),
        contains(
          _issue(
            PlatformValidationField.searchText,
            PlatformValidationCode.tooLong,
          ),
        ),
      );
    });

    test('rejects control characters without treating punctuation as SQL', () {
      expect(
        OrderFilters(searchText: 'player\u0000name').validate(),
        contains(
          _issue(
            PlatformValidationField.searchText,
            PlatformValidationCode.containsControlCharacters,
          ),
        ),
      );
      expect(OrderFilters(searchText: '(player), name.').isValid, isTrue);
    });

    test('accepts a valid exclusive date range and normalizes it to UTC', () {
      final filters = OrderFilters(
        dateFrom: DateTime.parse('2026-07-01T00:00:00+01:00'),
        dateToExclusive: DateTime.parse('2026-08-01T00:00:00+01:00'),
      );

      expect(filters.isValid, isTrue);
      expect(filters.dateFrom?.isUtc, isTrue);
      expect(filters.dateToExclusive?.isUtc, isTrue);
    });

    test('rejects equal or reversed date ranges', () {
      final start = DateTime.utc(2026, 7, 10);

      for (final end in <DateTime>[start, start.subtract(const Duration(days: 1))]) {
        expect(
          OrderFilters(dateFrom: start, dateToExclusive: end).validate(),
          contains(
            _issue(
              PlatformValidationField.dateRange,
              PlatformValidationCode.invalidRange,
            ),
          ),
        );
      }
    });

    test('copyWith updates and explicitly clears optional filters', () {
      final initial = OrderFilters(
        orderStatus: OrderStatus.newOrder,
        paymentStatus: PaymentStatus.awaitingPayment,
        paymentMethod: PaymentMethod.transfer,
        gameId: 'game-id',
        searchText: 'player',
      );
      final updated = initial.copyWith(
        orderStatus: OrderStatus.processing,
        paymentStatus: null,
        searchText: null,
      );

      expect(updated.orderStatus, OrderStatus.processing);
      expect(updated.paymentStatus, isNull);
      expect(updated.paymentMethod, PaymentMethod.transfer);
      expect(updated.gameId, 'game-id');
      expect(updated.searchText, isNull);
    });

    test('contains no PostgREST query syntax', () {
      final filters = OrderFilters(searchText: 'name,(42).');

      expect(filters.searchText, 'name,(42).');
      expect(filters.isValid, isTrue);
    });
  });

  group('OrderCursor', () {
    test('keeps the server row id and normalizes createdAt to UTC', () {
      final cursor = OrderCursor(
        createdAt: DateTime.parse('2026-07-17T12:00:00+01:00'),
        id: '  11111111-1111-1111-1111-111111111111  ',
      );

      expect(cursor.createdAt, DateTime.utc(2026, 7, 17, 11));
      expect(cursor.id, '11111111-1111-1111-1111-111111111111');
    });

    test('requires a non-empty server row id', () {
      expect(
        () => OrderCursor(createdAt: DateTime.utc(2026), id: '  '),
        throwsArgumentError,
      );
    });

    test('retains id as the tie-breaker for equal timestamps', () {
      final createdAt = DateTime.utc(2026, 7, 17, 11);
      final first = OrderCursor(createdAt: createdAt, id: 'first-id');
      final second = OrderCursor(createdAt: createdAt, id: 'second-id');

      expect(first.createdAt, second.createdAt);
      expect(first.id, isNot(second.id));
    });

    test('does not print the internal id', () {
      const id = '11111111-1111-1111-1111-111111111111';
      final cursor = OrderCursor(createdAt: DateTime.utc(2026), id: id);

      expect(cursor.toString(), isNot(contains(id)));
    });
  });

  test('customer order page limits are capped at 25', () {
    expect(customerOrdersMaxPageSize, 25);
    expect(isValidCustomerOrdersPageLimit(1), isTrue);
    expect(isValidCustomerOrdersPageLimit(25), isTrue);
    expect(isValidCustomerOrdersPageLimit(0), isFalse);
    expect(isValidCustomerOrdersPageLimit(26), isFalse);
  });
}

PlatformValidationIssue _issue(
  PlatformValidationField field,
  PlatformValidationCode code,
) {
  return PlatformValidationIssue(field: field, code: code);
}
