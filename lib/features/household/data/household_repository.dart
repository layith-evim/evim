import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/models/household_model.dart';
import '../domain/models/household_member_model.dart';

abstract class HouseholdRepository {
  Future<HouseholdModel> createHousehold(String name, {String city = 'إسطنبول'});
  Future<HouseholdModel> joinHousehold(String inviteCode);
  Future<Map<String, dynamic>> joinHouseholdWithCode(String code);
  Future<Map<String, dynamic>> requestJoinHousehold(String inviteCode);
  Future<void> respondToJoinRequest({
    required String requestId,
    required bool accept,
  });
  Future<List<HouseholdModel>> getMyHouseholds();
  Future<HouseholdMemberModel?> getMyMembership(String householdId);
  Future<List<HouseholdMemberModel>> getHouseholdMembers(String householdId);
  Future<void> removeMember({required String householdId, required String memberUserId});
  Future<void> updateHouseholdInfo({required String householdId, required String name, String? city});
  Future<void> deleteHousehold(String householdId);
  Future<void> leaveHousehold(String householdId);
  Future<void> updateDisplayName(String displayName);
  Future<void> deleteUserAccount();
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
  Future<HouseholdModel> createHousehold(String name, {String city = 'إسطنبول'}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AppException(
        code: 'AUTH_REQUIRED',
        messageAr: 'يجب تسجيل الدخول لإنشاء منزل.',
        messageTr: 'Hane oluşturmak için giriş yapmalısınız.',
      );
    }

    final finalName = name.trim().isEmpty ? 'منزلنا' : name.trim();

    try {
      try {
        final response = await _client.rpc<dynamic>('create_household_transaction', params: {
          'household_name': finalName,
          'household_city': city,
        });
        if (response != null) {
          if (response is Map<String, dynamic>) {
            return HouseholdModel.fromJson(response);
          } else if (response is List && response.isNotEmpty) {
            return HouseholdModel.fromJson(Map<String, dynamic>.from(response.first as Map));
          }
        }
      } catch (rpcErr) {
        debugPrint('create_household_transaction RPC fallback to direct insert: $rpcErr');
      }

      final inviteCode = _generateInviteCode();

      // 1. Insert new household
      final householdData = await _client
          .from(AppConstants.tableHouseholds)
          .insert({
            'name': finalName,
            'invite_code': inviteCode,
            'city': city.trim(),
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
    } catch (e, st) {
      debugPrint('Failed to create household: $e');
      if (e is PostgrestException) {
        throw AppException.fromPostgrest(e, st);
      }
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<Map<String, dynamic>> joinHouseholdWithCode(String code) async {
    try {
      final response = await _client.rpc<dynamic>('join_household_by_code', params: {
        'p_invite_code': code.trim().toUpperCase(),
      });
      final result = Map<String, dynamic>.from(response as Map);
      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'تعذر الانضمام للمنزل');
      }
      return result;
    } catch (e) {
      debugPrint('Join household error: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> requestJoinHousehold(String inviteCode) async {
    try {
      final response = await _client.rpc<dynamic>(
        'request_join_household_by_code',
        params: {'p_invite_code': inviteCode.trim().toUpperCase()},
      );
      final result = Map<String, dynamic>.from(response as Map);
      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'تعذر تقديم طلب الانضمام');
      }
      return result;
    } catch (e) {
      debugPrint('Error in requestJoinHousehold: $e');
      rethrow;
    }
  }

  @override
  Future<void> respondToJoinRequest({
    required String requestId,
    required bool accept,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'respond_to_join_request',
        params: {
          'p_request_id': requestId,
          'p_accept': accept,
        },
      );
      final result = Map<String, dynamic>.from(response as Map);
      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'تعذر معالجة الطلب');
      }
    } catch (e) {
      debugPrint('Error in respondToJoinRequest: $e');
      rethrow;
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
      // 1. Try RPC join_household_by_code first
      try {
        final rpcResult = await joinHouseholdWithCode(code);
        if (rpcResult['household'] is Map) {
          return HouseholdModel.fromJson(Map<String, dynamic>.from(rpcResult['household'] as Map));
        } else if (rpcResult['household_id'] != null) {
          final hId = rpcResult['household_id'].toString();
          final hData = await _client
              .from(AppConstants.tableHouseholds)
              .select()
              .eq('id', hId)
              .maybeSingle();
          if (hData != null) {
            return HouseholdModel.fromJson(hData);
          }
        }
      } catch (rpcErr) {
        debugPrint('join_household_by_code RPC fallback to direct query: $rpcErr');
      }

      // 2. Direct query fallback
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

      // 3. Check if user is already a member
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

      // 4. Add user as member
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

  @override
  Future<List<HouseholdMemberModel>> getHouseholdMembers(String householdId) async {
    try {
      final response = await _client.rpc<dynamic>(
        'get_household_members_details',
        params: {'p_household_id': householdId},
      );
      if (response != null && response is List) {
        return response
            .map((item) => HouseholdMemberModel.fromRpcJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching household members RPC: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeMember({required String householdId, required String memberUserId}) async {
    try {
      final response = await _client.rpc<dynamic>(
        'remove_household_member',
        params: {
          'p_household_id': householdId,
          'p_member_user_id': memberUserId,
        },
      );
      final result = Map<String, dynamic>.from(response as Map);
      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'تعذر إزالة العضو');
      }
    } catch (e) {
      debugPrint('Error removing member: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateHouseholdInfo({
    required String householdId,
    required String name,
    String? city,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name.trim(),
      };
      if (city != null) {
        data['city'] = city.trim();
      }

      await _client
          .from(AppConstants.tableHouseholds)
          .update(data)
          .eq('id', householdId);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> deleteHousehold(String householdId) async {
    try {
      // Delete membership associations and household
      await _client
          .from(AppConstants.tableHouseholdMembers)
          .delete()
          .eq('household_id', householdId);

      await _client
          .from(AppConstants.tableHouseholds)
          .delete()
          .eq('id', householdId);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> leaveHousehold(String householdId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client
          .from(AppConstants.tableHouseholdMembers)
          .delete()
          .eq('household_id', householdId)
          .eq('user_id', user.id);
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(data: {'name': displayName.trim()}),
      );

      final user = _client.auth.currentUser;
      if (user != null) {
        try {
          await _client
              .from(AppConstants.tableProfiles)
              .update({'name': displayName.trim()})
              .eq('id', user.id);
        } catch (_) {}
      }
    } on AuthException catch (e, st) {
      throw AppException.fromAuth(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> deleteUserAccount() async {
    try {
      try {
        await _client.rpc<void>('delete_user_account');
      } catch (_) {}
      await _client.auth.signOut();
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

/// Stream / Future of members in a specific household
final householdMembersProvider =
    FutureProvider.family.autoDispose<List<HouseholdMemberModel>, String>((ref, householdId) async {
  final repo = ref.watch(householdRepositoryProvider);
  return repo.getHouseholdMembers(householdId);
});
