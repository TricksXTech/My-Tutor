class ChapterModel {
  final String id;
  final String subjectId;
  final String unitNumber;
  final String title;
  final String description;
  final int messageCount;
  final DateTime lastUpdated;

  ChapterModel({
    required this.id,
    required this.subjectId,
    required this.unitNumber,
    required this.title,
    required this.description,
    this.messageCount = 0,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectId': subjectId,
      'unitNumber': unitNumber,
      'title': title,
      'description': description,
      'messageCount': messageCount,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    return ChapterModel(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      unitNumber: json['unitNumber'] as String? ?? 'Unit 1',
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      messageCount: json['messageCount'] as int? ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : DateTime.now(),
    );
  }

  ChapterModel copyWith({
    String? id,
    String? subjectId,
    String? unitNumber,
    String? title,
    String? description,
    int? messageCount,
    DateTime? lastUpdated,
  }) {
    return ChapterModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      unitNumber: unitNumber ?? this.unitNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      messageCount: messageCount ?? this.messageCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
