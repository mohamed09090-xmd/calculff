class CursorPage<T> {
  CursorPage({
    required Iterable<T> items,
    required this.nextCursor,
    required this.hasMore,
  }) : items = List<T>.unmodifiable(items);

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
}
