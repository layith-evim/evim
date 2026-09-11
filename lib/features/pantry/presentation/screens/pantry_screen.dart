import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evim/core/theme/app_colors.dart';
import 'package:evim/features/household/presentation/controllers/current_household_controller.dart';
import 'package:evim/features/pantry/data/pantry_repository.dart';
import 'package:evim/features/pantry/domain/models/pantry_item_model.dart';
import 'package:evim/features/shopping/presentation/screens/shopping_screen.dart';

/// Kitchen Pantry Screen tracking on-hand items with single-tap shopping transfer
class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  void _openAddPantryDialog(BuildContext context, String householdId) {
    showDialog<void>(
      context: context,
      builder: (_) => _AddPantryItemDialog(householdId: householdId),
    );
  }

  void _transferItemToShopping(PantryItemModel item) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => _TransferToShoppingDialog(pantryItem: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentHousehold = ref.watch(currentHouseholdProvider).value;
    final pantryListAsync = ref.watch(pantryListProvider);

    if (currentHousehold == null) {
      return const Center(child: Text('يرجى اختيار منزل'));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: pantryListAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.kitchen_rounded, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'المؤونة فارغة حالياً',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'أضف الأغذية والمواد المتوفرة في مطبخك لتتبعها بسهولة',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.borderLight),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.turquoise.withValues(alpha: 0.12),
                      child: const Icon(Icons.inventory_2_outlined, color: AppColors.turquoise, size: 20),
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Text(
                      'الكمية المتوفرة: ${item.quantity}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _transferItemToShopping(item),
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                          label: const Text('نقل للمشتريات', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warmAmber.withValues(alpha: 0.15),
                            foregroundColor: Colors.brown.shade800,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(60, 34),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.grey),
                          tooltip: 'حذف',
                          onPressed: () async {
                            final repo = ref.read(pantryRepositoryProvider);
                            await repo.deletePantryItem(item.id);
                            ref.invalidate(pantryListProvider);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('تعذر تحميل المؤونة: $err')),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAddPantryDialog(context, currentHousehold.id),
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: const Text('إضافة للمؤونة'),
          backgroundColor: AppColors.turquoise,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

class _AddPantryItemDialog extends ConsumerStatefulWidget {
  final String householdId;
  const _AddPantryItemDialog({required this.householdId});

  @override
  ConsumerState<_AddPantryItemDialog> createState() => _AddPantryItemDialogState();
}

class _AddPantryItemDialogState extends ConsumerState<_AddPantryItemDialog> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  bool _isSubmitting = false;

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
    final repo = ref.read(pantryRepositoryProvider);
    await repo.addPantryItem(
      householdId: widget.householdId,
      name: name,
      quantity: _quantityController.text.trim(),
    );
    ref.invalidate(pantryListProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('إضافة عنصر للمؤونة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم المادة في المطبخ',
                hintText: 'مثال: أرز، زيت زيتون، سكر',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'الكمية الحالية',
                hintText: 'مثال: 2 كجم, 3 علب',
              ),
            ),
          ],
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
                : const Text('حفظ في المؤونة'),
          ),
        ],
      ),
    );
  }
}

class _TransferToShoppingDialog extends ConsumerStatefulWidget {
  final PantryItemModel pantryItem;
  const _TransferToShoppingDialog({required this.pantryItem});

  @override
  ConsumerState<_TransferToShoppingDialog> createState() => _TransferToShoppingDialogState();
}

class _TransferToShoppingDialogState extends ConsumerState<_TransferToShoppingDialog> {
  String _selectedCat = 'BİM';
  final List<String> _categories = ['BİM', 'A101', 'Şok', 'Migros', 'بازار', 'عام'];
  bool _isTransferring = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('نقل إلى قائمة المشتريات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل نفدت مادة (${widget.pantryItem.name}) وترغب بنقلها إلى قائمة التسوق؟',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'اختر متجر الشراء المفضل:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _categories.map((cat) {
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
        actions: [
          TextButton(
            onPressed: _isTransferring ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _isTransferring
                ? null
                : () async {
                    setState(() => _isTransferring = true);
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    final itemName = widget.pantryItem.name;
                    final category = _selectedCat;
                    final repo = ref.read(pantryRepositoryProvider);
                    await repo.transferToShopping(
                      pantryItem: widget.pantryItem,
                      category: category,
                    );
                    ref.invalidate(pantryListProvider);
                    if (mounted) {
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.oliveGreen,
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                            'تم نقل $itemName إلى قائمة المشتريات ($category)',
                            textAlign: TextAlign.right,
                          ),
                        ),
                      );
                    }
                  },
            child: _isTransferring
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('تأكيد النقل'),
          ),
        ],
      ),
    );
  }
}
