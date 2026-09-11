/// Domain model for kitchen pantry items
class PantryItemModel {
  final String id;
  final String householdId;
  final String name;
  final String quantity;
  final DateTime createdAt;

  const PantryItemModel({
    required this.id,
    required this.householdId,
    required this.name,
    this.quantity = '1',
    required this.createdAt,
  });

  factory PantryItemModel.fromJson(Map<String, dynamic> json) {
    return PantryItemModel(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as String? ?? '1',
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
      'quantity': quantity,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PantryItemModel copyWith({
    String? id,
    String? householdId,
    String? name,
    String? quantity,
    DateTime? createdAt,
  }) {
    return PantryItemModel(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PantryItemModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
