import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/chapter_model.dart';
import '../data/services/storage_service.dart';

class ChapterProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<ChapterModel> _allChapters = [];

  ChapterProvider(this._storageService) {
    loadChapters();
  }

  List<ChapterModel> get allChapters => _allChapters;

  void loadChapters() {
    _allChapters = _storageService.getChapters();
    notifyListeners();
  }

  List<ChapterModel> getChaptersForSubject(String subjectId) {
    return _allChapters.where((c) => c.subjectId == subjectId).toList();
  }

  Future<void> addChapter({
    required String subjectId,
    required String title,
    required String unitNumber,
    required String description,
  }) async {
    final newChapter = ChapterModel(
      id: 'chap_${const Uuid().v4().substring(0, 8)}',
      subjectId: subjectId,
      unitNumber: unitNumber.trim().isEmpty ? 'Unit ${_allChapters.where((c) => c.subjectId == subjectId).length + 1}' : unitNumber.trim(),
      title: title.trim(),
      description: description.trim(),
      messageCount: 0,
      lastUpdated: DateTime.now(),
    );

    _allChapters.add(newChapter);
    await _storageService.saveChapters(_allChapters);
    notifyListeners();
  }

  Future<void> deleteChapter(String chapterId) async {
    _allChapters.removeWhere((c) => c.id == chapterId);
    await _storageService.saveChapters(_allChapters);
    notifyListeners();
  }

  Future<void> incrementMessageCount(String chapterId) async {
    final index = _allChapters.indexWhere((c) => c.id == chapterId);
    if (index != -1) {
      final current = _allChapters[index];
      _allChapters[index] = current.copyWith(
        messageCount: current.messageCount + 1,
        lastUpdated: DateTime.now(),
      );
      await _storageService.saveChapters(_allChapters);
      notifyListeners();
    }
  }

  ChapterModel? getChapterById(String id) {
    try {
      return _allChapters.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
