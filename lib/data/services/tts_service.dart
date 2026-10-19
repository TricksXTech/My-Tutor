import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> currentSpeakingId = ValueNotifier<String?>(null);

  bool _isInitialized = false;
  String _currentLanguage = 'hi_IN';
  double _speechRate = 0.45; // 0.45 is comfortable professor pace
  final double _pitch = 1.0;

  TtsService._internal();

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setSpeechRate(_speechRate);

      if (Platform.isAndroid) {
        // QueueMode 1 flushes previous speech immediately so utterances never overlap
        await _flutterTts.setQueueMode(1);
      }

      // Check available languages & prioritize Indian Hindi / Indian English
      final languages = await _flutterTts.getLanguages;
      if (languages is List) {
        if (languages.contains('hi-IN')) {
          _currentLanguage = 'hi-IN';
        } else if (languages.contains('en-IN')) {
          _currentLanguage = 'en-IN';
        } else if (languages.contains('hi_IN')) {
          _currentLanguage = 'hi_IN';
        } else if (languages.contains('en_IN')) {
          _currentLanguage = 'en_IN';
        }
      }
      await _flutterTts.setLanguage(_currentLanguage);
      await _applyFemaleVoice();

      _flutterTts.setStartHandler(() {
        isSpeakingNotifier.value = true;
      });

      _flutterTts.setCompletionHandler(() {
        isSpeakingNotifier.value = false;
        currentSpeakingId.value = null;
      });

      _flutterTts.setCancelHandler(() {
        isSpeakingNotifier.value = false;
        currentSpeakingId.value = null;
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('TtsService Error: $msg');
        isSpeakingNotifier.value = false;
        currentSpeakingId.value = null;
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('TtsService init failed: $e');
    }
  }

  /// Automatically scans engine voices and explicitly locks TTS to an authentic female voice
  Future<void> _applyFemaleVoice() async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices is List) {
        Map<String, String>? chosenFemaleVoice;
        for (final v in voices) {
          if (v is Map) {
            final name = (v['name'] ?? '').toString().toLowerCase();
            final locale = (v['locale'] ?? '').toString();
            final gender = (v['gender'] ?? '').toString().toLowerCase();

            final isTargetLocale = locale.replaceAll('_', '-').toLowerCase().startsWith(
                  _currentLanguage.replaceAll('_', '-').toLowerCase().split('-').first,
                );

            final isFemale = gender.contains('female') ||
                name.contains('female') ||
                name.contains('woman') ||
                name.contains('-hie-') || // Google Hindi Female
                name.contains('-hia-') || // Google Hindi Female
                name.contains('-end-') || // Google Indian English Female
                name.contains('#female');

            if (isTargetLocale && isFemale) {
              chosenFemaleVoice = {'name': v['name'].toString(), 'locale': locale};
              break;
            } else if (isFemale && chosenFemaleVoice == null) {
              chosenFemaleVoice = {'name': v['name'].toString(), 'locale': locale};
            }
          }
        }

        if (chosenFemaleVoice != null) {
          await _flutterTts.setVoice(chosenFemaleVoice);
          debugPrint('TTS locked to female voice: $chosenFemaleVoice');
        }
      }
    } catch (e) {
      debugPrint('TTS female voice setup notice: $e');
    }
  }

  Future<void> setLanguage(String lang) async {
    _currentLanguage = lang;
    try {
      await _flutterTts.setLanguage(lang);
      await _applyFemaleVoice();
    } catch (e) {
      debugPrint('setLanguage error: $e');
    }
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    try {
      await _flutterTts.setSpeechRate(rate);
    } catch (e) {
      debugPrint('setSpeechRate error: $e');
    }
  }

  /// Converts markdown formatted text into spoken-friendly, crystal-clear plain Hinglish text.
  /// IMPORTANT: Uses replaceAllMapped so capture groups are NEVER replaced with literal "$1"!
  String cleanTextForSpeech(String markdown) {
    String clean = markdown;

    // 1. Announce code blocks naturally instead of reading raw code symbols
    clean = clean.replaceAll(
      RegExp(r'```[a-zA-Z0-9_\-]*\n[\s\S]*?\n```'),
      ' Dekhiye, code screen par diya gaya hai. ',
    );

    // 2. Remove inline code backticks while keeping the inner word (use replaceAllMapped!)
    clean = clean.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (match) => match.group(1) ?? '',
    );

    // 3. Remove markdown headers (### Header)
    clean = clean.replaceAll(RegExp(r'#{1,6}\s*'), '');

    // 4. Remove bold and italics (**text** or *text*) keeping the exact text
    clean = clean.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'),
      (match) => match.group(1) ?? '',
    );
    clean = clean.replaceAllMapped(
      RegExp(r'\*([^*]+)\*'),
      (match) => match.group(1) ?? '',
    );
    clean = clean.replaceAllMapped(
      RegExp(r'__([^_]+)__'),
      (match) => match.group(1) ?? '',
    );
    clean = clean.replaceAllMapped(
      RegExp(r'_([^_]+)_'),
      (match) => match.group(1) ?? '',
    );

    // 5. Remove markdown links [text](url) -> keep text
    clean = clean.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (match) => match.group(1) ?? '',
    );

    // 6. Strip unicode emojis (e.g. 🎯, 💡, ⚡, 📝, 🏃) which cause Android TTS to stutter or announce emoji names
    clean = clean.replaceAll(
      RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1FA00}-\u{1FAFF}]', unicode: true),
      '',
    );

    // 7. Remove quotation marks ("...") so TTS reads the words smoothly without saying "quote" or pausing
    clean = clean.replaceAll(RegExp(r'[""''«»]'), ' ');

    // 8. Replace technical symbols with spoken academic terms for high precision
    clean = clean.replaceAll(RegExp(r'\bB\.Tech\b', caseSensitive: false), 'B Tech');
    clean = clean.replaceAll(RegExp(r'\bCSE\b', caseSensitive: false), 'C S E');
    clean = clean.replaceAll(RegExp(r'\b1st\b', caseSensitive: false), 'first');
    clean = clean.replaceAll(RegExp(r'\b2nd\b', caseSensitive: false), 'second');
    clean = clean.replaceAll(RegExp(r'\b3rd\b', caseSensitive: false), 'third');
    clean = clean.replaceAll(RegExp(r'\bC\+\+\b'), 'C plus plus');
    clean = clean.replaceAll(RegExp(r'\bGolang\b'), 'Go language');
    clean = clean.replaceAll(RegExp(r'\bprintf\b'), 'print f');
    clean = clean.replaceAll(RegExp(r'\bscanf\b'), 'scan f');
    clean = clean.replaceAll(RegExp(r'\bsizeof\b'), 'size of');
    clean = clean.replaceAll(RegExp(r'->'), ' points to ');
    clean = clean.replaceAll(RegExp(r'=='), ' equal to ');
    clean = clean.replaceAll(RegExp(r'!='), ' not equal to ');
    clean = clean.replaceAll(RegExp(r'&&'), ' logical AND ');
    clean = clean.replaceAll(RegExp(r'\|\|'), ' logical OR ');
    clean = clean.replaceAll(RegExp(r'\^'), ' XOR ');
    clean = clean.replaceAll(RegExp(r'<<'), ' left shift ');
    clean = clean.replaceAll(RegExp(r'>>'), ' right shift ');
    clean = clean.replaceAll(RegExp(r'\+='), ' plus equals ');
    clean = clean.replaceAll(RegExp(r'\+\+'), ' plus plus ');

    // 9. Remove bullet dashes and numbers at start of lines
    clean = clean.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
    clean = clean.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');

    // 10. Math & LaTeX formula speech conversion (makes mathematical derivations sound natural)
    clean = clean.replaceAll(RegExp(r'\$\$?'), ' '); // Strip LaTeX math delimiters
    clean = clean.replaceAllMapped(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'), (m) => '${m.group(1)} by ${m.group(2)}');
    clean = clean.replaceAllMapped(RegExp(r'\\mathbf\{([^}]+)\}'), (m) => '${m.group(1)}');
    clean = clean.replaceAllMapped(RegExp(r'\\text\{([^}]+)\}'), (m) => '${m.group(1)}');
    clean = clean.replaceAll(RegExp(r'\\log\b'), ' log ');
    clean = clean.replaceAll(RegExp(r'\\ln\b'), ' natural log ');
    clean = clean.replaceAll(RegExp(r'\\cdot\b'), ' into ');
    clean = clean.replaceAll(RegExp(r'\\times\b'), ' multiplied by ');
    clean = clean.replaceAll(RegExp(r'\\pm\b'), ' plus or minus ');
    clean = clean.replaceAll(RegExp(r'\\neq\b'), ' not equal to ');
    clean = clean.replaceAll(RegExp(r'\\leq\b'), ' less than or equal to ');
    clean = clean.replaceAll(RegExp(r'\\geq\b'), ' greater than or equal to ');
    clean = clean.replaceAll(RegExp(r'\\implies\b'), ' implies ');
    clean = clean.replaceAll(RegExp(r'\\lambda\b'), ' lambda ');
    clean = clean.replaceAll(RegExp(r'\\theta\b'), ' theta ');
    clean = clean.replaceAll(RegExp(r'\\pi\b'), ' pie ');
    clean = clean.replaceAll(RegExp(r'\\int\b'), ' integral ');
    clean = clean.replaceAll(RegExp(r'\\sum\b'), ' summation ');
    clean = clean.replaceAll(RegExp(r'\\infty\b'), ' infinity ');
    clean = clean.replaceAll(RegExp(r'\^\{?\\circ\}?|°'), ' degrees ');
    clean = clean.replaceAll(RegExp(r'\\circ\b'), ' degrees ');
    clean = clean.replaceAll(RegExp(r'sin⁻¹'), ' sin inverse ');
    clean = clean.replaceAll(RegExp(r'cos⁻¹'), ' cos inverse ');
    clean = clean.replaceAll(RegExp(r'tan⁻¹'), ' tan inverse ');
    clean = clean.replaceAll(RegExp(r'\\left[([{]'), '(');
    clean = clean.replaceAll(RegExp(r'\\right[)\]}]'), ')');
    clean = clean.replaceAll(RegExp(r'[{}]'), ' ');

    // 11. Normalize colons, semicolons, dashes and extra spaces
    clean = clean.replaceAll(RegExp(r'[:;]+'), ', ');
    clean = clean.replaceAll(RegExp(r'---'), ' ');

    // 12. Female Professor Voice Harmonization (Ensures voice consistently speaks with female grammatical markers)
    // Hinglish patterns:
    clean = clean.replaceAll(RegExp(r'\bkarta\s+(?:hoon|hu|hun)\b', caseSensitive: false), 'karti hoon');
    clean = clean.replaceAll(RegExp(r'\bsamjhata\s+(?:hoon|hu|hun)\b', caseSensitive: false), 'samjhati hoon');
    clean = clean.replaceAll(RegExp(r'\bbatata\s+(?:hoon|hu|hun)\b', caseSensitive: false), 'batati hoon');
    clean = clean.replaceAll(RegExp(r'\bdikhata\s+(?:hoon|hu|hun)\b', caseSensitive: false), 'dikhati hoon');
    clean = clean.replaceAll(RegExp(r'\bpadhata\s+(?:hoon|hu|hun)\b', caseSensitive: false), 'padhati hoon');
    clean = clean.replaceAll(RegExp(r'\braha\s+(?:hoon|hu|hun)\b', caseSensitive: false), 'rahi hoon');
    clean = clean.replaceAll(RegExp(r'\bkarunga\b', caseSensitive: false), 'karungi');
    clean = clean.replaceAll(RegExp(r'\bbataunga\b', caseSensitive: false), 'bataungi');
    clean = clean.replaceAll(RegExp(r'\bsamjhaunga\b', caseSensitive: false), 'samjhaungi');
    clean = clean.replaceAll(RegExp(r'\bmain\s+hoon\s+tumhara\b', caseSensitive: false), 'main hoon aapki');
    clean = clean.replaceAll(RegExp(r'\bmain\s+hoon\s+aapka\b', caseSensitive: false), 'main hoon aapki');
    clean = clean.replaceAll(RegExp(r'\baapka\s+professor\b', caseSensitive: false), 'aapki professor');
    clean = clean.replaceAll(RegExp(r'\baapka\s+tutor\b', caseSensitive: false), 'aapki tutor');
    clean = clean.replaceAll(RegExp(r'\btumhara\s+professor\b', caseSensitive: false), 'aapki professor');
    clean = clean.replaceAll(RegExp(r'\btumhara\s+tutor\b', caseSensitive: false), 'aapki tutor');
    clean = clean.replaceAll(RegExp(r'\btumhara\b', caseSensitive: false), 'aapka');
    clean = clean.replaceAll(RegExp(r'\btumhare\b', caseSensitive: false), 'aapke');
    clean = clean.replaceAll(RegExp(r'\btumhari\b', caseSensitive: false), 'aapki');
    clean = clean.replaceAll(RegExp(r'\btumhe\b', caseSensitive: false), 'aapko');

    // Devanagari Hindi female patterns:
    clean = clean.replaceAll('करता हूँ', 'करती हूँ');
    clean = clean.replaceAll('समझाता हूँ', 'समझाती हूँ');
    clean = clean.replaceAll('बताता हूँ', 'बताती हूँ');
    clean = clean.replaceAll('दिखाता हूँ', 'दिखाती हूँ');
    clean = clean.replaceAll('पढ़ाता हूँ', 'पढ़ाती हूँ');
    clean = clean.replaceAll('रहा हूँ', 'रही हूँ');
    clean = clean.replaceAll('करूँगा', 'करूँगी');
    clean = clean.replaceAll('बताऊँगा', 'बताऊँगी');
    clean = clean.replaceAll('समझाऊँगा', 'समझाऊँगी');
    clean = clean.replaceAll('आपका प्रोफेसर', 'आपकी प्रोफेसर');
    clean = clean.replaceAll('तुम्हारा प्रोफेसर', 'आपकी प्रोफेसर');
    clean = clean.replaceAll('आपका ट्यूटर', 'आपकी ट्यूटर');
    clean = clean.replaceAll('तुम्हारा ट्यूटर', 'आपकी ट्यूटर');
    clean = clean.replaceAll('तुम्हारा', 'आपका');
    clean = clean.replaceAll('तुम्हारे', 'आपके');
    clean = clean.replaceAll('तुम्हारी', 'आपकी');
    clean = clean.replaceAll('तुम्हें', 'आपको');

    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();

    return clean;
  }

  Future<void> speak(String text, {String? messageId, String? language}) async {
    if (!_isInitialized) await init();

    if (isSpeakingNotifier.value) {
      await stop();
    }

    final spokenText = cleanTextForSpeech(text);
    if (spokenText.isEmpty) return;

    // Auto-detect if text contains Devanagari Hindi script
    final bool hasDevanagari = RegExp(r'[\u0900-\u097F]').hasMatch(spokenText);
    final String targetLang = language ?? (hasDevanagari ? 'hi-IN' : _currentLanguage);

    try {
      await _flutterTts.setLanguage(targetLang);
    } catch (_) {}

    currentSpeakingId.value = messageId;
    isSpeakingNotifier.value = true;
    await _flutterTts.speak(spokenText);
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('TtsService stop error: $e');
    } finally {
      isSpeakingNotifier.value = false;
      currentSpeakingId.value = null;
    }
  }

  void dispose() {
    _flutterTts.stop();
  }
}
