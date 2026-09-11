/// Global application constants for Evim
class AppConstants {
  AppConstants._();

  static const String appName = 'Evim';
  static const String appVersion = '1.0.0';
  static const String bundleId = 'com.evim.app';

  // Currency
  static const String currencyCode = 'TRY';
  static const String currencySymbol = '₺';

  // Supabase Table Names
  static const String tableHouseholds = 'households';
  static const String tableHouseholdMembers = 'household_members';
  static const String tableProfiles = 'profiles';
  static const String tableShoppingItems = 'shopping_items';
  static const String tablePantryItems = 'pantry_items';
  static const String tableRecurringExpenses = 'recurring_expenses';
  static const String tableCriticalDeadlines = 'critical_deadlines';
  static const String tableGovGuides = 'gov_guides';
  static const String tableGovTasks = 'gov_tasks';
  static const String tableHouseholdGovProgress = 'household_gov_progress';

  // Default Deadlines Warning Intervals (in days)
  static const int ikametWarningThresholdDays = 60;
  static const int tuvtrukWarningThresholdDays = 30;
  static const int daskWarningThresholdDays = 30;
}
