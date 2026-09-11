import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/household_repository.dart';
import '../../domain/models/household_model.dart';
import '../../domain/models/household_member_model.dart';
import '../../../auth/data/auth_repository.dart';

/// Riverpod controller managing the active household context and household switching
class CurrentHouseholdController extends AsyncNotifier<HouseholdModel?> {
  @override
  FutureOr<HouseholdModel?> build() async {
    try {
      final repo = ref.watch(householdRepositoryProvider);
      final households = await repo.getMyHouseholds();
      if (households.isNotEmpty) {
        return households.first;
      }
      return null;
    } catch (e) {
      debugPrint('CurrentHouseholdController build fallback: $e');
      return null;
    }
  }

  /// Switches active household context
  void switchHousehold(HouseholdModel household) {
    state = AsyncData(household);
  }

  /// Creates a new household and immediately sets it as active
  Future<bool> createHousehold(String name) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(householdRepositoryProvider);
      final newHousehold = await repo.createHousehold(name);
      // Invalidate household checks so routers update
      ref.invalidate(userHasHouseholdProvider);
      ref.invalidate(userHouseholdsProvider);
      return newHousehold;
    });

    return !state.hasError;
  }

  /// Joins a household by 6-character invite code and sets it as active
  Future<bool> joinHousehold(String inviteCode) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(householdRepositoryProvider);
      final joinedHousehold = await repo.joinHousehold(inviteCode);
      // Invalidate household checks so routers update
      ref.invalidate(userHasHouseholdProvider);
      ref.invalidate(userHouseholdsProvider);
      return joinedHousehold;
    });

    return !state.hasError;
  }
}

/// Provider for CurrentHouseholdController
final currentHouseholdProvider =
    AsyncNotifierProvider<CurrentHouseholdController, HouseholdModel?>(
  CurrentHouseholdController.new,
);

/// Alias provider for activeHouseholdProvider
final activeHouseholdProvider = currentHouseholdProvider;

/// Provider to fetch current user's membership role in the active household
final currentHouseholdMemberRoleProvider =
    FutureProvider.autoDispose<HouseholdMemberModel?>((ref) async {
  final currentHousehold = ref.watch(currentHouseholdProvider).value;
  if (currentHousehold == null) return null;

  final repo = ref.watch(householdRepositoryProvider);
  return repo.getMyMembership(currentHousehold.id);
});
