import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/models/critical_deadline_model.dart';
import '../../household/presentation/controllers/current_household_controller.dart';

abstract class DeadlinesRepository {
  Future<List<CriticalDeadlineModel>> getDeadlines(String householdId);
  Future<void> addDeadline(CriticalDeadlineModel deadline);
  Future<void> toggleDeadlineCompleted({required String deadlineId, required bool isCompleted});
  Future<void> deleteDeadline(String deadlineId);
}

class SupabaseDeadlinesRepository implements DeadlinesRepository {
  final SupabaseClient _client;

  SupabaseDeadlinesRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  @override
  Future<List<CriticalDeadlineModel>> getDeadlines(String householdId) async {
    try {
      final response = await _client
          .from(AppConstants.tableCriticalDeadlines)
          .select()
          .eq('household_id', householdId)
          .order('due_date', ascending: true);

      final list = response as List<dynamic>;
      return list
          .map((item) => CriticalDeadlineModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> addDeadline(CriticalDeadlineModel deadline) async {
    try {
      await _client.from(AppConstants.tableCriticalDeadlines).insert({
        'household_id': deadline.householdId,
        'title': deadline.title.trim(),
        'category': deadline.category.trim(),
        'due_date': deadline.dueDate.toIso8601String().split('T').first,
        'reminder_days_before': deadline.reminderDaysBefore,
        'notes': deadline.notes?.trim(),
        'is_completed': deadline.isCompleted,
      });
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> toggleDeadlineCompleted({
    required String deadlineId,
    required bool isCompleted,
  }) async {
    try {
      await _client.from(AppConstants.tableCriticalDeadlines).update({
        'is_completed': isCompleted,
      }).eq('id', deadlineId);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> deleteDeadline(String deadlineId) async {
    try {
      await _client.from(AppConstants.tableCriticalDeadlines).delete().eq('id', deadlineId);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }
}

/// Provider for DeadlinesRepository
final deadlinesRepositoryProvider = Provider<DeadlinesRepository>((ref) {
  return SupabaseDeadlinesRepository();
});

/// Future provider for list of critical deadlines in active household
final criticalDeadlinesListProvider =
    FutureProvider.autoDispose<List<CriticalDeadlineModel>>((ref) async {
  final currentHousehold = ref.watch(currentHouseholdProvider).value;
  if (currentHousehold == null) return [];

  final repo = ref.watch(deadlinesRepositoryProvider);
  return repo.getDeadlines(currentHousehold.id);
});
