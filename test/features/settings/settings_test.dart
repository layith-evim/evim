import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:evim/features/auth/data/auth_repository.dart';
import 'package:evim/core/theme/theme_provider.dart';
import 'package:evim/features/household/data/household_repository.dart';
import 'package:evim/features/household/domain/models/household_model.dart';
import 'package:evim/features/household/domain/models/household_member_model.dart';
import 'package:evim/features/household/presentation/controllers/current_household_controller.dart';
import 'package:evim/features/settings/models/user_preferences.dart';
import 'package:evim/features/settings/providers/notification_settings_provider.dart';
import 'package:evim/features/settings/providers/settings_provider.dart';
import 'package:evim/features/settings/presentation/screens/settings_screen.dart';
import 'package:evim/features/settings/presentation/widgets/profile_header_card.dart';
import 'package:evim/features/settings/presentation/widgets/member_preferences_section.dart';
import 'package:evim/features/settings/presentation/widgets/danger_zone_section.dart';

class FakeCurrentHouseholdController extends CurrentHouseholdController {
  final HouseholdModel? _initial;
  FakeCurrentHouseholdController([this._initial]);

  @override
  Future<HouseholdModel?> build() async {
    return _initial;
  }
}

class FakeAuthRepository implements AuthRepository {
  User? _user;
  final _controller = StreamController<AuthState>.broadcast();

  FakeAuthRepository([this._user]);

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  User? get currentUser => _user;

  @override
  Session? get currentSession => null;

  @override
  Future<AuthResponse> signInWithEmail({required String email, required String password}) async =>
      AuthResponse(session: null, user: _user);

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async =>
      AuthResponse(session: null, user: _user);

  @override
  Future<void> signOut() async {
    _user = null;
  }

  @override
  Future<void> deleteAccountWithPassword(String password) async {
    _user = null;
  }

  @override
  Future<bool> hasHousehold() async => true;

  @override
  Future<List<String>> getHouseholdIds() async => ['h-1'];
}

class FakeHouseholdRepository implements HouseholdRepository {
  final List<HouseholdModel> _households = [];
  final List<HouseholdMemberModel> _members = [];
  String? updatedName;

  FakeHouseholdRepository({
    List<HouseholdModel>? households,
    List<HouseholdMemberModel>? members,
  }) {
    if (households != null) _households.addAll(households);
    if (members != null) _members.addAll(members);
  }

  @override
  Future<HouseholdModel> createHousehold(String name, {String city = 'إسطنبول'}) async {
    final h = HouseholdModel(
      id: 'h-new',
      name: name,
      inviteCode: 'NEW123',
      city: city,
      createdAt: DateTime.now(),
    );
    _households.add(h);
    return h;
  }

  @override
  Future<Map<String, dynamic>> joinHouseholdWithCode(String code) async {
    return {
      'success': true,
      'message': 'تم الانضمام بنجاح',
    };
  }

  @override
  Future<Map<String, dynamic>> requestJoinHousehold(String inviteCode) async {
    return {
      'success': true,
      'message': 'تم إرسال طلب الانضمام إلى صاحب المنزل بنجاح.',
    };
  }

  @override
  Future<void> respondToJoinRequest({
    required String requestId,
    required bool accept,
  }) async {}

  @override
  Future<HouseholdModel> joinHousehold(String inviteCode) async {
    return _households.first;
  }

  @override
  Future<List<HouseholdModel>> getMyHouseholds() async {
    return _households;
  }

  @override
  Future<HouseholdMemberModel?> getMyMembership(String householdId) async {
    return _members.where((m) => m.householdId == householdId).firstOrNull;
  }

  @override
  Future<List<HouseholdMemberModel>> getHouseholdMembers(String householdId) async {
    return _members.where((m) => m.householdId == householdId).toList();
  }

  @override
  Future<void> updateHouseholdInfo({
    required String householdId,
    required String name,
    String? city,
  }) async {
    final index = _households.indexWhere((h) => h.id == householdId);
    if (index != -1) {
      _households[index] = _households[index].copyWith(name: name, city: city);
    }
  }

  @override
  Future<void> deleteHousehold(String householdId) async {
    _households.removeWhere((h) => h.id == householdId);
    _members.removeWhere((m) => m.householdId == householdId);
  }

  @override
  Future<void> leaveHousehold(String householdId) async {
    _members.removeWhere((m) => m.householdId == householdId && m.userId == 'user-current');
  }

  @override
  Future<void> removeMember({
    required String householdId,
    required String memberUserId,
  }) async {
    _members.removeWhere((m) => m.householdId == householdId && m.userId == memberUserId);
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    updatedName = displayName;
  }

  @override
  Future<void> deleteUserAccount() async {
    _households.clear();
    _members.clear();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserPreferences Model Tests', () {
    test('Default values are initialized correctly', () {
      const prefs = UserPreferences();
      expect(prefs.notifyBills, isTrue);
      expect(prefs.notifyResidency, isTrue);
      expect(prefs.notifyPantry, isTrue);
      expect(prefs.language, 'ar');
      expect(prefs.themeMode, 'light');
    });

    test('Serialization toMap/toJson and fromJson works accurately', () {
      const prefs = UserPreferences(
        notifyBills: false,
        notifyResidency: true,
        notifyPantry: false,
        language: 'tr',
        themeMode: 'dark',
      );

      final map = prefs.toMap();
      expect(map['notify_bills'], isFalse);
      expect(map['language'], 'tr');
      expect(map['theme_mode'], 'dark');

      final parsed = UserPreferences.fromJson(map);
      expect(parsed.notifyBills, isFalse);
      expect(parsed.notifyResidency, isTrue);
      expect(parsed.notifyPantry, isFalse);
      expect(parsed.language, 'tr');
      expect(parsed.themeMode, 'dark');
    });

    test('copyWith updates fields independently', () {
      const prefs = UserPreferences();
      final updated = prefs.copyWith(notifyBills: false, themeMode: 'dark');
      expect(updated.notifyBills, isFalse);
      expect(updated.notifyResidency, isTrue);
      expect(updated.themeMode, 'dark');
      expect(updated.language, 'ar');
    });
  });

  group('ThemeModeNotifier Tests', () {
    test('Switches between light, dark, and system modes and persists', () async {
      final container = ProviderContainer();
      final notifier = container.read(themeProvider.notifier);

      expect(container.read(themeProvider), ThemeMode.light);

      await notifier.setThemeMode(ThemeMode.dark);
      expect(container.read(themeProvider), ThemeMode.dark);

      await notifier.setThemeMode(ThemeMode.system);
      expect(container.read(themeProvider), ThemeMode.system);

      await notifier.setThemeMode(ThemeMode.light);
      expect(container.read(themeProvider), ThemeMode.light);

      container.dispose();
    });
  });

  group('NotificationSettingsNotifier Tests', () {
    test('Toggles notify_bills, notify_residency, and notify_pantry with storage', () async {
      final container = ProviderContainer();
      final notifier = container.read(notificationSettingsProvider.notifier);

      expect(container.read(notificationSettingsProvider).notifyBills, isTrue);

      await notifier.toggleNotifyBills(false);
      expect(container.read(notificationSettingsProvider).notifyBills, isFalse);

      await notifier.toggleNotifyResidency(false);
      expect(container.read(notificationSettingsProvider).notifyResidency, isFalse);

      await notifier.toggleNotifyPantry(false);
      expect(container.read(notificationSettingsProvider).notifyPantry, isFalse);

      container.dispose();
    });
  });

  group('SettingsNotifier Tests', () {
    test('Toggles and updates preferences in state', () async {
      final container = ProviderContainer();
      final notifier = container.read(settingsProvider.notifier);

      await notifier.toggleNotifyBills(false);
      expect(container.read(settingsProvider).notifyBills, isFalse);

      await notifier.toggleNotifyResidency(false);
      expect(container.read(settingsProvider).notifyResidency, isFalse);

      await notifier.toggleNotifyPantry(false);
      expect(container.read(settingsProvider).notifyPantry, isFalse);

      await notifier.setThemeMode('dark');
      expect(container.read(settingsProvider).themeMode, 'dark');

      await notifier.setLanguage('tr');
      expect(container.read(settingsProvider).language, 'tr');

      container.dispose();
    });
  });

  group('Settings Presentation & Role-Aware Widgets', () {
    testWidgets('ProfileHeaderCard renders owner badge when isOwner is true', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProfileHeaderCard(isOwner: true),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('مالك المنزل'), findsOneWidget);
    });

    testWidgets('ProfileHeaderCard renders member badge when isOwner is false', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProfileHeaderCard(isOwner: false),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('عضو'), findsOneWidget);
    });

    testWidgets('MemberPreferencesSection displays all notification toggles', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MemberPreferencesSection(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('تفضيلات التطبيق والإشعارات'), findsOneWidget);
      expect(find.text('تنبيهات الفواتير والإيجار'), findsOneWidget);
      expect(find.text('رادار الإقامات والمعاملات'), findsOneWidget);
      expect(find.text('تحديثات قائمة المؤونة والمشتريات'), findsOneWidget);
    });

    testWidgets('DangerZoneSection displays delete household for owner', (tester) async {
      final testHousehold = HouseholdModel(
        id: 'h-1',
        name: 'منزل إسطنبول',
        inviteCode: 'ABC123',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            householdRepositoryProvider.overrideWithValue(FakeHouseholdRepository()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DangerZoneSection(
                household: testHousehold,
                isOwner: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('منطقة الحساب والأمان'), findsOneWidget);
      expect(find.text('حذف المنزل بالكامل'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
      expect(find.text('حذف الحساب نهائياً'), findsOneWidget);
    });

    testWidgets('DangerZoneSection displays leave household for normal member', (tester) async {
      final testHousehold = HouseholdModel(
        id: 'h-1',
        name: 'منزل إسطنبول',
        inviteCode: 'ABC123',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            householdRepositoryProvider.overrideWithValue(FakeHouseholdRepository()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DangerZoneSection(
                household: testHousehold,
                isOwner: false,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('مغادرة المنزل'), findsOneWidget);
    });

    testWidgets('SettingsScreen hides OwnerManagementSection when role is member', (tester) async {
      final testHousehold = HouseholdModel(
        id: 'h-1',
        name: 'منزل إسطنبول',
        inviteCode: 'ABC123',
        createdAt: DateTime.now(),
      );
      final memberRole = HouseholdMemberModel(
        id: 'm-1',
        userId: 'user-1',
        householdId: 'h-1',
        role: 'member',
        createdAt: DateTime.now(),
      );
      final fakeHouseholdRepo = FakeHouseholdRepository(
        households: [testHousehold],
        members: [memberRole],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            householdRepositoryProvider.overrideWithValue(fakeHouseholdRepo),
            currentHouseholdProvider.overrideWith(() => FakeCurrentHouseholdController(testHousehold)),
            currentHouseholdMemberRoleProvider.overrideWith((ref) => memberRole),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('الإعدادات والحساب'), findsOneWidget);
      expect(find.text('لوحة تحكم مالك المنزل'), findsNothing);
      expect(find.text('تفضيلات التطبيق والإشعارات'), findsOneWidget);
    });

    testWidgets('SettingsScreen shows OwnerManagementSection when role is owner', (tester) async {
      final testHousehold = HouseholdModel(
        id: 'h-1',
        name: 'منزل إسطنبول',
        inviteCode: 'ABC123',
        createdAt: DateTime.now(),
      );
      final ownerRole = HouseholdMemberModel(
        id: 'm-1',
        userId: 'user-1',
        householdId: 'h-1',
        role: 'owner',
        createdAt: DateTime.now(),
      );
      final fakeHouseholdRepo = FakeHouseholdRepository(
        households: [testHousehold],
        members: [ownerRole],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            householdRepositoryProvider.overrideWithValue(fakeHouseholdRepo),
            currentHouseholdProvider.overrideWith(() => FakeCurrentHouseholdController(testHousehold)),
            currentHouseholdMemberRoleProvider.overrideWith((ref) => ownerRole),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('لوحة تحكم مالك المنزل'), findsOneWidget);
      expect(find.text('رمز الدعوة: '), findsOneWidget);
    });
  });
}
