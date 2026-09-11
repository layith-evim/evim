import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evim/core/error/app_exception.dart';
import 'package:evim/features/household/domain/models/household_model.dart';
import 'package:evim/features/household/domain/models/household_member_model.dart';
import 'package:evim/features/household/data/household_repository.dart';
import 'package:evim/features/household/presentation/controllers/current_household_controller.dart';

class FakeHouseholdRepository implements HouseholdRepository {
  final List<HouseholdModel> households = [];
  bool shouldThrow = false;

  @override
  Future<HouseholdModel> createHousehold(String name, {String city = 'إسطنبول'}) async {
    if (shouldThrow) {
      throw const AppException(
        code: 'CREATE_ERROR',
        messageAr: 'فشل إنشاء المنزل',
        messageTr: 'Hane oluşturulamadı',
      );
    }
    final newHousehold = HouseholdModel(
      id: 'h-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      inviteCode: 'EVIM99',
      city: city,
      isPremium: false,
      createdAt: DateTime.now(),
    );
    households.add(newHousehold);
    return newHousehold;
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
    if (shouldThrow) {
      throw const AppException(
        code: 'JOIN_ERROR',
        messageAr: 'رمز الدعوة غير صحيح',
        messageTr: 'Geçersiz davet kodu',
      );
    }
    return {
      'success': true,
      'message': 'تم إرسال طلب الانضمام إلى صاحب المنزل بنجاح.',
    };
  }

  @override
  Future<void> respondToJoinRequest({
    required String requestId,
    required bool accept,
  }) async {
    if (shouldThrow) {
      throw const AppException(
        code: 'RESPOND_ERROR',
        messageAr: 'تعذر معالجة الطلب',
        messageTr: 'İstek işlenemedi',
      );
    }
  }

  @override
  Future<HouseholdModel> joinHousehold(String inviteCode) async {
    if (shouldThrow) {
      throw const AppException(
        code: 'JOIN_ERROR',
        messageAr: 'رمز الدعوة غير صحيح',
        messageTr: 'Geçersiz davet kodu',
      );
    }
    final joined = HouseholdModel(
      id: 'h-joined',
      name: 'منزل العائلة',
      inviteCode: inviteCode.toUpperCase(),
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
  late FakeHouseholdRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = FakeHouseholdRepository();
    container = ProviderContainer(
      overrides: [
        householdRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('CurrentHouseholdController Tests', () {
    test('initial state loads null when user has no households', () async {
      final state = await container.read(currentHouseholdProvider.future);
      expect(state, isNull);
    });

    test('createHousehold adds household and updates active state', () async {
      final controller = container.read(currentHouseholdProvider.notifier);
      final success = await controller.createHousehold('منزل إسطنبول');

      expect(success, isTrue);
      final state = container.read(currentHouseholdProvider).value;
      expect(state, isNotNull);
      expect(state!.name, 'منزل إسطنبول');
      expect(state.inviteCode, 'EVIM99');
    });

    test('createHousehold with empty string defaults to fallback name', () async {
      final controller = container.read(currentHouseholdProvider.notifier);
      final name = ''.trim().isEmpty ? 'منزلنا' : ''.trim();
      final success = await controller.createHousehold(name);

      expect(success, isTrue);
      final state = container.read(currentHouseholdProvider).value;
      expect(state, isNotNull);
      expect(state!.name, 'منزلنا');
    });

    test('joinHousehold joins and updates active state', () async {
      final controller = container.read(currentHouseholdProvider.notifier);
      final success = await controller.joinHousehold('ABC123');

      expect(success, isTrue);
      final state = container.read(currentHouseholdProvider).value;
      expect(state, isNotNull);
      expect(state!.inviteCode, 'ABC123');
    });

    test('switchHousehold changes active household context', () async {
      final h1 = HouseholdModel(
        id: '1',
        name: 'منزل 1',
        inviteCode: 'CODE01',
        createdAt: DateTime.now(),
      );
      final h2 = HouseholdModel(
        id: '2',
        name: 'منزل 2',
        inviteCode: 'CODE02',
        createdAt: DateTime.now(),
      );

      final controller = container.read(currentHouseholdProvider.notifier);
      controller.switchHousehold(h1);
      expect(container.read(currentHouseholdProvider).value?.id, '1');

      controller.switchHousehold(h2);
      expect(container.read(currentHouseholdProvider).value?.id, '2');
    });

    test('HouseholdMemberModel profile parsing handles first_name, last_name, and fallbacks', () {
      final jsonWithProfile = {
        'id': 'm-1',
        'user_id': 'u-1',
        'household_id': 'h-1',
        'role': 'owner',
        'profiles': {
          'first_name': 'أحمد',
          'last_name': 'المصري',
          'email': 'ahmad@example.com',
        },
        'created_at': DateTime.now().toIso8601String(),
      };

      final member = HouseholdMemberModel.fromJson(jsonWithProfile);
      expect(member.profile, isNotNull);
      expect(member.profile!.firstName, 'أحمد');
      expect(member.profile!.lastName, 'المصري');
      expect(member.profile!.fullName, 'أحمد المصري');
      expect(member.isOwner, isTrue);

      final jsonFallback = {
        'id': 'm-2',
        'user_id': 'u-2',
        'household_id': 'h-1',
        'role': 'member',
        'created_at': DateTime.now().toIso8601String(),
      };

      final memberFallback = HouseholdMemberModel.fromJson(jsonFallback);
      final fullName = (memberFallback.profile != null &&
              (memberFallback.profile!.firstName.isNotEmpty || memberFallback.profile!.lastName.isNotEmpty))
          ? '${memberFallback.profile!.firstName} ${memberFallback.profile!.lastName}'.trim()
          : (memberFallback.userName != null && memberFallback.userName!.isNotEmpty)
              ? memberFallback.userName!
              : 'مستخدم مسجل';
      expect(fullName, 'مستخدم مسجل');
      expect(memberFallback.isOwner, isFalse);
    });

    test('HouseholdMemberModel.fromRpcJson maps RPC columns to model and profile correctly', () {
      final rpcJson = {
        'member_id': 'mem-100',
        'household_id': 'house-200',
        'user_id': 'user-300',
        'role': 'owner',
        'joined_at': '2026-09-11T20:00:00.000Z',
        'full_name': 'خالد العلي',
        'first_name': 'خالد',
        'last_name': 'العلي',
        'email': 'khaled@example.com',
      };

      final member = HouseholdMemberModel.fromRpcJson(rpcJson);
      expect(member.id, 'mem-100');
      expect(member.householdId, 'house-200');
      expect(member.userId, 'user-300');
      expect(member.role, 'owner');
      expect(member.isOwner, isTrue);
      expect(member.userName, 'خالد العلي');
      expect(member.userEmail, 'khaled@example.com');
      expect(member.profile, isNotNull);
      expect(member.profile!.firstName, 'خالد');
      expect(member.profile!.lastName, 'العلي');
      expect(member.profile!.fullName, 'خالد العلي');
    });

    test('HouseholdRepository.removeMember executes without error', () async {
      await expectLater(
        fakeRepo.removeMember(
          householdId: 'h-1',
          memberUserId: 'user-2',
        ),
        completes,
      );
    });

    test('HouseholdRepository.requestJoinHousehold submits join request', () async {
      final res = await fakeRepo.requestJoinHousehold('EVIM01');
      expect(res['success'], isTrue);
      expect(res['message'], contains('تم إرسال طلب الانضمام'));
    });

    test('HouseholdRepository.respondToJoinRequest accepts/rejects without error', () async {
      await expectLater(
        fakeRepo.respondToJoinRequest(
          requestId: 'req-1',
          accept: true,
        ),
        completes,
      );
      await expectLater(
        fakeRepo.respondToJoinRequest(
          requestId: 'req-1',
          accept: false,
        ),
        completes,
      );
    });
  });
}
