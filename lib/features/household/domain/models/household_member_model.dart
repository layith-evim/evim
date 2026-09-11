/// Model representing a user profile associated with a household membership
class MemberProfile {
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? _explicitFullName;

  const MemberProfile({
    this.firstName = '',
    this.lastName = '',
    String? fullName,
    this.email,
    this.phone,
  }) : _explicitFullName = fullName;

  String get fullName {
    if (_explicitFullName != null && _explicitFullName!.trim().isNotEmpty) {
      return _explicitFullName!.trim();
    }
    final combined = '$firstName $lastName'.trim();
    return combined.isNotEmpty ? combined : 'مستخدم مسجل';
  }
}

/// Model representing a user's membership in a Household
class HouseholdMemberModel {
  final String id;
  final String userId;
  final String householdId;
  final String role; // 'owner' or 'member'
  final String? userName;
  final String? userEmail;
  final MemberProfile? profile;
  final DateTime createdAt;
  final DateTime joinedAt;

  HouseholdMemberModel({
    required this.id,
    required this.userId,
    required this.householdId,
    required this.role,
    this.userName,
    this.userEmail,
    this.profile,
    DateTime? createdAt,
    DateTime? joinedAt,
  })  : createdAt = createdAt ?? joinedAt ?? DateTime.now(),
        joinedAt = joinedAt ?? createdAt ?? DateTime.now();

  bool get isOwner {
    final r = role.trim().toLowerCase();
    return r == 'owner' || r == 'admin' || r == 'مالك' || r == 'المالك';
  }

  factory HouseholdMemberModel.fromRpcJson(Map<String, dynamic> json) {
    final role = (json['role'] as String? ?? 'member').toLowerCase();
    final fullName = json['full_name'] as String? ?? (role == 'owner' ? 'مالك المنزل' : 'عضو في العائلة');
    final joinedAtRaw = json['joined_at'] ?? json['created_at'];
    final joinedAt = DateTime.tryParse(joinedAtRaw?.toString() ?? '') ?? DateTime.now();

    return HouseholdMemberModel(
      id: (json['member_id'] ?? json['id'] ?? '') as String,
      householdId: (json['household_id'] ?? '') as String,
      userId: (json['user_id'] ?? '') as String,
      role: role,
      joinedAt: joinedAt,
      createdAt: joinedAt,
      userName: fullName,
      userEmail: json['email'] as String? ?? '',
      profile: MemberProfile(
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        fullName: fullName,
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
      ),
    );
  }

  factory HouseholdMemberModel.fromJson(Map<String, dynamic> json) {
    String? name = json['user_name'] as String?;
    String? email = json['user_email'] as String?;
    MemberProfile? prof;

    if (json['profiles'] is Map<String, dynamic>) {
      final p = json['profiles'] as Map<String, dynamic>;
      final fn = (p['first_name'] as String?)?.trim() ?? '';
      final ln = (p['last_name'] as String?)?.trim() ?? '';
      final n = (p['name'] as String? ?? p['full_name'] as String?)?.trim();
      name ??= (fn.isNotEmpty || ln.isNotEmpty) ? '$fn $ln'.trim() : n;
      email ??= p['email'] as String?;

      String effectiveFirst = fn;
      String effectiveLast = ln;
      if (effectiveFirst.isEmpty && effectiveLast.isEmpty && n != null && n.isNotEmpty) {
        final parts = n.split(' ');
        effectiveFirst = parts.isNotEmpty ? parts.first : '';
        effectiveLast = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }

      prof = MemberProfile(
        firstName: effectiveFirst,
        lastName: effectiveLast,
        email: email,
      );
    } else if (name != null && name.isNotEmpty) {
      final parts = name.split(' ');
      final effectiveFirst = parts.isNotEmpty ? parts.first : '';
      final effectiveLast = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      prof = MemberProfile(
        firstName: effectiveFirst,
        lastName: effectiveLast,
        email: email,
      );
    }

    final rawCreatedAt = json['created_at'] ?? json['joined_at'];
    return HouseholdMemberModel(
      id: (json['id'] ?? json['member_id'] ?? '') as String,
      userId: json['user_id'] as String? ?? '',
      householdId: json['household_id'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      userName: name,
      userEmail: email,
      profile: prof,
      createdAt: rawCreatedAt != null
          ? DateTime.tryParse(rawCreatedAt.toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'household_id': householdId,
      'role': role,
      if (userName != null) 'user_name': userName,
      if (userEmail != null) 'user_email': userEmail,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
