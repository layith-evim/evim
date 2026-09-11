import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/current_household_controller.dart';

enum HouseholdSetupMode { create, join }

/// Screen allowing new users to create their first home or join an existing one via invite code
class HouseholdSetupScreen extends ConsumerStatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  ConsumerState<HouseholdSetupScreen> createState() => _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends ConsumerState<HouseholdSetupScreen> {
  final _createFormKey = GlobalKey<FormState>();
  final _joinFormKey = GlobalKey<FormState>();

  final _homeNameController = TextEditingController(text: 'منزلنا');
  final _inviteCodeController = TextEditingController();

  HouseholdSetupMode _mode = HouseholdSetupMode.create;

  @override
  void dispose() {
    _homeNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _submitCreate() async {
    FocusScope.of(context).unfocus();
    if (!_createFormKey.currentState!.validate()) return;

    final name = _homeNameController.text.trim();
    final controller = ref.read(currentHouseholdProvider.notifier);
    await controller.createHousehold(name);
  }

  Future<void> _submitJoin() async {
    FocusScope.of(context).unfocus();
    if (!_joinFormKey.currentState!.validate()) return;

    final code = _inviteCodeController.text.trim();
    final controller = ref.read(currentHouseholdProvider.notifier);
    await controller.joinHousehold(code);
  }

  @override
  Widget build(BuildContext context) {
    final householdState = ref.watch(currentHouseholdProvider);
    final isLoading = householdState.isLoading;

    // Listen to errors
    ref.listen<AsyncValue<dynamic>>(currentHouseholdProvider, (_, next) {
      if (next.hasError) {
        final appException = AppException.fromGeneric(next.error);
        final errorMessage = appException.localizedMessage('ar');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.terracotta,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إعداد المنزل'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'تسجيل الخروج',
              onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.turquoise.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cottage_rounded,
                          size: 52,
                          color: AppColors.turquoise,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'خطوتك الأولى في إيفيم',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'قم بإنشاء مساحة لمنزلك أو انضم لمنزل شريك حياتك برمز الدعوة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Tab Selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TabButton(
                              title: 'إنشاء منزل جديد',
                              isSelected: _mode == HouseholdSetupMode.create,
                              onTap: () => setState(() => _mode = HouseholdSetupMode.create),
                            ),
                          ),
                          Expanded(
                            child: _TabButton(
                              title: 'الانضمام لمنزل',
                              isSelected: _mode == HouseholdSetupMode.join,
                              onTap: () => setState(() => _mode = HouseholdSetupMode.join),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Forms
                    if (_mode == HouseholdSetupMode.create) ...[
                      Form(
                        key: _createFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'اسم المنزل / المسكن',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _homeNameController,
                              decoration: const InputDecoration(
                                hintText: 'مثال: بيت إسطنبول، شقة باشاك شهير',
                                prefixIcon: Icon(Icons.home_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'يرجى كتابة اسم للمنزل.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: isLoading ? null : _submitCreate,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'إنشاء المنزل ومتابعة',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Form(
                        key: _joinFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'رمز الدعوة (6 خانات)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _inviteCodeController,
                              textCapitalization: TextCapitalization.characters,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                letterSpacing: 4,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'A1B2C3',
                                hintTextDirection: TextDirection.ltr,
                                prefixIcon: Icon(Icons.key_rounded),
                              ),
                              validator: (value) =>
                                  Validators.validateInviteCode(value, locale: 'ar'),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: isLoading ? null : _submitJoin,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'الانضمام إلى المنزل',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
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
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}
