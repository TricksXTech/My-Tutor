import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/models/chat_message_model.dart';
import '../data/models/saved_document_model.dart';
import '../data/services/storage_service.dart';
import '../data/services/llm_service.dart';
import '../data/services/tts_service.dart';
import '../data/services/voice_service.dart';
import 'tutor_settings_provider.dart';

class ChatProvider extends ChangeNotifier {
  final StorageService _storageService;
  final LlmService _llmService = LlmService();
  final TtsService _ttsService = TtsService();
  final VoiceService _voiceService = VoiceService();

  String _currentChapterId = '';
  String _currentSubjectTitle = '';
  String _currentChapterTitle = '';

  List<ChatMessageModel> _allMessages = [];
  bool _isGenerating = false;
  bool _isCancelled = false;
  String _recognizedVoiceText = '';

  ChatProvider(this._storageService) {
    loadMessages();
    _ttsService.init();
    _voiceService.initialize();
  }

  bool get isGenerating => _isGenerating;
  String get recognizedVoiceText => _recognizedVoiceText;
  String get currentChapterId => _currentChapterId;

  ValueNotifier<bool> get isListeningNotifier => _voiceService.isListeningNotifier;
  ValueNotifier<double> get soundLevelNotifier => _voiceService.soundLevelNotifier;
  ValueNotifier<bool> get isSpeakingNotifier => _ttsService.isSpeakingNotifier;
  ValueNotifier<String?> get currentSpeakingIdNotifier => _ttsService.currentSpeakingId;

  void loadMessages() {
    _allMessages = List<ChatMessageModel>.from(_storageService.getMessages());
    notifyListeners();
  }

  void enterRoom({
    required String chapterId,
    required String subjectTitle,
    required String chapterTitle,
  }) {
    if (_currentChapterId != chapterId) {
      // FIX ROOT CAUSE 8: Reset active context, session, and KV cache on room switch
      _llmService.resetChatContext();
    }
    _currentChapterId = chapterId;
    _currentSubjectTitle = subjectTitle;
    _currentChapterTitle = chapterTitle;
    _recognizedVoiceText = '';
    _ttsService.stop();
    notifyListeners();
  }

  List<ChatMessageModel> get activeRoomMessages {
    return _allMessages.where((m) => m.chapterId == _currentChapterId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> sendUserMessage({
    required String text,
    required TutorSettingsProvider settings,
    required VoidCallback onChapterCountIncrement,
  }) async {
    final query = text.trim();
    if (query.isEmpty) return;

    // 1. Add User Message
    final userMessage = ChatMessageModel(
      id: 'msg_${const Uuid().v4().substring(0, 8)}',
      chapterId: _currentChapterId,
      text: query,
      isUser: true,
      timestamp: DateTime.now(),
    );

    _allMessages.add(userMessage);
    onChapterCountIncrement();

    // 2. Add Live AI Message Placeholder for Real-Time Streaming
    final aiMessageId = 'msg_${const Uuid().v4().substring(0, 8)}';
    final liveAiMessage = ChatMessageModel(
      id: aiMessageId,
      chapterId: _currentChapterId,
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
      modelEngine: _llmService.activeEngineDisplayName,
    );
    _allMessages.add(liveAiMessage);

    _recognizedVoiceText = '';
    _isCancelled = false;
    _isGenerating = true;
    notifyListeners();

    // Save incrementally for this chapter in background
    _storageService.saveMessagesForChapter(
      _currentChapterId,
      activeRoomMessages,
      debounce: true,
    );

    // 3. CONTEXT MEMORY: Examine the last 5-10 messages in this room
    final priorWindow = _allMessages.length >= 3
        ? _allMessages.sublist(math.max(0, _allMessages.length - 12), _allMessages.length - 2)
        : <ChatMessageModel>[];

    // Check if any document was uploaded or active in the recent 5-10 chat window
    final recentDocMsg = priorWindow.reversed.firstWhere(
      (m) => m.attachmentType != null || m.documentId != null,
      orElse: () => ChatMessageModel(
        id: '',
        chapterId: '',
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );

    final allDocs = _storageService.getSavedDocuments();
    // FIX ROOT CAUSE 1: Strictly isolate attachments to the current chat/chapter room
    final chapterDocs = allDocs.where((d) => d.chapterId == _currentChapterId).toList();

    SavedDocumentModel? activeDoc;
    if (recentDocMsg.id.isNotEmpty) {
      try {
        activeDoc = chapterDocs.firstWhere(
          (d) => d.id == recentDocMsg.documentId || d.fileName == recentDocMsg.attachmentName,
        );
      } catch (_) {
        activeDoc = chapterDocs.isNotEmpty ? chapterDocs.first : null;
      }
    } else if (chapterDocs.isNotEmpty) {
      activeDoc = chapterDocs.first;
    }
    // Note: Never fall back to allDocs.first across different rooms!

    // 4. Determine if query is asking about an uploaded document (PDF, TXT, image OCR) OR is a general tutor question / follow-up
    final lowerQ = query.toLowerCase().trim();

    // Check direct persistent recall match ONLY within this current chapter room
    final relevantDocs = _storageService
        .findRelevantDocuments(query, currentChapterId: _currentChapterId)
        .where((d) => d.chapterId == _currentChapterId)
        .toList();
    SavedDocumentModel? targetDoc = relevantDocs.isNotEmpty ? relevantDocs.first : null;

    if (targetDoc == null && activeDoc != null) {
      // FIX ROOT CAUSE 3: Precision document targeting for any file (txt, pdf, image, etc.)
      final cleanDocName = activeDoc.fileName.toLowerCase().replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final docNameTokens = cleanDocName.split(RegExp(r'[\s_\-]+')).where((w) => w.length >= 2).toList();

      // (a) Explicit document mention (e.g. "xx.txt", "xxx.pdf", "pdf", "txt", "text file", "document", "image", "photo", "notes", "file")
      final bool mentionsDocumentExplicitly =
          RegExp(r'\b(pdf|txt|text\s*file|document|attachment|notes|photo|image|pic|file|dastavez)\b').hasMatch(lowerQ) ||
          (docNameTokens.isNotEmpty && docNameTokens.any((token) => lowerQ.contains(token))) ||
          lowerQ.contains(activeDoc.fileName.toLowerCase());

      // (b) True deictic follow-up: ONLY if the immediately preceding turn was discussing this document
      final bool lastTurnWasDocRelated = priorWindow.isNotEmpty &&
          (priorWindow.last.attachmentType != null ||
           priorWindow.last.documentId != null ||
           priorWindow.last.text.contains('Aim &') ||
           priorWindow.last.text.contains('Working Principle'));

      final bool isExplicitSectionChoice = RegExp(r'^(1|2|3|4)$').hasMatch(lowerQ) ||
          lowerQ.startsWith('1 ') || lowerQ.startsWith('2 ') || lowerQ.startsWith('3 ') || lowerQ.startsWith('4 ');

      final bool isDocReferentialFollowUp = lastTurnWasDocRelated && (
          isExplicitSectionChoice ||
          RegExp(r'\b(it|this|that|step\s*\d+|point\s*\d+|working\s*principle|circuit\s*diagram|viva\s*questions?|aim|components?)\b').hasMatch(lowerQ)
      );

      final bool isContextFollowUp = (mentionsDocumentExplicitly || isDocReferentialFollowUp) &&
          !lowerQ.startsWith('hello') &&
          !lowerQ.startsWith('hi ') &&
          lowerQ != 'hi' &&
          !lowerQ.contains('what is your name') &&
          !lowerQ.contains('who are you') &&
          !lowerQ.contains('what model');

      if (isContextFollowUp) {
        targetDoc = activeDoc;
      }
    }

    // FIX ROOT CAUSE 2 & 4: Keep prompt clean as user query.
    // Attachments are isolated and passed via attachments parameter; never stuffed into user turn body.
    final List<SavedDocumentModel> attachments = targetDoc != null ? [targetDoc] : const [];

    // 4. Stream AI Response
    await _streamAiResponse(
      prompt: query,
      attachments: attachments,
      aiMessageId: aiMessageId,
      currentUserMessageId: userMessage.id, // FIX ROOT CAUSE 6: Exclude current user turn from history
      liveAiMessage: liveAiMessage,
      settings: settings,
      onChapterCountIncrement: onChapterCountIncrement,
    );
  }

  /// Sends an uploaded PDF or Image note with an optional caption
  /// - With caption: AI focuses strictly on answering the caption question
  /// - Without caption: AI explains the core concepts of the document
  /// - Context window management: adds invitation line at the end
  Future<void> sendAttachmentMessage({
    required File file,
    required String fileName,
    required String fileType, // 'pdf' or 'image'
    String? caption,
    required String extractedText,
    required TutorSettingsProvider settings,
    required VoidCallback onChapterCountIncrement,
  }) async {
    final cleanCaption = caption?.trim();
    final hasCaption = cleanCaption != null && cleanCaption.isNotEmpty;

    // 1. Save to Persistent Document Memory Store
    final docId = 'doc_${const Uuid().v4().substring(0, 8)}';
    final savedDoc = SavedDocumentModel(
      id: docId,
      fileName: fileName,
      fileType: fileType,
      localPath: file.path,
      uploadedAt: DateTime.now(),
      chapterId: _currentChapterId,
      subjectTitle: _currentSubjectTitle,
      caption: cleanCaption,
      extractedText: extractedText,
    );
    await _storageService.saveDocument(savedDoc);

    // 2. Add User Message with Attachment Data
    final userMessage = ChatMessageModel(
      id: 'msg_${const Uuid().v4().substring(0, 8)}',
      chapterId: _currentChapterId,
      text: hasCaption ? cleanCaption : '📄 Uploaded $fileName',
      isUser: true,
      timestamp: DateTime.now(),
      attachmentType: fileType,
      attachmentName: fileName,
      attachmentPath: file.path,
      caption: cleanCaption,
      documentId: docId,
    );

    _allMessages.add(userMessage);
    onChapterCountIncrement();

    // 3. Add Live AI Message Placeholder
    final aiMessageId = 'msg_${const Uuid().v4().substring(0, 8)}';
    final liveAiMessage = ChatMessageModel(
      id: aiMessageId,
      chapterId: _currentChapterId,
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
      modelEngine: _llmService.activeEngineDisplayName,
    );
    _allMessages.add(liveAiMessage);

    _recognizedVoiceText = '';
    _isCancelled = false;
    _isGenerating = true;
    notifyListeners();

    _storageService.saveMessagesForChapter(
      _currentChapterId,
      activeRoomMessages,
      debounce: true,
    );

    // 4. FIX ROOT CAUSE 2 & 4: Prompt contains ONLY the student's actual intent/caption.
    // Document text is NEVER stuffed into the user prompt. It is passed via attachments parameter!
    final cleanPrompt = hasCaption
        ? cleanCaption
        : 'Please explain the core concepts and key points of this uploaded document.';

    // 5. Stream AI Response
    await _streamAiResponse(
      prompt: cleanPrompt,
      attachments: [savedDoc],
      aiMessageId: aiMessageId,
      currentUserMessageId: userMessage.id, // FIX ROOT CAUSE 6: Exclude current user turn from history
      liveAiMessage: liveAiMessage,
      settings: settings,
      onChapterCountIncrement: onChapterCountIncrement,
    );
  }

  Future<void> _streamAiResponse({
    required String prompt,
    List<SavedDocumentModel> attachments = const [],
    required String aiMessageId,
    required String currentUserMessageId,
    required ChatMessageModel liveAiMessage,
    required TutorSettingsProvider settings,
    required VoidCallback onChapterCountIncrement,
  }) async {
    try {
      // FIX ROOT CAUSE 6: History must only contain turns BEFORE the current message being answered
      final priorChapterMessages = _allMessages
          .where((m) =>
              m.chapterId == _currentChapterId &&
              m.id != liveAiMessage.id &&
              m.id != currentUserMessageId &&
              m.text.trim().isNotEmpty)
          .toList();
      final recentHistory = priorChapterMessages.length > 20
          ? priorChapterMessages.sublist(priorChapterMessages.length - 20)
          : priorChapterMessages;

      // FIX ROOT CAUSE 9: Strip thinking tags from past assistant turns
      final conversationHistory = recentHistory
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.isUser ? m.text : stripThinkingTags(m.text),
              })
          .where((turn) => turn['content']!.trim().isNotEmpty)
          .toList();

      final replyResult = await _llmService.generateTutorReply(
        userPrompt: prompt,
        chapterTitle: _currentChapterTitle,
        subjectName: _currentSubjectTitle,
        attachments: attachments,
        conversationHistory: conversationHistory,
        responseLanguage: settings.responseLanguage,
        onProgress: (partialText, engineName) {
          if (_isCancelled) return;
          final idx = _allMessages.indexWhere((m) => m.id == aiMessageId);
          if (idx != -1) {
            _allMessages[idx] = ChatMessageModel(
              id: aiMessageId,
              chapterId: _currentChapterId,
              text: stripThinkingTags(partialText),
              isUser: false,
              timestamp: liveAiMessage.timestamp,
              modelEngine: engineName,
            );
            notifyListeners();
          }
        },
      );

      if (_isCancelled) {
        final curIdx = _allMessages.indexWhere((m) => m.id == aiMessageId);
        if (curIdx != -1) {
          final existing = _allMessages[curIdx];
          final stoppedText = existing.text.isNotEmpty ? stripThinkingTags(existing.text) : 'Response stopped by user.';
          _allMessages[curIdx] = ChatMessageModel(
            id: aiMessageId,
            chapterId: _currentChapterId,
            text: stoppedText,
            isUser: false,
            timestamp: existing.timestamp,
            modelEngine: existing.modelEngine,
          );
          await _storageService.saveMessagesForChapter(_currentChapterId, activeRoomMessages);
        }
        return;
      }

      final cleanFinalText = stripThinkingTags(replyResult.text);
      final finalIndex = _allMessages.indexWhere((m) => m.id == aiMessageId);
      final finalAiMessage = ChatMessageModel(
        id: aiMessageId,
        chapterId: _currentChapterId,
        text: cleanFinalText,
        isUser: false,
        timestamp: liveAiMessage.timestamp,
        modelEngine: replyResult.engineName,
      );

      if (finalIndex != -1) {
        _allMessages[finalIndex] = finalAiMessage;
      } else {
        _allMessages.add(finalAiMessage);
      }
      await _storageService.saveMessagesForChapter(_currentChapterId, activeRoomMessages);
      onChapterCountIncrement();

      // Auto-speak if enabled
      if (settings.autoSpeak) {
        try {
          await _ttsService.speak(cleanFinalText, messageId: finalAiMessage.id);
        } catch (ttsErr) {
          debugPrint('TTS auto-speak error: $ttsErr');
        }
      }
    } catch (e) {
      debugPrint('Error generating AI reply: $e');
      final finalIndex = _allMessages.indexWhere((m) => m.id == aiMessageId);
      final errorMsg = 'Kuch gadbad hui response generate karne mein. Kripya punah prayas karein ($e).';
      if (finalIndex != -1) {
        _allMessages[finalIndex] = ChatMessageModel(
          id: aiMessageId,
          chapterId: _currentChapterId,
          text: errorMsg,
          isUser: false,
          timestamp: liveAiMessage.timestamp,
          modelEngine: 'System Error',
        );
      }
      await _storageService.saveMessagesForChapter(_currentChapterId, activeRoomMessages);
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// FIX ROOT CAUSE 9: Strips reasoning scratchpads (`<think>...</think>`) from stored messages
  static String stripThinkingTags(String text) {
    if (!text.contains('<think>')) return text;
    var cleaned = text.replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'<think>[\s\S]*$', caseSensitive: false), '');
    return cleaned.trim();
  }

  /// Stops ongoing LLM generation and TTS speech on user request (e.g. double click loading icon)
  void stopGeneration() {
    if (!_isGenerating) return;
    _isCancelled = true;
    _isGenerating = false;
    _llmService.stopGeneration();
    _ttsService.stop();
    debugPrint('ChatProvider: Generation stopped by student.');
    notifyListeners();
  }

  // --- VOICE-TO-TEXT (STT) ---
  Future<void> toggleVoiceInput({
    required Function(String liveText) onLiveTranscript,
  }) async {
    if (_voiceService.isListening) {
      await _voiceService.stopListening();
      return;
    }

    _recognizedVoiceText = '';
    await _voiceService.startListening(
      onResult: (words, isFinal) {
        _recognizedVoiceText = words;
        onLiveTranscript(words);
        notifyListeners();
      },
      onSoundLevelChanged: () {
        // Notifier handles animation updates
      },
    );
  }

  Future<void> stopVoiceInput() async {
    await _voiceService.stopListening();
  }

  // --- TEXT-TO-SPEECH (TTS) ---
  Future<void> toggleSpeakMessage(ChatMessageModel message, {String? customText}) async {
    final textToSpeak = (customText != null && customText.isNotEmpty) ? customText : message.text;
    if (_ttsService.currentSpeakingId.value == message.id &&
        _ttsService.isSpeakingNotifier.value) {
      await _ttsService.stop();
    } else {
      await _ttsService.speak(textToSpeak, messageId: message.id);
    }
  }

  Future<void> stopTts() async {
    await _ttsService.stop();
  }

  Future<void> clearRoomChat() async {
    _allMessages.removeWhere((m) => m.chapterId == _currentChapterId);
    await _storageService.saveMessagesForChapter(_currentChapterId, []);
    await _ttsService.stop();
    notifyListeners();
  }

  Future<void> clearAllChats() async {
    _allMessages.clear();
    await _storageService.clearAllChatMessages();
    await _ttsService.stop();
    notifyListeners();
  }
}
