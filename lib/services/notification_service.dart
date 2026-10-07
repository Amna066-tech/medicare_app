import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../main.dart'; // To access the background/foreground handlers

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();
    try {
      final TimezoneInfo timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (e) {
      debugPrint('Could not get local timezone: $e');
      // Fallback to UTC so the app doesn't crash when scheduling notifications
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  Future<void> requestPermission() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleReminderNotification({
    required int id,
    required String itemTitle,
    required String category,
    String? subtitle,
    String? medicationId, // Optional because measurements don't have it
    required DateTime scheduledTime,
    bool repeatDaily = true,
  }) async {
    // Lazy initialization for Hot Reloads or if init() was missed
    try {
      tz.local;
    } catch (_) {
      debugPrint("tz.local not initialized, initializing now...");
      tz.initializeTimeZones();
      try {
        final TimezoneInfo timeZoneInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
      } catch (e) {
        debugPrint('Could not get local timezone: $e');
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    }

    final payload = jsonEncode({
      'itemTitle': itemTitle,
      'category': category,
      'subtitle': subtitle,
      'medicationId': medicationId,
    });

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: 'Time for $category!',
      body: subtitle != null && subtitle.isNotEmpty ? '$itemTitle ($subtitle)' : itemTitle,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'medicare_reminders_channel_1',
          'Health Reminders',
          channelDescription: 'Gentle reminders for health tracking',
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            const AndroidNotificationAction(
              'action_done',
              'Done',
              showsUserInterface: false, // Handle in background
            ),
            const AndroidNotificationAction(
              'action_dismiss',
              'Dismiss',
              showsUserInterface: false, // Handle in background (just dismiss)
            ),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
    );
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicare_alerts_channel',
          'Health Alerts',
          channelDescription: 'Important alerts for low stock and missed meds',
          importance: Importance.max,
          priority: Priority.max,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }
}