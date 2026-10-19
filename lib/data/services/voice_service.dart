import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;

  final SpeechToText _speechToText = SpeechToText();
  final ValueNotifier<bool> isListeningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> soundLevelNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> isAvailableNotifier = ValueNotifier<bool>(false);

  bool _isInitialized = false;
  String _preferredLocaleId = 'hi_IN'; // Default to Hinglish context

  VoiceService._internal();

  bool get isListening => _speechToText.isListening;
  bool get isAvailable => _isInitialized && _speechToText.isAvailable;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request mic permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('Microphone permission not granted: $status');
        return false;
      }

      final available = await _speechToText.initialize(
        onError: (errorNotification) {
          debugPrint('SpeechToText error: ${errorNotification.errorMsg}');
          isListeningNotifier.value = false;
          soundLevelNotifier.value = 0.0;
        },
        onStatus: (status) {
          debugPrint('SpeechToText status: $status');
          if (status == 'listening') {
            isListeningNotifier.value = true;
          } else if (status == 'notListening' || status == 'done') {
            isListeningNotifier.value = false;
            soundLevelNotifier.value = 0.0;
          }
        },
      );

      _isInitialized = available;
      isAvailableNotifier.value = available;

      if (available) {
        final locales = await _speechToText.locales();
        final hasHindi = locales.any((l) => l.localeId == 'hi_IN' || l.localeId == 'hi-IN');
        final hasIndianEnglish = locales.any((l) => l.localeId == 'en_IN' || l.localeId == 'en-IN');

        if (hasHindi) {
          _preferredLocaleId = 'hi_IN';
        } else if (hasIndianEnglish) {
          _preferredLocaleId = 'en_IN';
        } else if (locales.isNotEmpty) {
          _preferredLocaleId = locales.first.localeId;
        }
      }

      return available;
    } catch (e) {
      debugPrint('VoiceService initialization failed: $e');
      _isInitialized = false;
      isAvailableNotifier.value = false;
      return false;
    }
  }

  Future<void> startListening({
    required Function(String recognizedWords, bool isFinal) onResult,
    required VoidCallback onSoundLevelChanged,
    String? localeId,
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    if (_speechToText.isListening) {
      await stopListening();
      return;
    }

    final targetLocale = localeId ?? _preferredLocaleId;

    try {
      await _speechToText.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: (level) {
          // Normalize sound level between 0.0 and 1.0
          soundLevelNotifier.value = (level / 10).clamp(0.0, 1.0);
          onSoundLevelChanged();
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          cancelOnError: true,
          partialResults: true,
          localeId: targetLocale,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
        ),
      );
      isListeningNotifier.value = true;
    } catch (e) {
      debugPrint('Error starting speech listen: $e');
      isListeningNotifier.value = false;
    }
  }

  Future<void> stopListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (e) {
      debugPrint('Error stopping speech listen: $e');
    } finally {
      isListeningNotifier.value = false;
      soundLevelNotifier.value = 0.0;
    }
  }

  void setLocale(String localeId) {
    _preferredLocaleId = localeId;
  }
}
