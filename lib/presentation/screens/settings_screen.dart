import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/llm_service.dart';
import '../../data/services/tts_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/file_storage_service.dart';
import '../../providers/tutor_settings_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/subject_provider.dart';
import '../../providers/chapter_provider.dart';
import 'legal/terms_of_use_screen.dart';
import 'legal/privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LlmService _llmService = LlmService();
  final TtsService _ttsService = TtsService();
  bool _isTestingVoice = false;
  ModelStatus _gemmaStatus = ModelStatus.notDownloaded;
  ModelStatus _qwenStatus = ModelStatus.notDownloaded;
  ModelStatus _llamaStatus = ModelStatus.notDownloaded;
  Future<StorageBreakdown>? _storageBreakdownFuture;

  @override
  void initState() {
    super.initState();
    _checkAllModelStatus();
    _refreshStorageBreakdown();
  }

  void _refreshStorageBreakdown() {
    setState(() {
      _storageBreakdownFuture = StorageService.getInstance().then((s) => s.getStorageBreakdown());
    });
  }

  Future<void> _checkAllModelStatus() async {
    final gemma = await _llmService.checkModelStatus(AppConstants.gemmaModelName);
    final qwen = await _llmService.checkModelStatus(AppConstants.qwenModelName);
    final llama = await _llmService.checkModelStatus(AppConstants.llamaModelName);

    if (mounted) {
      setState(() {
        _gemmaStatus = gemma;
        _qwenStatus = qwen;
        _llamaStatus = llama;
      });
    }
  }

  Future<void> _triggerModelDownload({
    required String modelName,
    required String downloadUrl,
  }) async {
    // Request storage / notification permission if applicable
    await Permission.storage.request();

    _llmService.downloadModel(
      downloadUrl,
      modelName: modelName,
      onProgress: (progress) {
        setState(() {});
      },
      onComplete: () async {
        await _checkAllModelStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$modelName installed and ready for on-device inference!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
      onError: (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: $err'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<TutorSettingsProvider>();
    final isAnyModelInstalled = _gemmaStatus == ModelStatus.ready ||
        _qwenStatus == ModelStatus.ready ||
        _llamaStatus == ModelStatus.ready;
    final int installedCount = (_gemmaStatus == ModelStatus.ready ? 1 : 0) +
        (_qwenStatus == ModelStatus.ready ? 1 : 0) +
        (_llamaStatus == ModelStatus.ready ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tutor & AI Settings',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // PROMINENT MODEL STATUS & QUICK DOWNLOAD HERO CARD
          ValueListenableBuilder<ModelDownloadInfo?>(
            valueListenable: _llmService.downloadInfoNotifier,
            builder: (context, downloadInfo, _) {
              final isDownloading = _llmService.isDownloading;

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF26263E), Color(0xFF1B1B2C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isAnyModelInstalled
                        ? AppColors.secondaryAccent.withAlpha(120)
                        : AppColors.primaryAccent.withAlpha(120),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(110),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (isAnyModelInstalled
                                    ? AppColors.secondaryAccent
                                    : AppColors.primaryAccent)
                                .withAlpha(30),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isAnyModelInstalled
                                ? Icons.verified_rounded
                                : Icons.downloading_rounded,
                            color: isAnyModelInstalled
                                ? AppColors.secondaryAccent
                                : AppColors.primaryLight,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'On-Device GGUF Status',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isAnyModelInstalled
                                    ? '$installedCount Model(s) Installed & Ready'
                                    : 'Not Installed (Using Built-in Engine)',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isAnyModelInstalled
                                      ? AppColors.secondaryAccent
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isAnyModelInstalled
                                    ? AppColors.success
                                    : AppColors.warning)
                                .withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isAnyModelInstalled
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                          child: Text(
                            isAnyModelInstalled ? 'READY' : 'NOT INSTALLED',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isAnyModelInstalled
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // LIVE DOWNLOAD PROGRESS BAR
                    if (isDownloading && downloadInfo != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Downloading ${downloadInfo.modelName}: ${downloadInfo.percent}% (${downloadInfo.receivedMb} MB / ${downloadInfo.totalMb} MB)',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.secondaryAccent,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18, color: AppColors.error),
                                  tooltip: 'Cancel Download',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    _llmService.cancelDownload();
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: downloadInfo.progress,
                              backgroundColor: AppColors.surfaceCard,
                              color: AppColors.secondaryAccent,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),
                    ]
                    // PROMINENT "DOWNLOAD GEMMA 4 (2B)" BUTTON (if no models installed)
                    else if (!isAnyModelInstalled) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isDownloading
                              ? null
                              : () => _triggerModelDownload(
                                    modelName: AppConstants.gemmaModelName,
                                    downloadUrl: AppConstants.gemmaDownloadUrl,
                                  ),
                          icon: const Icon(Icons.cloud_download_rounded, size: 20),
                          label: Text(
                            'Download Gemma 4 (2B Parameter • ${AppConstants.gemmaModelSize})',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          // ACTIVE MODEL SELECTOR (Shown prominently when multiple models or GGUF models are installed)
          if (installedCount >= 2) ...[
            const SizedBox(height: 20),
            _buildSectionHeader('ACTIVE ON-DEVICE AI MODEL'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.secondaryAccent.withAlpha(140), width: 1.3),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: AppColors.secondaryAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Select Active AI Model for Chats & Quizzes',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'You have multiple offline models installed. Choose which model generates your responses:',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  if (_gemmaStatus == ModelStatus.ready)
                    _buildActiveRadioOption(
                      title: 'Gemma 4 (2B Parameter)',
                      subtitle: 'Google Gemma • Primary Model',
                      isSelected: settings.activeGgufModelName == AppConstants.gemmaModelName,
                      onTap: () {
                        settings.setActiveGgufModelName(AppConstants.gemmaModelName);
                        settings.setLlmMode(LlmMode.gemmaGguf);
                      },
                    ),
                  if (_qwenStatus == ModelStatus.ready)
                    _buildActiveRadioOption(
                      title: 'Qwen 2.5 (1.5B Parameter)',
                      subtitle: 'Alibaba Qwen • Strong Reasoning & Code',
                      isSelected: settings.activeGgufModelName == AppConstants.qwenModelName,
                      onTap: () {
                        settings.setActiveGgufModelName(AppConstants.qwenModelName);
                        settings.setLlmMode(LlmMode.qwenGguf);
                      },
                    ),
                  if (_llamaStatus == ModelStatus.ready)
                    _buildActiveRadioOption(
                      title: 'Llama 3.2 (1B Parameter)',
                      subtitle: 'Meta Llama • Compact High-Speed Model',
                      isSelected: settings.activeGgufModelName == AppConstants.llamaModelName,
                      onTap: () {
                        settings.setActiveGgufModelName(AppConstants.llamaModelName);
                        settings.setLlmMode(LlmMode.llamaGguf);
                      },
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Section 1: AI Model Engine
          _buildSectionHeader('QUANTIZED GGUF MODELS (OFFLINE FIRST)'),
          const SizedBox(height: 10),

          // Built-in Hinglish Engine Option
          _buildModelCard(
            title: 'Built-in Hinglish Engine',
            subtitle: 'Instant zero-latency responses for Physics, Chem, Math & Coding. Ready out-of-the-box (0 MB).',
            badge: 'READY',
            badgeColor: AppColors.accentGreen,
            isSelected: settings.selectedLlmMode == LlmMode.builtinHinglish,
            onSelect: () => settings.setLlmMode(LlmMode.builtinHinglish),
          ),

          const SizedBox(height: 10),

          // Gemma 4 2B GGUF Option (Hackathon Primary Model)
          _buildModelCard(
            title: 'Gemma 4 - 2B Parameter',
            subtitle: 'Google Gemma Open-Weight Model (${AppConstants.gemmaModelSize}). Primary model suggested.',
            badge: _gemmaStatus == ModelStatus.ready
                ? 'INSTALLED'
                : (_gemmaStatus == ModelStatus.downloading ? 'DOWNLOADING' : 'NOT INSTALLED'),
            badgeColor: _gemmaStatus == ModelStatus.ready
                ? AppColors.secondaryAccent
                : (_gemmaStatus == ModelStatus.downloading
                    ? AppColors.accentYellow
                    : AppColors.textMuted),
            isSelected: settings.selectedLlmMode == LlmMode.gemmaGguf ||
                (settings.activeGgufModelName == AppConstants.gemmaModelName && _gemmaStatus == ModelStatus.ready),
            onSelect: () {
              settings.setActiveGgufModelName(AppConstants.gemmaModelName);
              settings.setLlmMode(LlmMode.gemmaGguf);
            },
            downloadAction: _gemmaStatus == ModelStatus.ready || _llmService.isDownloading
                ? null
                : () => _triggerModelDownload(
                      modelName: AppConstants.gemmaModelName,
                      downloadUrl: AppConstants.gemmaDownloadUrl,
                    ),
          ),

          const SizedBox(height: 10),

          // Qwen 2.5 1.5B GGUF Option
          _buildModelCard(
            title: 'Qwen2.5-1.5B-Instruct-Q4_K_M',
            subtitle: 'Hugging Face Quantized Model (${AppConstants.qwenModelSize}). High accuracy in math and reasoning.',
            badge: _qwenStatus == ModelStatus.ready
                ? 'INSTALLED'
                : (_qwenStatus == ModelStatus.downloading ? 'DOWNLOADING' : 'NOT INSTALLED'),
            badgeColor: _qwenStatus == ModelStatus.ready
                ? AppColors.secondaryAccent
                : (_qwenStatus == ModelStatus.downloading
                    ? AppColors.accentYellow
                    : AppColors.textMuted),
            isSelected: settings.selectedLlmMode == LlmMode.qwenGguf ||
                (settings.activeGgufModelName == AppConstants.qwenModelName && _qwenStatus == ModelStatus.ready),
            onSelect: () {
              settings.setActiveGgufModelName(AppConstants.qwenModelName);
              settings.setLlmMode(LlmMode.qwenGguf);
            },
            downloadAction: _qwenStatus == ModelStatus.ready || _llmService.isDownloading
                ? null
                : () => _triggerModelDownload(
                      modelName: AppConstants.qwenModelName,
                      downloadUrl: LlmService.qwenDownloadUrl,
                    ),
          ),

          const SizedBox(height: 10),

          // Llama 3.2 1B GGUF Option
          _buildModelCard(
            title: 'Llama-3.2-1B-Instruct-Q4_K_M',
            subtitle: 'Meta Quantized Compact Model (${AppConstants.llamaModelSize}). Fast mobile execution.',
            badge: _llamaStatus == ModelStatus.ready
                ? 'INSTALLED'
                : (_llamaStatus == ModelStatus.downloading ? 'DOWNLOADING' : 'NOT INSTALLED'),
            badgeColor: _llamaStatus == ModelStatus.ready
                ? AppColors.secondaryAccent
                : (_llamaStatus == ModelStatus.downloading
                    ? AppColors.accentYellow
                    : AppColors.textMuted),
            isSelected: settings.selectedLlmMode == LlmMode.llamaGguf ||
                (settings.activeGgufModelName == AppConstants.llamaModelName && _llamaStatus == ModelStatus.ready),
            onSelect: () {
              settings.setActiveGgufModelName(AppConstants.llamaModelName);
              settings.setLlmMode(LlmMode.llamaGguf);
            },
            downloadAction: _llamaStatus == ModelStatus.ready || _llmService.isDownloading
                ? null
                : () => _triggerModelDownload(
                      modelName: AppConstants.llamaModelName,
                      downloadUrl: LlmService.llamaDownloadUrl,
                    ),
          ),

          const SizedBox(height: 24),

          // Section: Online Data / Live AI Search Gate (Strict User Opt-In)
          _buildSectionHeader('ONLINE AI & INTERNET SEARCH (OPT-IN)'),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: settings.useOnlineData
                    ? AppColors.secondaryAccent.withAlpha(150)
                    : AppColors.border,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Icon(
                        settings.useOnlineData
                            ? Icons.wifi_rounded
                            : Icons.wifi_off_rounded,
                        color: settings.useOnlineData
                            ? AppColors.secondaryAccent
                            : AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Use Online Data (Live AI Search)',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      settings.useOnlineData
                          ? 'Enabled: If on-device models need broader data, answers stream live via real-time online AI.'
                          : 'Disabled: 100% Offline Mode. App strictly answers using downloaded on-device models with zero internet access.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: settings.useOnlineData
                            ? AppColors.secondaryAccent
                            : AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  value: settings.useOnlineData,
                  activeThumbColor: AppColors.secondaryAccent,
                  onChanged: (val) => settings.setUseOnlineData(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 2: Speech & Voice Settings
          _buildSectionHeader('VOICE & SPEECH SYNTHESIS'),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Auto-Speak Toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Auto-Speak Professor Replies',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Speaks out Hinglish explanations as soon as they arrive.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  value: settings.autoSpeak,
                  activeThumbColor: AppColors.primaryAccent,
                  onChanged: (val) => settings.toggleAutoSpeak(),
                ),

                const Divider(color: AppColors.border, height: 24),

                // Voice Language (Hinglish hi_IN vs Indian English en_IN)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Speech Recognition Language',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'Mic accent & context',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    DropdownButton<String>(
                      value: settings.voiceLanguage,
                      dropdownColor: AppColors.surfaceElevated,
                      style: GoogleFonts.inter(color: AppColors.primaryLight, fontSize: 13),
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: 'hi_IN',
                          child: Text('Hinglish (hi_IN)'),
                        ),
                        DropdownMenuItem(
                          value: 'en_IN',
                          child: Text('English (en_IN)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) settings.setVoiceLanguage(val);
                      },
                    ),
                  ],
                ),

                const Divider(color: AppColors.border, height: 24),

                // Speech Speed Slider & Pace Controls
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Speech Rate (Professor Pace)',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _getSpeechRateDescriptor(settings.speechRate),
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppColors.secondaryAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${(settings.speechRate * 100).toInt()}%',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondaryAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Slider(
                      value: settings.speechRate.clamp(0.25, 0.85),
                      min: 0.25,
                      max: 0.85,
                      divisions: 12,
                      activeColor: AppColors.primaryAccent,
                      inactiveColor: AppColors.surfaceElevated,
                      onChanged: (val) {
                        final rounded = double.parse(val.toStringAsFixed(2));
                        settings.setSpeechRate(rounded);
                      },
                    ),

                    // Quick Pace Presets
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildPaceChip('0.30x Slow', 0.30, settings),
                        _buildPaceChip('0.40x Relaxed', 0.40, settings),
                        _buildPaceChip('0.45x Normal', 0.45, settings),
                        _buildPaceChip('0.55x Brisk', 0.55, settings),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Test Voice Button
                    Center(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          if (_isTestingVoice) {
                            await _ttsService.stop();
                            if (mounted) setState(() => _isTestingVoice = false);
                            return;
                          }
                          setState(() => _isTestingVoice = true);
                          final testPhrase = settings.responseLanguage == 'hindi'
                              ? 'नमस्ते! यह आवाज की गति कैसी लग रही है? मैं आपका बी.टेक एआई प्रोफेसर हूँ।'
                              : settings.responseLanguage == 'english'
                                  ? 'Hello! How does this speaking speed sound to you? I am your B.Tech AI Professor.'
                                  : 'Namaste! Yeh voice speed kaisa lag raha hai? Main hoon aapka B.Tech AI Professor.';
                          await _ttsService.speak(testPhrase);
                          if (mounted) setState(() => _isTestingVoice = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _isTestingVoice
                                ? AppColors.secondaryAccent.withAlpha(40)
                                : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _isTestingVoice
                                  ? AppColors.secondaryAccent
                                  : AppColors.primaryAccent.withAlpha(120),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isTestingVoice
                                    ? Icons.stop_rounded
                                    : Icons.volume_up_rounded,
                                color: AppColors.secondaryAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isTestingVoice ? 'Listening...' : 'Test Professor Voice',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 3: AI Response Language Selection (Hinglish, English, Hindi)
          _buildSectionHeader('AI RESPONSE LANGUAGE (OUTPUT)'),
          const SizedBox(height: 6),
          Text(
            'Prof. AI will formulate and explain all engineering concepts in your chosen language:',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          // Hinglish Option (Default & Recommended)
          _buildLanguageCard(
            title: 'Hinglish (Hindi + English)',
            subtitle: 'Conversational blend of Hindi & English. Ideal for B.Tech concepts, code logic, and everyday analogies.',
            badge: 'RECOMMENDED',
            badgeColor: AppColors.secondaryAccent,
            isSelected: settings.responseLanguage == 'hinglish',
            onSelect: () => settings.setResponseLanguage('hinglish'),
          ),

          const SizedBox(height: 10),

          // English Option
          _buildLanguageCard(
            title: 'English (Academic & Formal)',
            subtitle: 'Standard technical English for formal university exams, viva definitions, and documentation.',
            badge: 'ENGLISH',
            badgeColor: AppColors.primaryLight,
            isSelected: settings.responseLanguage == 'english',
            onSelect: () => settings.setResponseLanguage('english'),
          ),

          const SizedBox(height: 10),

          // Hindi Option
          _buildLanguageCard(
            title: 'हिंदी (Pure Hindi)',
            subtitle: 'Complete explanation in Devanagari script for deep native understanding with key technical terms preserved.',
            badge: 'DEVANAGARI',
            badgeColor: AppColors.accentOrange,
            isSelected: settings.responseLanguage == 'hindi',
            onSelect: () => settings.setResponseLanguage('hindi'),
          ),

          const SizedBox(height: 24),

          // Section 4: Dynamic B.Tech CSE System Prompt
          _buildSectionHeader('PROFESSOR SYSTEM PROMPT'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.psychology_outlined,
                            size: 18, color: AppColors.primaryLight),
                        const SizedBox(width: 8),
                        Text(
                          'Tuned for B.Tech Students',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        settings.responseLanguage.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondaryAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppConstants.getSystemPrompt(settings.responseLanguage),
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          // STORAGE & DATA MANAGEMENT SECTION
          const SizedBox(height: 24),
          _buildSectionHeader('STORAGE & DATA MANAGEMENT'),
          const SizedBox(height: 10),
          _buildStorageBreakdownCard(),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryLight),
                  title: Text(
                    'Clear Chat History',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    'Delete all conversation messages across all subjects',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  onTap: () => _confirmClearChatHistory(context),
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  leading: const Icon(Icons.folder_delete_outlined, color: AppColors.secondaryAccent),
                  title: Text(
                    'Clear Uploaded Documents',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    'Delete all saved notes, PDFs, and extracted OCR text',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  onTap: () => _confirmClearDocuments(context),
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  leading: const Icon(Icons.restore_from_trash_rounded, color: AppColors.error),
                  title: Text(
                    'Clear All Data & Reset App',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error),
                  ),
                  subtitle: Text(
                    'Permanently wipe chats, documents, and restore default subjects',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onTap: () => _confirmClearAllData(context),
                ),
              ],
            ),
          ),

          // LEGAL & ABOUT SECTION
          const SizedBox(height: 24),
          _buildSectionHeader('LEGAL & ABOUT'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: AppColors.primaryLight),
                  title: Text(
                    'Terms of Use',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    'Educational terms, user responsibilities, and disclaimers',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfUseScreen()));
                  },
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.secondaryAccent),
                  title: Text(
                    'Privacy Policy',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    '100% on-device processing and data deletion rights',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
                  },
                ),
                const Divider(height: 1, color: AppColors.border),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: AppColors.accentYellow),
                  title: Text(
                    'About ${AppConstants.appName}',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    'Version ${AppConstants.appVersion} • Open Source Licenses',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: AppConstants.appName,
                      applicationVersion: AppConstants.appVersion,
                      applicationLegalese: 'An offline AI study companion for B.Tech engineering students.',
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  void _confirmClearChatHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            Text(
              'Clear All Chats?',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete all messages across all subjects and chapter rooms? This cannot be undone.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<ChatProvider>().clearAllChats();
              _refreshStorageBreakdown();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All chat messages cleared successfully.')),
                );
              }
            },
            child: Text('Delete All', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _confirmClearDocuments(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.folder_delete_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 10),
            Text(
              'Clear All Documents?',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete all saved PDF notes, images, and extracted text? Past document attachments in chats will no longer be analyzed.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final storage = await StorageService.getInstance();
              await storage.clearAllSavedDocuments();
              _refreshStorageBreakdown();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All saved documents cleared.')),
                );
              }
            },
            child: Text('Clear Documents', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _confirmClearAllData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 26),
            const SizedBox(width: 10),
            Text(
              'Reset All Data?',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.error),
            ),
          ],
        ),
        content: Text(
          'This will permanently wipe all chats, uploaded documents, subjects, and chapters, and restore the initial default curriculum. This action cannot be reversed.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final storage = await StorageService.getInstance();
              await storage.clearAllData();
              _refreshStorageBreakdown();
              if (context.mounted) {
                context.read<SubjectProvider>().loadSubjects();
                context.read<ChapterProvider>().loadChapters();
                context.read<ChatProvider>().loadMessages();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data reset to defaults.')),
                );
              }
            },
            child: Text('Reset App', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageBreakdownCard() {
    return FutureBuilder<StorageBreakdown>(
      future: _storageBreakdownFuture,
      builder: (context, snapshot) {
        final breakdown = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pie_chart_outline_rounded, size: 20, color: AppColors.primaryLight),
                      const SizedBox(width: 8),
                      Text(
                        'Disk Storage Usage',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondaryAccent),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18, color: AppColors.secondaryAccent),
                    onPressed: isLoading ? null : _refreshStorageBreakdown,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Recalculate Storage',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStorageMetricTile(
                      icon: Icons.chat_rounded,
                      color: AppColors.primaryAccent,
                      label: 'Chat Rooms',
                      value: breakdown?.chatsSizeFormatted ?? '...',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStorageMetricTile(
                      icon: Icons.description_rounded,
                      color: AppColors.secondaryAccent,
                      label: 'Saved Notes',
                      value: breakdown?.documentsSizeFormatted ?? '...',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildStorageMetricTile(
                      icon: Icons.memory_rounded,
                      color: AppColors.accentOrange,
                      label: 'GGUF Models',
                      value: breakdown?.modelsSizeFormatted ?? '...',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStorageMetricTile(
                      icon: Icons.storage_rounded,
                      color: AppColors.primaryLight,
                      label: 'Total Storage',
                      value: breakdown?.totalSizeFormatted ?? '...',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStorageMetricTile({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildModelCard({
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required bool isSelected,
    required VoidCallback onSelect,
    VoidCallback? downloadAction,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppColors.primaryAccent : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected
                          ? AppColors.primaryAccent
                          : AppColors.textMuted,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badgeColor.withAlpha(120)),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),

                if (downloadAction != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        side: const BorderSide(color: AppColors.primaryAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      onPressed: downloadAction,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download GGUF', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getSpeechRateDescriptor(double rate) {
    if (rate <= 0.35) return 'Relaxed & Slow pace';
    if (rate <= 0.45) return 'Comfortable (Default Recommended)';
    if (rate <= 0.60) return 'Moderate brisk pace';
    return 'Fast speed';
  }

  Widget _buildPaceChip(String label, double value, TutorSettingsProvider settings) {
    final isSelected = (settings.speechRate - value).abs() < 0.02;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => settings.setSpeechRate(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryAccent
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.secondaryAccent : AppColors.border,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard({
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.secondaryAccent : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected
                      ? AppColors.secondaryAccent
                      : AppColors.textMuted,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: badgeColor.withAlpha(120), width: 0.8),
                            ),
                            child: Text(
                              badge,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveRadioOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.secondaryAccent.withAlpha(25)
            : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.secondaryAccent : AppColors.border,
          width: isSelected ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected
                      ? AppColors.secondaryAccent
                      : AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.secondaryAccent : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryAccent.withAlpha(35),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.secondaryAccent.withAlpha(120)),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
