import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/models/recurring_expense_model.dart';
import '../../household/presentation/controllers/current_household_controller.dart';

abstract class ExpensesRepository {
  Future<List<RecurringExpenseModel>> getExpenses(String householdId);
  Future<void> addExpense(RecurringExpenseModel expense);
  Future<void> toggleExpensePaid({required String expenseId, required bool isPaid});
  Future<void> deleteExpense(String expenseId);
}

class SupabaseExpensesRepository implements ExpensesRepository {
  final SupabaseClient _client;

  SupabaseExpensesRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  @override
  Future<List<RecurringExpenseModel>> getExpenses(String householdId) async {
    try {
      final response = await _client
          .from(AppConstants.tableRecurringExpenses)
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: true);

      final list = response as List<dynamic>;
      return list
          .map((item) => RecurringExpenseModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> addExpense(RecurringExpenseModel expense) async {
    try {
      await _client.from(AppConstants.tableRecurringExpenses).insert({
        'household_id': expense.householdId,
        'title': expense.title.trim(),
        'category': expense.category.trim(),
        'amount': expense.amount,
        'due_day': expense.dueDay,
        'is_paid': expense.isPaid,
        'last_paid_at': expense.isPaid ? DateTime.now().toIso8601String() : null,
      });
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> toggleExpensePaid({
    required String expenseId,
    required bool isPaid,
  }) async {
    try {
      await _client.from(AppConstants.tableRecurringExpenses).update({
        'is_paid': isPaid,
        'last_paid_at': isPaid ? DateTime.now().toIso8601String() : null,
      }).eq('id', expenseId);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    try {
      await _client.from(AppConstants.tableRecurringExpenses).delete().eq('id', expenseId);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }
}

/// Provider for ExpensesRepository
final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return SupabaseExpensesRepository();
});

/// Future provider for list of recurring expenses in active household
final recurringExpensesListProvider =
    FutureProvider.autoDispose<List<RecurringExpenseModel>>((ref) async {
  final currentHousehold = ref.watch(currentHouseholdProvider).value;
  if (currentHousehold == null) return [];

  final repo = ref.watch(expensesRepositoryProvider);
  return repo.getExpenses(currentHousehold.id);
});
