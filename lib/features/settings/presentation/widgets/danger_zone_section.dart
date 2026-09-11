import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../household/data/household_repository.dart';
import '../../../household/domain/models/household_model.dart';
import '../../../household/presentation/controllers/current_household_controller.dart';

/// Section for dangerous and security actions (Leave Household, Delete Household, Logout, Delete Account)
class DangerZoneSection extends ConsumerWidget {
  final HouseholdModel? household;
  final bool isOwner;

  const DangerZoneSection({
    super.key,
    required this.household,
    required this.isOwner,
  });

  void _confirmLeaveHousehold(BuildContext context, WidgetRef ref, String householdId) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'مغادرة المنزل',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: const Text(
            'هل أنت متأكد من مغادرة هذا المنزل؟ ستفقد إمكانية الوصول إلى الفواتير والمشتريات والمستندات الخاصة به.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await ref.read(householdRepositoryProvider).leaveHousehold(householdId);
                ref.invalidate(userHasHouseholdProvider);
                ref.invalidate(userHouseholdsProvider);
                ref.invalidate(currentHouseholdProvider);
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              child: const Text('تأكيد المغادرة'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteHousehold(BuildContext context, WidgetRef ref, HouseholdModel h) {
    final confirmController = TextEditingController();
    bool isMatch = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'حذف المنزل نهائياً',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.error),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سيتم حذف المنزل "${h.name}" وجميع السجلات والفواتير والمواد الخاصة به نهائياً.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                const Text(
                  'للتأكيد، يرجى كتابة اسم المنزل بدقة:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: confirmController,
                  decoration: InputDecoration(
                    hintText: h.name,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (val) {
                    setDialogState(() {
                      isMatch = val.trim() == h.name.trim();
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: isMatch
                    ? () async {
                        Navigator.pop(dialogCtx);
                        await ref.read(householdRepositoryProvider).deleteHousehold(h.id);
                        ref.invalidate(userHasHouseholdProvider);
                        ref.invalidate(userHouseholdsProvider);
                        ref.invalidate(currentHouseholdProvider);
                        if (context.mounted) {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        }
                      }
                    : null,
                child: const Text('حذف نهائي'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تسجيل الخروج'),
          content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.slateNavy,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;
    bool isLoading = false;
    String? errorMessage;

    showDialog<void>(
      context: context,
      barrierDismissible: !isLoading,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تأكيد حذف الحساب نهائياً',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'هذا الإجراء نهائي وسيتم مسح جميع بياناتك وفواتيرك ومستنداتك بشكل لا يمكن استرجاعه. يرجى إدخال كلمة المرور لتأكيد ملكية الحساب:',
                      style: TextStyle(fontSize: 13, height: 1.45),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الحالية',
                        hintText: 'أدخل كلمة مرور حسابك...',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'يرجى إدخال كلمة المرور';
                        }
                        return null;
                      },
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.error, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (formKey.currentState?.validate() ?? false) {
                          final password = passwordController.text;
                          setDialogState(() {
                            isLoading = true;
                            errorMessage = null;
                          });

                          try {
                            await ref
                                .read(authRepositoryProvider)
                                .deleteAccountWithPassword(password);

                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();

                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  content: Text('تم حذف الحساب والبيانات نهائياً'),
                                ),
                              );
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          } catch (e) {
                            debugPrint('Account deletion error: $e');
                            setDialogState(() {
                              isLoading = false;
                              if (e is AppException) {
                                if (e.code == 'INVALID_PASSWORD') {
                                  errorMessage = e.messageAr;
                                } else if (e.originalError != null) {
                                  errorMessage = '${e.messageAr}\nالتفاصيل: ${e.originalError}';
                                } else {
                                  errorMessage = e.messageAr;
                                }
                              } else {
                                errorMessage = e.toString().replaceAll('Exception:', '').trim();
                              }
                            });
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('حذف الحساب نهائياً'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            'منطقة الحساب والأمان',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.error.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          color: Colors.white,
          child: Column(
            children: [
              if (household != null) ...[
                if (isOwner)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 20),
                    ),
                    title: const Text(
                      'حذف المنزل بالكامل',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error),
                    ),
                    subtitle: const Text(
                      'حذف هذا المنزل وجميع سجلات المشتريات والفواتير',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                    onTap: () => _confirmDeleteHousehold(context, ref, household!),
                  )
                else
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.exit_to_app_rounded, color: AppColors.error, size: 20),
                    ),
                    title: const Text(
                      'مغادرة المنزل',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error),
                    ),
                    subtitle: const Text(
                      'الخروج من المنزل الحالي مع إمكانية الانضمام لاحقاً',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                    onTap: () => _confirmLeaveHousehold(context, ref, household!.id),
                  ),
                const Divider(height: 1, indent: 64, color: AppColors.borderLight),
              ],
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.slateNavy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded, color: AppColors.slateNavy, size: 20),
                ),
                title: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'تسجيل الخروج من الحساب الحالي على هذا الجهاز',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
                onTap: () => _confirmSignOut(context, ref),
              ),
              const Divider(height: 1, indent: 64, color: AppColors.borderLight),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_remove_outlined, color: AppColors.error, size: 20),
                ),
                title: const Text(
                  'حذف الحساب نهائياً',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error),
                ),
                subtitle: const Text(
                  'مسح كامل البيانات الشخصية والحساب نهائياً (KVKK)',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
                onTap: () => _confirmDeleteAccount(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
