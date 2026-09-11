import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';

/// Riverpod AsyncNotifier controller managing authentication UI states and user actions
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Initial state is AsyncData(null)
    return null;
  }

  /// Signs in the user with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithEmail(email: email, password: password);
    });

    // Return true if success
    return !state.hasError;
  }

  /// Registers a new user with email and password and optional profile metadata
  Future<bool> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.signUpWithEmail(
        email: email,
        password: password,
        data: data,
      );
    });

    return !state.hasError;
  }

  /// Signs out the current user and invalidates session states
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.signOut();
    });
  }
}

/// Provider for AuthController
final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
