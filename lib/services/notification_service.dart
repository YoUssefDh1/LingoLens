import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _morningId = 0;
  static const int _eveningId = 1;

  /// Initialize plugin and permissions
  static Future<void> initialize() async {
    tz.initializeTimeZones();

    // Set correct local timezone
    final String localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone));

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
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    print('Scheduling id=$id at $scheduled (now=$now)');

    const androidDetails = AndroidNotificationDetails(
      'daily_reminder',
      'Daily Reminder',
      channelDescription: 'Daily reminder to use LingoLens AI',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Show an immediate notification (useful for testing)
  static Future<void> _showImmediateNotification({
    required String title,
    required String body,
  }) async {
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

  /// Schedule both morning & evening reminders
  static Future<void> scheduleDefaultReminders({
    required String title,
    required String body,
  }) async {
    await _plugin.cancelAll();

    // Show immediate notification to confirm it works
    await _showImmediateNotification(title: title, body: body);

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
    print('Pending after scheduling: ${pending.length}');
    for (var p in pending) {
      print('  id=${p.id} title=${p.title}');
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