import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evim/core/services/subscription_service.dart';
import 'package:evim/features/household/domain/models/household_model.dart';
import 'package:evim/features/household/domain/models/household_member_model.dart';
import 'package:evim/features/household/data/household_repository.dart';
import 'package:evim/features/household/presentation/controllers/current_household_controller.dart';
import 'package:evim/features/paywall/widgets/pro_badge.dart';

class FakeHouseholdRepository implements HouseholdRepository {
  final List<HouseholdModel> households;

  FakeHouseholdRepository(this.households);

  @override
  Future<HouseholdModel> createHousehold(String name, {String city = 'إسطنبول'}) async {
    final newH = HouseholdModel(
      id: 'new-id',
      name: name,
      inviteCode: 'EVIM01',
      city: city,
      isPremium: false,
      createdAt: DateTime.now(),
    );
    households.add(newH);
    return newH;
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
    final joined = HouseholdModel(
      id: 'join-id',
      name: 'منزل منضم',
      inviteCode: inviteCode,
      isPremium: false,
      createdAt: DateTime.now(),
    );
    households.add(joined);
    return joined;
  }

  @override
  Future<List<HouseholdModel>> getMyHouseholds() async {
    return households;
  }

  @override
  Future<HouseholdMemberModel?> getMyMembership(String householdId) async {
    return HouseholdMemberModel(
      id: 'm-1',
      userId: 'user-1',
      householdId: householdId,
      role: 'owner',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<HouseholdMemberModel>> getHouseholdMembers(String householdId) async {
    return [
      HouseholdMemberModel(
        id: 'm-1',
        userId: 'user-1',
        householdId: householdId,
        role: 'owner',
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<void> updateHouseholdInfo({
    required String householdId,
    required String name,
    String? city,
  }) async {
    final index = households.indexWhere((h) => h.id == householdId);
    if (index != -1) {
      households[index] = households[index].copyWith(name: name, city: city);
    }
  }

  @override
  Future<void> deleteHousehold(String householdId) async {
    households.removeWhere((h) => h.id == householdId);
  }

  @override
  Future<void> leaveHousehold(String householdId) async {
    households.removeWhere((h) => h.id == householdId);
  }

  @override
  Future<void> removeMember({
    required String householdId,
    required String memberUserId,
  }) async {}

  @override
  Future<void> updateDisplayName(String displayName) async {}

  @override
  Future<void> deleteUserAccount() async {
    households.clear();
  }
}

void main() {
  group('SubscriptionPackage Model Tests', () {
    test('availablePackages contains annual and monthly packages with correct attributes', () {
      const packages = SubscriptionService.availablePackages;
      expect(packages.length, 2);

      final annual = packages.firstWhere((p) => p.type == PackageType.annual);
      expect(annual.id, 'evim_pro_annual');
      expect(annual.price, 899.99);
      expect(annual.period, 'سنة');
      expect(annual.discountBadge, 'وفر 30%');
      expect(annual.formattedPrice, '899.99 ₺ / سنة');

      final monthly = packages.firstWhere((p) => p.type == PackageType.monthly);
      expect(monthly.id, 'evim_pro_monthly');
      expect(monthly.price, 109.99);
      expect(monthly.period, 'شهر');
      expect(monthly.formattedPrice, '109.99 ₺ / شهر');
    });

    test('SubscriptionModel defaults to active free tier', () {
      const sub = SubscriptionModel();
      expect(sub.planTier, 'free');
      expect(sub.status, 'active');
      expect(sub.isPremium, isFalse);
      expect(sub.isPro, isFalse);
    });

    test('householdSubscriptionProvider falls back to Free Tier on empty or invalid id', () async {
      final container = ProviderContainer();
      final sub = await container.read(householdSubscriptionProvider('').future);

      expect(sub.planTier, 'free');
      expect(sub.status, 'active');
      expect(sub.isPro, isFalse);
      container.dispose();
    });
  });

  group('Subscription Providers & Gating Tests', () {
    test('isHouseholdPremiumProvider reflects current household premium status', () async {
      final freeHousehold = HouseholdModel(
        id: 'h-1',
        name: 'شقة إسطنبول',
        inviteCode: 'IST001',
        isPremium: false,
        createdAt: DateTime.now(),
      );

      final proHousehold = HouseholdModel(
        id: 'h-2',
        name: 'فيلا بودروم',
        inviteCode: 'BOD002',
        isPremium: true,
        createdAt: DateTime.now(),
      );

      final freeRepo = FakeHouseholdRepository([freeHousehold]);
      final freeContainer = ProviderContainer(
        overrides: [
          householdRepositoryProvider.overrideWithValue(freeRepo),
        ],
      );
      await freeContainer.read(currentHouseholdProvider.future);
      expect(freeContainer.read(isHouseholdPremiumProvider), isFalse);
      freeContainer.dispose();

      final proRepo = FakeHouseholdRepository([proHousehold]);
      final proContainer = ProviderContainer(
        overrides: [
          householdRepositoryProvider.overrideWithValue(proRepo),
        ],
      );
      await proContainer.read(currentHouseholdProvider.future);
      expect(proContainer.read(isHouseholdPremiumProvider), isTrue);
      proContainer.dispose();
    });

    test('canCreateHouseholdProvider enforces Free Tier (1 household limit)', () async {
      final freeHousehold = HouseholdModel(
        id: 'h-1',
        name: 'شقة إسطنبول',
        inviteCode: 'IST001',
        isPremium: false,
        createdAt: DateTime.now(),
      );

      // 1. User with no households can create a household
      final emptyRepo = FakeHouseholdRepository([]);
      final emptyContainer = ProviderContainer(
        overrides: [
          householdRepositoryProvider.overrideWithValue(emptyRepo),
        ],
      );
      await emptyContainer.read(userHouseholdsProvider.future);
      await emptyContainer.read(currentHouseholdProvider.future);
      expect(emptyContainer.read(canCreateHouseholdProvider), isTrue);
      emptyContainer.dispose();

      // 2. Free user with 1 existing household cannot create another household
      final freeRepo = FakeHouseholdRepository([freeHousehold]);
      final freeUserContainer = ProviderContainer(
        overrides: [
          householdRepositoryProvider.overrideWithValue(freeRepo),
        ],
      );
      await freeUserContainer.read(userHouseholdsProvider.future);
      await freeUserContainer.read(currentHouseholdProvider.future);
      expect(freeUserContainer.read(canCreateHouseholdProvider), isFalse);
      freeUserContainer.dispose();
    });

    test('canCreateHouseholdProvider unlocks multi-home creation for Pro users', () async {
      final proHousehold1 = HouseholdModel(
        id: 'h-1',
        name: 'شقة إسطنبول',
        inviteCode: 'IST001',
        isPremium: true,
        createdAt: DateTime.now(),
      );
      final proHousehold2 = HouseholdModel(
        id: 'h-2',
        name: 'فيلا بودروم',
        inviteCode: 'BOD002',
        isPremium: true,
        createdAt: DateTime.now(),
      );

      // Pro user with households can create additional households
      final proRepo = FakeHouseholdRepository([proHousehold1, proHousehold2]);
      final proContainer = ProviderContainer(
        overrides: [
          householdRepositoryProvider.overrideWithValue(proRepo),
        ],
      );
      await proContainer.read(userHouseholdsProvider.future);
      await proContainer.read(currentHouseholdProvider.future);
      expect(proContainer.read(canCreateHouseholdProvider), isTrue);
      proContainer.dispose();
    });
  });

  group('ProBadge Widget Tests', () {
    testWidgets('renders standard PRO badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProBadge(),
          ),
        ),
      );

      expect(find.text('PRO'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('renders large Evim Pro badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProBadge(isLarge: true),
          ),
        ),
      );

      expect(find.text('Evim Pro'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });
  });
}
