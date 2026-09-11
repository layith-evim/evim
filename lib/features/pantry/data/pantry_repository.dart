import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/models/pantry_item_model.dart';
import '../../household/presentation/controllers/current_household_controller.dart';
import '../../shopping/data/shopping_repository.dart';

abstract class PantryRepository {
  Future<List<PantryItemModel>> getPantryItems(String householdId);
  Future<void> addPantryItem({
    required String householdId,
    required String name,
    String quantity = '1',
  });
  Future<void> deletePantryItem(String itemId);
  Future<void> transferToShopping({
    required PantryItemModel pantryItem,
    required String category,
  });
}

class SupabasePantryRepository implements PantryRepository {
  final SupabaseClient _client;
  final Ref _ref;

  SupabasePantryRepository(this._ref, [SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  @override
  Future<List<PantryItemModel>> getPantryItems(String householdId) async {
    try {
      final response = await _client
          .from(AppConstants.tablePantryItems)
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: false);

      final list = response as List<dynamic>;
      return list.map((item) => PantryItemModel.fromJson(item as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> addPantryItem({
    required String householdId,
    required String name,
    String quantity = '1',
  }) async {
    try {
      await _client.from(AppConstants.tablePantryItems).insert({
        'household_id': householdId,
        'name': name.trim(),
        'quantity': quantity.trim().isEmpty ? '1' : quantity.trim(),
      });
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> deletePantryItem(String itemId) async {
    try {
      await _client.from(AppConstants.tablePantryItems).delete().eq('id', itemId);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> transferToShopping({
    required PantryItemModel pantryItem,
    required String category,
  }) async {
    try {
      final shoppingRepo = _ref.read(shoppingRepositoryProvider);
      // 1. Add to shopping list
      await shoppingRepo.addItem(
        householdId: pantryItem.householdId,
        name: pantryItem.name,
        category: category,
        quantity: pantryItem.quantity,
      );
      // 2. Delete from pantry
      await deletePantryItem(pantryItem.id);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }
}

/// Provider for PantryRepository
final pantryRepositoryProvider = Provider<PantryRepository>((ref) {
  return SupabasePantryRepository(ref);
});

/// Future provider for list of pantry items in active household
final pantryListProvider =
    FutureProvider.autoDispose<List<PantryItemModel>>((ref) async {
  final currentHousehold = ref.watch(currentHouseholdProvider).value;
  if (currentHousehold == null) return [];

  final repo = ref.watch(pantryRepositoryProvider);
  return repo.getPantryItems(currentHousehold.id);
});
