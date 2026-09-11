import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evim/core/services/notification_service.dart';
import 'package:evim/features/notifications/domain/models/notification_model.dart';
import 'package:evim/features/notifications/data/notification_repository.dart';

class FakeNotificationRepository implements NotificationRepository {
  final List<NotificationModel> _notifications = [];

  FakeNotificationRepository([List<NotificationModel>? initial]) {
    if (initial != null) {
      _notifications.addAll(initial);
    }
  }

  @override
  Stream<List<NotificationModel>> streamNotifications(String householdId) {
    return Stream.value(
      _notifications.where((n) => n.householdId == householdId).toList(),
    );
  }

  @override
  Future<List<NotificationModel>> getNotifications(String householdId) async {
    return _notifications.where((n) => n.householdId == householdId).toList();
  }

  @override
  Future<NotificationModel> createNotification({
    required String householdId,
    required String title,
    required String body,
    NotificationType type = NotificationType.general,
    String? relatedId,
  }) async {
    final newNotif = NotificationModel(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      userId: 'user-1',
      householdId: householdId,
      title: title,
      body: body,
      type: type,
      relatedId: relatedId,
      isRead: false,
      createdAt: DateTime.now(),
    );
    _notifications.add(newNotif);
    return newNotif;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
    }
  }

  @override
  Future<void> markAllAsRead(String householdId) async {
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].householdId == householdId) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
  }

  @override
  Future<void> clearAllNotifications(String householdId) async {
    _notifications.removeWhere((n) => n.householdId == householdId);
  }
}

void main() {
  group('NotificationModel & NotificationType Tests', () {
    test('NotificationType parsing from various string representations', () {
      expect(NotificationType.fromString('bill'), NotificationType.bill);
      expect(NotificationType.fromString('expense'), NotificationType.bill);
      expect(NotificationType.fromString('guide'), NotificationType.ikametExpiry);
      expect(NotificationType.fromString('gov'), NotificationType.ikametExpiry);
      expect(NotificationType.fromString('member_joined'), NotificationType.memberJoined);
      expect(NotificationType.fromString('join_request'), NotificationType.joinRequest);
      expect(NotificationType.fromString('join_accepted'), NotificationType.joinAccepted);
      expect(NotificationType.fromString('join_rejected'), NotificationType.joinRejected);
      expect(NotificationType.fromString('other'), NotificationType.general);
    });

    test('NotificationModel serialization fromJson and toMap/toJson with requestId', () {
      final now = DateTime.now();
      final model = NotificationModel(
        id: 'n-123',
        userId: 'u-1',
        householdId: 'h-1',
        title: 'طلب انضمام جديد',
        body: 'طلب خالد الانضمام لمنزلك',
        type: NotificationType.joinRequest,
        relatedId: 'user-2',
        requestId: 'req-999',
        isRead: false,
        createdAt: now,
      );

      final map = model.toMap();
      expect(map['id'], 'n-123');
      expect(map['type'], 'join_request');
      expect(map['request_id'], 'req-999');
      expect(map['is_read'], false);

      final jsonMap = model.toJson();
      expect(jsonMap['id'], 'n-123');
      expect(jsonMap['title'], 'طلب انضمام جديد');
      expect(jsonMap['request_id'], 'req-999');

      final parsed = NotificationModel.fromJson(map);
      expect(parsed.id, model.id);
      expect(parsed.title, model.title);
      expect(parsed.type, NotificationType.joinRequest);
      expect(parsed.requestId, 'req-999');
      expect(parsed.isRead, isFalse);
    });

    test('NotificationModel copyWith updates isRead and requestId cleanly', () {
      final model = NotificationModel(
        id: 'n-1',
        userId: 'u-1',
        householdId: 'h-1',
        title: 'تنبيه إقامة',
        body: 'تبقى 30 يوماً',
        type: NotificationType.ikametExpiry,
        createdAt: DateTime.now(),
      );

      final updated = model.copyWith(isRead: true, requestId: 'req-new');
      expect(updated.isRead, isTrue);
      expect(updated.requestId, 'req-new');
      expect(updated.id, model.id);
      expect(updated.title, model.title);
    });
  });

  group('NotificationRepository & Stream Tests', () {
    test('createNotification adds alert to household and increments total', () async {
      final repo = FakeNotificationRepository();
      final created = await repo.createNotification(
        householdId: 'h-100',
        title: 'فاتورة الغاز',
        body: 'تستحق السداد',
        type: NotificationType.bill,
      );

      expect(created.householdId, 'h-100');
      expect(created.isRead, isFalse);

      final list = await repo.getNotifications('h-100');
      expect(list.length, 1);
      expect(list.first.title, 'فاتورة الغاز');
    });

    test('markAsRead updates read state of specific notification', () async {
      final item = NotificationModel(
        id: 'n-10',
        userId: 'u-1',
        householdId: 'h-100',
        title: 'ملاحظة',
        body: 'نص التنبيه',
        isRead: false,
        createdAt: DateTime.now(),
      );
      final repo = FakeNotificationRepository([item]);

      await repo.markAsRead('n-10');
      final list = await repo.getNotifications('h-100');
      expect(list.first.isRead, isTrue);
    });

    test('markAllAsRead marks all notifications in household as read', () async {
      final item1 = NotificationModel(
        id: 'n-1',
        userId: 'u-1',
        householdId: 'h-100',
        title: '1',
        body: '1',
        isRead: false,
        createdAt: DateTime.now(),
      );
      final item2 = NotificationModel(
        id: 'n-2',
        userId: 'u-1',
        householdId: 'h-100',
        title: '2',
        body: '2',
        isRead: false,
        createdAt: DateTime.now(),
      );
      final repo = FakeNotificationRepository([item1, item2]);

      await repo.markAllAsRead('h-100');
      final list = await repo.getNotifications('h-100');
      expect(list.every((n) => n.isRead), isTrue);
    });

    test('deleteNotification removes single notification', () async {
      final item1 = NotificationModel(
        id: 'n-1',
        userId: 'u-1',
        householdId: 'h-100',
        title: '1',
        body: '1',
        isRead: false,
        createdAt: DateTime.now(),
      );
      final item2 = NotificationModel(
        id: 'n-2',
        userId: 'u-1',
        householdId: 'h-100',
        title: '2',
        body: '2',
        isRead: false,
        createdAt: DateTime.now(),
      );
      final repo = FakeNotificationRepository([item1, item2]);

      await repo.deleteNotification('n-1');
      final list = await repo.getNotifications('h-100');
      expect(list.length, 1);
      expect(list.first.id, 'n-2');
    });

    test('unreadNotificationsCountProvider calculates unread notifications count correctly', () async {
      final item1 = NotificationModel(
        id: 'n-1',
        userId: 'u-1',
        householdId: 'h-100',
        title: '1',
        body: '1',
        isRead: false,
        createdAt: DateTime.now(),
      );
      final item2 = NotificationModel(
        id: 'n-2',
        userId: 'u-1',
        householdId: 'h-100',
        title: '2',
        body: '2',
        isRead: true,
        createdAt: DateTime.now(),
      );
      final item3 = NotificationModel(
        id: 'n-3',
        userId: 'u-1',
        householdId: 'h-100',
        title: '3',
        body: '3',
        isRead: false,
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          notificationsStreamProvider.overrideWith((ref) => Stream.value([item1, item2, item3])),
        ],
      );

      await container.read(notificationsStreamProvider.future);
      final unreadCount = container.read(unreadNotificationsCountProvider);
      expect(unreadCount, 2);
      container.dispose();
    });

    test('notificationsProvider resolves notification list for current household', () async {
      final item = NotificationModel(
        id: 'n-99',
        userId: 'u-1',
        householdId: 'h-100',
        title: 'طلب انضمام',
        body: 'طلب انضمام جديد',
        type: NotificationType.joinRequest,
        requestId: 'req-50',
        isRead: false,
        createdAt: DateTime.now(),
      );
      final repo = FakeNotificationRepository([item]);
      final container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(repo),
          notificationsProvider.overrideWith((ref) => repo.getNotifications('h-100')),
        ],
      );

      final list = await container.read(notificationsProvider.future);
      expect(list.length, 1);
      expect(list.first.requestId, 'req-50');
      container.dispose();
    });
  });

  group('NotificationService Scheduling Tests', () {
    test('NotificationService instantiates and exposes scheduling methods', () async {
      final service = NotificationService();
      await service.initialize();

      // Ensure scheduling and canceling does not throw
      await service.scheduleBillReminder(
        billId: 'b-1',
        title: 'فاتورة إنترنت Turkcell',
        dueDate: DateTime.now().add(const Duration(days: 5)),
        reminderDaysBefore: 2,
      );

      await service.scheduleResidencyReminder(
        permitId: 'p-1',
        expiryDate: DateTime.now().add(const Duration(days: 45)),
        reminderDaysBefore: 30,
      );

      await service.cancelReminder('b-1');
      await service.cancelAll();
    });
  });
}
