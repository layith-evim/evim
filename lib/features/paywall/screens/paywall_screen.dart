import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evim/core/theme/app_colors.dart';
import 'package:evim/core/services/subscription_service.dart';
import 'package:evim/features/household/presentation/controllers/current_household_controller.dart';
import 'package:evim/features/household/data/household_repository.dart';

/// Modern Paywall Modal & Screen for Evim Pro Monetization
class PaywallScreen extends ConsumerStatefulWidget {
  final String? householdId;

  const PaywallScreen({super.key, this.householdId});

  /// Static helper to display the Paywall as a modal bottom sheet
  static Future<bool?> show(BuildContext context, {String? householdId}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaywallScreen(householdId: householdId),
    );
  }

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  PackageType _selectedPackage = PackageType.annual;
  bool _isProcessing = false;

  final List<({IconData icon, String title, String description})> _features = const [
    (
      icon: Icons.holiday_village_rounded,
      title: 'إدارة أكثر من منزل في وقت واحد',
      description: 'تنقل بسلاسة بين شقة إسطنبول، ومنزل العطلة في بودروم أو أنطاليا.',
    ),
    (
      icon: Icons.group_add_rounded,
      title: 'إضافة جميع أفراد العائلة دون قيود',
      description: 'مزامنة لحظية للقوائم والمصاريف مع العائلة وشركاء السكن.',
    ),
    (
      icon: Icons.alarm_on_rounded,
      title: 'رادار المواعيد والمهام الحرجة غير المحدود',
      description: 'تنبيهات ذكية ومبكرة لتجديد الإقامة، فحص TÜVTÜRK، وعقود الإيجار.',
    ),
    (
      icon: Icons.verified_user_rounded,
      title: 'أولوية التحديثات الحكومية',
      description: 'دليل شامل ومحدث لكافة الإجراءات الرسمية وبوابة E-Devlet.',
    ),
  ];

  Future<void> _handlePurchase() async {
    final activeHousehold = ref.read(currentHouseholdProvider).value;
    final targetHouseholdId = widget.householdId ?? activeHousehold?.id ?? '';

    if (targetHouseholdId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد منزل لتفعيل اشتراك Pro.'),
          backgroundColor: AppColors.terracotta,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final subService = ref.read(subscriptionServiceProvider);
      final success = await subService.purchasePackage(
        householdId: targetHouseholdId,
        packageType: _selectedPackage,
      );

      if (success) {
        // Refresh household states
        ref.invalidate(userHouseholdsProvider);
        ref.invalidate(currentHouseholdProvider);

        if (mounted) {
          navigator.pop(true);
          messenger.showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.oliveGreen,
              content: Row(
                children: [
                  Icon(Icons.stars_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    '🎉 تهانينا! تم تفعيل Evim Pro بنجاح لمنزلك.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('تعذر إتمام العملية: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    final activeHousehold = ref.read(currentHouseholdProvider).value;
    final targetHouseholdId = widget.householdId ?? activeHousehold?.id ?? '';

    if (targetHouseholdId.isEmpty) return;

    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final subService = ref.read(subscriptionServiceProvider);
      final isPremium = await subService.restorePurchases(householdId: targetHouseholdId);

      if (isPremium) {
        ref.invalidate(userHouseholdsProvider);
        ref.invalidate(currentHouseholdProvider);
        if (mounted) {
          Navigator.of(context).pop(true);
          messenger.showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.oliveGreen,
              content: Text('تم استعادة اشتراك Evim Pro بنجاح!'),
            ),
          );
        }
      } else {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('لم يتم العثور على اشتراكات سابقة لهذا الحساب.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('خطأ في استعادة المشتريات: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Drag Handle & Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Hero Icon & Title
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.warmAmber.withOpacity(0.2),
                        AppColors.primaryLight.withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    size: 48,
                    color: AppColors.warmAmber,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'الترقية إلى Evim Pro',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'إدارة شاملة لعدة منازل، عائلتك، ومواعيدك القانونية في تركيا بكل راحة بال',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Feature Highlights List
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: _features.map((f) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(f.icon, size: 20, color: AppColors.primaryDark),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  f.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Plan Selector (Annual vs. Monthly)
              ...SubscriptionService.availablePackages.map((pkg) {
                final isSelected = _selectedPackage == pkg.type;

                return GestureDetector(
                  onTap: () => setState(() => _selectedPackage = pkg.type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryLight.withOpacity(0.25)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryDark : AppColors.border,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    pkg.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (pkg.discountBadge != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.terracotta,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        pkg.discountBadge!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (pkg.monthlyEquivalent != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  pkg.monthlyEquivalent!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          pkg.formattedPrice,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Purchase CTA Button
              ElevatedButton(
                onPressed: _isProcessing ? null : _handlePurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.flash_on_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _selectedPackage == PackageType.annual
                                ? 'ابدأ الاشتراك السنوي وفر 30%'
                                : 'ابدأ الاشتراك الشهري',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),

              // Restore Purchases Button
              Center(
                child: TextButton(
                  onPressed: _isProcessing ? null : _handleRestore,
                  child: const Text(
                    'استعادة المشتريات السابقة (Restore Purchases)',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),

              // Terms & Privacy Note
              const SizedBox(height: 4),
              const Text(
                'يتم تجديد الاشتراك تلقائياً ويمكن إلغاؤه في أي وقت من إعدادات المتجر.\nبالاشتراك أنت توافق على شروط الاستخدام وسياسة الخصوصية.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
