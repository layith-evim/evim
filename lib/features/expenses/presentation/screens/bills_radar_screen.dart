import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:evim/core/theme/app_colors.dart';
import 'package:evim/core/utils/validators.dart';
import 'package:evim/features/household/presentation/controllers/current_household_controller.dart';
import 'package:evim/features/expenses/data/expenses_repository.dart';
import 'package:evim/features/expenses/data/deadlines_repository.dart';
import 'package:evim/features/expenses/domain/models/recurring_expense_model.dart';
import 'package:evim/features/expenses/domain/models/critical_deadline_model.dart';

enum BillsRadarTab { expenses, deadlines }

/// Screen combining monthly recurring expenses with life deadline countdown radar
class BillsRadarScreen extends ConsumerStatefulWidget {
  const BillsRadarScreen({super.key});

  @override
  ConsumerState<BillsRadarScreen> createState() => _BillsRadarScreenState();
}

class _BillsRadarScreenState extends ConsumerState<BillsRadarScreen> {
  BillsRadarTab _currentTab = BillsRadarTab.expenses;

  void _openAddExpenseSheet(BuildContext context, String householdId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddExpenseBottomSheet(householdId: householdId),
    );
  }

  void _openAddDeadlineSheet(BuildContext context, String householdId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddDeadlineBottomSheet(householdId: householdId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentHousehold = ref.watch(currentHouseholdProvider).value;
    final expensesAsync = ref.watch(recurringExpensesListProvider);
    final deadlinesAsync = ref.watch(criticalDeadlinesListProvider);

    if (currentHousehold == null) {
      return const Center(child: Text('يرجى اختيار منزل'));
    }

    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Column(
          children: [
            // Top Summary Card (Total budget, Paid, Remaining)
            expensesAsync.when(
              data: (expenses) {
                final total = expenses.fold<double>(0.0, (sum, item) => sum + item.amount);
                final paid = expenses
                    .where((e) => e.isPaid)
                    .fold<double>(0.0, (sum, item) => sum + item.amount);
                final remaining = total - paid;

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الميزانية الشهرية المقدرة',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Text(
                            '${currencyFormat.format(total)} ₺',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryColumn(
                              title: 'تم سداده',
                              amount: '${currencyFormat.format(paid)} ₺',
                              color: Colors.greenAccent.shade200,
                              icon: Icons.check_circle_outline_rounded,
                            ),
                          ),
                          Container(width: 1, height: 32, color: Colors.white24),
                          Expanded(
                            child: _SummaryColumn(
                              title: 'المتبقي للدفع',
                              amount: '${currencyFormat.format(remaining)} ₺',
                              color: AppColors.warmAmber,
                              icon: Icons.pending_actions_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 110,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Tab Switcher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _RadarTabButton(
                        title: 'الفواتير والعائدات',
                        icon: Icons.receipt_long_rounded,
                        isSelected: _currentTab == BillsRadarTab.expenses,
                        onTap: () => setState(() => _currentTab = BillsRadarTab.expenses),
                      ),
                    ),
                    Expanded(
                      child: _RadarTabButton(
                        title: 'رادار المواعيد القانونية',
                        icon: Icons.radar_rounded,
                        isSelected: _currentTab == BillsRadarTab.deadlines,
                        onTap: () => setState(() => _currentTab = BillsRadarTab.deadlines),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Body
            Expanded(
              child: _currentTab == BillsRadarTab.expenses
                  ? _ExpensesListView(expensesAsync: expensesAsync)
                  : _DeadlinesListView(deadlinesAsync: deadlinesAsync),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            if (_currentTab == BillsRadarTab.expenses) {
              _openAddExpenseSheet(context, currentHousehold.id);
            } else {
              _openAddDeadlineSheet(context, currentHousehold.id);
            }
          },
          icon: Icon(
            _currentTab == BillsRadarTab.expenses
                ? Icons.add_card_rounded
                : Icons.add_alarm_rounded,
          ),
          label: Text(
            _currentTab == BillsRadarTab.expenses ? 'إضافة فاتورة' : 'إضافة موعد',
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final IconData icon;

  const _SummaryColumn({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _RadarTabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RadarTabButton({
    required this.title,
    required this.icon,
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
        padding: const EdgeInsets.symmetric(vertical: 10),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Expenses List View
// -----------------------------------------------------------------------------
class _ExpensesListView extends ConsumerWidget {
  final AsyncValue<List<RecurringExpenseModel>> expensesAsync;
  const _ExpensesListView({required this.expensesAsync});

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'إيجار':
        return Icons.apartment_rounded;
      case 'عائدات':
        return Icons.home_repair_service_rounded;
      case 'غاز':
        return Icons.local_fire_department_rounded;
      case 'ماء':
        return Icons.water_drop_rounded;
      case 'كهرباء':
        return Icons.bolt_rounded;
      case 'إنترنت':
        return Icons.wifi_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return expensesAsync.when(
      data: (expenses) {
        if (expenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'لا توجد فواتير أو مصاريف دورية مسجلة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'أضف الإيجار، العائدات (Aidat)، فواتير الغاز والماء والكهرباء',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final exp = expenses[index];

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: exp.isPaid ? Colors.grey.shade200 : AppColors.borderLight,
                ),
              ),
              color: exp.isPaid ? Colors.grey.shade50 : Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: exp.isPaid
                      ? AppColors.oliveGreen.withOpacity(0.12)
                      : AppColors.primary.withOpacity(0.1),
                  child: Icon(
                    _getCategoryIcon(exp.category),
                    color: exp.isPaid ? AppColors.oliveGreen : AppColors.primary,
                  ),
                ),
                title: Text(
                  exp.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    decoration: exp.isPaid ? TextDecoration.lineThrough : null,
                    color: exp.isPaid ? Colors.grey.shade500 : AppColors.textPrimaryLight,
                  ),
                ),
                subtitle: Text(
                  exp.dueDay != null
                      ? 'يستحق يوم ${exp.dueDay} من كل شهر'
                      : 'فئة: ${exp.category}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${currencyFormat.format(exp.amount)} ₺',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: exp.isPaid ? AppColors.oliveGreen : AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          exp.isPaid ? 'تم السداد' : 'غير مسدد',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: exp.isPaid ? AppColors.oliveGreen : AppColors.terracotta,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: exp.isPaid,
                      activeColor: AppColors.oliveGreen,
                      onChanged: (val) async {
                        final repo = ref.read(expensesRepositoryProvider);
                        await repo.toggleExpensePaid(expenseId: exp.id, isPaid: val);
                        ref.invalidate(recurringExpensesListProvider);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('تعذر تحميل الفواتير: $err')),
    );
  }
}

// -----------------------------------------------------------------------------
// Deadlines List View (Radar)
// -----------------------------------------------------------------------------
class _DeadlinesListView extends ConsumerWidget {
  final AsyncValue<List<CriticalDeadlineModel>> deadlinesAsync;
  const _DeadlinesListView({required this.deadlinesAsync});

  Color _getUrgencyColor(DeadlineUrgency urgency) {
    switch (urgency) {
      case DeadlineUrgency.urgent:
        return AppColors.terracotta; // 🔴
      case DeadlineUrgency.warning:
        return AppColors.warmAmber; // 🟡
      case DeadlineUrgency.safe:
        return AppColors.oliveGreen; // 🟢
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return deadlinesAsync.when(
      data: (deadlines) {
        if (deadlines.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.alarm_on_rounded, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'لا توجد مواعيد حرجة قريبة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'أضف مواعيد تجديد الإقامة، فحص TÜVTÜRK، تأمين DASK وعقد الإيجار',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: deadlines.length,
          itemBuilder: (context, index) {
            final item = deadlines[index];
            final urgency = item.urgency;
            final badgeColor = _getUrgencyColor(urgency);
            final formattedDate = DateFormat('yyyy/MM/dd').format(item.dueDate);

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: item.isCompleted ? Colors.grey.shade200 : badgeColor.withOpacity(0.4),
                  width: item.isCompleted ? 1 : 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    // Urgency Indicator
                    Container(
                      width: 12,
                      height: 52,
                      decoration: BoxDecoration(
                        color: item.isCompleted ? Colors.grey.shade300 : badgeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title & Category
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.category,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'تاريخ الاستحقاق: $formattedDate',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    // Countdown badge & toggle
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: item.isCompleted
                                ? Colors.grey.shade100
                                : badgeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.formattedDaysRemaining,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: item.isCompleted ? Colors.grey.shade600 : badgeColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                item.isCompleted
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 22,
                                color: item.isCompleted ? AppColors.oliveGreen : Colors.grey,
                              ),
                              tooltip: 'تحديد كمكتمل',
                              onPressed: () async {
                                final repo = ref.read(deadlinesRepositoryProvider);
                                await repo.toggleDeadlineCompleted(
                                  deadlineId: item.id,
                                  isCompleted: !item.isCompleted,
                                );
                                ref.invalidate(criticalDeadlinesListProvider);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                              tooltip: 'حذف',
                              onPressed: () async {
                                final repo = ref.read(deadlinesRepositoryProvider);
                                await repo.deleteDeadline(item.id);
                                ref.invalidate(criticalDeadlinesListProvider);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('تعذر تحميل المواعيد: $err')),
    );
  }
}

// -----------------------------------------------------------------------------
// Add Expense BottomSheet
// -----------------------------------------------------------------------------
class _AddExpenseBottomSheet extends ConsumerStatefulWidget {
  final String householdId;
  const _AddExpenseBottomSheet({required this.householdId});

  @override
  ConsumerState<_AddExpenseBottomSheet> createState() => _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends ConsumerState<_AddExpenseBottomSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _dueDayController = TextEditingController(text: '1');
  String _selectedCategory = 'عائدات';

  final List<String> _categories = ['إيجار', 'عائدات', 'غاز', 'ماء', 'كهرباء', 'إنترنت', 'عام'];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(amountText);
    final dueDay = int.tryParse(_dueDayController.text.trim());

    if (title.isEmpty || amount == null || amount <= 0) return;

    setState(() => _isSubmitting = true);
    final repo = ref.read(expensesRepositoryProvider);

    final expense = RecurringExpenseModel(
      id: '',
      householdId: widget.householdId,
      title: title,
      category: _selectedCategory,
      amount: amount,
      dueDay: dueDay,
      createdAt: DateTime.now(),
    );

    await repo.addExpense(expense);
    ref.invalidate(recurringExpensesListProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'إضافة بند فاتورة / مصروف دوري',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'اسم الفاتورة أو المصروف',
                hintText: 'مثال: عائدات العمارة، إيجار الشقة، فاتورة الغاز',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ الشهري (₺)',
                      hintText: '1500',
                    ),
                    validator: (v) => Validators.validatePositiveAmount(v, locale: 'ar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _dueDayController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'يوم الاستحقاق',
                      hintText: '1-31',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('نوع الفاتورة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ الفاتورة'),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Add Deadline BottomSheet
// -----------------------------------------------------------------------------
class _AddDeadlineBottomSheet extends ConsumerStatefulWidget {
  final String householdId;
  const _AddDeadlineBottomSheet({required this.householdId});

  @override
  ConsumerState<_AddDeadlineBottomSheet> createState() => _AddDeadlineBottomSheetState();
}

class _AddDeadlineBottomSheetState extends ConsumerState<_AddDeadlineBottomSheet> {
  final _titleController = TextEditingController(text: 'تجديد الإقامة السياحية');
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 60));
  String _selectedCategory = 'إقامة';
  int _reminderDays = 60;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _presets = [
    {'title': 'تجديد الإقامة', 'cat': 'إقامة', 'reminder': 60},
    {'title': 'فحص TÜVTÜRK للسيارة', 'cat': 'TÜVTÜRK', 'reminder': 30},
    {'title': 'تأمين الزلازل DASK', 'cat': 'DASK', 'reminder': 30},
    {'title': 'تجديد عقد الإيجار', 'cat': 'عقد إيجار', 'reminder': 30},
    {'title': 'تجديد جواز السفر', 'cat': 'جواز سفر', 'reminder': 90},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSubmitting = true);
    final repo = ref.read(deadlinesRepositoryProvider);

    final deadline = CriticalDeadlineModel(
      id: '',
      householdId: widget.householdId,
      title: title,
      category: _selectedCategory,
      dueDate: _selectedDate,
      reminderDaysBefore: _reminderDays,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: DateTime.now(),
    );

    await repo.addDeadline(deadline);
    ref.invalidate(criticalDeadlinesListProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('yyyy/MM/dd').format(_selectedDate);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'إضافة موعد قانوني أو إداري حرج',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text('نماذج جاهزة سريعة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _presets.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ActionChip(
                      label: Text(p['title'] as String, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _titleController.text = p['title'] as String;
                          _selectedCategory = p['cat'] as String;
                          _reminderDays = p['reminder'] as int;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'عنوان الموعد'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تاريخ الاستحقاق أو الانتهاء'),
              subtitle: Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              trailing: ElevatedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                label: const Text('تحديد التاريخ'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(120, 36),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ الموعد في الرادار'),
            ),
          ],
        ),
      ),
    );
  }
}
