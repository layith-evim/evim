import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import 'package:evim/core/theme/app_colors.dart';
import 'package:evim/features/household/presentation/controllers/current_household_controller.dart';
import 'package:evim/features/gov_guide/data/gov_guide_repository.dart';
import 'package:evim/features/gov_guide/domain/models/gov_guide_model.dart';
import 'package:evim/features/gov_guide/domain/models/gov_task_model.dart';

class GovGuideDetailScreen extends ConsumerStatefulWidget {
  final GovGuideModel guide;

  const GovGuideDetailScreen({
    super.key,
    required this.guide,
  });

  @override
  ConsumerState<GovGuideDetailScreen> createState() => _GovGuideDetailScreenState();
}

class _GovGuideDetailScreenState extends ConsumerState<GovGuideDetailScreen> {
  bool _isProcessing = false;

  Future<void> _toggleTask(GovTaskModel task, String householdId) async {
    if (householdId.isEmpty) return;

    try {
      final repo = ref.read(govGuideRepositoryProvider);
      await repo.toggleTaskProgress(
        householdId: householdId,
        taskId: task.id,
        isCompleted: !task.isCompleted,
      );
      ref.invalidate(guideTasksProvider(widget.guide.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحديث الحالة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openEDevletLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر فتح الرابط الخارجي.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح الرابط.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showConvertToDeadlinesDialog(BuildContext context, GovTaskModel task, String householdId) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    final titleController = TextEditingController(text: 'موعد: ${task.title}');
    final notesController = TextEditingController(
      text: 'دليل: ${widget.guide.title} - الخطوة ${task.stepNumber}',
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: AppColors.surfaceDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                title: const Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: AppColors.primaryLight),
                    SizedBox(width: 8),
                    Text(
                      'تحويل إلى موعد في الرادار',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'سيتم إضافة هذا الموعد إلى رادار المواعيد والمهام الحرجة لتلقي التنبيهات ومتابعة العد التنازلي.',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'عنوان الموعد',
                          labelStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.title_rounded, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event_rounded, color: AppColors.primaryLight),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'تاريخ الموعد / الموعد النهائي',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('yyyy-MM-dd (EEEE)', 'ar').format(selectedDate),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: notesController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات إضافية (اختياري)',
                          labelStyle: TextStyle(color: Colors.white70),
                          prefixIcon: Icon(Icons.notes_rounded, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            final title = titleController.text.trim();
                            if (title.isEmpty) return;

                            final messenger = ScaffoldMessenger.of(context);
                            final nav = Navigator.of(dialogContext);

                            setState(() => _isProcessing = true);
                            nav.pop();

                            try {
                              final repo = ref.read(govGuideRepositoryProvider);
                              await repo.convertTaskToDeadline(
                                householdId: householdId,
                                title: title,
                                dueDate: selectedDate,
                                notes: notesController.text.trim(),
                              );

                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      '🎉 تمت إضافة الموعد بنجاح إلى رادار المواعيد!',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    backgroundColor: AppColors.accent,
                                    action: SnackBarAction(
                                      label: 'إغلاق',
                                      textColor: Colors.white,
                                      onPressed: () {},
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('تعذر حفظ الموعد: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isProcessing = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('حفظ في الرادار'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final household = ref.watch(currentHouseholdProvider).value;
    final householdId = household?.id ?? '';
    final tasksAsync = ref.watch(guideTasksProvider(widget.guide.id));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.guide.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث الخطوات',
              onPressed: () => ref.invalidate(guideTasksProvider(widget.guide.id)),
            ),
          ],
        ),
        body: tasksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(
                    'تعذر تحميل الخطوات: $error',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(guideTasksProvider(widget.guide.id)),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
          data: (tasks) {
            final completedCount = tasks.where((t) => t.isCompleted).length;
            final totalCount = tasks.length;
            final percent = totalCount > 0 ? (completedCount / totalCount) : 0.0;

            return CustomScrollView(
              slivers: [
                // Header Banner
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primaryLight.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.guide.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'نسبة الإنجاز ($completedCount من $totalCount)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryLight,
                              ),
                            ),
                            Text(
                              '${(percent * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              percent == 1.0 ? AppColors.accent : AppColors.primaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Step by Step List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final task = tasks[index];
                        return _StepTaskCard(
                          task: task,
                          householdId: householdId,
                          onToggle: () => _toggleTask(task, householdId),
                          onOpenLink: () => _openEDevletLink(task.eDevletLink),
                          onConvertToDeadline: () => _showConvertToDeadlinesDialog(
                            context,
                            task,
                            householdId,
                          ),
                        );
                      },
                      childCount: tasks.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StepTaskCard extends StatelessWidget {
  final GovTaskModel task;
  final String householdId;
  final VoidCallback onToggle;
  final VoidCallback onOpenLink;
  final VoidCallback onConvertToDeadline;

  const _StepTaskCard({
    required this.task,
    required this.householdId,
    required this.onToggle,
    required this.onOpenLink,
    required this.onConvertToDeadline,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = task.isCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDone ? AppColors.accent.withOpacity(0.6) : Colors.white24,
          width: isDone ? 1.5 : 1.0,
        ),
      ),
      color: isDone ? AppColors.accent.withOpacity(0.08) : AppColors.surfaceDark,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step Number Badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDone ? AppColors.accent : AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: isDone
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                      : Text(
                          '${task.stepNumber}',
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? Colors.white60 : Colors.white,
                    ),
                  ),
                ),
                // Toggle Checkbox
                Checkbox(
                  value: isDone,
                  activeColor: AppColors.accent,
                  checkColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  onChanged: (_) => onToggle(),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Instructions Text
            Padding(
              padding: const EdgeInsets.only(right: 44),
              child: Text(
                task.instructions,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.45,
                ),
              ),
            ),

            // Required Docs Section
            if (task.requiredDocs.isNotEmpty) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(right: 44),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الأوراق والمستندات المطلوبة:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: task.requiredDocs.map((doc) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.warmAmber.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.warmAmber.withOpacity(0.45),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.description_outlined,
                                size: 14,
                                color: AppColors.warmAmber,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                doc,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Action Buttons Bar
            Padding(
              padding: const EdgeInsets.only(right: 44),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (task.eDevletLink != null && task.eDevletLink!.isNotEmpty)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        side: const BorderSide(color: AppColors.primaryLight),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: onOpenLink,
                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                      label: const Text(
                        'بوابة E-Devlet',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.turquoise,
                      side: const BorderSide(color: AppColors.turquoise),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onConvertToDeadline,
                    icon: const Icon(Icons.alarm_add_rounded, size: 15),
                    label: const Text(
                      'تحويل إلى موعد بالرادار',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
