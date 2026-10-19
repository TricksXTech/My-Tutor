class ChatMessageModel {
  final String id;
  final String chapterId;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? modelEngine;
  bool isSpeaking;

  final String? attachmentType; // 'pdf' or 'image'
  final String? attachmentName;
  final String? attachmentPath;
  final String? caption;
  final String? documentId;

  ChatMessageModel({
    required this.id,
    required this.chapterId,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.modelEngine,
    this.isSpeaking = false,
    this.attachmentType,
    this.attachmentName,
    this.attachmentPath,
    this.caption,
    this.documentId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapterId': chapterId,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'modelEngine': modelEngine,
      'attachmentType': attachmentType,
      'attachmentName': attachmentName,
      'attachmentPath': attachmentPath,
      'caption': caption,
      'documentId': documentId,
    };
  }

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      text: json['text'] as String,
      isUser: json['isUser'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      modelEngine: json['modelEngine'] as String?,
      isSpeaking: false,
      attachmentType: json['attachmentType'] as String?,
      attachmentName: json['attachmentName'] as String?,
      attachmentPath: json['attachmentPath'] as String?,
      caption: json['caption'] as String?,
      documentId: json['documentId'] as String?,
    );
  }

  ChatMessageModel copyWith({
    String? id,
    String? chapterId,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? modelEngine,
    bool? isSpeaking,
    String? attachmentType,
    String? attachmentName,
    String? attachmentPath,
    String? caption,
    String? documentId,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      modelEngine: modelEngine ?? this.modelEngine,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      attachmentType: attachmentType ?? this.attachmentType,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      caption: caption ?? this.caption,
      documentId: documentId ?? this.documentId,
    );
  }
}
