import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evim/core/theme/app_colors.dart';
import 'package:evim/features/auth/data/auth_repository.dart';
import 'package:evim/features/household/presentation/controllers/current_household_controller.dart';
import 'package:evim/features/shopping/data/shopping_repository.dart';
import 'package:evim/features/shopping/domain/models/shopping_item_model.dart';

/// Categories configuration
const List<String> kShoppingCategories = [
  'الكل',
  'BİM',
  'A101',
  'Şok',
  'Migros',
  'بازار',
  'عام',
];

Color getCategoryColor(String category) {
  switch (category.trim().toUpperCase()) {
    case 'BİM':
    case 'BIM':
      return AppColors.bim;
    case 'A101':
      return AppColors.a101;
    case 'ŞOK':
    case 'SOK':
      return AppColors.sok;
    case 'MIGROS':
      return AppColors.migros;
    case 'بازار':
      return AppColors.bazaar;
    default:
      return AppColors.primary;
  }
}

/// Collaborative Shopping Screen with Realtime streaming and Turkish chain category filters
class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  String _selectedCategory = 'الكل';
  bool _showBoughtSection = true;

  void _openAddItemDialog(BuildContext context, String householdId) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => _AddShoppingItemDialog(householdId: householdId),
    );
  }

  void _confirmClearBought(BuildContext context, String householdId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف المشتريات المكتملة'),
          content: const Text('هل أنت متأكد من حذف جميع العناصر التي تم شراؤها؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.terracotta),
              onPressed: () async {
                Navigator.pop(ctx);
                final repo = ref.read(shoppingRepositoryProvider);
                await repo.clearBoughtItems(householdId);
              },
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentHousehold = ref.watch(currentHouseholdProvider).value;
    final shoppingListAsync = ref.watch(shoppingListStreamProvider);
    final user = ref.watch(authRepositoryProvider).currentUser;

    if (currentHousehold == null) {
      return const Center(child: Text('يرجى تحديد منزل'));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Column(
          children: [
            // Category Filter Bar
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: kShoppingCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = kShoppingCategories[index];
                  final isSelected = _selectedCategory == cat;
                  final catColor = cat == 'الكل' ? AppColors.primary : getCategoryColor(cat);

                  return ChoiceChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected
                            ? (cat == 'Şok' ? AppColors.sokText : Colors.white)
                            : Colors.white.withValues(alpha: 0.85),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: catColor,
                    backgroundColor: const Color(0xFF1E293B),
                    side: BorderSide(
                      color: isSelected ? catColor : Colors.white24,
                      width: 1,
                    ),
                    showCheckmark: false,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = cat);
                      }
                    },
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Items List
            Expanded(
              child: shoppingListAsync.when(
                data: (items) {
                  // Filter by category
                  final filteredItems = _selectedCategory == 'الكل'
                      ? items
                      : items.where((i) => i.category == _selectedCategory).toList();

                  final unbought = filteredItems.where((i) => !i.isBought).toList();
                  final bought = filteredItems.where((i) => i.isBought).toList();

                  if (filteredItems.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_basket_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            _selectedCategory == 'الكل'
                                ? 'قائمة المشتريات فارغة'
                                : 'لا توجد طلبات لـ $_selectedCategory',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // Unbought items
                      if (unbought.isNotEmpty) ...[
                        ...unbought.map((item) => _ShoppingItemTile(
                              item: item,
                              userEmail: user?.email,
                              onToggle: (val) {
                                ref.read(shoppingRepositoryProvider).toggleItemStatus(
                                      itemId: item.id,
                                      isBought: val,
                                      buyerEmail: user?.email,
                                    );
                              },
                              onDelete: () {
                                ref.read(shoppingRepositoryProvider).deleteItem(item.id);
                              },
                            )),
                      ],

                      // Bought items section
                      if (bought.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () => setState(() => _showBoughtSection = !_showBoughtSection),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Row(
                              children: [
                                Icon(
                                  _showBoughtSection
                                      ? Icons.keyboard_arrow_down_rounded
                                      : Icons.keyboard_arrow_left_rounded,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'تم شراؤها (${bought.length})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => _confirmClearBought(context, currentHousehold.id),
                                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                                  label: const Text('مسح المكتمل'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.terracotta,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showBoughtSection) ...[
                          ...bought.map((item) => _ShoppingItemTile(
                                item: item,
                                userEmail: user?.email,
                                onToggle: (val) {
                                  ref.read(shoppingRepositoryProvider).toggleItemStatus(
                                        itemId: item.id,
                                        isBought: val,
                                        buyerEmail: user?.email,
                                      );
                                },
                                onDelete: () {
                                  ref.read(shoppingRepositoryProvider).deleteItem(item.id);
                                },
                              )),
                        ],
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('تعذر تحميل قائمة المشتريات: $err'),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAddItemDialog(context, currentHousehold.id),
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: const Text('إضافة طلب'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  final ShoppingItemModel item;
  final String? userEmail;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _ShoppingItemTile({
    required this.item,
    required this.userEmail,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = getCategoryColor(item.category);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.isBought ? Colors.grey.shade200 : AppColors.borderLight,
        ),
      ),
      color: item.isBought ? Colors.grey.shade50 : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Checkbox(
          value: item.isBought,
          activeColor: AppColors.oliveGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          onChanged: (val) {
            if (val != null) onToggle(val);
          },
        ),
        title: Text(
          item.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: item.isBought ? FontWeight.normal : FontWeight.w600,
            decoration: item.isBought ? TextDecoration.lineThrough : null,
            color: item.isBought ? Colors.grey.shade500 : AppColors.textPrimaryLight,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.category,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: catColor,
                ),
              ),
            ),
            if (item.quantity.isNotEmpty && item.quantity != '1') ...[
              const SizedBox(width: 8),
              Text(
                'الكمية: ${item.quantity}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            if (item.isBought && item.boughtBy != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تم بواسطة: ${item.boughtBy!.split('@').first}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
          onPressed: onDelete,
          tooltip: 'حذف',
        ),
      ),
    );
  }
}

class _AddShoppingItemDialog extends ConsumerStatefulWidget {
  final String householdId;
  const _AddShoppingItemDialog({required this.householdId});

  @override
  ConsumerState<_AddShoppingItemDialog> createState() => _AddShoppingItemDialogState();
}

class _AddShoppingItemDialogState extends ConsumerState<_AddShoppingItemDialog> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  String _selectedCat = 'BİM';
  bool _isSubmitting = false;

  final List<String> _availableCats = ['BİM', 'A101', 'Şok', 'Migros', 'بازار', 'عام'];

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSubmitting = true);
    final repo = ref.read(shoppingRepositoryProvider);
    await repo.addItem(
      householdId: widget.householdId,
      name: name,
      category: _selectedCat,
      quantity: _quantityController.text.trim(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('إضافة طلب مشتريات'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'اسم الغرض أو السلعة',
                  hintText: 'مثال: حليب، بيض، خبز تركي',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'الكمية أو الحجم',
                  hintText: 'مثال: 1, 2 كجم, صندوق',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'اختر المتجر / المكان:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _availableCats.map((cat) {
                  final isSelected = _selectedCat == cat;
                  final color = getCategoryColor(cat);

                  return ChoiceChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected
                            ? (cat == 'Şok' ? AppColors.sokText : Colors.white)
                            : Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: color,
                    backgroundColor: const Color(0xFF1E293B),
                    side: BorderSide(
                      color: isSelected ? color : Colors.white24,
                      width: 1,
                    ),
                    showCheckmark: false,
                    onSelected: (val) {
                      if (val) setState(() => _selectedCat = cat);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}
