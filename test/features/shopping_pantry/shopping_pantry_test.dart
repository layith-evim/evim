import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evim/features/household/presentation/controllers/current_household_controller.dart';
import 'package:evim/features/household/domain/models/household_model.dart';
import 'package:evim/features/shopping/domain/models/shopping_item_model.dart';
import 'package:evim/features/shopping/data/shopping_repository.dart';
import 'package:evim/features/pantry/domain/models/pantry_item_model.dart';
import 'package:evim/features/pantry/data/pantry_repository.dart';

class FakeShoppingRepository implements ShoppingRepository {
  final List<ShoppingItemModel> items = [];
  final _streamController = StreamController<List<ShoppingItemModel>>.broadcast();

  @override
  Stream<List<ShoppingItemModel>> streamShoppingItems(String householdId) {
    return _streamController.stream;
  }

  @override
  Future<void> addItem({
    required String householdId,
    required String name,
    required String category,
    String quantity = '1',
  }) async {
    final newItem = ShoppingItemModel(
      id: 'item-${items.length + 1}',
      householdId: householdId,
      name: name,
      category: category,
      quantity: quantity,
      isBought: false,
      createdAt: DateTime.now(),
    );
    items.add(newItem);
    _streamController.add(List.from(items));
  }

  @override
  Future<void> toggleItemStatus({
    required String itemId,
    required bool isBought,
    required String? buyerEmail,
  }) async {
    final index = items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      items[index] = items[index].copyWith(
        isBought: isBought,
        boughtBy: isBought ? buyerEmail : null,
      );
      _streamController.add(List.from(items));
    }
  }

  @override
  Future<void> deleteItem(String itemId) async {
    items.removeWhere((i) => i.id == itemId);
    _streamController.add(List.from(items));
  }

  @override
  Future<void> clearBoughtItems(String householdId) async {
    items.removeWhere((i) => i.householdId == householdId && i.isBought);
    _streamController.add(List.from(items));
  }

  void dispose() {
    _streamController.close();
  }
}

class FakePantryRepository implements PantryRepository {
  final List<PantryItemModel> pantryItems = [];

  @override
  Future<List<PantryItemModel>> getPantryItems(String householdId) async {
    return pantryItems.where((p) => p.householdId == householdId).toList();
  }

  @override
  Future<void> addPantryItem({
    required String householdId,
    required String name,
    String quantity = '1',
  }) async {
    pantryItems.add(
      PantryItemModel(
        id: 'p-${pantryItems.length + 1}',
        householdId: householdId,
        name: name,
        quantity: quantity,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> deletePantryItem(String itemId) async {
    pantryItems.removeWhere((p) => p.id == itemId);
  }

  @override
  Future<void> transferToShopping({
    required PantryItemModel pantryItem,
    required String category,
  }) async {
    deletePantryItem(pantryItem.id);
  }
}

void main() {
  late FakeShoppingRepository fakeShoppingRepo;
  late FakePantryRepository fakePantryRepo;
  late ProviderContainer container;

  final testHousehold = HouseholdModel(
    id: 'h-1',
    name: 'منزلنا',
    inviteCode: 'EVIM01',
    createdAt: DateTime.now(),
  );

  setUp(() {
    fakeShoppingRepo = FakeShoppingRepository();
    fakePantryRepo = FakePantryRepository();
    container = ProviderContainer(
      overrides: [
        shoppingRepositoryProvider.overrideWithValue(fakeShoppingRepo),
        pantryRepositoryProvider.overrideWithValue(fakePantryRepo),
        currentHouseholdProvider.overrideWith(() => _MockHouseholdNotifier(testHousehold)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    fakeShoppingRepo.dispose();
  });

  group('Phase 3 Collaborative Shopping & Pantry Tests', () {
    test('add shopping item and toggle bought status with buyer stamp', () async {
      await fakeShoppingRepo.addItem(
        householdId: 'h-1',
        name: 'حليب كامل الدسم',
        category: 'BİM',
        quantity: '2',
      );

      expect(fakeShoppingRepo.items.length, 1);
      expect(fakeShoppingRepo.items.first.name, 'حليب كامل الدسم');
      expect(fakeShoppingRepo.items.first.category, 'BİM');
      expect(fakeShoppingRepo.items.first.isBought, isFalse);

      await fakeShoppingRepo.toggleItemStatus(
        itemId: fakeShoppingRepo.items.first.id,
        isBought: true,
        buyerEmail: 'spouse@evim.app',
      );

      expect(fakeShoppingRepo.items.first.isBought, isTrue);
      expect(fakeShoppingRepo.items.first.boughtBy, 'spouse@evim.app');
    });

    test('clear bought items removes only purchased elements', () async {
      await fakeShoppingRepo.addItem(householdId: 'h-1', name: 'سكر', category: 'A101');
      await fakeShoppingRepo.addItem(householdId: 'h-1', name: 'شاي تركي', category: 'Şok');

      await fakeShoppingRepo.toggleItemStatus(
        itemId: fakeShoppingRepo.items.first.id,
        isBought: true,
        buyerEmail: 'user@evim.app',
      );

      await fakeShoppingRepo.clearBoughtItems('h-1');

      expect(fakeShoppingRepo.items.length, 1);
      expect(fakeShoppingRepo.items.first.name, 'شاي تركي');
    });

    test('pantry item add and deletion', () async {
      await fakePantryRepo.addPantryItem(
        householdId: 'h-1',
        name: 'زيت زيتون تركي',
        quantity: '1 لتر',
      );

      final list = await fakePantryRepo.getPantryItems('h-1');
      expect(list.length, 1);
      expect(list.first.name, 'زيت زيتون تركي');

      await fakePantryRepo.deletePantryItem(list.first.id);
      final emptyList = await fakePantryRepo.getPantryItems('h-1');
      expect(emptyList.isEmpty, isTrue);
    });
  });
}

class _MockHouseholdNotifier extends CurrentHouseholdController {
  final HouseholdModel _mock;
  _MockHouseholdNotifier(this._mock);

  @override
  FutureOr<HouseholdModel?> build() => _mock;
}
