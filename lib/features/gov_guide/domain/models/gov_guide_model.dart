/// Domain model for an interactive Turkish administrative process guide
class GovGuideModel {
  final String id;
  final String title;
  final String category;
  final String description;
  final String? estimatedDays;
  final String icon;

  const GovGuideModel({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    this.estimatedDays,
    required this.icon,
  });

  factory GovGuideModel.fromJson(Map<String, dynamic> json) {
    return GovGuideModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      description: json['description'] as String? ?? '',
      estimatedDays: json['estimated_days'] as String?,
      icon: json['icon'] as String? ?? 'description',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'estimated_days': estimatedDays,
      'icon': icon,
    };
  }

  GovGuideModel copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    String? estimatedDays,
    String? icon,
  }) {
    return GovGuideModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      estimatedDays: estimatedDays ?? this.estimatedDays,
      icon: icon ?? this.icon,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GovGuideModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
