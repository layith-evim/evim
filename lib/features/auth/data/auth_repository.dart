import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/services/supabase_service.dart';

/// Abstract contract for authentication operations in Evim
abstract class AuthRepository {
  Stream<AuthState> get authStateChanges;
  User? get currentUser;
  Session? get currentSession;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  });

  Future<void> signOut();

  /// Re-authenticates with password and performs cascade permanent account deletion
  Future<void> deleteAccountWithPassword(String password);

  /// Queries whether the current authenticated user belongs to any household
  Future<bool> hasHousehold();

  /// Fetches household IDs associated with the current user
  Future<List<String>> getHouseholdIds();
}

/// Supabase implementation of AuthRepository
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException catch (e, st) {
      throw AppException.fromAuth(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: data,
      );
      return response;
    } on AuthException catch (e, st) {
      throw AppException.fromAuth(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e, st) {
      throw AppException.fromAuth(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<void> deleteAccountWithPassword(String password) async {
    final email = _client.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw const AppException(
        code: 'USER_NOT_FOUND',
        messageAr: 'لم يتم العثور على بريد المستخدم المسجل.',
        messageTr: 'Kullanıcı e-posta adresi bulunamadı.',
      );
    }

    try {
      // 1. Re-authenticate with email & password
      try {
        await _client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } on AuthException catch (e, st) {
        if (e.statusCode == '400' ||
            e.message.toLowerCase().contains('invalid login credentials') ||
            e.message.toLowerCase().contains('invalid_credentials') ||
            e.message.toLowerCase().contains('invalid_grant')) {
          throw const AppException(
            code: 'INVALID_PASSWORD',
            messageAr: 'كلمة المرور غير صحيحة. يرجى التأكد وإعادة المحاولة.',
            messageTr: 'Şifre hatalı. Lütfen kontrol edip tekrar deneyin.',
          );
        }
        throw AppException.fromAuth(e, st);
      }

      // 2. Invoke cascade user deletion RPC without swallowing errors
      await _client.rpc<void>('delete_user_account');

      // 3. Clear auth session
      await _client.auth.signOut();

      // 4. Clear all local preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      if (e is AppException) rethrow;
      throw AppException.fromSupabase(e, st);
    }
  }

  @override
  Future<bool> hasHousehold() async {
    final user = currentUser;
    if (user == null) return false;

    try {
      final response = await _client
          .from(AppConstants.tableHouseholdMembers)
          .select('household_id')
          .eq('user_id', user.id)
          .limit(1);

      return (response as List<dynamic>).isNotEmpty;
    } catch (e) {
      debugPrint('hasHousehold fallback: $e');
      return false;
    }
  }

  @override
  Future<List<String>> getHouseholdIds() async {
    final user = currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from(AppConstants.tableHouseholdMembers)
          .select('household_id')
          .eq('user_id', user.id);

      final list = response as List<dynamic>;
      return list
          .map((item) => (item as Map<String, dynamic>)['household_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('getHouseholdIds fallback: $e');
      return [];
    }
  }
}

/// Riverpod Providers
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository();
});

/// Stream of auth state changes (SignIn, SignOut, TokenRefreshed, etc.)
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Reactive check if authenticated user belongs to at least one household
final userHasHouseholdProvider = FutureProvider.autoDispose<bool>((ref) async {
  // Watch auth state to re-evaluate whenever auth state changes
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(authRepositoryProvider);
  if (repo.currentUser == null) return false;
  try {
    return await repo.hasHousehold();
  } catch (e) {
    debugPrint('userHasHouseholdProvider fallback: $e');
    return false;
  }
});
