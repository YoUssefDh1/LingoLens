import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _morningId = 0;
  static const int _eveningId = 1;

  /// Initialize plugin and permissions
  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    await requestPermissions();
  }

  /// Request notification & exact alarm permissions
  static Future<void> requestPermissions() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  /// Schedule a single notification at a specific hour/minute
  static Future<void> _scheduleSingleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    print("_scheduleSingleDaily CALLED for id $id");

    final now = tz.TZDateTime.now(tz.local);

    // Schedule for today if time is still ahead, otherwise tomorrow
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));

    print("Now: $now");
    print("Scheduled time: $scheduled");

    const androidDetails = AndroidNotificationDetails(
      'daily_reminder',
      'Daily Reminder',
      channelDescription: 'Daily reminder to use LingoLens AI',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );

    final pending = await _plugin.pendingNotificationRequests();
    print("Pending notifications after scheduling id $id: ${pending.length}");
    for (var p in pending) {
      print("Pending id: ${p.id}, title: ${p.title}, body: ${p.body}");
    }
  }

  /// Show a single immediate notification (to activate channel)
  static Future<void> _showImmediateNotification({
    required String title,
    required String body,
  }) async {
    print("_showImmediateNotification CALLED");
    await _plugin.show(
      999,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily Reminder',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Schedule both morning & evening reminders + show immediate test notification
  static Future<void> scheduleDefaultReminders({
    required String title,
    required String body,
  }) async {
    print("scheduleDefaultReminders CALLED");

    // Cancel existing to prevent duplicates
    await _plugin.cancelAll();

    // 🔥 Show one immediate notification first
    await _showImmediateNotification(title: title, body: body);

    // Schedule morning & evening daily notifications
    await _scheduleSingleDaily(
      id: _morningId,
      hour: 10,
      minute: 0,
      title: title,
      body: body,
    );

    await _scheduleSingleDaily(
      id: _eveningId,
      hour: 21,
      minute: 0,
      title: title,
      body: body,
    );

    final pending = await _plugin.pendingNotificationRequests();
    print("Pending notifications: ${pending.length}");
    for (var p in pending) {
      print("Pending id: ${p.id}, title: ${p.title}, body: ${p.body}");
    }
  }

  /// Cancel all scheduled notifications
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Save notification enabled preference
  static Future<void> savePreferences({required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsOn', enabled);
  }

  /// Load notification enabled preference
  static Future<bool> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notificationsOn') ?? false;
  }
}