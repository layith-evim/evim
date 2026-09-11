import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:evim/core/error/app_exception.dart';
import 'package:evim/features/auth/data/auth_repository.dart';
import 'package:evim/features/auth/presentation/controllers/auth_controller.dart';

// Mock AuthRepository for testing
class FakeAuthRepository implements AuthRepository {
  bool shouldThrow = false;
  bool userHasHome = false;
  User? mockUser;
  final _controller = StreamController<AuthState>.broadcast();

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  User? get currentUser => mockUser;

  @override
  Session? get currentSession => null;

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (shouldThrow) {
      throw const AppException(
        code: 'AUTH_INVALID_CREDENTIALS',
        messageAr: 'بيانات الدخول غير صحيحة.',
        messageTr: 'Giriş bilgileri hatalı.',
      );
    }
    return AuthResponse(session: null, user: mockUser);
  }

  Map<String, dynamic>? lastSignUpData;

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    lastSignUpData = data;
    if (shouldThrow) {
      throw const AppException(
        code: 'AUTH_USER_EXISTS',
        messageAr: 'هذا البريد مسجل بالفعل.',
        messageTr: 'Bu e-posta zaten kayıtlı.',
      );
    }
    return AuthResponse(session: null, user: mockUser);
  }

  @override
  Future<void> signOut() async {
    mockUser = null;
  }

  @override
  Future<void> deleteAccountWithPassword(String password) async {
    if (shouldThrow) {
      throw const AppException(
        code: 'INVALID_PASSWORD',
        messageAr: 'كلمة المرور غير صحيحة.',
        messageTr: 'Şifre hatalı.',
      );
    }
    mockUser = null;
  }

  @override
  Future<bool> hasHousehold() async => userHasHome;

  @override
  Future<List<String>> getHouseholdIds() async => userHasHome ? ['household-123'] : [];

  void dispose() {
    _controller.close();
  }
}

void main() {
  late FakeAuthRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    fakeRepo.dispose();
  });

  group('AuthController Tests', () {
    test('initial state is AsyncData(null)', () {
      final state = container.read(authControllerProvider);
      expect(state, const AsyncData<void>(null));
    });

    test('signIn success updates state cleanly and returns true', () async {
      fakeRepo.shouldThrow = false;
      final controller = container.read(authControllerProvider.notifier);

      final success = await controller.signIn(
        email: 'test@example.com',
        password: 'Password123',
      );

      expect(success, isTrue);
      expect(container.read(authControllerProvider).hasError, isFalse);
    });

    test('signIn failure sets state to AsyncError and returns false', () async {
      fakeRepo.shouldThrow = true;
      final controller = container.read(authControllerProvider.notifier);

      final success = await controller.signIn(
        email: 'wrong@example.com',
        password: 'WrongPassword123',
      );

      expect(success, isFalse);
      final state = container.read(authControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<AppException>());
    });

    test('signUp success updates state cleanly and returns true', () async {
      fakeRepo.shouldThrow = false;
      final controller = container.read(authControllerProvider.notifier);

      final success = await controller.signUp(
        email: 'newuser@example.com',
        password: 'Password123',
        data: {
          'first_name': 'محمد',
          'last_name': 'الحلبي',
          'phone': '+905551234567',
          'city': 'إسطنبول',
          'age': 28,
          'nationality': 'سوري',
          'gender': 'ذكر',
        },
      );

      expect(success, isTrue);
      expect(container.read(authControllerProvider).hasError, isFalse);
      expect(fakeRepo.lastSignUpData?['first_name'], 'محمد');
      expect(fakeRepo.lastSignUpData?['city'], 'إسطنبول');
      expect(fakeRepo.lastSignUpData?['age'], 28);
    });

    test('signUp failure sets state to AsyncError and returns false', () async {
      fakeRepo.shouldThrow = true;
      final controller = container.read(authControllerProvider.notifier);

      final success = await controller.signUp(
        email: 'existing@example.com',
        password: 'Password123',
      );

      expect(success, isFalse);
      final state = container.read(authControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<AppException>());
    });

    test('signOut executes without throwing', () async {
      final controller = container.read(authControllerProvider.notifier);
      await controller.signOut();
      expect(container.read(authControllerProvider).hasError, isFalse);
    });
  });

  group('AuthException Mapping Tests', () {
    test('Invalid login credentials maps to unregistered / deleted account message', () {
      const authEx = AuthException('Invalid login credentials', statusCode: '400');
      final appEx = AppException.fromAuth(authEx);

      expect(appEx.code, 'AUTH_INVALID_CREDENTIALS');
      expect(
        appEx.messageAr,
        'هذا الحساب غير مسجل أو تم حذفه مسبقاً. يرجى التأكد من البيانات أو إنشاء حساب جديد.',
      );
    });

    test('invalid_grant maps to unregistered / deleted account message', () {
      const authEx = AuthException('invalid_grant: user not found');
      final appEx = AppException.fromAuth(authEx);

      expect(appEx.code, 'AUTH_INVALID_CREDENTIALS');
      expect(
        appEx.messageAr,
        'هذا الحساب غير مسجل أو تم حذفه مسبقاً. يرجى التأكد من البيانات أو إنشاء حساب جديد.',
      );
    });
  });
}
