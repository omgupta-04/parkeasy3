import 'package:flutter/cupertino.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotiService {
  final notificationPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initNotification() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    print(currentTimeZone);
    tz.setLocalLocation(tz.getLocation(currentTimeZone));
    const initAndroidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: initAndroidSettings,
    );

    await notificationPlugin.initialize(initSettings);
    _isInitialized = true;
  }

  NotificationDetails notificationDetails() {
    return const NotificationDetails(
        android: AndroidNotificationDetails(
            'daily_channel_id', 'Daily Notification',
            channelDescription: 'Daily Notification Channel',
            importance: Importance.max,
            priority: Priority.high));
  }

  Future<void> showNotification(
      {int id = 0, String? title, String? body}) async {
    notificationPlugin.show(id, title, body, notificationDetails());
  }

  Future<void> scheduleNotification({
    int id = 1,
    required String title,
    required String body,
    required int hour,
    required int min,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduleDate = tz.TZDateTime(tz.local,now.year,now.month,now.day,hour,min);
    print(scheduleDate);
    await notificationPlugin.zonedSchedule(id, title, body, scheduleDate, notificationDetails(), androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
    print('Scheduled Success');
  }

  void scheduleNotificationBefore20Min(TextEditingController hourController,TextEditingController minController){
    int inputHours = int.tryParse(hourController.text) ?? 0;
    int inputMinutes = int.tryParse(minController.text) ?? 0;
    if (inputMinutes >= 60) {
      return;
    }
    if (inputMinutes <20 &&inputHours==0) {
      return;
    }
    if(inputMinutes < 20 &&inputHours>0){
      inputHours--;inputMinutes+=60;
    }
    Duration fullDuration = Duration(hours: inputHours,minutes: inputMinutes);
    DateTime completeTime = DateTime.now().add(fullDuration);
    DateTime notificationTime = completeTime.subtract(const Duration(minutes: 20));
    NotiService().scheduleNotification(
      title: 'Scheduled Notification',
      body: 'Step 2 Done',
      hour: notificationTime.hour,
      min: notificationTime.minute,
    );
  }
}
