import '../common/platform_validation.dart';

class PublicOfferInput {
  PublicOfferInput({
    required String gameId,
    required String nameAr,
    required String nameFr,
    required this.rewardQuantity,
    required this.salePriceDzd,
    this.isPublished = false,
    this.sortOrder = 0,
  }) : gameId = gameId.trim(),
       nameAr = nameAr.trim(),
       nameFr = nameFr.trim();

  final String gameId;
  final String nameAr;
  final String nameFr;
  final int rewardQuantity;
  final int salePriceDzd;
  final bool isPublished;
  final int sortOrder;

  List<PlatformValidationIssue> validate({required bool selectedGameIsActive}) {
    final issues = <PlatformValidationIssue>[];

    if (gameId.isEmpty) {
      issues.add(
        const PlatformValidationIssue(
          field: PlatformValidationField.gameId,
          code: PlatformValidationCode.required,
        ),
      );
    }
    _validateOfferName(
      value: nameAr,
      field: PlatformValidationField.nameAr,
      issues: issues,
    );
    _validateOfferName(
      value: nameFr,
      field: PlatformValidationField.nameFr,
      issues: issues,
    );
    if (rewardQuantity <= 0) {
      issues.add(
        const PlatformValidationIssue(
          field: PlatformValidationField.rewardQuantity,
          code: PlatformValidationCode.mustBePositive,
        ),
      );
    }
    if (salePriceDzd <= 0) {
      issues.add(
        const PlatformValidationIssue(
          field: PlatformValidationField.salePriceDzd,
          code: PlatformValidationCode.mustBePositive,
        ),
      );
    }
    final publicationIssue = PublicOfferPublicationPolicy.validate(
      isPublished: isPublished,
      selectedGameIsActive: selectedGameIsActive,
    );
    if (publicationIssue != null) {
      issues.add(publicationIssue);
    }

    return List<PlatformValidationIssue>.unmodifiable(issues);
  }

  bool isValid({required bool selectedGameIsActive}) {
    return validate(selectedGameIsActive: selectedGameIsActive).isEmpty;
  }
}

abstract final class PublicOfferPublicationPolicy {
  static PlatformValidationIssue? validate({
    required bool isPublished,
    required bool selectedGameIsActive,
  }) {
    if (isPublished && !selectedGameIsActive) {
      return const PlatformValidationIssue(
        field: PlatformValidationField.selectedGameIsActive,
        code: PlatformValidationCode.inactiveGame,
      );
    }
    return null;
  }
}

void _validateOfferName({
  required String value,
  required PlatformValidationField field,
  required List<PlatformValidationIssue> issues,
}) {
  if (value.isEmpty) {
    issues.add(
      PlatformValidationIssue(
        field: field,
        code: PlatformValidationCode.required,
      ),
    );
  } else if (value.length > 120) {
    issues.add(
      PlatformValidationIssue(
        field: field,
        code: PlatformValidationCode.tooLong,
      ),
    );
  }
}
