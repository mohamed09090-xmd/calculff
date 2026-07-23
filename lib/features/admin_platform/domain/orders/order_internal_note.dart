class OrderInternalNote {
  OrderInternalNote({required this.text, required DateTime createdAt})
    : createdAt = createdAt.toUtc();

  final String text;
  final DateTime createdAt;

  @override
  String toString() => 'OrderInternalNote(createdAt: $createdAt)';
}
