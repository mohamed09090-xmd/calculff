import '../common/platform_validation.dart';

final RegExp _slugPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
final RegExp _rewardUnitCodePattern = RegExp(r'^[a-z0-9_]+$');

class GameInput {
  GameInput({
    required String slug,
    required String nameAr,
    required String nameFr,
    required String rewardUnitCode,
    required String rewardUnitNameAr,
    required String rewardUnitNameFr,
    this.isActive = false,
    this.sortOrder = 0,
  }) : slug = slug.trim(),
       nameAr = nameAr.trim(),
       nameFr = nameFr.trim(),
       rewardUnitCode = rewardUnitCode.trim(),
       rewardUnitNameAr = rewardUnitNameAr.trim(),
       rewardUnitNameFr = rewardUnitNameFr.trim();

  final String slug;
  final String nameAr;
  final String nameFr;
  final String rewardUnitCode;
  final String rewardUnitNameAr;
  final String rewardUnitNameFr;
  final bool isActive;
  final int sortOrder;

  List<PlatformValidationIssue> validate() {
    final issues = <PlatformValidationIssue>[];

    _validateSlug(issues);
    _validateRequiredName(
      value: nameAr,
      field: PlatformValidationField.nameAr,
      issues: issues,
    );
    _validateRequiredName(
      value: nameFr,
      field: PlatformValidationField.nameFr,
      issues: issues,
    );
    _validateRewardUnitCode(issues);
    _validateRequiredName(
      value: rewardUnitNameAr,
      field: PlatformValidationField.rewardUnitNameAr,
      issues: issues,
    );
    _validateRequiredName(
      value: rewardUnitNameFr,
      field: PlatformValidationField.rewardUnitNameFr,
      issues: issues,
    );

    return List<PlatformValidationIssue>.unmodifiable(issues);
  }

  bool get isValid => validate().isEmpty;

  void _validateSlug(List<PlatformValidationIssue> issues) {
    if (slug.isEmpty) {
      issues.add(
        const PlatformValidationIssue(
          field: PlatformValidationField.slug,
          code: PlatformValidationCode.required,
        ),
      );
      return;
    }
    if (slug.length < 2) {
      issues.add(
        const PlatformValidationIssue(
          field: PlatformValidationField.slug,
          code: PlatformValidationCode.tooShort,
        ),
      );
      return;
    }
    if (slug.length > 64) {
      issues.add(
        const PlatformValidationIssue(
          field: PlatformValidationField.slug,
          code: PlatformValidationCode.tooLong,
        ),
      );
      return;
    }
    if (slug != slug.toLowerCase()) {
      issues.add(
        const PlatformValidationIssue(
          field: PlatformValidationField.slug,
          code: PlatformValidationCode.mustBeLowercase,
        ),
      );
      return;
    }
    if (!_slugPattern.hasMatch(slug)) {
      issues.add(
        const PlatformValidationIssue(
          field: PlatformValidationField.slug,
          code: PlatformValidationCode.invalidFormat,
        ),
      );
    }
  }

  void _validateRewardUnitCode(List<PlatformValidationIssue> issues) {
    if (rewardUnitCode.isEmpty) {
      issues.add(
        const PlatformValidationIssue(
          field: PlatformValidationField.rewardUnitCode,
          code: PlatformValidationCode.required,
        ),
      );
      return;
    }
    if (rewardUnitCode.length < 2) {
      issues.add(
        const PlatformValidationIssue(
          field: PlatformValidationField.rewardUnitCode,
          code: PlatformValidationCode.tooShort,
        ),
      );
      return;
    }
    if (rewardUnitCode.length > 32) {
      issues.add(
        const PlatformValidationIssue(
          field: PlatformValidationField.rewardUnitCode,
          code: PlatformValidationCode.tooLong,
        ),
      );
      return;
    }
    if (rewardUnitCode != rewardUnitCode.toLowerCase()) {
      issues.add(
        const PlatformValidationIssue(
          field: PlatformValidationField.rewardUnitCode,
          code: PlatformValidationCode.mustBeLowercase,
        ),
      );
      return;
    }
    if (!_rewardUnitCodePattern.hasMatch(rewardUnitCode)) {
      issues.add(
        const PlatformValidationIssue(
          field: PlatformValidationField.rewardUnitCode,
          code: PlatformValidationCode.invalidFormat,
        ),
      );
    }
  }
}

void _validateRequiredName({
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
