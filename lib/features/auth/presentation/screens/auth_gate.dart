import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../household/presentation/screens/home_screen.dart';
import '../../../household/presentation/screens/household_setup_screen.dart';
import '../../data/auth_repository.dart';
import '../controllers/auth_controller.dart';
import 'auth_screen.dart';

/// Intelligent route dispatcher listening to session changes and household status
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStateAsync = ref.watch(authStateChangesProvider);

    return authStateAsync.when(
      data: (authState) {
        final session = authState.session;

        // 1. Not Authenticated -> AuthScreen
        if (session == null) {
          return const AuthScreen();
        }

        // 2. Authenticated -> Check whether user has joined or created a household
        final householdCheckAsync = ref.watch(userHasHouseholdProvider);

        return householdCheckAsync.when(
          data: (hasHousehold) {
            if (hasHousehold) {
              return const HomeScreen();
            } else {
              return const HouseholdSetupScreen();
            }
          },
          loading: () => const _SplashScreen(statusText: 'جاري التحقق من بيانات المنزل...'),
          error: (error, _) => _ErrorRetryScreen(
            message: 'تعذر التحقق من اشتراك المنزل.',
            onRetry: () => ref.invalidate(userHasHouseholdProvider),
            onSignOut: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        );
      },
      loading: () => const _SplashScreen(statusText: 'جاري استعادة الجلسة...'),
      error: (error, _) => const AuthScreen(),
    );
  }
}

/// Animated splash & loading screen
class _SplashScreen extends StatelessWidget {
  final String statusText;
  const _SplashScreen({required this.statusText});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.home_work_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                statusText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fallback error screen with retry and signout options
class _ErrorRetryScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  const _ErrorRetryScreen({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 56,
                  color: AppColors.terracotta,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onSignOut,
                  child: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
