import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../error/app_exception.dart';
import '../services/supabase_service.dart';
import '../../features/household/presentation/controllers/current_household_controller.dart';
import '../../features/household/data/household_repository.dart';

/// Available subscription package types
enum PackageType { monthly, annual }

/// Representation of a Subscription model in Evim with default active Free tier
class SubscriptionModel {
  final String planTier; // 'free' or 'pro'
  final String status;   // 'active', 'expired', 'cancelled'
  final bool isPremium;

  const SubscriptionModel({
    this.planTier = 'free',
    this.status = 'active',
    this.isPremium = false,
  });

  bool get isPro => planTier.toLowerCase() == 'pro' || isPremium;

  @override
  String toString() => 'SubscriptionModel(planTier: $planTier, status: $status, isPremium: $isPremium)';
}

/// Representation of a Subscription package in Evim
class SubscriptionPackage {
  final String id;
  final PackageType type;
  final String title;
  final double price;
  final String currency;
  final String period;
  final String? discountBadge;
  final String? monthlyEquivalent;

  const SubscriptionPackage({
    required this.id,
    required this.type,
    required this.title,
    required this.price,
    this.currency = '₺',
    required this.period,
    this.discountBadge,
    this.monthlyEquivalent,
  });

  String get formattedPrice => '${price.toStringAsFixed(2)} $currency / $period';
}

/// Core Subscription & In-App Purchase Service (Mock-Ready for Web/Cross-Platform)
class SubscriptionService {
  final SupabaseClient _client;

  SubscriptionService([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  /// Default subscription packages in Turkish Liras (₺)
  static const List<SubscriptionPackage> availablePackages = [
    SubscriptionPackage(
      id: 'evim_pro_annual',
      type: PackageType.annual,
      title: 'باقة سنوية',
      price: 899.99,
      period: 'سنة',
      discountBadge: 'وفر 30%',
      monthlyEquivalent: '74.99 ₺ / شهرياً',
    ),
    SubscriptionPackage(
      id: 'evim_pro_monthly',
      type: PackageType.monthly,
      title: 'باقة شهرية',
      price: 109.99,
      period: 'شهر',
      monthlyEquivalent: '109.99 ₺ / شهرياً',
    ),
  ];

  /// Retrieves household subscription details with graceful Free Tier fallback
  Future<SubscriptionModel> getHouseholdSubscription(String householdId) async {
    if (householdId.isEmpty) {
      return const SubscriptionModel(planTier: 'free', status: 'active', isPremium: false);
    }

    try {
      final response = await _client
          .from(AppConstants.tableHouseholds)
          .select('is_premium')
          .eq('id', householdId)
          .maybeSingle();

      if (response == null) {
        return const SubscriptionModel(planTier: 'free', status: 'active', isPremium: false);
      }

      final isPremium = response['is_premium'] as bool? ?? false;
      return SubscriptionModel(
        planTier: isPremium ? 'pro' : 'free',
        status: 'active',
        isPremium: isPremium,
      );
    } catch (e) {
      debugPrint('Subscription check fallback: $e');
      return const SubscriptionModel(planTier: 'free', status: 'active', isPremium: false);
    }
  }

  /// Checks if a household currently has active premium entitlement with graceful fallback
  Future<bool> checkHouseholdPremium(String householdId) async {
    if (householdId.isEmpty) return false;
    try {
      final response = await _client
          .from(AppConstants.tableHouseholds)
          .select('is_premium')
          .eq('id', householdId)
          .maybeSingle();

      if (response == null) return false;
      return response['is_premium'] as bool? ?? false;
    } catch (e) {
      debugPrint('Subscription check fallback: $e');
      return false;
    }
  }

  /// Triggers a purchase for the given package and upgrades the household to Pro
  Future<bool> purchasePackage({
    required String householdId,
    required PackageType packageType,
  }) async {
    if (householdId.isEmpty) {
      throw const AppException(
        code: 'HOUSEHOLD_REQUIRED',
        messageAr: 'يرجى تحديد منزل لتفعيل الاشتراك.',
        messageTr: 'Aboneliği etkinleştirmek için bir hane seçmelisiniz.',
      );
    }

    try {
      // Simulate network / store processing latency
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Update household record in Supabase
      await _client
          .from(AppConstants.tableHouseholds)
          .update({'is_premium': true})
          .eq('id', householdId);

      return true;
    } on PostgrestException catch (e, st) {
      throw AppException.fromPostgrest(e, st);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }

  /// Restores previous purchases
  Future<bool> restorePurchases({required String householdId}) async {
    if (householdId.isEmpty) return false;

    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return await checkHouseholdPremium(householdId);
    } catch (e, st) {
      throw AppException.fromSupabase(e, st);
    }
  }
}

/// Provider for SubscriptionService
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

/// Async Family provider for household subscription with guaranteed Free fallback
final householdSubscriptionProvider =
    FutureProvider.family.autoDispose<SubscriptionModel, String>((ref, householdId) async {
  try {
    final service = ref.watch(subscriptionServiceProvider);
    return await service.getHouseholdSubscription(householdId);
  } catch (e) {
    debugPrint('Subscription check fallback: $e');
    return const SubscriptionModel(planTier: 'free', status: 'active', isPremium: false);
  }
});

/// Tracks premium entitlement status of the currently active household
final isHouseholdPremiumProvider = Provider<bool>((ref) {
  try {
    final household = ref.watch(currentHouseholdProvider).value;
    return household?.isPremium ?? false;
  } catch (e) {
    debugPrint('Subscription check fallback: $e');
    return false;
  }
});

/// Evaluates if the current user can create an additional household (Freemium gating rule)
/// Free Tier: 1 household. Pro Tier: Unlimited households.
final canCreateHouseholdProvider = Provider<bool>((ref) {
  try {
    final householdsAsync = ref.watch(userHouseholdsProvider);
    final isCurrentPro = ref.watch(isHouseholdPremiumProvider);

    return householdsAsync.maybeWhen(
      data: (households) {
        if (isCurrentPro) return true;
        // Free users can only create 1 household
        return households.isEmpty;
      },
      orElse: () => true,
    );
  } catch (e) {
    debugPrint('Subscription check fallback: $e');
    return true;
  }
});
