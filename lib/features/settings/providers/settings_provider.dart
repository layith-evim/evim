import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_service.dart';
import '../../household/data/household_repository.dart';
import '../models/user_preferences.dart';

/// StateNotifier managing user preferences and notification settings
class SettingsNotifier extends StateNotifier<UserPreferences> {
  final Ref _ref;

  SettingsNotifier(this._ref) : super(const UserPreferences()) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final loaded = await UserPreferences.load();
    state = loaded;
  }

  Future<void> toggleNotifyBills(bool enabled) async {
    state = state.copyWith(notifyBills: enabled);
    await state.save();

    if (!enabled) {
      final notifService = _ref.read(notificationServiceProvider);
      // Cancel bill notification channel reminders if disabled
      await notifService.cancelReminder('all_bills');
    }
  }

  Future<void> toggleNotifyResidency(bool enabled) async {
    state = state.copyWith(notifyResidency: enabled);
    await state.save();

    if (!enabled) {
      final notifService = _ref.read(notificationServiceProvider);
      // Cancel residency notification channel reminders if disabled
      await notifService.cancelReminder('all_residency');
    }
  }

  Future<void> toggleNotifyPantry(bool enabled) async {
    state = state.copyWith(notifyPantry: enabled);
    await state.save();
  }

  Future<void> setLanguage(String languageCode) async {
    state = state.copyWith(language: languageCode);
    await state.save();
  }

  Future<void> setThemeMode(String themeMode) async {
    state = state.copyWith(themeMode: themeMode);
    await state.save();
  }

  Future<void> updateDisplayName(String name) async {
    final repo = _ref.read(householdRepositoryProvider);
    await repo.updateDisplayName(name);
  }
}

/// Provider for user preferences and settings
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, UserPreferences>((ref) {
  return SettingsNotifier(ref);
});
