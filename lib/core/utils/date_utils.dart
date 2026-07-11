class AppDateUtils {
  const AppDateUtils._();

  static String format(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)} – ${two(local.hour)}:${two(local.minute)}';
  }

  static String remaining(DateTime expiresAt, {DateTime? now}) {
    final difference = expiresAt.difference(now ?? DateTime.now());
    if (difference.isNegative) return 'منتهي';
    if (difference.inDays >= 1) return '${difference.inDays} يوم';
    if (difference.inHours >= 1) return '${difference.inHours} ساعة';
    return '${difference.inMinutes.clamp(0, 59)} دقيقة';
  }
}
