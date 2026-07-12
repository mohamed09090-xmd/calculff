List<int> appendPatternNode(List<int> current, int next) {
  if (next < 0 || next > 8 || current.contains(next)) {
    return List<int>.unmodifiable(current);
  }

  final result = List<int>.from(current);
  if (result.isNotEmpty) {
    final middle = patternMiddleNode(result.last, next);
    if (middle != null && !result.contains(middle)) {
      result.add(middle);
    }
  }
  result.add(next);
  return List<int>.unmodifiable(result);
}

int? patternMiddleNode(int first, int second) {
  if (first < 0 || first > 8 || second < 0 || second > 8) return null;
  final firstRow = first ~/ 3;
  final firstColumn = first % 3;
  final secondRow = second ~/ 3;
  final secondColumn = second % 3;
  final rowDistance = (firstRow - secondRow).abs();
  final columnDistance = (firstColumn - secondColumn).abs();

  final crossesMiddle = rowDistance == 2 || columnDistance == 2;
  final integerMiddle =
      (firstRow + secondRow).isEven && (firstColumn + secondColumn).isEven;
  if (!crossesMiddle || !integerMiddle) return null;

  final middleRow = (firstRow + secondRow) ~/ 2;
  final middleColumn = (firstColumn + secondColumn) ~/ 2;
  return (middleRow * 3) + middleColumn;
}
