import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/common/platform_validation.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/games/game_input.dart';

void main() {
  group('GameInput', () {
    test('trims manager supplied text fields', () {
      final input = _validInput(
        slug: '  free-fire  ',
        nameAr: '  Free Fire AR  ',
        nameFr: '  Free Fire FR  ',
        rewardUnitCode: '  diamonds  ',
        rewardUnitNameAr: '  Diamonds AR  ',
        rewardUnitNameFr: '  Diamonds FR  ',
      );

      expect(input.slug, 'free-fire');
      expect(input.nameAr, 'Free Fire AR');
      expect(input.nameFr, 'Free Fire FR');
      expect(input.rewardUnitCode, 'diamonds');
      expect(input.rewardUnitNameAr, 'Diamonds AR');
      expect(input.rewardUnitNameFr, 'Diamonds FR');
      expect(input.isValid, isTrue);
    });

    test('accepts a backend-compatible slug', () {
      expect(_validInput(slug: 'game-2').isValid, isTrue);
    });

    test('rejects an empty slug', () {
      expect(
        _validInput(slug: ' ').validate(),
        contains(
          _issue(
            PlatformValidationField.slug,
            PlatformValidationCode.required,
          ),
        ),
      );
    });

    test('rejects uppercase slug characters', () {
      expect(
        _validInput(slug: 'Free-fire').validate(),
        contains(
          _issue(
            PlatformValidationField.slug,
            PlatformValidationCode.mustBeLowercase,
          ),
        ),
      );
    });

    test('rejects internal spaces and unsupported characters', () {
      expect(
        _validInput(slug: 'free fire').validate(),
        contains(
          _issue(
            PlatformValidationField.slug,
            PlatformValidationCode.invalidFormat,
          ),
        ),
      );
      expect(
        _validInput(slug: 'free.fire').validate(),
        contains(
          _issue(
            PlatformValidationField.slug,
            PlatformValidationCode.invalidFormat,
          ),
        ),
      );
    });

    test('rejects leading, trailing, and consecutive hyphens', () {
      for (final slug in <String>['-free', 'free-', 'free--fire']) {
        expect(
          _validInput(slug: slug).validate(),
          contains(
            _issue(
              PlatformValidationField.slug,
              PlatformValidationCode.invalidFormat,
            ),
          ),
        );
      }
    });

    test('enforces slug minimum and maximum lengths', () {
      expect(
        _validInput(slug: 'a').validate(),
        contains(
          _issue(PlatformValidationField.slug, PlatformValidationCode.tooShort),
        ),
      );
      expect(_validInput(slug: 'a'.padRight(64, 'a')).isValid, isTrue);
      expect(
        _validInput(slug: 'a'.padRight(65, 'a')).validate(),
        contains(
          _issue(PlatformValidationField.slug, PlatformValidationCode.tooLong),
        ),
      );
    });

    test('requires names and limits them to 120 characters', () {
      expect(
        _validInput(nameAr: ' ').validate(),
        contains(
          _issue(
            PlatformValidationField.nameAr,
            PlatformValidationCode.required,
          ),
        ),
      );
      expect(
        _validInput(nameFr: 'a'.padRight(121, 'a')).validate(),
        contains(
          _issue(
            PlatformValidationField.nameFr,
            PlatformValidationCode.tooLong,
          ),
        ),
      );
      expect(
        _validInput(rewardUnitNameAr: ' ').validate(),
        contains(
          _issue(
            PlatformValidationField.rewardUnitNameAr,
            PlatformValidationCode.required,
          ),
        ),
      );
      expect(
        _validInput(rewardUnitNameFr: 'a'.padRight(121, 'a')).validate(),
        contains(
          _issue(
            PlatformValidationField.rewardUnitNameFr,
            PlatformValidationCode.tooLong,
          ),
        ),
      );
    });

    test('validates reward unit code format and length', () {
      expect(_validInput(rewardUnitCode: 'uc_2').isValid, isTrue);
      expect(
        _validInput(rewardUnitCode: 'UCoins').validate(),
        contains(
          _issue(
            PlatformValidationField.rewardUnitCode,
            PlatformValidationCode.mustBeLowercase,
          ),
        ),
      );
      expect(
        _validInput(rewardUnitCode: 'u-coins').validate(),
        contains(
          _issue(
            PlatformValidationField.rewardUnitCode,
            PlatformValidationCode.invalidFormat,
          ),
        ),
      );
      expect(
        _validInput(rewardUnitCode: 'u').validate(),
        contains(
          _issue(
            PlatformValidationField.rewardUnitCode,
            PlatformValidationCode.tooShort,
          ),
        ),
      );
      expect(
        _validInput(rewardUnitCode: 'u'.padRight(33, 'u')).validate(),
        contains(
          _issue(
            PlatformValidationField.rewardUnitCode,
            PlatformValidationCode.tooLong,
          ),
        ),
      );
    });

    test('uses safe inactive and zero ordering defaults', () {
      final input = _validInput();

      expect(input.isActive, isFalse);
      expect(input.sortOrder, 0);
    });
  });
}

GameInput _validInput({
  String slug = 'free-fire',
  String nameAr = 'Free Fire AR',
  String nameFr = 'Free Fire FR',
  String rewardUnitCode = 'diamonds',
  String rewardUnitNameAr = 'Diamonds AR',
  String rewardUnitNameFr = 'Diamonds FR',
  bool isActive = false,
  int sortOrder = 0,
}) {
  return GameInput(
    slug: slug,
    nameAr: nameAr,
    nameFr: nameFr,
    rewardUnitCode: rewardUnitCode,
    rewardUnitNameAr: rewardUnitNameAr,
    rewardUnitNameFr: rewardUnitNameFr,
    isActive: isActive,
    sortOrder: sortOrder,
  );
}

PlatformValidationIssue _issue(
  PlatformValidationField field,
  PlatformValidationCode code,
) {
  return PlatformValidationIssue(field: field, code: code);
}
