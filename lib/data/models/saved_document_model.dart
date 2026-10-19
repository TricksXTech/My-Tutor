class SavedDocumentModel {
  final String id;
  final String fileName;
  final String fileType; // 'pdf' or 'image'
  final String localPath;
  final DateTime uploadedAt;
  final String chapterId;
  final String subjectTitle;
  final String? caption;
  final String extractedText;
  final int characterCount;

  SavedDocumentModel({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.localPath,
    required this.uploadedAt,
    required this.chapterId,
    required this.subjectTitle,
    this.caption,
    required this.extractedText,
    int? characterCount,
  }) : characterCount = characterCount ?? extractedText.length;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'fileType': fileType,
      'localPath': localPath,
      'uploadedAt': uploadedAt.toIso8601String(),
      'chapterId': chapterId,
      'subjectTitle': subjectTitle,
      'caption': caption,
      'extractedText': extractedText,
      'characterCount': characterCount,
    };
  }

  factory SavedDocumentModel.fromJson(Map<String, dynamic> json) {
    return SavedDocumentModel(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      fileType: json['fileType'] as String? ?? 'pdf',
      localPath: json['localPath'] as String? ?? '',
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.parse(json['uploadedAt'] as String)
          : DateTime.now(),
      chapterId: json['chapterId'] as String? ?? '',
      subjectTitle: json['subjectTitle'] as String? ?? '',
      caption: json['caption'] as String?,
      extractedText: json['extractedText'] as String? ?? '',
      characterCount: json['characterCount'] as int? ??
          (json['extractedText'] as String? ?? '').length,
    );
  }
}
