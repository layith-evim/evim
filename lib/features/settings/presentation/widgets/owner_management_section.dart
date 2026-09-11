import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../household/data/household_repository.dart';
import '../../../household/domain/models/household_model.dart';
import '../../../household/presentation/controllers/current_household_controller.dart';
import '../../../household/presentation/screens/household_members_screen.dart';
import '../../../paywall/screens/paywall_screen.dart';
import '../../../paywall/widgets/pro_badge.dart';

/// Control panel section exclusive to household owners
class OwnerManagementSection extends ConsumerWidget {
  final HouseholdModel household;

  const OwnerManagementSection({
    super.key,
    required this.household,
  });

  static const List<String> turkishCities = [
    'إسطنبول',
    'أنقرة',
    'إزمير',
    'بورصة',
    'أنطاليا',
    'غازي عنتاب',
    'مرسين',
    'طرابزون',
    'أخرى',
  ];

  void _showEditHouseholdDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: household.name);
    String selectedCity = household.city ?? turkishCities.first;
    if (!turkishCities.contains(selectedCity)) {
      selectedCity = 'أخرى';
    }

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'تعديل بيانات المنزل',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المنزل',
                      hintText: 'مثال: منزل إسطنبول الأساسي',
                      prefixIcon: Icon(Icons.cottage_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'المدينة / الولاية في تركيا',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCity,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    items: turkishCities.map((city) {
                      return DropdownMenuItem(
                        value: city,
                        child: Text(city, style: const TextStyle(fontSize: 13.5)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCity = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  if (newName.isNotEmpty) {
                    Navigator.pop(dialogCtx);
                    await ref.read(householdRepositoryProvider).updateHouseholdInfo(
                          householdId: household.id,
                          name: newName,
                          city: selectedCity,
                        );
                    // Refresh household state
                    ref.invalidate(currentHouseholdProvider);
                    ref.invalidate(userHouseholdsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('تم تحديث بيانات المنزل بنجاح'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('حفظ التعديلات'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyInviteCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: household.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('تم نسخ رمز الدعوة بنجاح'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(householdMembersProvider(household.id));
    final memberCount = membersAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_outlined, size: 18, color: AppColors.warmAmber),
            const SizedBox(width: 6),
            const Text(
              'لوحة تحكم مالك المنزل',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.warmAmber,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warmAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'صلاحيات المالك',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warmAmber,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.warmAmber.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          color: Colors.white,
          child: Column(
            children: [
              // Household info tile
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cottage_rounded, color: AppColors.primary, size: 20),
                ),
                title: Text(
                  household.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  household.city != null && household.city!.isNotEmpty
                      ? 'المدينة: ${household.city}'
                      : 'اضغط لتحديد مدينة المنزل في تركيا',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('تعديل', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showEditHouseholdDialog(context, ref),
                ),
              ),
              const Divider(height: 1, indent: 64, color: AppColors.borderLight),

              // Invite code & Member management
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.turquoise.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.group_add_rounded, color: AppColors.turquoise, size: 20),
                ),
                title: Row(
                  children: [
                    const Text(
                      'رمز الدعوة: ',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      household.inviteCode,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  'عدد الأفراد الحاليين: $memberCount أفراد',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.primary),
                      tooltip: 'نسخ رمز الدعوة',
                      onPressed: () => _copyInviteCode(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondaryLight),
                      tooltip: 'إدارة أفراد العائلة',
                      onPressed: () => HouseholdMembersScreen.show(context, household),
                    ),
                  ],
                ),
                onTap: () => HouseholdMembersScreen.show(context, household),
              ),
              const Divider(height: 1, indent: 64, color: AppColors.borderLight),

              // SaaS Subscription status card
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: household.isPremium
                        ? AppColors.warmAmber.withValues(alpha: 0.15)
                        : AppColors.borderLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    household.isPremium ? Icons.verified_rounded : Icons.star_outline_rounded,
                    color: household.isPremium ? AppColors.warmAmber : AppColors.textSecondaryLight,
                    size: 20,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      household.isPremium ? 'باقة Evim Pro (نشط)' : 'النسخة المجانية',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    if (household.isPremium) ...[
                      const SizedBox(width: 8),
                      const ProBadge(),
                    ],
                  ],
                ),
                subtitle: Text(
                  household.isPremium
                      ? 'تم تفعيل إدارة منازل غير محدودة وأفراد غير محدودين'
                      : 'منزل واحد وما يصل إلى فردين',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: household.isPremium ? AppColors.surfaceLight : AppColors.warmAmber,
                    foregroundColor: household.isPremium ? AppColors.primary : Colors.white,
                    elevation: 0,
                    minimumSize: const Size(70, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => PaywallScreen.show(context),
                  child: Text(
                    household.isPremium ? 'إدارة' : 'ترقية',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
