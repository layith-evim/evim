import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../providers/notification_settings_provider.dart';
import '../../providers/settings_provider.dart';

/// Section providing notification toggles, theme selector, and language options
class MemberPreferencesSection extends ConsumerWidget {
  const MemberPreferencesSection({super.key});

  void _showThemeSelector(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اختر مظهر التطبيق',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Text('☀️', style: TextStyle(fontSize: 22)),
                  title: const Text('النمط الفاتح النظيف'),
                  trailing: currentMode == ThemeMode.light
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                      : null,
                  onTap: () {
                    ref.read(themeProvider.notifier).setThemeMode(ThemeMode.light);
                    Navigator.pop(sheetCtx);
                  },
                ),
                ListTile(
                  leading: const Text('🌙', style: TextStyle(fontSize: 22)),
                  title: const Text('النمط الداكن المعتدل'),
                  trailing: currentMode == ThemeMode.dark
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                      : null,
                  onTap: () {
                    ref.read(themeProvider.notifier).setThemeMode(ThemeMode.dark);
                    Navigator.pop(sheetCtx);
                  },
                ),
                ListTile(
                  leading: const Text('⚙️', style: TextStyle(fontSize: 22)),
                  title: const Text('تلقائي (حسب النظام)'),
                  trailing: currentMode == ThemeMode.system
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                      : null,
                  onTap: () {
                    ref.read(themeProvider.notifier).setThemeMode(ThemeMode.system);
                    Navigator.pop(sheetCtx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageSelector(BuildContext context, WidgetRef ref, String currentLang) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'لغة التطبيق',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Text('🇸🇦', style: TextStyle(fontSize: 22)),
                  title: const Text('اللغة العربية'),
                  trailing: currentLang == 'ar'
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                      : null,
                  onTap: () {
                    ref.read(settingsProvider.notifier).setLanguage('ar');
                    Navigator.pop(sheetCtx);
                  },
                ),
                const ListTile(
                  leading: Text('🇹🇷', style: TextStyle(fontSize: 22)),
                  title: Text('Türkçe (قريباً)'),
                  subtitle: Text('Yakında kullanıma sunulacak'),
                  enabled: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '☀️ النمط الفاتح النظيف';
      case ThemeMode.dark:
        return '🌙 النمط الداكن المعتدل';
      case ThemeMode.system:
        return '⚙️ تلقائي (حسب النظام)';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifSettings = ref.watch(notificationSettingsProvider);
    final notifNotifier = ref.read(notificationSettingsProvider.notifier);
    final activeThemeMode = ref.watch(themeProvider);
    final userPrefs = ref.watch(settingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            'تفضيلات التطبيق والإشعارات',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.borderLight),
          ),
          color: Colors.white,
          child: Column(
            children: [
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warmAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: AppColors.warmAmber, size: 20),
                ),
                title: const Text(
                  'تنبيهات الفواتير والإيجار',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'تذكير ذكي قبل 3 أيام وفي نفس موعد الاستحقاق',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
                value: notifSettings.notifyBills,
                activeColor: AppColors.primary,
                onChanged: (val) => notifNotifier.toggleNotifyBills(val),
              ),
              const Divider(height: 1, indent: 64, color: AppColors.borderLight),
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.turquoise.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_rounded, color: AppColors.turquoise, size: 20),
                ),
                title: const Text(
                  'رادار الإقامات والمعاملات',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'تنبيه مبكر قبل 60 و 30 يوماً من انتهاء الإقامة والمستندات',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
                value: notifSettings.notifyResidency,
                activeColor: AppColors.primary,
                onChanged: (val) => notifNotifier.toggleNotifyResidency(val),
              ),
              const Divider(height: 1, indent: 64, color: AppColors.borderLight),
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shopping_cart_outlined, color: AppColors.primary, size: 20),
                ),
                title: const Text(
                  'تحديثات قائمة المؤونة والمشتريات',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'إشعارات عند إضافة مواد جديدة أو شراء أغراض القائمة',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
                value: notifSettings.notifyPantry,
                activeColor: AppColors.primary,
                onChanged: (val) => notifNotifier.toggleNotifyPantry(val),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.borderLight),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.slateNavy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.palette_outlined, color: AppColors.slateNavy, size: 20),
                ),
                title: const Text(
                  'مظهر التطبيق',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _themeModeLabel(activeThemeMode),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
                trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondaryLight),
                onTap: () => _showThemeSelector(context, ref, activeThemeMode),
              ),
              const Divider(height: 1, indent: 64, color: AppColors.borderLight),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.language_rounded, color: AppColors.primary, size: 20),
                ),
                title: const Text(
                  'لغة التطبيق',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'اللغة العربية',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
                trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondaryLight),
                onTap: () => _showLanguageSelector(context, ref, userPrefs.language),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
