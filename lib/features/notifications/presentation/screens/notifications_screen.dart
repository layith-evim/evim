import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/theme/app_colors.dart';
import '../../../household/data/household_repository.dart';
import '../../../household/presentation/controllers/current_household_controller.dart';
import '../../data/notification_repository.dart';
import '../../domain/models/notification_model.dart';
import '../../../gov_guide/data/gov_guide_repository.dart';
import '../../../gov_guide/presentation/screens/gov_guide_detail_screen.dart';

/// Screen displaying in-app notification center and smart reminders
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _processingRequestId;

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) {
      return 'الآن';
    } else if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} دقيقة';
    } else if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} ساعة';
    } else if (diff.inDays == 1) {
      return 'أمس';
    } else if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} أيام';
    } else {
      return DateFormat('yyyy/MM/dd').format(dateTime);
    }
  }

  void _handleTapNotification(NotificationModel notification) async {
    // Mark as read immediately
    if (!notification.isRead) {
      ref.read(notificationRepositoryProvider).markAsRead(notification.id);
    }

    if (notification.type == NotificationType.bill) {
      Navigator.pop(context, 'open_bills');
    } else if ((notification.type == NotificationType.guide ||
            notification.type == NotificationType.ikametExpiry) &&
        notification.relatedId != null &&
        notification.relatedId!.isNotEmpty) {
      final guides = await ref.read(govGuidesListProvider.future);
      final guide = guides.where((g) => g.id == notification.relatedId).firstOrNull;
      if (guide != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => GovGuideDetailScreen(guide: guide),
          ),
        );
      } else if (mounted) {
        Navigator.pop(context, 'open_guides');
      }
    }
  }

  Future<void> _handleDecision(String requestId, bool isAccept, String notificationId) async {
    setState(() => _processingRequestId = requestId);
    try {
      final householdRepo = ref.read(householdRepositoryProvider);
      await householdRepo.respondToJoinRequest(
        requestId: requestId,
        accept: isAccept,
      );

      // Mark notification as read
      await ref.read(notificationRepositoryProvider).markAsRead(notificationId);

      // Invalidate stream and household members
      ref.invalidate(notificationsStreamProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
      final currentH = ref.read(currentHouseholdProvider).value;
      if (currentH != null) {
        ref.invalidate(householdMembersProvider(currentH.id));
      }
      ref.invalidate(householdMembersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: isAccept ? const Color(0xFF00897B) : AppColors.error,
            content: Text(isAccept ? 'تم قبول العضو بنجاح' : 'تم رفض الطلب'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final rawError = e.toString().replaceFirst('Exception: ', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
            content: Text('تعذر معالجة الطلب: $rawError'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingRequestId = null);
      }
    }
  }

  void _confirmClearAll(String householdId) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('مسح جميع الإشعارات'),
          content: const Text('هل أنت متأكد من رغبتك في حذف جميع الإشعارات؟ لا يمكن التراجع عن هذا الإجراء.'),
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
                await ref.read(notificationRepositoryProvider).clearAllNotifications(householdId);
              },
              child: const Text('مسح الكل'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentHousehold = ref.watch(currentHouseholdProvider).value;
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'مركز الإشعارات والتذكيرات',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            if (currentHousehold != null) ...[
              IconButton(
                icon: const Icon(Icons.done_all_rounded),
                tooltip: 'تحديد الكل كمقروء',
                onPressed: () {
                  ref.read(notificationRepositoryProvider).markAllAsRead(currentHousehold.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('تم تحديد جميع الإشعارات كمقروءة.'),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded),
                tooltip: 'مسح جميع الإشعارات',
                onPressed: () => _confirmClearAll(currentHousehold.id),
              ),
            ],
          ],
        ),
        body: notificationsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text('خطأ في جلب الإشعارات: $err', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(notificationsStreamProvider),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
          data: (notifications) {
            if (notifications.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 52,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'لا توجد إشعارات حالياً',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ستصلك تنبيهات ذكية وفورية حول مواعيد الفواتير وتجديد الإقامات والمستجدات الحكومية هنا.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Group notifications by date: Today, This Week, Older
            final now = DateTime.now();
            final today = <NotificationModel>[];
            final thisWeek = <NotificationModel>[];
            final older = <NotificationModel>[];

            for (final n in notifications) {
              final diff = now.difference(n.createdAt);
              if (diff.inDays < 1 && now.day == n.createdAt.day) {
                today.add(n);
              } else if (diff.inDays < 7) {
                thisWeek.add(n);
              } else {
                older.add(n);
              }
            }

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(notificationsStreamProvider);
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadNotificationsCountProvider);
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (today.isNotEmpty) ...[
                    _SectionHeader(title: 'اليوم', count: today.length),
                    ...today.map((n) => _NotificationTile(
                          notification: n,
                          timeFormatted: _formatRelativeTime(n.createdAt),
                          isProcessing: _processingRequestId == n.requestId,
                          onTap: () => _handleTapNotification(n),
                          onDecision: (reqId, accept) => _handleDecision(reqId, accept, n.id),
                          onDelete: () =>
                              ref.read(notificationRepositoryProvider).deleteNotification(n.id),
                        )),
                    const SizedBox(height: 12),
                  ],
                  if (thisWeek.isNotEmpty) ...[
                    _SectionHeader(title: 'هذا الأسبوع', count: thisWeek.length),
                    ...thisWeek.map((n) => _NotificationTile(
                          notification: n,
                          timeFormatted: _formatRelativeTime(n.createdAt),
                          isProcessing: _processingRequestId == n.requestId,
                          onTap: () => _handleTapNotification(n),
                          onDecision: (reqId, accept) => _handleDecision(reqId, accept, n.id),
                          onDelete: () =>
                              ref.read(notificationRepositoryProvider).deleteNotification(n.id),
                        )),
                    const SizedBox(height: 12),
                  ],
                  if (older.isNotEmpty) ...[
                    _SectionHeader(title: 'السابقة', count: older.length),
                    ...older.map((n) => _NotificationTile(
                          notification: n,
                          timeFormatted: _formatRelativeTime(n.createdAt),
                          isProcessing: _processingRequestId == n.requestId,
                          onTap: () => _handleTapNotification(n),
                          onDecision: (reqId, accept) => _handleDecision(reqId, accept, n.id),
                          onDelete: () =>
                              ref.read(notificationRepositoryProvider).deleteNotification(n.id),
                        )),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8, right: 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final String timeFormatted;
  final bool isProcessing;
  final VoidCallback onTap;
  final void Function(String requestId, bool accept)? onDecision;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.timeFormatted,
    this.isProcessing = false,
    required this.onTap,
    this.onDecision,
    required this.onDelete,
  });

  ({IconData icon, Color bg, Color fg}) _getStyle() {
    switch (notification.type) {
      case NotificationType.bill:
        return (
          icon: Icons.receipt_long_rounded,
          bg: AppColors.warmAmber.withValues(alpha: 0.15),
          fg: AppColors.warmAmber,
        );
      case NotificationType.guide:
      case NotificationType.ikametExpiry:
        return (
          icon: Icons.account_balance_rounded,
          bg: AppColors.turquoise.withValues(alpha: 0.15),
          fg: AppColors.turquoise,
        );
      case NotificationType.memberJoined:
        return (
          icon: Icons.group_add_rounded,
          bg: AppColors.primary.withValues(alpha: 0.15),
          fg: AppColors.primaryDark,
        );
      case NotificationType.joinRequest:
        return (
          icon: Icons.person_add_alt_1_rounded,
          bg: const Color(0xFF82C8E5).withValues(alpha: 0.2),
          fg: const Color(0xFF1E6F90),
        );
      case NotificationType.joinAccepted:
        return (
          icon: Icons.check_circle_outline_rounded,
          bg: const Color(0xFF00897B).withValues(alpha: 0.15),
          fg: const Color(0xFF00897B),
        );
      case NotificationType.joinRejected:
        return (
          icon: Icons.cancel_outlined,
          bg: Colors.redAccent.withValues(alpha: 0.15),
          fg: Colors.redAccent,
        );
      case NotificationType.general:
        return (
          icon: Icons.notifications_active_rounded,
          bg: AppColors.primary.withValues(alpha: 0.15),
          fg: AppColors.primaryDark,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _getStyle();
    final isJoinRequest = notification.type == NotificationType.joinRequest;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        color: notification.isRead
            ? Colors.white
            : (isJoinRequest
                ? const Color(0xFF82C8E5).withValues(alpha: 0.08)
                : AppColors.primary.withValues(alpha: 0.05)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: notification.isRead
                ? AppColors.borderLight
                : (isJoinRequest
                    ? const Color(0xFF82C8E5).withValues(alpha: 0.6)
                    : AppColors.primary.withValues(alpha: 0.35)),
            width: notification.isRead ? 1.0 : 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: style.bg,
                      child: Icon(style.icon, color: style.fg, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontWeight:
                                        notification.isRead ? FontWeight.w600 : FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimaryLight,
                                  ),
                                ),
                              ),
                              Text(
                                timeFormatted,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.body,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: notification.isRead
                                  ? AppColors.textSecondaryLight
                                  : AppColors.textPrimaryLight.withValues(alpha: 0.85),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!notification.isRead) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: isJoinRequest ? const Color(0xFF00897B) : AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),

                // Interactive Accept / Reject decision bar
                if (isJoinRequest && !notification.isRead && notification.requestId != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Row(
                      children: [
                        // زر القبول
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00897B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: isProcessing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 18),
                            label: const Text(
                              'قبول',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: isProcessing
                                ? null
                                : () => onDecision?.call(notification.requestId!, true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // زر الرفض
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text(
                              'رفض',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: isProcessing
                                ? null
                                : () => onDecision?.call(notification.requestId!, false),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isJoinRequest && notification.isRead) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'تمت المعالجة',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

