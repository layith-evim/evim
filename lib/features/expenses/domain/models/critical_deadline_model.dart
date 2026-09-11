/// Urgency levels for critical life deadlines
enum DeadlineUrgency {
  urgent, // 🔴 Past due or <= 7 days
  warning, // 🟡 <= reminder threshold (e.g. <= 60 days)
  safe, // 🟢 Safe
}

/// Domain model for residency, legal, and vehicle deadlines in Turkey
class CriticalDeadlineModel {
  final String id;
  final String householdId;
  final String title;
  final String category; // 'إقامة', 'TÜVTÜRK', 'DASK', 'عقد إيجار', 'جواز سفر', 'أخرى'
  final DateTime dueDate;
  final int reminderDaysBefore;
  final String? notes;
  final bool isCompleted;
  final DateTime createdAt;

  const CriticalDeadlineModel({
    required this.id,
    required this.householdId,
    required this.title,
    required this.category,
    required this.dueDate,
    this.reminderDaysBefore = 30,
    this.notes,
    this.isCompleted = false,
    required this.createdAt,
  });

  /// Computed days remaining relative to a reference date (defaults to now)
  int calculateDaysRemaining([DateTime? relativeTo]) {
    final now = relativeTo ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return target.difference(today).inDays;
  }

  int get daysRemaining => calculateDaysRemaining();

  /// Computed urgency status
  DeadlineUrgency calculateUrgency([DateTime? relativeTo]) {
    if (isCompleted) return DeadlineUrgency.safe;
    final diff = calculateDaysRemaining(relativeTo);
    if (diff <= 7) return DeadlineUrgency.urgent;
    if (diff <= reminderDaysBefore) return DeadlineUrgency.warning;
    return DeadlineUrgency.safe;
  }

  DeadlineUrgency get urgency => calculateUrgency();

  /// Formatted countdown label in Arabic
  String get formattedDaysRemaining {
    final days = daysRemaining;
    if (isCompleted) return 'مكتمل ✅';
    if (days < 0) return 'منتهي منذ ${-days} يوماً ⚠️';
    if (days == 0) return 'اليوم هو الموعد الأخير 🚨';
    if (days == 1) return 'متبقي يوم واحد 🚨';
    if (days == 2) return 'متبقي يومان 🚨';
    if (days <= 10) return 'متبقي $days أيام';
    return 'متبقي $days يوماً';
  }

  factory CriticalDeadlineModel.fromJson(Map<String, dynamic> json) {
    return CriticalDeadlineModel(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      title: json['title'] as String,
      category: json['category'] as String? ?? 'أخرى',
      dueDate: DateTime.parse(json['due_date'] as String),
      reminderDaysBefore: json['reminder_days_before'] as int? ?? 30,
      notes: json['notes'] as String?,
      isCompleted: json['is_completed'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'household_id': householdId,
      'title': title,
      'category': category,
      'due_date': dueDate.toIso8601String().split('T').first,
      'reminder_days_before': reminderDaysBefore,
      'notes': notes,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CriticalDeadlineModel copyWith({
    String? id,
    String? householdId,
    String? title,
    String? category,
    DateTime? dueDate,
    int? reminderDaysBefore,
    String? notes,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return CriticalDeadlineModel(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CriticalDeadlineModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
