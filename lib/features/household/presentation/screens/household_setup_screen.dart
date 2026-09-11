import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../notifications/data/notification_repository.dart';
import '../../../notifications/domain/models/notification_model.dart';
import '../../data/household_repository.dart';
import '../controllers/current_household_controller.dart';
import 'home_screen.dart';

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
  bool _isCreating = false;
  bool _isJoining = false;

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  RealtimeChannel? _membershipChannel;

  @override
  void initState() {
    super.initState();
    _setupRealtimeMembershipListener();
  }

  void _setupRealtimeMembershipListener() {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        _membershipChannel = Supabase.instance.client
            .channel('public:household_members:user:$currentUserId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'household_members',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: currentUserId,
              ),
              callback: (payload) async {
                if (mounted) {
                  ref.invalidate(userHouseholdsProvider);
                  ref.invalidate(activeHouseholdProvider);
                  ref.invalidate(userHasHouseholdProvider);
                  ref.invalidate(currentHouseholdProvider);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.celebration_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '🎉 تمت الموافقة على طلب انضمامك! مرحباً بك في المنزل.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Color(0xFF00897B),
                      duration: Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                }
              },
            )
            .subscribe();
      }
    } catch (_) {
      // Fallback for tests / uninitialized client
    }
  }

  void _startCooldown([int seconds = 10]) {
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  @override
  void dispose() {
    try {
      if (_membershipChannel != null) {
        Supabase.instance.client.removeChannel(_membershipChannel!);
      }
    } catch (_) {}
    _cooldownTimer?.cancel();
    _homeNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _submitCreate() async {
    FocusScope.of(context).unfocus();
    if (_createFormKey.currentState != null && !_createFormKey.currentState!.validate()) {
      return;
    }

    final rawName = _homeNameController.text.trim();
    final name = rawName.isEmpty ? 'منزلنا' : rawName;

    setState(() => _isCreating = true);
    try {
      final controller = ref.read(currentHouseholdProvider.notifier);
      final success = await controller.createHousehold(name);

      if (!mounted) return;

      if (success) {
        ref.invalidate(userHouseholdsProvider);
        ref.invalidate(activeHouseholdProvider);
        ref.invalidate(userHasHouseholdProvider);

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
        final error = ref.read(currentHouseholdProvider).error;
        final appException = AppException.fromGeneric(error);
        final errorMessage = error != null ? error.toString() : appException.localizedMessage('ar');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تعذر إنشاء المنزل: $errorMessage',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تعذر إنشاء المنزل: $e',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _submitJoin() async {
    FocusScope.of(context).unfocus();

    if (_cooldownSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.amber.shade800,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.timer_outlined, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'يرجى الانتظار $_cooldownSeconds ثوانٍ قبل إرسال طلب جديد',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    if (_joinFormKey.currentState != null && !_joinFormKey.currentState!.validate()) {
      return;
    }

    final code = _inviteCodeController.text.trim();
    setState(() => _isJoining = true);
    try {
      final householdRepo = ref.read(householdRepositoryProvider);
      await householdRepo.requestJoinHousehold(code);

      _startCooldown(10);

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 28),
                SizedBox(width: 8),
                Text('تم إرسال الطلب', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'تم إرسال طلب الانضمام إلى صاحب المنزل بنجاح.\nطلبك قيد المراجعة حالياً، وسيتم إشعارك فور قبول انضمامك.',
              style: TextStyle(height: 1.5),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF82C8E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final rawError = e.toString().replaceFirst('Exception: ', '').trim();
      final appException = AppException.fromGeneric(e);
      final errorMessage = (rawError.isNotEmpty && !rawError.contains('Instance of'))
          ? rawError
          : appException.localizedMessage('ar');

      if (errorMessage.contains('يرجى الانتظار') ||
          errorMessage.toLowerCase().contains('wait') ||
          errorMessage.toLowerCase().contains('cooldown')) {
        final match = RegExp(r'(\d+)').firstMatch(errorMessage);
        final secs = match != null ? int.tryParse(match.group(1)!) ?? 10 : 10;
        _startCooldown(secs);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
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
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reactive listener for join_accepted notification while user is waiting on this screen
    ref.listen<AsyncValue<List<NotificationModel>>>(notificationsStreamProvider, (prev, next) {
      next.whenData((notifications) {
        final acceptedNotification = notifications.where(
          (n) => n.type == NotificationType.joinAccepted && !n.isRead,
        ).firstOrNull ?? notifications.where(
          (n) => n.type == NotificationType.joinAccepted,
        ).firstOrNull;

        if (acceptedNotification != null && mounted) {
          // 1. Refresh all household providers
          ref.invalidate(userHouseholdsProvider);
          ref.invalidate(activeHouseholdProvider);
          ref.invalidate(userHasHouseholdProvider);
          ref.invalidate(currentHouseholdProvider);

          // 2. Mark notification as read so it doesn't fire multiple times
          if (!acceptedNotification.isRead) {
            try {
              ref.read(notificationRepositoryProvider).markAsRead(acceptedNotification.id);
            } catch (_) {}
          }

          // 3. Show celebration feedback
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.celebration_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🎉 تمت الموافقة على طلب انضمامك! مرحباً بك في المنزل.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF00897B),
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );

          // 4. Navigate immediately to HomeScreen and remove setup screen from stack
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      });
    });

    final householdState = ref.watch(currentHouseholdProvider);
    final isAsyncLoading = householdState.isLoading;
    final isLoading = _isCreating || _isJoining || isAsyncLoading;

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
                                hintText: 'مثال: منزلنا، بيت إسطنبول، شقة باشاك شهير',
                                prefixIcon: Icon(Icons.home_outlined),
                              ),
                              validator: (value) {
                                // Default name is 'منزلنا' if left blank, so no blocking error
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: isLoading ? null : _submitCreate,
                              child: _isCreating
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
                              onPressed: (_cooldownSeconds > 0 || isLoading) ? null : _submitJoin,
                              child: _isJoining
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _cooldownSeconds > 0
                                          ? 'يرجى الانتظار ($_cooldownSeconds ثانية)...'
                                          : 'الانضمام إلى المنزل',
                                      style: const TextStyle(
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
