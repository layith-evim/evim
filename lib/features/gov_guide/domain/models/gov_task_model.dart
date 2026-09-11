/// Domain model for an actionable step within a Turkish administrative guide
class GovTaskModel {
  final String id;
  final String guideId;
  final int stepNumber;
  final String title;
  final String instructions;
  final List<String> requiredDocs;
  final String? eDevletLink;
  final bool isCompleted;

  const GovTaskModel({
    required this.id,
    required this.guideId,
    required this.stepNumber,
    required this.title,
    required this.instructions,
    required this.requiredDocs,
    this.eDevletLink,
    this.isCompleted = false,
  });

  factory GovTaskModel.fromJson(Map<String, dynamic> json, {bool isCompleted = false}) {
    List<String> docs = [];
    final rawDocs = json['required_docs'];
    if (rawDocs is List) {
      docs = rawDocs.map((e) => e.toString()).toList();
    } else if (rawDocs is String && rawDocs.isNotEmpty) {
      docs = rawDocs.split(',').map((e) => e.trim()).toList();
    }

    return GovTaskModel(
      id: json['id'] as String? ?? '',
      guideId: json['guide_id'] as String? ?? '',
      stepNumber: (json['step_number'] as num?)?.toInt() ?? 1,
      title: json['title'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
      requiredDocs: docs,
      eDevletLink: json['e_devlet_link'] as String?,
      isCompleted: isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'guide_id': guideId,
      'step_number': stepNumber,
      'title': title,
      'instructions': instructions,
      'required_docs': requiredDocs,
      'e_devlet_link': eDevletLink,
    };
  }

  GovTaskModel copyWith({
    String? id,
    String? guideId,
    int? stepNumber,
    String? title,
    String? instructions,
    List<String>? requiredDocs,
    String? eDevletLink,
    bool? isCompleted,
  }) {
    return GovTaskModel(
      id: id ?? this.id,
      guideId: guideId ?? this.guideId,
      stepNumber: stepNumber ?? this.stepNumber,
      title: title ?? this.title,
      instructions: instructions ?? this.instructions,
      requiredDocs: requiredDocs ?? this.requiredDocs,
      eDevletLink: eDevletLink ?? this.eDevletLink,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GovTaskModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isCompleted == other.isCompleted;

  @override
  int get hashCode => Object.hash(id, isCompleted);
}
