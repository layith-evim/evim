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
  Future<HouseholdModel> createHousehold(String name) async {
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
      isPremium: false,
      createdAt: DateTime.now(),
    );
    households.add(newHousehold);
    return newHousehold;
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
  });
}
