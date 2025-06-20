import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/medication_reminder.dart';
import 'dart:io' show Platform;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:typed_data';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final bool _debug = true;

  // Fixed mapping of timezone names
  static const Map<String, String> _timezoneMapping = {
    'Asia/Calcutta': 'Asia/Kolkata',
    // Add more mappings if needed
  };

  String _mapTimezoneName(String timezoneName) {
    return _timezoneMapping[timezoneName] ?? timezoneName;
  }

  void _log(String message) {
    if (_debug) {
      debugPrint('NotificationService: $message');
    }
  }

  Future<void> testImmediateNotification() async {
    try {
      if (!_initialized) {
        await initializeNotifications();
      }

      _log('Testing immediate notification...');

      await flutterLocalNotificationsPlugin.show(
        0,
        'Test Notification',
        'This is a test notification',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication Reminders',
            channelDescription: 'Notifications for medication reminders',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
          ),
        ),
      );
      _log('Test notification sent successfully');
    } catch (e) {
      _log('Error sending test notification: $e');
      rethrow;
    }
  }

  Future<void> initializeNotifications() async {
    if (_initialized) {
      _log('Notifications already initialized');
      return;
    }

    try {
      _log('Starting notification initialization...');

      // Clean up existing notifications
      await flutterLocalNotificationsPlugin.cancelAll();

      // Initialize timezone data
      tz.initializeTimeZones();

      // Get and set device timezone
      try {
        final String timeZoneName = _mapTimezoneName(await FlutterTimezone.getLocalTimezone());
        _log('Device timezone (mapped): $timeZoneName');
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (e) {
        _log('Error setting timezone: $e');
        _log('Falling back to UTC timezone');
        tz.setLocalLocation(tz.UTC);
      }

      // Platform-specific initialization settings
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iOSSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final InitializationSettings initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: iOSSettings,
      );

      // Initialize plugin
      final bool? initResult = await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initResult != true) {
        throw Exception('Notification initialization failed');
      }

      _log('Notification initialization result: $initResult');

      // Create notification channel for Android
      if (Platform.isAndroid) {
        await _createNotificationChannel();
        await _requestAndroidNotificationPermission();
      }

      _initialized = true;
      _log('Notifications initialized successfully');

      // Verify pending notifications
      final pending = await getPendingNotifications();
      _log('Initial pending notifications count: ${pending.length}');

    } catch (e) {
      _log('Error initializing notifications: $e');
      _initialized = false;
      rethrow;
    }
  }

  Future<void> _createNotificationChannel() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'medication_reminders',
        'Medication Reminders',
        description: 'Notifications for medication reminders',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification'),
        showBadge: true,
        enableLights: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      _log('Android notification channel created');
    } catch (e) {
      _log('Error creating notification channel: $e');
      rethrow;
    }
  }

  void _onNotificationTapped(NotificationResponse details) {
    _log('Notification tapped: ${details.payload}');
    // Add navigation logic here if needed
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
      _log('Time already passed today, scheduling for tomorrow');
    }

    // Add a small buffer for scheduling
    if (scheduledDate.difference(now) < const Duration(minutes: 1)) {
      scheduledDate = scheduledDate.add(const Duration(minutes: 1));
      _log('Added buffer time to ensure notification triggers');
    }

    return scheduledDate;
  }

  Future<bool> _requestAndroidNotificationPermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin == null) {
        _log('Android plugin not available');
        return false;
      }

      final bool? granted = await androidPlugin.requestNotificationsPermission();
      _log('Android notification permission ${granted == true ? 'granted' : 'denied'}');
      return granted ?? false;
    } catch (e) {
      _log('Error requesting Android notification permission: $e');
      return false;
    }
  }

  Future<bool> _verifyNotificationPermissions() async {
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        final bool? permissionGranted = await androidPlugin?.areNotificationsEnabled();

        if (permissionGranted != true) {
          return await _requestAndroidNotificationPermission();
        }
        return permissionGranted ?? false;
      }
      return true; // iOS permissions are handled during initialization
    } catch (e) {
      _log('Error verifying notification permissions: $e');
      return false;
    }
  }

  Future<bool> _verifyNotificationScheduled(int notificationId) async {
    try {
      final List<PendingNotificationRequest> pendingNotifications =
      await flutterLocalNotificationsPlugin.pendingNotificationRequests();

      final bool isScheduled = pendingNotifications.any((n) => n.id == notificationId);

      _log('''
      Notification verification:
      - Total pending notifications: ${pendingNotifications.length}
      - Is notification $notificationId scheduled? $isScheduled
      ''');

      return isScheduled;
    } catch (e) {
      _log('Error verifying notification schedule: $e');
      return false;
    }
  }

  Future<void> scheduleMedicationReminder(MedicationReminder medication) async {
    try {
      if (!_initialized) {
        await initializeNotifications();
      }

      // Validate input
      if (medication.name.isEmpty || medication.dosage.isEmpty) {
        throw ArgumentError('Medication name and dosage cannot be empty');
      }

      final bool permissionGranted = await _verifyNotificationPermissions();
      if (!permissionGranted) {
        throw Exception('Notification permissions not granted');
      }

      final int notificationId = medication.name.hashCode;
      final tz.TZDateTime scheduledDate = _nextInstanceOfTime(medication.time);

      // Cancel existing notification
      await flutterLocalNotificationsPlugin.cancel(notificationId);

      bool? canScheduleExactAlarms;
      if (Platform.isAndroid) {
        final androidPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        try {
          canScheduleExactAlarms = await androidPlugin?.requestExactAlarmsPermission();
        } catch (e) {
          _log('Error checking exact alarms permission: $e');
        }
      }

      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        'Medication Reminder',
        'Time to take ${medication.dosage} of ${medication.name}',
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication Reminders',
            channelDescription: 'Notifications for medication reminders',
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            showWhen: true,
            icon: '@mipmap/ic_launcher',
            visibility: NotificationVisibility.public,
            autoCancel: true,
            ongoing: false,
            sound: RawResourceAndroidNotificationSound('notification'),
            playSound: true,
            channelShowBadge: true,
            additionalFlags: Int32List.fromList(<int>[4]),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
            threadIdentifier: 'medication_reminders',
          ),
        ),
        androidScheduleMode: canScheduleExactAlarms == true
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: medication.name,
      );

      final bool scheduled = await _verifyNotificationScheduled(notificationId);
      if (!scheduled) {
        throw Exception('Failed to schedule notification');
      }

      _log('Notification scheduled successfully for ${medication.name}');
    } catch (e) {
      _log('Error scheduling medication reminder: $e');
      rethrow;
    }
  }

  Future<void> cancelMedicationReminder(String medicationName) async {
    try {
      final int notificationId = medicationName.hashCode;
      await flutterLocalNotificationsPlugin.cancel(notificationId);
      _log('Cancelled notification for: $medicationName (ID: $notificationId)');
    } catch (e) {
      _log('Error cancelling medication reminder: $e');
      rethrow;
    }
  }

  Future<void> cancelAllReminders() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      _log('Cancelled all notifications');
    } catch (e) {
      _log('Error cancelling all reminders: $e');
      rethrow;
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      final List<PendingNotificationRequest> pendingNotifications =
      await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      _log('Pending notifications: ${pendingNotifications.length}');
      return pendingNotifications;
    } catch (e) {
      _log('Error getting pending notifications: $e');
      return [];
    }
  }
}