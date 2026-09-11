import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evim/core/theme/app_colors.dart';
import 'package:evim/core/services/subscription_service.dart';
import 'package:evim/features/expenses/presentation/screens/bills_radar_screen.dart';
import 'package:evim/features/gov_guide/presentation/screens/gov_guides_screen.dart';
import 'package:evim/features/pantry/presentation/screens/pantry_screen.dart';
import 'package:evim/features/shopping/presentation/screens/shopping_screen.dart';
import 'package:evim/features/household/data/household_repository.dart';
import 'package:evim/features/household/domain/models/household_model.dart';
import 'package:evim/features/household/presentation/controllers/current_household_controller.dart';
import 'package:evim/features/household/presentation/screens/household_setup_screen.dart';
import 'package:evim/features/paywall/screens/paywall_screen.dart';
import 'package:evim/features/paywall/widgets/pro_badge.dart';
import 'package:evim/features/notifications/data/notification_repository.dart';
import 'package:evim/features/notifications/domain/models/notification_model.dart';
import 'package:evim/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:evim/features/auth/data/auth_repository.dart';
import 'package:evim/features/settings/presentation/screens/settings_screen.dart';
import 'package:evim/features/household/presentation/screens/household_members_screen.dart';

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
      isScrollControlled: true,
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
                              final canCreate = ref.read(canCreateHouseholdProvider);
                              if (!canCreate) {
                                Navigator.pop(sheetContext);
                                PaywallScreen.show(context, householdId: currentHousehold?.id);
                              } else {
                                Navigator.pop(sheetContext);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => const HouseholdSetupScreen(),
                                  ),
                                );
                              }
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

                          return ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 320),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const ClampingScrollPhysics(),
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
                                        isSelected ? AppColors.onPrimary : AppColors.primaryDark,
                                    child: const Icon(Icons.cottage_rounded),
                                  ),
                                  title: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          h.name,
                                          style: TextStyle(
                                            fontWeight:
                                                isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (h.isPremium) ...[
                                        const SizedBox(width: 8),
                                        const ProBadge(),
                                      ],
                                    ],
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
    // Listen for member_joined, join_request, and join_accepted notifications in real-time
    ref.listen<AsyncValue<List<NotificationModel>>>(notificationsStreamProvider, (prev, next) {
      final prevList = prev?.value ?? [];
      final nextList = next.value ?? [];

      if (prev != null && prev.hasValue) {
        final prevIds = prevList.map((n) => n.id).toSet();
        final newlyAdded = nextList.where((n) => !prevIds.contains(n.id)).toList();

        for (final notification in newlyAdded) {
          if (notification.type == NotificationType.memberJoined) {
            final currentH = ref.read(currentHouseholdProvider).value;
            if (currentH != null) {
              ref.invalidate(householdMembersProvider(currentH.id));
            }
            ref.invalidate(householdMembersProvider);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.primaryDark,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
                content: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.turquoise.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: AppColors.turquoise,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title.isNotEmpty ? notification.title : 'انضمام فرد جديد!',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            notification.body.isNotEmpty
                                ? notification.body
                                : 'انضم فرد جديد إلى مسكنكم بنجاح',
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 4),
              ),
            );
          } else if (notification.type == NotificationType.joinRequest) {
            ref.invalidate(notificationsProvider);
            ref.invalidate(unreadNotificationsCountProvider);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.primaryDark,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
                content: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF82C8E5).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Color(0xFF82C8E5),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title.isNotEmpty ? notification.title : 'طلب انضمام جديد 📬',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            notification.body.isNotEmpty
                                ? notification.body
                                : 'وصلك طلب انضمام جديد إلى المنزل',
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                action: SnackBarAction(
                  label: 'عرض',
                  textColor: const Color(0xFF82C8E5),
                  onPressed: () => NotificationsScreen.show(context),
                ),
                duration: const Duration(seconds: 6),
              ),
            );
          } else if (notification.type == NotificationType.joinAccepted) {
            ref.invalidate(userHouseholdsProvider);
            ref.invalidate(activeHouseholdProvider);
            ref.invalidate(currentHouseholdProvider);
            ref.invalidate(userHasHouseholdProvider);
            final currentH = ref.read(currentHouseholdProvider).value;
            if (currentH != null) {
              ref.invalidate(householdMembersProvider(currentH.id));
            }
            ref.invalidate(householdMembersProvider);
          }
        }
      }
    });

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
                  if (household?.isPremium == true) ...[
                    const SizedBox(width: 8),
                    const ProBadge(),
                  ],
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down_rounded, size: 22),
                ],
              ),
            ),
          ),
          actions: [
            Consumer(
              builder: (context, ref, _) {
                final unreadCount = ref.watch(unreadNotificationsCountProvider);
                return IconButton(
                  icon: Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text('$unreadCount'),
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  tooltip: 'الإشعارات والتذكيرات',
                  onPressed: () async {
                    final result = await Navigator.push<dynamic>(
                      context,
                      MaterialPageRoute<dynamic>(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                    if (result == 'open_bills') {
                      setState(() => _currentTabIndex = 4);
                    } else if (result == 'open_guides') {
                      setState(() => _currentTabIndex = 3);
                    }
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'الإعدادات والحساب',
              onPressed: () => SettingsScreen.show(context),
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
    final householdAsync = ref.watch(currentHouseholdProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return householdAsync.when(
          data: (currentHousehold) {
            if (currentHousehold == null) {
              return _buildEmptyState(context, ref, constraints);
            }
            return _buildContent(context, ref, currentHousehold, constraints);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(
                    'حدث خطأ في تحميل البيانات: $err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(currentHouseholdProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, BoxConstraints constraints) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.maxHeight,
          minWidth: constraints.maxWidth,
        ),
        child: IntrinsicHeight(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cottage_outlined,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد بيانات حالياً',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'لم يتم العثور على منزل مسجل. يمكنك إنشاء منزل جديد أو الانضمام بكود دعوة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const HouseholdSetupScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_home_rounded),
                        label: const Text('إعداد منزل جديد'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(currentHouseholdProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('تحديث'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    HouseholdModel currentHousehold,
    BoxConstraints constraints,
  ) {
    final membershipAsync = ref.watch(currentHouseholdMemberRoleProvider);
    final isPremium = currentHousehold.isPremium;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - 40,
            maxWidth: 540,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pro Upgrade Banner or Pro Status Card
              if (!isPremium)
                Card(
                  elevation: 0,
                  color: AppColors.warmAmber.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.warmAmber.withValues(alpha: 0.35)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.warmAmber.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.stars_rounded,
                            color: AppColors.warmAmber,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الترقية إلى Evim Pro 🚀',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimaryLight,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'إدارة عدة منازل وعائلة غير محدودة ورادار متقدم',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => PaywallScreen.show(
                            context,
                            householdId: currentHousehold.id,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warmAmber,
                            foregroundColor: const Color(0xFF451A03),
                            elevation: 0,
                            minimumSize: const Size(60, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          child: const Text('ترقية'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  elevation: 0,
                  color: AppColors.warmAmber.withValues(alpha: 0.06),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.warmAmber.withValues(alpha: 0.25)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Row(
                      children: [
                        ProBadge(isLarge: true),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'منزلك يتمتع بميزات Pro الفائقة',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textPrimaryLight,
                                ),
                              ),
                              Text(
                                'أعضاء غير محدودين، ومزامنة متعددة المنازل مفعّلة.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

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
                          foregroundColor: AppColors.onPrimary,
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
              const SizedBox(height: 16),

              // Household Members Card
              Consumer(
                builder: (context, ref, _) {
                  final membersAsync = ref.watch(householdMembersProvider(currentHousehold.id));
                  final count = membersAsync.maybeWhen(
                    data: (list) => list.length,
                    orElse: () => 1,
                  );

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.borderLight),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF82C8E5).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: Color(0xFF1E6F90),
                          size: 22,
                        ),
                      ),
                      title: const Text(
                        'أفراد العائلة والمنزل',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        '$count أفراد مسجلين في المنزل',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'إدارة الأفراد',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondaryLight),
                        ],
                      ),
                      onTap: () => HouseholdMembersScreen.show(context, currentHousehold),
                    ),
                  );
                },
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
