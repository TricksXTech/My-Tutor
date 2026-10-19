import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../data/models/subject_model.dart';
import '../data/services/storage_service.dart';

class SubjectProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<SubjectModel> _subjects = [];
  bool _isLoading = false;

  SubjectProvider(this._storageService) {
    loadSubjects();
  }

  List<SubjectModel> get subjects => _subjects;
  bool get isLoading => _isLoading;
  bool get canAddSubject => _subjects.length < AppConstants.maxSubjectsLimit;
  int get currentCount => _subjects.length;
  int get maxLimit => AppConstants.maxSubjectsLimit;

  void loadSubjects() {
    _isLoading = true;
    notifyListeners();
    _subjects = _storageService.getSubjects();
    _isLoading = false;
    notifyListeners();
  }

  /// Adds a new subject if count < 7 limit.
  /// Returns null on success, or an error string (e.g. limit warning).
  Future<String?> addSubject({
    required String title,
    required String code,
    required String description,
    required int colorValue,
    required String iconCode,
  }) async {
    if (!canAddSubject) {
      return AppConstants.maxLimitWarning;
    }

    final newSubject = SubjectModel(
      id: 'sub_${const Uuid().v4().substring(0, 8)}',
      title: title.trim(),
      code: code.trim().isEmpty ? 'CSE' : code.trim().toUpperCase(),
      description: description.trim(),
      colorValue: colorValue,
      iconCode: iconCode,
      createdAt: DateTime.now(),
    );

    _subjects.add(newSubject);
    await _storageService.saveSubjects(_subjects);
    notifyListeners();
    return null;
  }

  Future<void> deleteSubject(String subjectId) async {
    _subjects.removeWhere((s) => s.id == subjectId);
    await _storageService.saveSubjects(_subjects);
    notifyListeners();
  }

  Future<void> updateSubject(SubjectModel updated) async {
    final index = _subjects.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      _subjects[index] = updated;
      await _storageService.saveSubjects(_subjects);
      notifyListeners();
    }
  }

  SubjectModel? getSubjectById(String id) {
    try {
      return _subjects.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
