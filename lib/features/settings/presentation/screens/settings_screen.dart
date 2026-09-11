import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../household/presentation/controllers/current_household_controller.dart';
import '../widgets/danger_zone_section.dart';
import '../widgets/member_preferences_section.dart';
import '../widgets/owner_management_section.dart';
import '../widgets/profile_header_card.dart';

/// Main screen for User Profile, Preferences, and Household Management
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeHousehold = ref.watch(currentHouseholdProvider).value;
    final currentMember = ref.watch(currentHouseholdMemberRoleProvider).value;
    final isOwner = currentMember?.isOwner ?? false;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'الإعدادات والحساب',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Profile Header Card
              ProfileHeaderCard(isOwner: isOwner),
              const SizedBox(height: 16),

              // 2. Owner Exclusive Management Section
              if (isOwner && activeHousehold != null) ...[
                OwnerManagementSection(household: activeHousehold),
                const SizedBox(height: 16),
              ],

              // 3. Member Preferences Section (Common to all members)
              const MemberPreferencesSection(),
              const SizedBox(height: 16),

              // 4. Danger Zone / Account Actions Section
              DangerZoneSection(
                household: activeHousehold,
                isOwner: isOwner,
              ),
              const SizedBox(height: 32),

              // 5. Version and Footer
              const Center(
                child: Text(
                  'Evim v1.0.0 — صنع للمقيمين في تركيا 🇹🇷',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
