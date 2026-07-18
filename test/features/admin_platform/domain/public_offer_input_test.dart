import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_validation.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/offers/public_offer_input.dart';

void main() {
  group('PublicOfferInput', () {
    test('trims identifiers and names', () {
      final input = _validInput(
        gameId: '  game-id  ',
        nameAr: '  Offer AR  ',
        nameFr: '  Offer FR  ',
      );

      expect(input.gameId, 'game-id');
      expect(input.nameAr, 'Offer AR');
      expect(input.nameFr, 'Offer FR');
      expect(input.isValid(selectedGameIsActive: true), isTrue);
    });

    test('requires a selected game', () {
      expect(
        _validInput(gameId: ' ').validate(selectedGameIsActive: true),
        contains(
          _issue(
            PlatformValidationField.gameId,
            PlatformValidationCode.required,
          ),
        ),
      );
    });

    test('requires names and limits them to 120 characters', () {
      expect(
        _validInput(nameAr: ' ').validate(selectedGameIsActive: true),
        contains(
          _issue(
            PlatformValidationField.nameAr,
            PlatformValidationCode.required,
          ),
        ),
      );
      expect(
        _validInput(
          nameFr: 'a'.padRight(121, 'a'),
        ).validate(selectedGameIsActive: true),
        contains(
          _issue(
            PlatformValidationField.nameFr,
            PlatformValidationCode.tooLong,
          ),
        ),
      );
    });

    test('requires a positive reward quantity', () {
      for (final quantity in <int>[0, -1]) {
        expect(
          _validInput(
            rewardQuantity: quantity,
          ).validate(selectedGameIsActive: true),
          contains(
            _issue(
              PlatformValidationField.rewardQuantity,
              PlatformValidationCode.mustBePositive,
            ),
          ),
        );
      }
    });

    test('requires a positive sale price', () {
      for (final price in <int>[0, -1]) {
        expect(
          _validInput(salePriceDzd: price).validate(selectedGameIsActive: true),
          contains(
            _issue(
              PlatformValidationField.salePriceDzd,
              PlatformValidationCode.mustBePositive,
            ),
          ),
        );
      }
    });

    test('uses hidden and zero ordering defaults', () {
      final input = _validInput();

      expect(input.isPublished, isFalse);
      expect(input.sortOrder, 0);
    });

    test('prevents publishing an offer for an inactive game', () {
      expect(
        _validInput(isPublished: true).validate(selectedGameIsActive: false),
        contains(
          _issue(
            PlatformValidationField.selectedGameIsActive,
            PlatformValidationCode.inactiveGame,
          ),
        ),
      );
    });

    test('allows saving a hidden offer for an inactive game', () {
      expect(_validInput().isValid(selectedGameIsActive: false), isTrue);
    });
  });
}

PublicOfferInput _validInput({
  String gameId = 'game-id',
  String nameAr = 'Offer AR',
  String nameFr = 'Offer FR',
  int rewardQuantity = 100,
  int salePriceDzd = 350,
  bool isPublished = false,
  int sortOrder = 0,
}) {
  return PublicOfferInput(
    gameId: gameId,
    nameAr: nameAr,
    nameFr: nameFr,
    rewardQuantity: rewardQuantity,
    salePriceDzd: salePriceDzd,
    isPublished: isPublished,
    sortOrder: sortOrder,
  );
}

PlatformValidationIssue _issue(
  PlatformValidationField field,
  PlatformValidationCode code,
) {
  return PlatformValidationIssue(field: field, code: code);
}
