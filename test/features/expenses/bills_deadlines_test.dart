import 'package:flutter_test/flutter_test.dart';
import 'package:evim/features/expenses/domain/models/recurring_expense_model.dart';
import 'package:evim/features/expenses/domain/models/critical_deadline_model.dart';

void main() {
  group('Phase 4 Bills & Deadlines Unit Tests', () {
    test('Recurring expense monthly budget calculation', () {
      final expenses = [
        RecurringExpenseModel(
          id: '1',
          householdId: 'h-1',
          title: 'إيجار الشقة',
          category: 'إيجار',
          amount: 25000.0,
          isPaid: true,
          createdAt: DateTime.now(),
        ),
        RecurringExpenseModel(
          id: '2',
          householdId: 'h-1',
          title: 'عائدات العمارة',
          category: 'عائدات',
          amount: 1500.0,
          isPaid: false,
          createdAt: DateTime.now(),
        ),
        RecurringExpenseModel(
          id: '3',
          householdId: 'h-1',
          title: 'فاتورة الغاز İGDAŞ',
          category: 'غاز',
          amount: 850.50,
          isPaid: false,
          createdAt: DateTime.now(),
        ),
      ];

      final total = expenses.fold<double>(0.0, (sum, i) => sum + i.amount);
      final paid = expenses.where((e) => e.isPaid).fold<double>(0.0, (sum, i) => sum + i.amount);
      final remaining = total - paid;

      expect(total, 27350.50);
      expect(paid, 25000.0);
      expect(remaining, 2350.50);
    });

    test('Critical deadline daysRemaining and urgency calculation', () {
      final now = DateTime(2026, 9, 11);

      // Urgent deadline (<= 7 days)
      final urgentDeadline = CriticalDeadlineModel(
        id: '1',
        householdId: 'h-1',
        title: 'فحص TÜVTÜRK',
        category: 'TÜVTÜRK',
        dueDate: DateTime(2026, 9, 15),
        reminderDaysBefore: 30,
        createdAt: now,
      );

      expect(urgentDeadline.calculateDaysRemaining(now), 4);
      expect(urgentDeadline.calculateUrgency(now), DeadlineUrgency.urgent);

      // Warning deadline (<= reminder threshold, e.g. 45 days remaining with 60 days threshold)
      final warningDeadline = CriticalDeadlineModel(
        id: '2',
        householdId: 'h-1',
        title: 'تجديد الإقامة السياحية',
        category: 'إقامة',
        dueDate: DateTime(2026, 10, 26),
        reminderDaysBefore: 60,
        createdAt: now,
      );

      expect(warningDeadline.calculateDaysRemaining(now), 45);
      expect(warningDeadline.calculateUrgency(now), DeadlineUrgency.warning);

      // Safe deadline (> reminder threshold, e.g. 100 days remaining with 30 days threshold)
      final safeDeadline = CriticalDeadlineModel(
        id: '3',
        householdId: 'h-1',
        title: 'تأمين DASK',
        category: 'DASK',
        dueDate: DateTime(2026, 12, 20),
        reminderDaysBefore: 30,
        createdAt: now,
      );

      expect(safeDeadline.calculateDaysRemaining(now), 100);
      expect(safeDeadline.calculateUrgency(now), DeadlineUrgency.safe);
    });

    test('Completed deadline always reports safe urgency', () {
      final now = DateTime(2026, 9, 11);
      final completed = CriticalDeadlineModel(
        id: '4',
        householdId: 'h-1',
        title: 'عقد إيجار',
        category: 'عقد إيجار',
        dueDate: DateTime(2026, 9, 12),
        isCompleted: true,
        createdAt: now,
      );

      expect(completed.calculateUrgency(now), DeadlineUrgency.safe);
      expect(completed.formattedDaysRemaining, 'مكتمل ✅');
    });
  });
}
