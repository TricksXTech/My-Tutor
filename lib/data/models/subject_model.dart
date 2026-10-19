class SubjectModel {
  final String id;
  final String title;
  final String code;
  final String description;
  final int colorValue;
  final String iconCode;
  final DateTime createdAt;

  SubjectModel({
    required this.id,
    required this.title,
    required this.code,
    required this.description,
    required this.colorValue,
    required this.iconCode,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'code': code,
      'description': description,
      'colorValue': colorValue,
      'iconCode': iconCode,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'] as String,
      title: json['title'] as String,
      code: json['code'] as String? ?? 'CSE',
      description: json['description'] as String? ?? '',
      colorValue: json['colorValue'] as int? ?? 0xFF6C5CE7,
      iconCode: json['iconCode'] as String? ?? 'book',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  SubjectModel copyWith({
    String? id,
    String? title,
    String? code,
    String? description,
    int? colorValue,
    String? iconCode,
    DateTime? createdAt,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      code: code ?? this.code,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      iconCode: iconCode ?? this.iconCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
