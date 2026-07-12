import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@drawable/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleExpiryWarning({
    required int notificationId,
    required String lotName,
    required DateTime expiresAt,
    required Duration warningBefore,
  }) async {
    final scheduled = expiresAt.subtract(warningBefore);
    if (!scheduled.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      notificationId,
      'رصيد يقترب من الانتهاء',
      '$lotName سينتهي قريبًا. راجع المخزون.',
      tz.TZDateTime.from(scheduled, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'credit_expiry',
          'تنبيهات انتهاء الرصيد',
          channelDescription: 'تنبيهات رزم الرصيد قبل انتهاء صلاحيتها',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();
}
