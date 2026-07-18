class OrderCursor {
  OrderCursor({required DateTime createdAt, required String id})
    : createdAt = createdAt.toUtc(),
      id = _requireId(id);

  final DateTime createdAt;
  final String id;

  @override
  String toString() {
    return 'OrderCursor(createdAt: ${createdAt.toIso8601String()})';
  }
}

String _requireId(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, 'id', 'Must not be empty.');
  }
  return normalized;
}
