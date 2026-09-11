import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service managing local and scheduled push notifications
class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String billChannelId = 'evim_bills_channel';
  static const String govChannelId = 'evim_gov_channel';

  /// Initializes timezone and local notification channels
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Initialization fallback (Web/Unsupported): $e');
      _isInitialized = true;
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[NotificationService] Notification tapped: ${response.payload}');
  }

  /// Requests notification permissions for Android 13+ and iOS
  Future<bool> requestPermissions() async {
    try {
      if (kIsWeb) return true;

      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }

      final iosPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      return true;
    } catch (e) {
      debugPrint('[NotificationService] Request permission error: $e');
      return false;
    }
  }

  /// Converts a string id into a stable 31-bit integer for notification ids
  int _hashId(String id) => id.hashCode.abs() & 0x7FFFFFFF;

  /// Shows an instant local notification
  Future<void> showInstantNotification({
    required String id,
    required String title,
    required String body,
    String? payload,
    String channelId = billChannelId,
  }) async {
    try {
      await initialize();
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == billChannelId ? 'تنبيهات الفواتير' : 'تنبيهات المعاملات',
        channelDescription: 'إشعارات تطبيق Evim الذكية',
        importance: Importance.high,
        priority: Priority.high,
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _localNotifications.show(
        id: _hashId(id),
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NotificationService] Show instant error: $e');
    }
  }

  /// Schedules reminders for an upcoming bill or rent:
  /// - 3 days before due_date
  /// - On the exact due date
  Future<void> scheduleBillReminder({
    required String billId,
    required String title,
    required DateTime dueDate,
    int reminderDaysBefore = 3,
  }) async {
    try {
      await initialize();
      const androidDetails = AndroidNotificationDetails(
        billChannelId,
        'تنبيهات الفواتير والمصاريف',
        channelDescription: 'تذكيرات بمواعيد سداد الفواتير الشهرية',
        importance: Importance.high,
        priority: Priority.high,
      );
      const darwinDetails = DarwinNotificationDetails();
      const details = NotificationDetails(android: androidDetails, iOS: darwinDetails);

      // 1. Advance reminder (e.g. 3 days before)
      final earlyReminder = dueDate.subtract(Duration(days: reminderDaysBefore));
      if (earlyReminder.isAfter(DateTime.now())) {
        final scheduledEarly = tz.TZDateTime.from(earlyReminder, tz.local);
        await _localNotifications.zonedSchedule(
          id: _hashId('$billId-early'),
          title: 'تذكير بموعد فاتورة 💡',
          body: 'فاتورة "$title" تستحق السداد بعد $reminderDaysBefore أيام في ${dueDate.year}/${dueDate.month}/${dueDate.day}.',
          scheduledDate: scheduledEarly,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'bill:$billId',
        );
      }

      // 2. Exact due date reminder
      if (dueDate.isAfter(DateTime.now())) {
        final scheduledDue = tz.TZDateTime.from(dueDate, tz.local);
        await _localNotifications.zonedSchedule(
          id: _hashId('$billId-due'),
          title: 'فاتورة تستحق السداد اليوم ⚡',
          body: 'اليوم هو الموعد النهائي لسداد فاتورة "$title". تجنب انقطاع الخدمة أو الغرامات.',
          scheduledDate: scheduledDue,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'bill:$billId',
        );
      }
    } catch (e) {
      debugPrint('[NotificationService] Schedule bill error: $e');
    }
  }

  /// Schedules reminders for residency / official procedures:
  /// - 60 days before expiry_date
  /// - 30 days before expiry_date
  Future<void> scheduleResidencyReminder({
    required String permitId,
    required DateTime expiryDate,
    int reminderDaysBefore = 30,
  }) async {
    try {
      await initialize();
      const androidDetails = AndroidNotificationDetails(
        govChannelId,
        'تنبيهات المواعيد والمعاملات الرسمية',
        channelDescription: 'تذكيرات بمواعيد الإقامة والنفوس وفحص السيارات',
        importance: Importance.max,
        priority: Priority.max,
      );
      const darwinDetails = DarwinNotificationDetails();
      const details = NotificationDetails(android: androidDetails, iOS: darwinDetails);

      // 1. 60 days before reminder
      final early60 = expiryDate.subtract(const Duration(days: 60));
      if (early60.isAfter(DateTime.now())) {
        final scheduled60 = tz.TZDateTime.from(early60, tz.local);
        await _localNotifications.zonedSchedule(
          id: _hashId('$permitId-60d'),
          title: 'تنبيه مبكر: تجديد الإقامة (60 يوماً) ⏳',
          body: 'تبقى شهران على موعد انتهاء الإقامة. يوصى بتجهيز الأوراق وحجز موعد عبر نظام e-İkamet.',
          scheduledDate: scheduled60,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'gov:$permitId',
        );
      }

      // 2. 30 days before reminder
      final early30 = expiryDate.subtract(Duration(days: reminderDaysBefore));
      if (early30.isAfter(DateTime.now())) {
        final scheduled30 = tz.TZDateTime.from(early30, tz.local);
        await _localNotifications.zonedSchedule(
          id: _hashId('$permitId-30d'),
          title: 'تنبيه رسمي هام: تجديد الإقامة ⚠️',
          body: 'تبقى $reminderDaysBefore يوماً على موعد انتهاء تصريح الإقامة الخاص بك. ابدأ إجراءات التجديد الآن.',
          scheduledDate: scheduled30,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'gov:$permitId',
        );
      }
    } catch (e) {
      debugPrint('[NotificationService] Schedule residency error: $e');
    }
  }

  /// Cancels an existing scheduled notification and its composite IDs
  Future<void> cancelReminder(String id) async {
    try {
      await _localNotifications.cancel(id: _hashId(id));
      await _localNotifications.cancel(id: _hashId('$id-early'));
      await _localNotifications.cancel(id: _hashId('$id-due'));
      await _localNotifications.cancel(id: _hashId('$id-60d'));
      await _localNotifications.cancel(id: _hashId('$id-30d'));
    } catch (e) {
      debugPrint('[NotificationService] Cancel reminder error: $e');
    }
  }

  /// Cancels scheduled reminders when a bill is marked as paid or deleted
  Future<void> cancelBillReminders(String billId) async {
    await cancelReminder(billId);
  }

  /// Cancels all bill channel notifications
  Future<void> cancelAllBillReminders() async {
    try {
      await cancelAll();
    } catch (e) {
      debugPrint('[NotificationService] Cancel all bills error: $e');
    }
  }

  /// Cancels all residency channel notifications
  Future<void> cancelAllResidencyReminders() async {
    try {
      await cancelAll();
    } catch (e) {
      debugPrint('[NotificationService] Cancel all residency error: $e');
    }
  }

  /// Cancels all scheduled notifications
  Future<void> cancelAll() async {
    try {
      await _localNotifications.cancelAll();
    } catch (e) {
      debugPrint('[NotificationService] Cancel all error: $e');
    }
  }
}

/// Provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  service.initialize();
  return service;
});
