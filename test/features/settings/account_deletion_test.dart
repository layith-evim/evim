import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:evim/core/error/app_exception.dart';
import 'package:evim/features/auth/data/auth_repository.dart';
import 'package:evim/features/settings/presentation/widgets/danger_zone_section.dart';

class MockAuthRepositoryForDeletion implements AuthRepository {
  final String correctPassword;
  final User? _user;
  final _controller = StreamController<AuthState>.broadcast();

  bool deleteAccountCalled = false;
  bool signOutCalled = false;
  String? lastPassedPassword;

  MockAuthRepositoryForDeletion({
    this.correctPassword = 'SecretPassword123!',
    User? user,
  }) : _user = user ??
            const User(
              id: 'user-del-123',
              appMetadata: {},
              userMetadata: {'full_name': 'Test User'},
              aud: 'authenticated',
              createdAt: '2026-01-01',
              email: 'test@evim.app',
            );

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  User? get currentUser => _user;

  @override
  Session? get currentSession => null;

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return AuthResponse(session: null, user: _user);
  }

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return AuthResponse(session: null, user: _user);
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<void> deleteAccountWithPassword(String password) async {
    lastPassedPassword = password;
    if (password != correctPassword) {
      throw const AppException(
        code: 'INVALID_PASSWORD',
        messageAr: 'كلمة المرور غير صحيحة. يرجى التأكد وإعادة المحاولة.',
        messageTr: 'Şifre hatalı. Lütfen kontrol edip tekrar deneyin.',
      );
    }

    deleteAccountCalled = true;
    await signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  @override
  Future<bool> hasHousehold() async => true;

  @override
  Future<List<String>> getHouseholdIds() async => ['h-1'];
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'app_theme_mode': 'dark',
      'notify_bills': true,
      'notify_residency': true,
      'app_language': 'ar',
    });
  });

  group('AuthRepository Account Deletion Logic Tests', () {
    test('deleteAccountWithPassword throws INVALID_PASSWORD on wrong password', () async {
      final repo = MockAuthRepositoryForDeletion(correctPassword: 'ValidPass123!');
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString('app_theme_mode'), 'dark');

      expect(
        () => repo.deleteAccountWithPassword('WrongPass!'),
        throwsA(isA<AppException>().having(
          (e) => e.code,
          'code',
          'INVALID_PASSWORD',
        )),
      );

      expect(repo.deleteAccountCalled, isFalse);
      expect(repo.signOutCalled, isFalse);
      // Preferences should NOT be cleared on failure
      expect(prefs.getString('app_theme_mode'), 'dark');
    });

    test('deleteAccountWithPassword succeeds with correct password & wipes preferences', () async {
      final repo = MockAuthRepositoryForDeletion(correctPassword: 'ValidPass123!');
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString('app_theme_mode'), 'dark');
      expect(prefs.getBool('notify_bills'), isTrue);

      await repo.deleteAccountWithPassword('ValidPass123!');

      expect(repo.deleteAccountCalled, isTrue);
      expect(repo.signOutCalled, isTrue);
      expect(repo.lastPassedPassword, 'ValidPass123!');
      // Preferences MUST be completely wiped
      expect(prefs.getKeys(), isEmpty);
    });
  });

  group('DangerZoneSection Password Modal Widget Tests', () {
    testWidgets('Opens confirmation dialog with password field on delete account tap', (tester) async {
      final mockRepo = MockAuthRepositoryForDeletion();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DangerZoneSection(
                  household: null,
                  isOwner: false,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify list tile exists
      expect(find.text('حذف الحساب نهائياً'), findsOneWidget);

      // Tap to open dialog
      await tester.tap(find.text('حذف الحساب نهائياً'));
      await tester.pumpAndSettle();

      // Check dialog elements
      expect(find.text('تأكيد حذف الحساب نهائياً'), findsOneWidget);
      expect(find.text('كلمة المرور الحالية'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
    });

    testWidgets('Shows validation error when submitting empty password', (tester) async {
      final mockRepo = MockAuthRepositoryForDeletion();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DangerZoneSection(
                  household: null,
                  isOwner: false,
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('حذف الحساب نهائياً'));
      await tester.pumpAndSettle();

      // Tap delete button in dialog with empty input
      final confirmBtn = find.widgetWithText(ElevatedButton, 'حذف الحساب نهائياً');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Validation error shown
      expect(find.text('يرجى إدخال كلمة المرور'), findsOneWidget);
      expect(mockRepo.deleteAccountCalled, isFalse);
    });

    testWidgets('Displays in-dialog error message on invalid password without dismissing dialog', (tester) async {
      final mockRepo = MockAuthRepositoryForDeletion(correctPassword: 'RightPassword123');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DangerZoneSection(
                  household: null,
                  isOwner: false,
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('حذف الحساب نهائياً'));
      await tester.pumpAndSettle();

      // Enter wrong password
      await tester.enterText(find.byType(TextFormField), 'WrongPassword');
      await tester.pump();

      // Tap confirm button
      final confirmBtn = find.widgetWithText(ElevatedButton, 'حذف الحساب نهائياً');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Error message is displayed in the dialog
      expect(find.text('كلمة المرور غير صحيحة. يرجى التأكد وإعادة المحاولة.'), findsOneWidget);
      // Dialog is still visible
      expect(find.text('تأكيد حذف الحساب نهائياً'), findsOneWidget);
      expect(mockRepo.deleteAccountCalled, isFalse);
    });

    testWidgets('Closes dialog, calls repository, and clears storage on correct password', (tester) async {
      final mockRepo = MockAuthRepositoryForDeletion(correctPassword: 'CorrectPassword123');
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DangerZoneSection(
                  household: null,
                  isOwner: false,
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('حذف الحساب نهائياً'));
      await tester.pumpAndSettle();

      // Enter correct password
      await tester.enterText(find.byType(TextFormField), 'CorrectPassword123');
      await tester.pump();

      // Tap confirm
      final confirmBtn = find.widgetWithText(ElevatedButton, 'حذف الحساب نهائياً');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('تأكيد حذف الحساب نهائياً'), findsNothing);
      // Repository called
      expect(mockRepo.deleteAccountCalled, isTrue);
      expect(mockRepo.signOutCalled, isTrue);
      // Storage wiped
      expect(prefs.getKeys(), isEmpty);
    });

    testWidgets('Toggles password obscurity when visibility icon is pressed', (tester) async {
      final mockRepo = MockAuthRepositoryForDeletion();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DangerZoneSection(
                  household: null,
                  isOwner: false,
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('حذف الحساب نهائياً'));
      await tester.pumpAndSettle();

      // Initially obscured (visibility_outlined icon)
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

      // Toggle visibility
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      // Now revealed (visibility_off_outlined icon)
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    });
  });
}
