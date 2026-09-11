import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../paywall/screens/paywall_screen.dart';
import '../../data/household_repository.dart';
import '../../domain/models/household_member_model.dart';
import '../../domain/models/household_model.dart';
import '../controllers/current_household_controller.dart';

/// Screen for viewing and managing household members and invite codes
class HouseholdMembersScreen extends ConsumerWidget {
  final HouseholdModel household;

  const HouseholdMembersScreen({
    super.key,
    required this.household,
  });

  static Future<void> show(BuildContext context, HouseholdModel household) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => HouseholdMembersScreen(household: household),
      ),
    );
  }

  void _copyInviteCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: household.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('تم نسخ رمز الدعوة (${household.inviteCode}) إلى الحافظة.'),
      ),
    );
  }

  Future<void> _confirmRemoveMember(
    BuildContext context,
    WidgetRef ref,
    HouseholdMemberModel member,
  ) async {
    final titleText = (member.profile != null && member.profile!.fullName.isNotEmpty)
        ? member.profile!.fullName
        : (member.userName != null && member.userName!.isNotEmpty)
            ? member.userName!
            : 'العضو';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'تأكيد إزالة العضو',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في إزالة $titleText من المنزل؟ لن يتمكن من الوصول لبيانات المسكن بعد الآن.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إزالة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(householdRepositoryProvider).removeMember(
              householdId: member.householdId.isNotEmpty ? member.householdId : household.id,
              memberUserId: member.userId,
            );
        ref.invalidate(householdMembersProvider(household.id));
        ref.invalidate(currentHouseholdMemberRoleProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
              content: Text('تمت إزالة العضو بنجاح'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
              content: Text('تعذر إزالة العضو: $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(householdMembersProvider(household.id));
    final currentRole = ref.watch(currentHouseholdMemberRoleProvider).value;
    String? currentUserId;
    String? currentUserEmail;
    try {
      currentUserId = Supabase.instance.client.auth.currentUser?.id;
      currentUserEmail = Supabase.instance.client.auth.currentUser?.email;
    } catch (_) {}
    currentUserId ??= ref.watch(authRepositoryProvider).currentUser?.id;
    currentUserEmail ??= ref.watch(authRepositoryProvider).currentUser?.email;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'أفراد المنزل والعائلة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(householdMembersProvider(household.id));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Invite code share card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                color: AppColors.primary.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.qr_code_rounded, color: AppColors.primary, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'رمز دعوة أفراد العائلة',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'شارك هذا الرمز مع أفراد عائلتك أو شركاء السكن للانضمام إلى هذا المنزل.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              household.inviteCode,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                              tooltip: 'نسخ الرمز',
                              onPressed: () => _copyInviteCode(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Members List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الأفراد المشتركون',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  membersAsync.maybeWhen(
                    data: (members) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${members.length} أفراد',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              membersAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('تعذر تحميل الأعضاء: $err'),
                  ),
                ),
                data: (members) {
                  if (members.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('لا يوجد أعضاء مسجلين بعد.'),
                      ),
                    );
                  }

                  final isCurrentUserOwner = (currentRole?.isOwner == true) ||
                      (currentUserId != null &&
                          members.any((m) =>
                              (m.userId == currentUserId ||
                                  (currentUserEmail != null &&
                                      currentUserEmail.isNotEmpty &&
                                      m.userEmail != null &&
                                      m.userEmail!.toLowerCase() == currentUserEmail.toLowerCase())) &&
                              m.isOwner)) ||
                      // Fallback: if only one owner exists and currentUser is null or matches owner
                      (members.where((m) => m.isOwner).length == 1 &&
                          (currentUserId == null ||
                              members.firstWhere((m) => m.isOwner).userId == currentUserId));

                  return Column(
                    children: members.map((m) {
                      final isMemberOwner = m.isOwner;
                      final profile = m.profile;
                      final titleText = (profile != null && profile.fullName.isNotEmpty)
                          ? profile.fullName
                          : (isMemberOwner ? 'مالك المنزل' : 'عضو في العائلة');

                      String getInitials(String name) {
                        final trimmed = name.trim();
                        if (trimmed.isEmpty) return '؟';
                        final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
                        if (parts.length == 1) {
                          return parts.first.characters.first;
                        }
                        return '${parts.first.characters.first}${parts.last.characters.first}';
                      }

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppColors.borderLight),
                        ),
                        color: Colors.white,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isMemberOwner
                                ? const Color(0xFFFFF3E0)
                                : const Color(0xFFE1F5FE),
                            child: Text(
                              getInitials(titleText),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isMemberOwner
                                    ? const Color(0xFFE65100)
                                    : const Color(0xFF0288D1),
                              ),
                            ),
                          ),
                          title: Text(
                            titleText,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            isMemberOwner ? 'المالك الأساسي' : 'عضو في العائلة',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. شارة الدور الحالية (مالك / عضو)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isMemberOwner
                                      ? const Color(0xFFFFF3E0)
                                      : const Color(0xFFE1F5FE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isMemberOwner ? 'المالك' : 'عضو',
                                  style: TextStyle(
                                    color: isMemberOwner
                                        ? const Color(0xFFE65100)
                                        : const Color(0xFF0288D1),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              // 2. زر الحذف: يظهر فقط إذا كان المستخدم الحالي مالكاً والعضو المستهدف ليس مالكاً
                              if (isCurrentUserOwner && !isMemberOwner) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.person_remove_rounded,
                                    color: Colors.redAccent,
                                    size: 22,
                                  ),
                                  tooltip: 'إزالة من المنزل',
                                  onPressed: () => _confirmRemoveMember(context, ref, m),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              if (!household.isPremium) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: AppColors.warmAmber.withValues(alpha: 0.3)),
                  ),
                  color: AppColors.warmAmber.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.warmAmber),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'الباقة المجانية تتيح حتى فردين كحد أقصى. قم بالترقية إلى Evim Pro لإضافة أفراد غير محدودين.',
                            style: TextStyle(fontSize: 12, height: 1.35),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => PaywallScreen.show(context),
                          child: const Text('ترقية'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
