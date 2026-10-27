import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../models/subject_model.dart';
import '../models/chapter_model.dart';
import '../models/chat_message_model.dart';
import '../models/saved_document_model.dart';
import 'file_storage_service.dart';

class StorageService {
  static StorageService? _instance;
  static SharedPreferences? _prefs;
  static FileStorageService? _fileStorage;

  List<ChatMessageModel> _cachedMessages = [];
  List<SavedDocumentModel> _cachedDocuments = [];

  StorageService._();

  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      _prefs = await SharedPreferences.getInstance();
      _fileStorage = await FileStorageService.getInstance();
      await _instance!._initStorage();
    }
    return _instance!;
  }

  Future<void> _initStorage() async {
    await _seedDefaultDataIfEmpty();
    _cachedMessages = await _fileStorage!.getAllMessages();
    _cachedDocuments = await _fileStorage!.getAllDocuments();
  }

  Future<void> _seedDefaultDataIfEmpty() async {
    final existingSubjects = _prefs?.getString(AppConstants.keySubjects);
    if (existingSubjects == null || existingSubjects.isEmpty || existingSubjects == '[]') {
      final initialSubjects = [
        SubjectModel(
          id: 'sub_physics',
          title: 'Engineering Physics',
          code: 'PHY-101',
          description: 'Quantum, Semiconductors, Wave Optics & Lasers',
          colorValue: 0xFF6C5CE7, // Indigo
          iconCode: 'science',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        SubjectModel(
          id: 'sub_chemistry',
          title: 'Engineering Chemistry',
          code: 'CHM-102',
          description: 'Polymers, Nanomaterials, Corrosion & Battery Tech',
          colorValue: 0xFF00CEC9, // Cyan
          iconCode: 'biotech',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        SubjectModel(
          id: 'sub_maths',
          title: 'Engineering Math',
          code: 'MTH-103',
          description: 'Linear Algebra, Eigenvalues, Calculus & Differential Eq',
          colorValue: 0xFFFD79A8, // Pink
          iconCode: 'functions',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        SubjectModel(
          id: 'sub_dsa',
          title: 'Data Structures & Algo',
          code: 'CSE-201',
          description: 'Arrays, Linked Lists, Trees, Graphs & Complexity',
          colorValue: 0xFF00B894, // Emerald
          iconCode: 'account_tree',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        SubjectModel(
          id: 'sub_c_prog',
          title: 'C & Memory Management',
          code: 'CSE-102',
          description: 'Pointers, Dynamic Allocation, Bitwise & Structs',
          colorValue: 0xFFFDCB6E, // Amber
          iconCode: 'code',
          createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        ),
      ];

      final initialChapters = [
        // Physics Units
        ChapterModel(
          id: 'chap_phy_1',
          subjectId: 'sub_physics',
          unitNumber: 'Unit 1',
          title: 'Semiconductors & Band Theory',
          description: 'Intrinsic vs Extrinsic, Fermi level & Energy gaps',
          messageCount: 1,
          lastUpdated: DateTime.now(),
        ),
        ChapterModel(
          id: 'chap_phy_2',
          subjectId: 'sub_physics',
          unitNumber: 'Unit 2',
          title: 'Lasers & Optical Fiber',
          description: 'Stimulated emission, Population inversion & Snell law',
          messageCount: 0,
          lastUpdated: DateTime.now(),
        ),
        // Chemistry Units
        ChapterModel(
          id: 'chap_chm_1',
          subjectId: 'sub_chemistry',
          unitNumber: 'Unit 1',
          title: 'Polymers & Composites',
          description: 'Addition vs Condensation, Conducting polymers',
          messageCount: 0,
          lastUpdated: DateTime.now(),
        ),
        ChapterModel(
          id: 'chap_chm_2',
          subjectId: 'sub_chemistry',
          unitNumber: 'Unit 2',
          title: 'Batteries & Energy Storage',
          description: 'Lithium-ion mechanism, Fuel cells & Corrosion control',
          messageCount: 0,
          lastUpdated: DateTime.now(),
        ),
        // Math Units
        ChapterModel(
          id: 'chap_mth_1',
          subjectId: 'sub_maths',
          unitNumber: 'Unit 1',
          title: 'Eigenvalues & Diagonalization',
          description: 'Cayley-Hamilton Theorem, Orthogonal transformation',
          messageCount: 1,
          lastUpdated: DateTime.now(),
        ),
        // DSA Units
        ChapterModel(
          id: 'chap_dsa_1',
          subjectId: 'sub_dsa',
          unitNumber: 'Unit 1',
          title: 'Pointers & Linked Lists',
          description: 'Singly vs Doubly, Fast & Slow pointer analogies',
          messageCount: 1,
          lastUpdated: DateTime.now(),
        ),
        // C Units
        ChapterModel(
          id: 'chap_c_1',
          subjectId: 'sub_c_prog',
          unitNumber: 'Unit 1',
          title: 'Pointers Demystified (* & &)',
          description: 'Dereferencing, Pointer arithmetic, Malloc vs Calloc',
          messageCount: 1,
          lastUpdated: DateTime.now(),
        ),
      ];

      final initialMessages = [
        ChatMessageModel(
          id: 'msg_welcome_c',
          chapterId: 'chap_c_1',
          text: 'Arrey student! Swagat hai C Programming room mein. Agar pointers se darr lagta hai, tension mat lo! Socho pointer bas ek **gharka address paper** hai, ghar nahi. Kya doubt hai poocho!',
          isUser: false,
          timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
        ChatMessageModel(
          id: 'msg_welcome_phy',
          chapterId: 'chap_phy_1',
          text: 'Namaste! Physics mein semiconductors samajhna bahut simple hai agar energy band diagram clear ho jaye. Batao Valency band aur Conduction band mein kya confusion hai?',
          isUser: false,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ];

      await saveSubjects(initialSubjects);
      await saveChapters(initialChapters);
      await saveMessages(initialMessages);
    }
  }

  // --- SUBJECTS ---
  List<SubjectModel> getSubjects() {
    final jsonStr = _prefs?.getString(AppConstants.keySubjects);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => SubjectModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> saveSubjects(List<SubjectModel> subjects) async {
    final list = subjects.map((s) => s.toJson()).toList();
    return await _prefs?.setString(AppConstants.keySubjects, jsonEncode(list)) ?? false;
  }

  // --- CHAPTERS ---
  List<ChapterModel> getChapters() {
    final jsonStr = _prefs?.getString(AppConstants.keyChapters);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => ChapterModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> saveChapters(List<ChapterModel> chapters) async {
    final list = chapters.map((c) => c.toJson()).toList();
    return await _prefs?.setString(AppConstants.keyChapters, jsonEncode(list)) ?? false;
  }

  // --- MESSAGES ---
  List<ChatMessageModel> getMessages() {
    return List<ChatMessageModel>.from(_cachedMessages);
  }

  /// Lazily loads messages for a specific chapter room from disk
  Future<List<ChatMessageModel>> getMessagesForChapter(String chapterId) async {
    return await _fileStorage?.getMessagesForChapter(chapterId) ?? [];
  }

  /// Saves messages incrementally for a specific room
  Future<void> saveMessagesForChapter(
    String chapterId,
    List<ChatMessageModel> messages, {
    bool debounce = false,
  }) async {
    _cachedMessages.removeWhere((m) => m.chapterId == chapterId);
    _cachedMessages.addAll(messages);
    _cachedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    await _fileStorage?.saveMessagesForChapter(chapterId, messages, debounce: debounce);
  }

  Future<bool> saveMessages(List<ChatMessageModel> messages) async {
    _cachedMessages = List<ChatMessageModel>.from(messages);
    final Map<String, List<ChatMessageModel>> partitioned = {};
    for (final m in messages) {
      partitioned.putIfAbsent(m.chapterId, () => []).add(m);
    }
    for (final entry in partitioned.entries) {
      await _fileStorage?.saveMessagesForChapter(entry.key, entry.value);
    }
    return true;
  }

  // Settings
  bool getAutoSpeak() {
    return _prefs?.getBool(AppConstants.keyAutoSpeak) ?? true;
  }

  Future<void> setAutoSpeak(bool value) async {
    await _prefs?.setBool(AppConstants.keyAutoSpeak, value);
  }

  double getSpeechRate() {
    return _prefs?.getDouble(AppConstants.keySpeechRate) ?? 0.45;
  }

  Future<void> setSpeechRate(double value) async {
    await _prefs?.setDouble(AppConstants.keySpeechRate, value);
  }

  String getResponseLanguage() {
    return _prefs?.getString(AppConstants.keyResponseLanguage) ?? 'hinglish';
  }

  Future<void> setResponseLanguage(String lang) async {
    await _prefs?.setString(AppConstants.keyResponseLanguage, lang);
  }

  String getVoiceLanguage() {
    return _prefs?.getString(AppConstants.keyVoiceLanguage) ?? 'hi_IN';
  }

  Future<void> setVoiceLanguage(String lang) async {
    await _prefs?.setString(AppConstants.keyVoiceLanguage, lang);
  }

  String getSelectedLlmMode() {
    return _prefs?.getString('key_selected_llm_mode') ?? 'builtinHinglish';
  }

  Future<void> setSelectedLlmMode(String mode) async {
    await _prefs?.setString('key_selected_llm_mode', mode);
  }

  bool getUseOnlineData() {
    return _prefs?.getBool(AppConstants.keyUseOnlineData) ?? false;
  }

  Future<void> setUseOnlineData(bool value) async {
    await _prefs?.setBool(AppConstants.keyUseOnlineData, value);
  }

  // --- SAVED DOCUMENT ATTACHMENTS & PERSISTENT MEMORY ---
  List<SavedDocumentModel> getSavedDocuments() {
    return List<SavedDocumentModel>.from(_cachedDocuments);
  }

  /// FIX CAUSE 2: Strict per-chat attachment isolation
  List<SavedDocumentModel> getDocumentsForChapter(String chapterId) {
    return _cachedDocuments.where((d) => d.chapterId == chapterId).toList();
  }

  Future<bool> saveDocument(SavedDocumentModel doc) async {
    _cachedDocuments.removeWhere((d) => d.id == doc.id);
    _cachedDocuments.insert(0, doc);
    if (_cachedDocuments.length > 50) {
      _cachedDocuments = _cachedDocuments.sublist(0, 50);
    }
    return await _fileStorage?.saveDocument(doc) ?? false;
  }

  Future<bool> deleteDocument(String id) async {
    _cachedDocuments.removeWhere((d) => d.id == id);
    return await _fileStorage?.deleteDocument(id) ?? false;
  }

  /// Searches saved documents when student asks questions referencing past PDFs/notes/photos
  /// Strictly isolated to the current chapter room.
  List<SavedDocumentModel> findRelevantDocuments(String query, {String? currentChapterId}) {
    var docs = getSavedDocuments();
    // FIX CAUSE 2: Never search or return documents belonging to other chats
    if (currentChapterId != null && currentChapterId.isNotEmpty) {
      docs = docs.where((d) => d.chapterId == currentChapterId).toList();
    }
    if (docs.isEmpty) return [];

    final lowerQuery = query.toLowerCase().trim();

    // 1. Strict recall intent detection (e.g., "remember I sent a pdf of my notes", "5-10 days old notes", "maine jo bheja tha")
    final recallRegex = RegExp(
      r'\b(remember|yaad|bheja|uploaded|upload|pdf|notes|sent|photo|image|pic|days?\s*ago|din\s*pehle|earlier\s*notes|previous\s*pdf|puran[aei]\s*(?:notes|pdf|file)|document)\b',
      caseSensitive: false,
    );
    final bool hasRecallIntent = recallRegex.hasMatch(lowerQuery);

    // 2. Direct match by file name (e.g. user mentions "iot lab" or "shishodia")
    final nameMatches = docs.where((doc) {
      final nameClean = doc.fileName.toLowerCase().replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final nameWords = nameClean.split(RegExp(r'[\s_\-]+')).where((w) => w.length > 2);
      for (final word in nameWords) {
        if (RegExp(r'\b' + RegExp.escape(word) + r'\b').hasMatch(lowerQuery)) return true;
      }
      return false;
    }).toList();

    if (nameMatches.isNotEmpty) {
      return nameMatches;
    }

    // 3. If recall intent is detected (e.g. "remember I sent a pdf 5-10 days ago")
    if (hasRecallIntent) {
      if (currentChapterId != null && currentChapterId.isNotEmpty) {
        final chapterDocs = docs.where((d) => d.chapterId == currentChapterId).toList();
        if (chapterDocs.isNotEmpty) return chapterDocs;
      }
      return docs.take(2).toList();
    }

    // 4. Content match ONLY with significant technical terms (strictly exclude common words/stop words)
    const stopWords = {
      'what', 'whats', 'your', 'name', 'model', 'this', 'that', 'with', 'from',
      'have', 'tell', 'give', 'when', 'where', 'which', 'about', 'some', 'more',
      'help', 'tutor', 'hello', 'please', 'good', 'know', 'like', 'there',
      'their', 'would', 'could', 'should', 'been', 'were', 'them', 'then',
      'make', 'does', 'doing', 'here', 'just', 'only', 'very', 'than', 'much',
      'mean', 'means', 'meaning', 'define', 'definition', 'explain', 'detail',
      'details', 'why', 'how', 'work', 'working', 'used', 'using', 'role',
      'purpose', 'kya', 'hai', 'hota', 'karo', 'batao', 'kyun'
    };

    final significantWords = lowerQuery
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^\w\-]'), ''))
        .where((w) => w.length >= 3 && !stopWords.contains(w))
        .toList();

    if (significantWords.isEmpty) return [];

    final scored = <SavedDocumentModel, int>{};
    for (final doc in docs) {
      final isCurrentChapter = currentChapterId != null && doc.chapterId == currentChapterId;
      final lowerContent = doc.extractedText.toLowerCase();
      int matchCount = 0;
      for (final word in significantWords) {
        if (lowerContent.contains(word)) {
          matchCount += (word.length >= 5 || RegExp(r'[0-9]').hasMatch(word)) ? 2 : 1;
        }
      }
      // In current chapter, even 1 specific keyword (e.g. "2n2222", "pir", "sensor") matches!
      // For cross-chapter, require score >= 2.
      if (isCurrentChapter && matchCount >= 1) {
        scored[doc] = matchCount + 5; // Boost current chapter relevance
      } else if (matchCount >= 2) {
        scored[doc] = matchCount;
      }
    }

    if (scored.isEmpty) return [];

    final sorted = scored.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(2).map((e) => e.key).toList();
  }

  // Active Model Name Persistence (when user has multiple models downloaded)
  String getActiveGgufModelName() {
    return _prefs?.getString('key_active_gguf_model_name') ?? AppConstants.gemmaModelName;
  }

  Future<void> setActiveGgufModelName(String modelName) async {
    await _prefs?.setString('key_active_gguf_model_name', modelName);
  }

  /// Clears all stored chat messages
  Future<void> clearAllChatMessages() async {
    _cachedMessages.clear();
    await _fileStorage?.clearAllChats();
    await _prefs?.remove(AppConstants.keyChatMessages);
  }

  /// Clears all saved documents & extracted text
  Future<void> clearAllSavedDocuments() async {
    _cachedDocuments.clear();
    await _fileStorage?.clearAllDocuments();
    await _prefs?.remove(AppConstants.keySavedDocuments);
  }

  /// Clears all user data (messages, documents, subjects, chapters) and resets to default seed
  Future<void> clearAllData() async {
    _cachedMessages.clear();
    _cachedDocuments.clear();
    await _fileStorage?.clearAllChats();
    await _fileStorage?.clearAllDocuments();
    await _prefs?.remove(AppConstants.keyChatMessages);
    await _prefs?.remove(AppConstants.keySavedDocuments);
    await _prefs?.remove(AppConstants.keySubjects);
    await _prefs?.remove(AppConstants.keyChapters);
    await _seedDefaultDataIfEmpty();
  }

  /// Provides detailed storage breakdown metrics
  Future<StorageBreakdown> getStorageBreakdown() async {
    return await _fileStorage?.getStorageBreakdown() ??
        StorageBreakdown(chatsBytes: 0, documentsBytes: 0, modelsBytes: 0, backupBytes: 0);
  }
}
