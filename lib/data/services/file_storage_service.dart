import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chat_message_model.dart';
import '../models/saved_document_model.dart';

class StorageBreakdown {
  final int chatsBytes;
  final int documentsBytes;
  final int modelsBytes;
  final int backupBytes;

  StorageBreakdown({
    required this.chatsBytes,
    required this.documentsBytes,
    required this.modelsBytes,
    required this.backupBytes,
  });

  int get totalBytes => chatsBytes + documentsBytes + modelsBytes + backupBytes;

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get chatsSizeFormatted => formatBytes(chatsBytes);
  String get documentsSizeFormatted => formatBytes(documentsBytes);
  String get modelsSizeFormatted => formatBytes(modelsBytes);
  String get backupSizeFormatted => formatBytes(backupBytes);
  String get totalSizeFormatted => formatBytes(totalBytes);
}

/// High-Performance File-Based Storage Engine
/// - One JSON file per chat room: tutor_data/chats/{chapterId}.json
/// - One JSON file per document: tutor_data/documents/{docId}.json
/// - Lightweight document index: tutor_data/documents/index.json
/// - Debounced incremental writes
/// - Safe one-time migration with backup
class FileStorageService {
  static FileStorageService? _instance;
  Directory? _baseDir;
  Directory? _chatsDir;
  Directory? _documentsDir;
  Directory? _backupDir;

  final Map<String, Timer> _saveDebouncers = {};
  final Map<String, List<ChatMessageModel>> _pendingChatSaves = {};

  FileStorageService._();

  static Future<FileStorageService> getInstance() async {
    if (_instance == null) {
      _instance = FileStorageService._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    Directory docsDir;
    try {
      docsDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      docsDir = Directory.systemTemp.createTempSync('tutor_storage');
    }
    _baseDir = Directory('${docsDir.path}/tutor_data');
    _chatsDir = Directory('${_baseDir!.path}/chats');
    _documentsDir = Directory('${_baseDir!.path}/documents');
    _backupDir = Directory('${_baseDir!.path}/backup');

    if (!await _chatsDir!.exists()) await _chatsDir!.create(recursive: true);
    if (!await _documentsDir!.exists()) await _documentsDir!.create(recursive: true);
    if (!await _backupDir!.exists()) await _backupDir!.create(recursive: true);
  }

  // ================= CHAT MESSAGES =================

  /// Lazily loads messages for a single specific chat room from its JSON file
  Future<List<ChatMessageModel>> getMessagesForChapter(String chapterId) async {
    // If there is an unflushed in-memory pending save for this chapter, return it
    if (_pendingChatSaves.containsKey(chapterId)) {
      return List<ChatMessageModel>.from(_pendingChatSaves[chapterId]!);
    }

    final file = File('${_chatsDir!.path}/$chapterId.json');
    if (!await file.exists()) return [];

    try {
      final jsonStr = await file.readAsString();
      if (jsonStr.isEmpty) return [];

      return await Isolate.run(() {
        final List<dynamic> list = jsonDecode(jsonStr);
        return list.map((item) => ChatMessageModel.fromJson(item as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      debugPrint('Error reading chat file for $chapterId: $e');
      return [];
    }
  }

  /// Incremental save for one chapter room with optional debouncing during streaming
  Future<void> saveMessagesForChapter(
    String chapterId,
    List<ChatMessageModel> messages, {
    bool debounce = false,
  }) async {
    _pendingChatSaves[chapterId] = List<ChatMessageModel>.from(messages);

    if (debounce) {
      _saveDebouncers[chapterId]?.cancel();
      _saveDebouncers[chapterId] = Timer(const Duration(milliseconds: 1200), () {
        _writeChatFileDirectly(chapterId);
      });
    } else {
      _saveDebouncers[chapterId]?.cancel();
      await _writeChatFileDirectly(chapterId);
    }
  }

  Future<void> _writeChatFileDirectly(String chapterId) async {
    final messages = _pendingChatSaves[chapterId];
    if (messages == null) return;

    try {
      final file = File('${_chatsDir!.path}/$chapterId.json');
      final jsonStr = await Isolate.run(() {
        final list = messages.map((m) => m.toJson()).toList();
        return jsonEncode(list);
      });
      await file.writeAsString(jsonStr, flush: true);
    } catch (e) {
      debugPrint('Error writing chat file for $chapterId: $e');
    }
  }

  /// Flushes any pending debounced writes immediately
  Future<void> flushAllPendingSaves() async {
    for (final chapterId in _pendingChatSaves.keys.toList()) {
      _saveDebouncers[chapterId]?.cancel();
      await _writeChatFileDirectly(chapterId);
    }
  }

  /// Deletes a single chat room file
  Future<void> deleteChatRoom(String chapterId) async {
    _saveDebouncers[chapterId]?.cancel();
    _pendingChatSaves.remove(chapterId);

    final file = File('${_chatsDir!.path}/$chapterId.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Returns all messages across all chapters (aggregated on-demand for backup/global search)
  Future<List<ChatMessageModel>> getAllMessages() async {
    await flushAllPendingSaves();
    final List<ChatMessageModel> all = [];
    if (!await _chatsDir!.exists()) return all;

    final files = _chatsDir!.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    for (final f in files) {
      try {
        final content = await f.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> list = jsonDecode(content);
          all.addAll(list.map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>)));
        }
      } catch (_) {}
    }
    all.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return all;
  }

  /// Clears all chat room files
  Future<void> clearAllChats() async {
    for (final timer in _saveDebouncers.values) {
      timer.cancel();
    }
    _saveDebouncers.clear();
    _pendingChatSaves.clear();

    if (await _chatsDir!.exists()) {
      final files = _chatsDir!.listSync().whereType<File>();
      for (final f in files) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }

  // ================= SAVED DOCUMENTS =================

  /// Reads lightweight document metadata index (without multi-megabyte extractedText)
  Future<List<SavedDocumentModel>> getDocumentsIndex() async {
    final indexFile = File('${_documentsDir!.path}/index.json');
    if (!await indexFile.exists()) return [];

    try {
      final jsonStr = await indexFile.readAsString();
      if (jsonStr.isEmpty) return [];

      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => SavedDocumentModel.fromJson(item as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    } catch (e) {
      debugPrint('Error reading documents index: $e');
      return [];
    }
  }

  /// Loads full document with full extractedText lazily when needed
  Future<SavedDocumentModel?> getDocument(String id) async {
    final file = File('${_documentsDir!.path}/$id.json');
    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      if (content.isEmpty) return null;
      return SavedDocumentModel.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error reading document $id: $e');
      return null;
    }
  }

  /// Loads all documents with full extractedText
  Future<List<SavedDocumentModel>> getAllDocuments() async {
    final index = await getDocumentsIndex();
    final List<SavedDocumentModel> list = [];
    for (final item in index) {
      final doc = await getDocument(item.id);
      if (doc != null) {
        list.add(doc);
      } else {
        list.add(item);
      }
    }
    return list;
  }

  /// Saves a document incrementally to its own file and updates index.json
  Future<bool> saveDocument(SavedDocumentModel doc) async {
    try {
      // 1. Write full document file with extractedText
      final docFile = File('${_documentsDir!.path}/${doc.id}.json');
      await docFile.writeAsString(jsonEncode(doc.toJson()));

      // 2. Update index.json (metadata only)
      final existingIndex = await getDocumentsIndex();
      existingIndex.removeWhere((d) => d.id == doc.id);
      existingIndex.insert(0, doc);

      // Cap index to 50 most recent
      final capped = existingIndex.length > 50 ? existingIndex.sublist(0, 50) : existingIndex;
      final indexItems = capped.map((d) {
        final json = d.toJson();
        json['extractedText'] = ''; // strip heavy text from index
        return json;
      }).toList();

      final indexFile = File('${_documentsDir!.path}/index.json');
      await indexFile.writeAsString(jsonEncode(indexItems));
      return true;
    } catch (e) {
      debugPrint('Error saving document ${doc.id}: $e');
      return false;
    }
  }

  /// Deletes a document file and updates index
  Future<bool> deleteDocument(String id) async {
    try {
      final docFile = File('${_documentsDir!.path}/$id.json');
      if (await docFile.exists()) {
        await docFile.delete();
      }

      final existingIndex = await getDocumentsIndex();
      existingIndex.removeWhere((d) => d.id == id);
      final indexItems = existingIndex.map((d) {
        final json = d.toJson();
        json['extractedText'] = '';
        return json;
      }).toList();

      final indexFile = File('${_documentsDir!.path}/index.json');
      await indexFile.writeAsString(jsonEncode(indexItems));
      return true;
    } catch (e) {
      debugPrint('Error deleting document $id: $e');
      return false;
    }
  }

  /// Clears all document files and resets index
  Future<void> clearAllDocuments() async {
    if (await _documentsDir!.exists()) {
      final files = _documentsDir!.listSync().whereType<File>();
      for (final f in files) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }

  // ================= STORAGE MANAGEMENT & METRICS =================

  /// Calculates total size of a directory recursively
  Future<int> _calculateDirSize(Directory? dir) async {
    if (dir == null || !await dir.exists()) return 0;
    int total = 0;
    try {
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final e in entities) {
        if (e is File) {
          total += await e.length();
        }
      }
    } catch (_) {}
    return total;
  }

  /// Provides detailed storage usage metrics
  Future<StorageBreakdown> getStorageBreakdown() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${docsDir.path}/models');

    final chats = await _calculateDirSize(_chatsDir);
    final documents = await _calculateDirSize(_documentsDir);
    final backup = await _calculateDirSize(_backupDir);
    final models = await _calculateDirSize(modelsDir);

    return StorageBreakdown(
      chatsBytes: chats,
      documentsBytes: documents,
      modelsBytes: models,
      backupBytes: backup,
    );
  }
}
