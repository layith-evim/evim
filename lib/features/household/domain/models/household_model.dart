/// Model representing a Household tenant in Evim
class HouseholdModel {
  final String id;
  final String name;
  final String inviteCode;
  final String? city;
  final bool isPremium;
  final DateTime createdAt;

  const HouseholdModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    this.city,
    this.isPremium = false,
    required this.createdAt,
  });

  factory HouseholdModel.fromJson(Map<String, dynamic> json) {
    return HouseholdModel(
      id: json['id'] as String,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String,
      city: json['city'] as String?,
      isPremium: json['is_premium'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'invite_code': inviteCode,
      if (city != null) 'city': city,
      'is_premium': isPremium,
      'created_at': createdAt.toIso8601String(),
    };
  }

  HouseholdModel copyWith({
    String? id,
    String? name,
    String? inviteCode,
    String? city,
    bool? isPremium,
    DateTime? createdAt,
  }) {
    return HouseholdModel(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      city: city ?? this.city,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HouseholdModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
