import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../expenses/data/deadlines_repository.dart';
import '../../expenses/data/expenses_repository.dart';
import '../../household/presentation/controllers/current_household_controller.dart';

/// State representing user notification preferences
class NotificationSettingsState {
  final bool notifyBills;
  final bool notifyResidency;
  final bool notifyPantry;

  const NotificationSettingsState({
    this.notifyBills = true,
    this.notifyResidency = true,
    this.notifyPantry = true,
  });

  NotificationSettingsState copyWith({
    bool? notifyBills,
    bool? notifyResidency,
    bool? notifyPantry,
  }) {
    return NotificationSettingsState(
      notifyBills: notifyBills ?? this.notifyBills,
      notifyResidency: notifyResidency ?? this.notifyResidency,
      notifyPantry: notifyPantry ?? this.notifyPantry,
    );
  }
}

/// Notifier managing persistence and realtime scheduling logic for notification switches
class NotificationSettingsNotifier extends StateNotifier<NotificationSettingsState> {
  final Ref _ref;

  static const String keyNotifyBills = 'notify_bills';
  static const String keyNotifyResidency = 'notify_residency';
  static const String keyNotifyPantry = 'notify_pantry';

  NotificationSettingsNotifier(this._ref)
      : super(const NotificationSettingsState()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bills = prefs.getBool(keyNotifyBills) ?? true;
      final residency = prefs.getBool(keyNotifyResidency) ?? true;
      final pantry = prefs.getBool(keyNotifyPantry) ?? true;

      state = NotificationSettingsState(
        notifyBills: bills,
        notifyResidency: residency,
        notifyPantry: pantry,
      );
    } catch (_) {}
  }

  Future<void> toggleNotifyBills(bool enabled) async {
    state = state.copyWith(notifyBills: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyNotifyBills, enabled);
    } catch (_) {}

    final notifService = _ref.read(notificationServiceProvider);
    if (!enabled) {
      await notifService.cancelAllBillReminders();
    } else {
      // Re-schedule upcoming unpaid bills
      final household = _ref.read(currentHouseholdProvider).value;
      if (household != null) {
        try {
          final expenses = await _ref.read(expensesRepositoryProvider).getExpenses(household.id);
          final now = DateTime.now();
          for (final exp in expenses.where((e) => !e.isPaid)) {
            final dueDay = exp.dueDay ?? 1;
            final nextDueDate = DateTime(now.year, now.month, dueDay);
            final targetDate = nextDueDate.isBefore(now)
                ? DateTime(now.year, now.month + 1, dueDay)
                : nextDueDate;

            await notifService.scheduleBillReminder(
              billId: exp.id,
              title: exp.title,
              dueDate: targetDate,
            );
          }
        } catch (_) {}
      }
    }
  }

  Future<void> toggleNotifyResidency(bool enabled) async {
    state = state.copyWith(notifyResidency: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyNotifyResidency, enabled);
    } catch (_) {}

    final notifService = _ref.read(notificationServiceProvider);
    if (!enabled) {
      await notifService.cancelAllResidencyReminders();
    } else {
      // Re-schedule upcoming deadlines
      final household = _ref.read(currentHouseholdProvider).value;
      if (household != null) {
        try {
          final deadlines = await _ref.read(deadlinesRepositoryProvider).getDeadlines(household.id);
          for (final d in deadlines.where((dl) => !dl.isCompleted)) {
            await notifService.scheduleResidencyReminder(
              permitId: d.id,
              expiryDate: d.dueDate,
              reminderDaysBefore: d.reminderDaysBefore,
            );
          }
        } catch (_) {}
      }
    }
  }

  Future<void> toggleNotifyPantry(bool enabled) async {
    state = state.copyWith(notifyPantry: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyNotifyPantry, enabled);
    } catch (_) {}
  }
}

/// Provider for notification settings state
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>((ref) {
  return NotificationSettingsNotifier(ref);
});
