import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/services/translation_service.dart';
import '../../data/services/llm_service.dart';

class ChatBubble extends StatefulWidget {
  final ChatMessageModel message;
  final bool isSpeaking;
  final VoidCallback onToggleSpeak;
  final void Function(String textToSpeak)? onToggleSpeakWithText;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isSpeaking,
    required this.onToggleSpeak,
    this.onToggleSpeakWithText,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  int _cycleIndex = 0;
  bool _isTranslating = false;
  final Map<String, String> _translationsCache = {};

  Widget? _cachedMarkdownWidget;
  String? _cachedForText;
  String? _cachedForLang;

  static final MarkdownStyleSheet _markdownStyleSheet = MarkdownStyleSheet(
    p: GoogleFonts.inter(
      fontSize: 14,
      color: AppColors.textPrimary,
      height: 1.5,
    ),
    h1: GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    h2: GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    h3: GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.secondaryAccent,
    ),
    code: GoogleFonts.firaCode(
      fontSize: 12.5,
      backgroundColor: AppColors.codeBackground,
      color: AppColors.secondaryAccent,
    ),
    codeblockDecoration: BoxDecoration(
      color: AppColors.codeBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: AppColors.borderLight,
        width: 1,
      ),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    blockquote: GoogleFonts.inter(
      fontSize: 13,
      fontStyle: FontStyle.italic,
      color: AppColors.primaryLight,
    ),
    blockquoteDecoration: BoxDecoration(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(8),
      border: const Border(
        left: BorderSide(
          color: AppColors.primaryAccent,
          width: 3,
        ),
      ),
    ),
    listBullet: GoogleFonts.inter(
      fontSize: 14,
      color: AppColors.primaryLight,
    ),
  );

  Widget _buildMarkdownContent(String displayedText) {
    if (_cachedMarkdownWidget != null &&
        _cachedForText == displayedText &&
        _cachedForLang == _currentLanguage) {
      return _cachedMarkdownWidget!;
    }

    final rendered = MarkdownBody(
      data: displayedText,
      selectable: true,
      styleSheet: _markdownStyleSheet,
    );

    _cachedMarkdownWidget = rendered;
    _cachedForText = displayedText;
    _cachedForLang = _currentLanguage;
    return rendered;
  }

  String _detectInitialLanguage() {
    final text = widget.message.text;
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
      return 'hindi';
    }
    final hinglishMarkers = [
      ' hai ', ' hain ', ' yeh ', ' woh ', ' hum ', ' aap ', ' tum ',
      ' samjhein ', ' samjho ', ' karte ', ' karta ', ' karti ',
      ' hota ', ' hoti ', ' hote ', ' nahi ', ' aur ', ' ya ',
      ' kaise ', ' kya ', ' kyun ', ' kyu ', ' chalte ', ' chalo ',
      ' mein ', ' par ', ' se ', ' ko ', ' ka ', ' ki ', ' ke ',
      ' dhyan ', ' pehle ', ' baad ', ' batao ', ' dekho '
    ];
    final lower = ' ${text.toLowerCase()} ';
    int matches = 0;
    for (final marker in hinglishMarkers) {
      if (lower.contains(marker)) matches++;
    }
    if (matches >= 2) return 'hinglish';
    return 'english';
  }

  List<String> get _translationCycle {
    final initial = _detectInitialLanguage();
    if (initial == 'english') {
      return ['default', 'hindi', 'hinglish'];
    } else if (initial == 'hindi') {
      return ['default', 'english', 'hinglish'];
    } else {
      // initial == 'hinglish'
      return ['default', 'hindi', 'english'];
    }
  }

  String get _currentLanguage => _translationCycle[_cycleIndex % _translationCycle.length];

  String _getDisplayedText() {
    final lang = _currentLanguage;
    if (lang == 'default') {
      return LlmService.formatMathTypography(widget.message.text);
    }
    final cached = _translationsCache[lang];
    if (cached != null && cached.isNotEmpty) {
      return LlmService.formatMathTypography(cached);
    }
    return LlmService.formatMathTypography(widget.message.text);
  }

  String _getTranslateButtonLabel() {
    switch (_currentLanguage) {
      case 'hindi':
        return 'हिंदी';
      case 'english':
        return 'English';
      case 'hinglish':
        return 'Hinglish';
      case 'default':
      default:
        return 'Translate';
    }
  }

  String _getLanguageToastText(String targetLang) {
    switch (targetLang) {
      case 'hindi':
        return 'Switched response to Hindi (हिंदी)';
      case 'english':
        return 'Switched response to English';
      case 'hinglish':
        return 'Switched response to Hinglish';
      case 'default':
      default:
        return 'Restored to default response';
    }
  }

  String _getCopyLanguageTag() {
    switch (_currentLanguage) {
      case 'hindi':
        return 'Hindi';
      case 'english':
        return 'English';
      case 'hinglish':
        return 'Hinglish';
      case 'default':
      default:
        return 'Original';
    }
  }

  Future<void> _handleTranslateTap() async {
    if (_isTranslating) return;

    final cycle = _translationCycle;
    final nextIndex = (_cycleIndex + 1) % cycle.length;
    final nextLang = cycle[nextIndex];

    if (nextLang == 'default') {
      setState(() {
        _cycleIndex = nextIndex;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getLanguageToastText('default')),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_translationsCache.containsKey(nextLang)) {
      setState(() {
        _cycleIndex = nextIndex;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getLanguageToastText(nextLang)),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Trigger async translation
    setState(() {
      _isTranslating = true;
    });

    try {
      final translated = await TranslationService().translateTextAsync(
        widget.message.text,
        nextLang,
      );
      _translationsCache[nextLang] = translated;
      if (mounted) {
        setState(() {
          _cycleIndex = nextIndex;
          _isTranslating = false;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getLanguageToastText(nextLang)),
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translation notice: $e'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleSpeak() {
    final text = _getDisplayedText();
    if (widget.onToggleSpeakWithText != null) {
      widget.onToggleSpeakWithText!(text);
    } else {
      widget.onToggleSpeak();
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = message.isUser;
    final isSpeaking = widget.isSpeaking;
    final timeStr = DateFormat('hh:mm a').format(message.timestamp);
    final displayedText = _getDisplayedText();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender Header (for Professor)
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryAccent.withAlpha(90),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Prof. AI (B.Tech)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (message.modelEngine != null && message.modelEngine != 'Offline Engine')
                            ? AppColors.primaryAccent.withAlpha(180)
                            : AppColors.border,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      message.modelEngine ?? 'Offline Engine',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: (message.modelEngine != null && message.modelEngine != 'Offline Engine')
                            ? AppColors.primaryLight
                            : AppColors.secondaryAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_currentLanguage != 'default') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryAccent.withAlpha(50),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primaryAccent,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        _getTranslateButtonLabel(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: AppColors.secondaryAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Message Bubble
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.84,
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isUser ? 16 : 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primaryAccent : AppColors.surfaceCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: Border.all(
                  color: isUser
                      ? AppColors.primaryLight.withAlpha(80)
                      : (isSpeaking
                          ? AppColors.secondaryAccent
                          : AppColors.border),
                  width: isSpeaking ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? AppColors.primaryAccent.withAlpha(50)
                        : Colors.black.withAlpha(90),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                  if (isSpeaking && !isUser)
                    BoxShadow(
                      color: AppColors.secondaryAccent.withAlpha(40),
                      blurRadius: 12,
                      offset: const Offset(0, 0),
                    ),
                ],
              ),
              child: isUser
                  ? InkWell(
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: message.caption ?? message.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Message copied to clipboard!'),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.attachmentType != null) ...[
                            if (message.attachmentType == 'image' &&
                                message.attachmentPath != null &&
                                File(message.attachmentPath!).existsSync()) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(message.attachmentPath!),
                                  width: double.infinity,
                                  height: 160,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ] else if (message.attachmentType == 'pdf') ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(50),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 22),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            message.attachmentName ?? 'Document.pdf',
                                            style: GoogleFonts.inter(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'PDF Notes Attached',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                          SelectableText(
                            (message.caption != null && message.caption!.isNotEmpty)
                                ? message.caption!
                                : message.text,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                          if (message.attachmentType != null &&
                              (message.caption == null || message.caption!.isEmpty)) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Explain Document',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (displayedText.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.secondaryAccent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Concept formulate kar rahi hoon...',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.secondaryAccent,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          // Cached Markdown content
                          _buildMarkdownContent(displayedText),

                          const SizedBox(height: 10),
                        const Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 6),

                        // Action Bar: Audio speak toggle + Translate button + Copy message
                        Row(
                          children: [
                            // 1. Audio Read Aloud (Sunao TTS) Button
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _handleSpeak,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSpeaking
                                      ? AppColors.secondaryAccent.withAlpha(30)
                                      : AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSpeaking
                                        ? AppColors.secondaryAccent
                                        : AppColors.border,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSpeaking
                                          ? Icons.stop_rounded
                                          : Icons.volume_up_rounded,
                                      size: 15,
                                      color: isSpeaking
                                          ? AppColors.secondaryAccent
                                          : AppColors.primaryLight,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isSpeaking ? 'Listening...' : 'Sunao (TTS)',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isSpeaking
                                            ? AppColors.secondaryAccent
                                            : AppColors.primaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // 2. Language Switcher (Translate) Button
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _isTranslating ? null : _handleTranslateTap,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _currentLanguage != 'default'
                                      ? AppColors.primaryAccent.withAlpha(45)
                                      : AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _currentLanguage != 'default'
                                        ? AppColors.secondaryAccent
                                        : AppColors.border,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isTranslating) ...[
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.8,
                                          color: AppColors.secondaryAccent,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Translating...',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.secondaryAccent,
                                        ),
                                      ),
                                    ] else ...[
                                      Icon(
                                        Icons.translate_rounded,
                                        size: 14,
                                        color: _currentLanguage != 'default'
                                            ? AppColors.secondaryAccent
                                            : AppColors.primaryLight,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _getTranslateButtonLabel(),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _currentLanguage != 'default'
                                              ? AppColors.secondaryAccent
                                              : AppColors.primaryLight,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            const Spacer(),

                            // 3. Copy message text button
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 15),
                              color: AppColors.textMuted,
                              tooltip: 'Copy Answer',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: displayedText));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Answer (${_getCopyLanguageTag()}) copied to clipboard!'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
            ),
          ),

          // Timestamp & Actions
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 6, right: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUser) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Prompt copied to clipboard!'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Copy Prompt',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  timeStr,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
