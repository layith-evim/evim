/// Domain model for recurring monthly bills and expenses
class RecurringExpenseModel {
  final String id;
  final String householdId;
  final String title;
  final String category; // 'إيجار', 'عائدات', 'غاز', 'ماء', 'كهرباء', 'إنترنت', 'عام'
  final double amount;
  final int? dueDay; // 1 to 31
  final bool isPaid;
  final DateTime? lastPaidAt;
  final DateTime createdAt;

  const RecurringExpenseModel({
    required this.id,
    required this.householdId,
    required this.title,
    required this.category,
    required this.amount,
    this.dueDay,
    this.isPaid = false,
    this.lastPaidAt,
    required this.createdAt,
  });

  factory RecurringExpenseModel.fromJson(Map<String, dynamic> json) {
    return RecurringExpenseModel(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      title: json['title'] as String,
      category: json['category'] as String? ?? 'عام',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      dueDay: json['due_day'] as int?,
      isPaid: json['is_paid'] as bool? ?? false,
      lastPaidAt: json['last_paid_at'] != null
          ? DateTime.parse(json['last_paid_at'] as String)
          : null,
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
      'amount': amount,
      'due_day': dueDay,
      'is_paid': isPaid,
      'last_paid_at': lastPaidAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  RecurringExpenseModel copyWith({
    String? id,
    String? householdId,
    String? title,
    String? category,
    double? amount,
    int? dueDay,
    bool? isPaid,
    DateTime? lastPaidAt,
    DateTime? createdAt,
  }) {
    return RecurringExpenseModel(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      dueDay: dueDay ?? this.dueDay,
      isPaid: isPaid ?? this.isPaid,
      lastPaidAt: lastPaidAt ?? this.lastPaidAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringExpenseModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
