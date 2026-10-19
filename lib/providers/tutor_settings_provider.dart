import 'package:flutter/material.dart';
import '../data/services/storage_service.dart';
import '../data/services/tts_service.dart';
import '../data/services/voice_service.dart';
import '../data/services/llm_service.dart';

class TutorSettingsProvider extends ChangeNotifier {
  final StorageService _storageService;
  final TtsService _ttsService = TtsService();
  final VoiceService _voiceService = VoiceService();
  final LlmService _llmService = LlmService();

  bool _autoSpeak = true;
  double _speechRate = 0.45;
  String _voiceLanguage = 'hi_IN';
  String _responseLanguage = 'hinglish'; // 'hinglish', 'english', 'hindi'
  LlmMode _selectedLlmMode = LlmMode.builtinHinglish;
  bool _useOnlineData = false;

  TutorSettingsProvider(this._storageService) {
    _loadSettings();
  }

  bool get autoSpeak => _autoSpeak;
  double get speechRate => _speechRate;
  String get voiceLanguage => _voiceLanguage;
  String get responseLanguage => _responseLanguage;
  LlmMode get selectedLlmMode => _selectedLlmMode;
  bool get useOnlineData => _useOnlineData;

  void _loadSettings() {
    _autoSpeak = _storageService.getAutoSpeak();
    _speechRate = _storageService.getSpeechRate();
    _voiceLanguage = _storageService.getVoiceLanguage();
    _responseLanguage = _storageService.getResponseLanguage();
    _useOnlineData = _storageService.getUseOnlineData();
    final savedMode = _storageService.getSelectedLlmMode();
    if (savedMode == 'gemmaGguf') {
      _selectedLlmMode = LlmMode.gemmaGguf;
    } else if (savedMode == 'qwenGguf') {
      _selectedLlmMode = LlmMode.qwenGguf;
    } else if (savedMode == 'llamaGguf') {
      _selectedLlmMode = LlmMode.llamaGguf;
    } else {
      _selectedLlmMode = LlmMode.builtinHinglish;
    }
    _llmService.setMode(_selectedLlmMode);
    _llmService.setActiveGgufModelName(_storageService.getActiveGgufModelName());
    _llmService.setUseOnlineData(_useOnlineData);
    _ttsService.setSpeechRate(_speechRate);
    _ttsService.setLanguage(_voiceLanguage);
    _voiceService.setLocale(_voiceLanguage);
    notifyListeners();
  }

  String get activeGgufModelName => _storageService.getActiveGgufModelName();

  Future<void> setActiveGgufModelName(String modelName) async {
    await _storageService.setActiveGgufModelName(modelName);
    _llmService.setActiveGgufModelName(modelName);
    await _llmService.loadOnDeviceModel(modelName: modelName);
    notifyListeners();
  }

  Future<void> toggleAutoSpeak() async {
    _autoSpeak = !_autoSpeak;
    await _storageService.setAutoSpeak(_autoSpeak);
    if (!_autoSpeak) {
      await _ttsService.stop();
    }
    notifyListeners();
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    await _storageService.setSpeechRate(rate);
    await _ttsService.setSpeechRate(rate);
    notifyListeners();
  }

  Future<void> setVoiceLanguage(String lang) async {
    _voiceLanguage = lang;
    await _storageService.setVoiceLanguage(lang);
    await _ttsService.setLanguage(lang);
    _voiceService.setLocale(lang);
    notifyListeners();
  }

  Future<void> setLlmMode(LlmMode mode) async {
    _selectedLlmMode = mode;
    _llmService.setMode(mode);
    String modeStr = 'builtinHinglish';
    if (mode == LlmMode.gemmaGguf) modeStr = 'gemmaGguf';
    if (mode == LlmMode.qwenGguf) modeStr = 'qwenGguf';
    if (mode == LlmMode.llamaGguf) modeStr = 'llamaGguf';
    await _storageService.setSelectedLlmMode(modeStr);
    notifyListeners();
  }

  Future<void> setResponseLanguage(String lang) async {
    _responseLanguage = lang;
    await _storageService.setResponseLanguage(lang);
    notifyListeners();
  }

  Future<void> setUseOnlineData(bool value) async {
    _useOnlineData = value;
    await _storageService.setUseOnlineData(value);
    _llmService.setUseOnlineData(value);
    notifyListeners();
  }
}
