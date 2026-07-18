enum PlatformValidationField {
  slug,
  nameAr,
  nameFr,
  rewardUnitCode,
  rewardUnitNameAr,
  rewardUnitNameFr,
  gameId,
  rewardQuantity,
  salePriceDzd,
  selectedGameIsActive,
  searchText,
  dateRange,
}

enum PlatformValidationCode {
  required,
  tooShort,
  tooLong,
  mustBeLowercase,
  invalidFormat,
  mustBePositive,
  inactiveGame,
  containsControlCharacters,
  invalidRange,
}

class PlatformValidationIssue {
  const PlatformValidationIssue({required this.field, required this.code});

  final PlatformValidationField field;
  final PlatformValidationCode code;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlatformValidationIssue &&
            other.field == field &&
            other.code == code;
  }

  @override
  int get hashCode => Object.hash(field, code);

  @override
  String toString() {
    return 'PlatformValidationIssue(field: ${field.name}, code: ${code.name})';
  }
}
