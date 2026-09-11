/// Model representing a user's membership in a Household
class HouseholdMemberModel {
  final String id;
  final String userId;
  final String householdId;
  final String role; // 'owner' or 'member'
  final DateTime createdAt;

  const HouseholdMemberModel({
    required this.id,
    required this.userId,
    required this.householdId,
    required this.role,
    required this.createdAt,
  });

  bool get isOwner => role.toLowerCase() == 'owner';

  factory HouseholdMemberModel.fromJson(Map<String, dynamic> json) {
    return HouseholdMemberModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      householdId: json['household_id'] as String,
      role: json['role'] as String? ?? 'member',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'household_id': householdId,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
