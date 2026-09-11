import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../../household/presentation/controllers/current_household_controller.dart';
import '../domain/models/notification_model.dart';

abstract class NotificationRepository {
  Stream<List<NotificationModel>> streamNotifications(String householdId);
  Future<List<NotificationModel>> getNotifications(String householdId);
  Future<NotificationModel> createNotification({
    required String householdId,
    required String title,
    required String body,
    NotificationType type = NotificationType.general,
    String? relatedId,
  });
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead(String householdId);
  Future<void> deleteNotification(String notificationId);
  Future<void> clearAllNotifications(String householdId);
}

class SupabaseNotificationRepository implements NotificationRepository {
  final SupabaseClient _client;

  SupabaseNotificationRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  @override
  Stream<List<NotificationModel>> streamNotifications(String householdId) {
    if (householdId.isEmpty) {
      return Stream.value([]);
    }

    try {
      return _client
          .from(AppConstants.tableNotifications)
          .stream(primaryKey: ['id'])
          .eq('household_id', householdId)
          .order('created_at', ascending: false)
          .map((rows) => rows.map((r) => NotificationModel.fromJson(r)).toList());
    } catch (_) {
      // Stream fallback
      return Stream.fromFuture(getNotifications(householdId));
    }
  }

  @override
  Future<List<NotificationModel>> getNotifications(String householdId) async {
    if (householdId.isEmpty) return [];

    try {
      final response = await _client
          .from(AppConstants.tableNotifications)
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: false);

      final list = response as List<dynamic>;
      return list
          .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<NotificationModel> createNotification({
    required String householdId,
    required String title,
    required String body,
    NotificationType type = NotificationType.general,
    String? relatedId,
  }) async {
    final user = _client.auth.currentUser;
    final userId = user?.id ?? '';

    try {
      final response = await _client
          .from(AppConstants.tableNotifications)
          .insert({
            'user_id': userId,
            'household_id': householdId,
            'title': title,
            'body': body,
            'type': type.value,
            'related_id': relatedId,
            'is_read': false,
          })
          .select()
          .single();

      return NotificationModel.fromJson(response);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from(AppConstants.tableNotifications)
          .update({'is_read': true})
          .eq('id', notificationId);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> markAllAsRead(String householdId) async {
    try {
      await _client
          .from(AppConstants.tableNotifications)
          .update({'is_read': true})
          .eq('household_id', householdId)
          .eq('is_read', false);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _client
          .from(AppConstants.tableNotifications)
          .delete()
          .eq('id', notificationId);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> clearAllNotifications(String householdId) async {
    try {
      await _client
          .from(AppConstants.tableNotifications)
          .delete()
          .eq('household_id', householdId);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }
}

/// Provider for NotificationRepository
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return SupabaseNotificationRepository();
});

/// Stream provider for current household notifications
final notificationsStreamProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final household = ref.watch(currentHouseholdProvider).value;
  if (household == null) return Stream.value([]);

  final repo = ref.watch(notificationRepositoryProvider);
  return repo.streamNotifications(household.id);
});

/// Future provider for current household notifications
final notificationsProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  final household = ref.watch(currentHouseholdProvider).value;
  if (household == null) return [];

  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getNotifications(household.id);
});

/// Computes the unread notification count
final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final notificationsAsync = ref.watch(notificationsStreamProvider);
  return notificationsAsync.maybeWhen(
    data: (list) => list.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});
