import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/models/household_model.dart';
import '../domain/models/household_member_model.dart';

abstract class HouseholdRepository {
  Future<HouseholdModel> createHousehold(String name);
  Future<HouseholdModel> joinHousehold(String inviteCode);
  Future<List<HouseholdModel>> getMyHouseholds();
  Future<HouseholdMemberModel?> getMyMembership(String householdId);
}

class SupabaseHouseholdRepository implements HouseholdRepository {
  final SupabaseClient _client;

  SupabaseHouseholdRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  /// Generates a random 6-character uppercase alphanumeric code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excludes confusing characters (I, O, 0, 1)
    final random = Random.secure();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  Future<HouseholdModel> createHousehold(String name) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AppException(
        code: 'AUTH_REQUIRED',
        messageAr: 'يجب تسجيل الدخول لإنشاء منزل.',
        messageTr: 'Hane oluşturmak için giriş yapmalısınız.',
      );
    }

    try {
      final inviteCode = _generateInviteCode();

      // 1. Insert new household
      final householdData = await _client
          .from(AppConstants.tableHouseholds)
          .insert({
            'name': name.trim(),
            'invite_code': inviteCode,
            'is_premium': false,
          })
          .select()
          .single();

      final household = HouseholdModel.fromJson(householdData);

      // 2. Insert creator as 'owner' in household_members
      await _client.from(AppConstants.tableHouseholdMembers).insert({
        'household_id': household.id,
        'user_id': user.id,
        'role': 'owner',
      });

      return household;
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<HouseholdModel> joinHousehold(String inviteCode) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AppException(
        code: 'AUTH_REQUIRED',
        messageAr: 'يجب تسجيل الدخول للانضمام إلى منزل.',
        messageTr: 'Haneye katılmak için giriş yapmalısınız.',
      );
    }

    final code = inviteCode.trim().toUpperCase();

    try {
      // 1. Find household by invite_code
      final householdResponse = await _client
          .from(AppConstants.tableHouseholds)
          .select()
          .eq('invite_code', code)
          .maybeSingle();

      if (householdResponse == null) {
        throw const AppException(
          code: 'HOUSEHOLD_NOT_FOUND',
          messageAr: 'رمز الدعوة غير صحيح أو لا يوجد منزل بهذا الرمز.',
          messageTr: 'Geçersiz davet kodu veya bu koda ait hane bulunamadı.',
        );
      }

      final household = HouseholdModel.fromJson(householdResponse);

      // 2. Check if user is already a member
      final existingMember = await _client
          .from(AppConstants.tableHouseholdMembers)
          .select()
          .eq('household_id', household.id)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingMember != null) {
        // User already in this household
        return household;
      }

      // 3. Add user as member
      await _client.from(AppConstants.tableHouseholdMembers).insert({
        'household_id': household.id,
        'user_id': user.id,
        'role': 'member',
      });

      return household;
    } on AppException {
      rethrow;
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<List<HouseholdModel>> getMyHouseholds() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      // Query household_members and join households table
      final response = await _client
          .from(AppConstants.tableHouseholdMembers)
          .select('household_id, ${AppConstants.tableHouseholds}(*)')
          .eq('user_id', user.id);

      final list = response as List<dynamic>;
      final households = <HouseholdModel>[];

      for (final item in list) {
        final householdMap = (item as Map<String, dynamic>)[AppConstants.tableHouseholds];
        if (householdMap != null) {
          households.add(HouseholdModel.fromJson(householdMap as Map<String, dynamic>));
        }
      }

      return households;
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<HouseholdMemberModel?> getMyMembership(String householdId) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from(AppConstants.tableHouseholdMembers)
          .select()
          .eq('household_id', householdId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return HouseholdMemberModel.fromJson(response);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }
}

/// Provider for HouseholdRepository
final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return SupabaseHouseholdRepository();
});

/// Stream / Future of all user's households
final userHouseholdsProvider = FutureProvider.autoDispose<List<HouseholdModel>>((ref) async {
  final repo = ref.watch(householdRepositoryProvider);
  return repo.getMyHouseholds();
});
