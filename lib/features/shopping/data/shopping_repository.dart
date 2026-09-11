import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/models/shopping_item_model.dart';
import '../../household/presentation/controllers/current_household_controller.dart';

abstract class ShoppingRepository {
  Stream<List<ShoppingItemModel>> streamShoppingItems(String householdId);
  Future<void> addItem({
    required String householdId,
    required String name,
    required String category,
    String quantity = '1',
  });
  Future<void> toggleItemStatus({
    required String itemId,
    required bool isBought,
    required String? buyerEmail,
  });
  Future<void> deleteItem(String itemId);
  Future<void> clearBoughtItems(String householdId);
}

class SupabaseShoppingRepository implements ShoppingRepository {
  final SupabaseClient _client;

  SupabaseShoppingRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  @override
  Stream<List<ShoppingItemModel>> streamShoppingItems(String householdId) {
    return _client
        .from(AppConstants.tableShoppingItems)
        .stream(primaryKey: ['id'])
        .eq('household_id', householdId)
        .order('created_at', ascending: true)
        .map((data) => data.map((item) => ShoppingItemModel.fromJson(item)).toList());
  }

  @override
  Future<void> addItem({
    required String householdId,
    required String name,
    required String category,
    String quantity = '1',
  }) async {
    try {
      await _client.from(AppConstants.tableShoppingItems).insert({
        'household_id': householdId,
        'name': name.trim(),
        'category': category.trim(),
        'quantity': quantity.trim().isEmpty ? '1' : quantity.trim(),
        'is_bought': false,
      });
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> toggleItemStatus({
    required String itemId,
    required bool isBought,
    required String? buyerEmail,
  }) async {
    try {
      await _client.from(AppConstants.tableShoppingItems).update({
        'is_bought': isBought,
        'bought_by': isBought ? buyerEmail : null,
      }).eq('id', itemId);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> deleteItem(String itemId) async {
    try {
      await _client.from(AppConstants.tableShoppingItems).delete().eq('id', itemId);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> clearBoughtItems(String householdId) async {
    try {
      await _client
          .from(AppConstants.tableShoppingItems)
          .delete()
          .eq('household_id', householdId)
          .eq('is_bought', true);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }
}

/// Provider for ShoppingRepository
final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return SupabaseShoppingRepository();
});

/// Realtime Stream of shopping items for the current active household
final shoppingListStreamProvider =
    StreamProvider.autoDispose<List<ShoppingItemModel>>((ref) {
  final currentHousehold = ref.watch(currentHouseholdProvider).value;
  if (currentHousehold == null) return const Stream.empty();

  final repo = ref.watch(shoppingRepositoryProvider);
  return repo.streamShoppingItems(currentHousehold.id);
});
