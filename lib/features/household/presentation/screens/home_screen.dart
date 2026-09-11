import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evim/core/theme/app_colors.dart';
import 'package:evim/features/auth/presentation/controllers/auth_controller.dart';
import 'package:evim/features/expenses/presentation/screens/bills_radar_screen.dart';
import 'package:evim/features/gov_guide/presentation/screens/gov_guides_screen.dart';
import 'package:evim/features/pantry/presentation/screens/pantry_screen.dart';
import 'package:evim/features/shopping/presentation/screens/shopping_screen.dart';
import 'package:evim/features/household/data/household_repository.dart';
import 'package:evim/features/household/presentation/controllers/current_household_controller.dart';
import 'package:evim/features/household/presentation/screens/household_setup_screen.dart';

/// Main Home Screen featuring NavigationBar with 5 tabs: Overview, Shopping, Pantry, Gov Guides, and Bills/Radar
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentTabIndex = 0;

  void _showHouseholdSwitcher(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Consumer(
                builder: (context, ref, _) {
                  final householdsAsync = ref.watch(userHouseholdsProvider);
                  final currentHousehold = ref.watch(currentHouseholdProvider).value;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'منازلك المسجلة',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_home_rounded, color: AppColors.primary),
                            tooltip: 'إضافة أو انضمام لمنزل آخر',
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const HouseholdSetupScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      householdsAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (err, _) => Center(
                          child: Text(
                            'خطأ في جلب المنازل: $err',
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                        data: (households) {
                          if (households.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('لا توجد منازل مسجلة'),
                            );
                          }

                          return Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: households.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final h = households[index];
                                final isSelected = h.id == currentHousehold?.id;

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isSelected
                                        ? AppColors.primary
                                        : AppColors.primary.withValues(alpha: 0.1),
                                    foregroundColor:
                                        isSelected ? Colors.white : AppColors.primary,
                                    child: const Icon(Icons.cottage_rounded),
                                  ),
                                  title: Text(
                                    h.name,
                                    style: TextStyle(
                                      fontWeight:
                                          isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text('كود الدعوة: ${h.inviteCode}'),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded,
                                          color: AppColors.primary)
                                      : null,
                                  onTap: () {
                                    ref
                                        .read(currentHouseholdProvider.notifier)
                                        .switchHousehold(h);
                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final household = ref.watch(currentHouseholdProvider).value;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: InkWell(
            onTap: () => _showHouseholdSwitcher(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cottage_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    household?.name ?? 'منزلي',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down_rounded, size: 22),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'تسجيل الخروج',
              onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentTabIndex,
          children: [
            _OverviewTab(onNavigateToTab: (index) => setState(() => _currentTabIndex = index)),
            const ShoppingScreen(),
            const PantryScreen(),
            const GovGuidesScreen(),
            const BillsRadarScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentTabIndex,
          onDestinationSelected: (index) {
            setState(() => _currentTabIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.cottage_outlined),
              selectedIcon: Icon(Icons.cottage_rounded),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined),
              selectedIcon: Icon(Icons.shopping_cart_rounded),
              label: 'المشتريات',
            ),
            NavigationDestination(
              icon: Icon(Icons.kitchen_outlined),
              selectedIcon: Icon(Icons.kitchen_rounded),
              label: 'المؤونة',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_outlined),
              selectedIcon: Icon(Icons.account_balance_rounded),
              label: 'المعاملات',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics_rounded),
              label: 'الرادار',
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab 1: Overview & Household Invite Information
class _OverviewTab extends ConsumerWidget {
  final ValueChanged<int>? onNavigateToTab;
  const _OverviewTab({this.onNavigateToTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentHousehold = ref.watch(currentHouseholdProvider).value;
    final membershipAsync = ref.watch(currentHouseholdMemberRoleProvider);

    if (currentHousehold == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Invite Code & Share Card
              Card(
                elevation: 0,
                color: AppColors.primary.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.key_rounded, color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'رمز دعوة العائلة / الشريك',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Text(
                          currentHousehold.inviteCode,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: currentHousehold.inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.oliveGreen,
                              content: Text(
                                'تم نسخ رمز الدعوة بنجاح! شاركه مع عائلتك.',
                                textAlign: TextAlign.right,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('نسخ كود الدعوة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(180, 42),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Membership Role Card
              membershipAsync.when(
                data: (membership) {
                  final isOwner = membership?.isOwner ?? false;
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.borderLight),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isOwner
                                ? AppColors.warmAmber.withValues(alpha: 0.15)
                                : AppColors.turquoise.withValues(alpha: 0.15),
                            child: Icon(
                              isOwner ? Icons.star_rounded : Icons.person_rounded,
                              color: isOwner ? AppColors.warmAmber : AppColors.turquoise,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isOwner ? 'أنت مالك هذا المنزل (Owner)' : 'أنت عضو في هذا المنزل (Member)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isOwner
                                      ? 'يمكنك إدارة المشتركين والاشتراكات ومشاركة المهام'
                                      : 'يمكنك تعديل القوائم ومزامنة المشتريات والفواتير في الوقت الفعلي',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),

              // Quick Navigation Actions
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إجراءات سريعة للمنزل',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.add_shopping_cart_rounded,
                              color: AppColors.primary,
                              label: 'المشتريات',
                              onTap: () => onNavigateToTab?.call(1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.kitchen_rounded,
                              color: AppColors.turquoise,
                              label: 'المؤونة',
                              onTap: () => onNavigateToTab?.call(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.account_balance_rounded,
                              color: AppColors.warmAmber,
                              label: 'المعاملات',
                              onTap: () => onNavigateToTab?.call(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.analytics_rounded,
                              color: AppColors.error,
                              label: 'الرادار',
                              onTap: () => onNavigateToTab?.call(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Gov Guide Featured Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                color: AppColors.primary.withValues(alpha: 0.04),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'دليل المعاملات الحكومية',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'تثبيت النفوس، العدادات، والرقم الضريبي خطوة بخطوة',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => onNavigateToTab?.call(3),
                        child: const Text('استعراض'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
