import '../common/platform_validation.dart';
import 'order_enums.dart';

const Object _unsetOrderFilter = Object();
final RegExp _controlCharacterPattern = RegExp(r'[\x00-\x1F\x7F]');

class OrderFilters {
  OrderFilters({
    this.orderStatus,
    this.paymentStatus,
    this.paymentMethod,
    String? gameId,
    DateTime? dateFrom,
    DateTime? dateToExclusive,
    String? searchText,
  }) : gameId = _normalizeOptionalText(gameId),
       dateFrom = dateFrom?.toUtc(),
       dateToExclusive = dateToExclusive?.toUtc(),
       searchText = _normalizeOptionalText(searchText);

  static const int maxSearchLength = 100;

  final OrderStatus? orderStatus;
  final PaymentStatus? paymentStatus;
  final PaymentMethod? paymentMethod;
  final String? gameId;
  final DateTime? dateFrom;
  final DateTime? dateToExclusive;
  final String? searchText;

  bool get isEmpty =>
      orderStatus == null &&
      paymentStatus == null &&
      paymentMethod == null &&
      gameId == null &&
      dateFrom == null &&
      dateToExclusive == null &&
      searchText == null;

  List<PlatformValidationIssue> validate() {
    final issues = <PlatformValidationIssue>[];
    final normalizedSearchText = searchText;

    if (normalizedSearchText != null) {
      if (normalizedSearchText.length > maxSearchLength) {
        issues.add(
          const PlatformValidationIssue(
            field: PlatformValidationField.searchText,
            code: PlatformValidationCode.tooLong,
          ),
        );
      }
      if (_controlCharacterPattern.hasMatch(normalizedSearchText)) {
        issues.add(
          const PlatformValidationIssue(
            field: PlatformValidationField.searchText,
            code: PlatformValidationCode.containsControlCharacters,
          ),
        );
      }
    }

    final normalizedDateFrom = dateFrom;
    final normalizedDateToExclusive = dateToExclusive;
    if (normalizedDateFrom != null &&
        normalizedDateToExclusive != null &&
        !normalizedDateToExclusive.isAfter(normalizedDateFrom)) {
      issues.add(
        const PlatformValidationIssue(
          field: PlatformValidationField.dateRange,
          code: PlatformValidationCode.invalidRange,
        ),
      );
    }

    return List<PlatformValidationIssue>.unmodifiable(issues);
  }

  bool get isValid => validate().isEmpty;

  OrderFilters copyWith({
    Object? orderStatus = _unsetOrderFilter,
    Object? paymentStatus = _unsetOrderFilter,
    Object? paymentMethod = _unsetOrderFilter,
    Object? gameId = _unsetOrderFilter,
    Object? dateFrom = _unsetOrderFilter,
    Object? dateToExclusive = _unsetOrderFilter,
    Object? searchText = _unsetOrderFilter,
  }) {
    return OrderFilters(
      orderStatus: identical(orderStatus, _unsetOrderFilter)
          ? this.orderStatus
          : orderStatus as OrderStatus?,
      paymentStatus: identical(paymentStatus, _unsetOrderFilter)
          ? this.paymentStatus
          : paymentStatus as PaymentStatus?,
      paymentMethod: identical(paymentMethod, _unsetOrderFilter)
          ? this.paymentMethod
          : paymentMethod as PaymentMethod?,
      gameId: identical(gameId, _unsetOrderFilter)
          ? this.gameId
          : gameId as String?,
      dateFrom: identical(dateFrom, _unsetOrderFilter)
          ? this.dateFrom
          : dateFrom as DateTime?,
      dateToExclusive: identical(dateToExclusive, _unsetOrderFilter)
          ? this.dateToExclusive
          : dateToExclusive as DateTime?,
      searchText: identical(searchText, _unsetOrderFilter)
          ? this.searchText
          : searchText as String?,
    );
  }
}

String? _normalizeOptionalText(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
