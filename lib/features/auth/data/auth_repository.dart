import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  });

  Future<void> signOut();

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
  }) async {
    try {
      final response = await _client.auth.signUp(
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
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
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
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
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
  return repo.hasHousehold();
});
