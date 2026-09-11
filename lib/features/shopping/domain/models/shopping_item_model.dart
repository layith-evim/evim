/// Domain model for collaborative shopping items
class ShoppingItemModel {
  final String id;
  final String householdId;
  final String name;
  final String category;
  final String quantity;
  final bool isBought;
  final String? boughtBy;
  final DateTime createdAt;

  const ShoppingItemModel({
    required this.id,
    required this.householdId,
    required this.name,
    this.category = 'عام',
    this.quantity = '1',
    this.isBought = false,
    this.boughtBy,
    required this.createdAt,
  });

  factory ShoppingItemModel.fromJson(Map<String, dynamic> json) {
    return ShoppingItemModel(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'عام',
      quantity: json['quantity'] as String? ?? '1',
      isBought: json['is_bought'] as bool? ?? false,
      boughtBy: json['bought_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'household_id': householdId,
      'name': name,
      'category': category,
      'quantity': quantity,
      'is_bought': isBought,
      'bought_by': boughtBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ShoppingItemModel copyWith({
    String? id,
    String? householdId,
    String? name,
    String? category,
    String? quantity,
    bool? isBought,
    String? boughtBy,
    DateTime? createdAt,
  }) {
    return ShoppingItemModel(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      isBought: isBought ?? this.isBought,
      boughtBy: boughtBy ?? this.boughtBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoppingItemModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
