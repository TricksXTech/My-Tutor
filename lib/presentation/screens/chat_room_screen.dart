import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/chat_provider.dart';
import '../../providers/chapter_provider.dart';
import '../../providers/tutor_settings_provider.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/document_text_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_control_bar.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chapterId;
  final String subjectTitle;
  final String chapterTitle;
  final Color accentColor;

  const ChatRoomScreen({
    super.key,
    required this.chapterId,
    required this.subjectTitle,
    required this.chapterTitle,
    this.accentColor = AppColors.primaryAccent,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DocumentTextService _docService = DocumentTextService();
  int _prevMessageCount = 0;
  int _prevLastMessageLength = 0;
  bool _initialScrolled = false;
  int _visibleMessageCount = 40;
  bool _isLoadingOlder = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().enterRoom(
            chapterId: widget.chapterId,
            subjectTitle: widget.subjectTitle,
            chapterTitle: widget.chapterTitle,
          );
      _scrollToBottomInstantly();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <= 100 && !_isLoadingOlder) {
      final total = context.read<ChatProvider>().activeRoomMessages.length;
      if (_visibleMessageCount < total) {
        _isLoadingOlder = true;
        final prevMaxScroll = _scrollController.position.maxScrollExtent;
        final prevPixels = _scrollController.position.pixels;
        setState(() {
          _visibleMessageCount = (_visibleMessageCount + 40).clamp(40, total);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final newMaxScroll = _scrollController.position.maxScrollExtent;
            final scrollDelta = newMaxScroll - prevMaxScroll;
            if (scrollDelta > 0) {
              _scrollController.jumpTo(prevPixels + scrollDelta);
            }
          }
          _isLoadingOlder = false;
        });
      }
    }
  }

  void _scrollToBottomInstantly() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      try {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        // Second pass after ListView items calculate layout heights
        Future.delayed(const Duration(milliseconds: 60), () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
        Future.delayed(const Duration(milliseconds: 180), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      } catch (_) {}
    });
  }

  void _scrollToBottomSmooth() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      try {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } catch (_) {}
    });
  }

  void _handleSendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final chatProv = context.read<ChatProvider>();
    final settings = context.read<TutorSettingsProvider>();
    final chapterProv = context.read<ChapterProvider>();

    _textController.clear();
    chatProv.sendUserMessage(
      text: text,
      settings: settings,
      onChapterCountIncrement: () {
        chapterProv.incrementMessageCount(widget.chapterId);
      },
    );
    _scrollToBottomSmooth();
  }

  void _showClearChatConfirmation(BuildContext context, ChatProvider chatProv) {
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
              'Clear Room Chat?',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete all messages in "${widget.chapterTitle}"? This cannot be undone.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              chatProv.clearRoomChat();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Room chat cleared'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'Clear Chat',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProv = context.watch<ChatProvider>();
    final settingsProv = context.watch<TutorSettingsProvider>();
    final allRoomMessages = chatProv.activeRoomMessages;
    final bool hasOlderMessages = allRoomMessages.length > _visibleMessageCount;
    final startIndex = hasOlderMessages ? allRoomMessages.length - _visibleMessageCount : 0;
    final messages = allRoomMessages.sublist(startIndex);

    // Automatically scroll to bottom on open or whenever message count changes or streaming grows
    final lastMsgLength = messages.isNotEmpty ? messages.last.text.length : 0;
    if (messages.length != _prevMessageCount) {
      final wasInitial = !_initialScrolled;
      _initialScrolled = true;
      _prevMessageCount = messages.length;
      _prevLastMessageLength = lastMsgLength;
      if (wasInitial) {
        _scrollToBottomInstantly();
      } else {
        _scrollToBottomSmooth();
      }
    } else if (chatProv.isGenerating && (lastMsgLength - _prevLastMessageLength).abs() > 30) {
      _prevLastMessageLength = lastMsgLength;
      _scrollToBottomSmooth();
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.chapterTitle,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Flexible(
                  child: Text(
                    widget.subjectTitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: widget.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: settingsProv.useOnlineData
                        ? AppColors.primaryAccent.withAlpha(40)
                        : AppColors.accentGreen.withAlpha(35),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: settingsProv.useOnlineData
                          ? AppColors.primaryAccent.withAlpha(120)
                          : AppColors.accentGreen.withAlpha(120),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        settingsProv.useOnlineData ? Icons.wifi_rounded : Icons.offline_bolt_rounded,
                        size: 9.5,
                        color: settingsProv.useOnlineData ? AppColors.primaryLight : AppColors.accentGreen,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        settingsProv.useOnlineData ? 'Online AI' : '100% Offline',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: settingsProv.useOnlineData ? AppColors.primaryLight : AppColors.accentGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Attachment Button (PDF, Notes, Photos)
          IconButton(
            icon: const Icon(Icons.attach_file_rounded, color: AppColors.primaryLight, size: 22),
            tooltip: 'Upload Notes (PDF / Photo)',
            onPressed: () => _openAttachmentMenu(context),
          ),
          // Photo Doubt Scanner Button (Offline OCR)
          IconButton(
            icon: const Icon(Icons.camera_alt_rounded, color: AppColors.secondaryAccent, size: 21),
            tooltip: 'Scan Question Photo (Offline OCR)',
            onPressed: () => _processPhotoAttachment(isCamera: true),
          ),
          // Clear Chat Button
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            color: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            onSelected: (val) {
              if (val == 'clear') {
                _showClearChatConfirmation(context, chatProv);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 18),
                    SizedBox(width: 8),
                    Text('Clear Room Chat', style: TextStyle(color: AppColors.error, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // Chat messages list
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withAlpha(25),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: widget.accentColor.withAlpha(80),
                                  width: 1.5),
                            ),
                            child: Icon(
                              Icons.headset_mic_rounded,
                              size: 38,
                              color: widget.accentColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'AI Voice Tutor Room Ready',
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bolo ya type karo! Physics numericals, C pointers, ya Math derivations — aapka Hinglish professor line-by-line samjhayega.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _buildPromptSuggestion('Pointers kaise kaam karte hain?'),
                              _buildPromptSuggestion('Semiconductor band gap samjhao'),
                              _buildPromptSuggestion('Eigenvalues ka practical use kya hai?'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : ValueListenableBuilder<String?>(
                    valueListenable: chatProv.currentSpeakingIdNotifier,
                    builder: (context, currentSpeakingId, child) {
                      return ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(top: 10, bottom: 20),
                        itemCount: messages.length + (hasOlderMessages ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (hasOlderMessages && index == 0) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    backgroundColor: AppColors.surfaceElevated,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _visibleMessageCount = (_visibleMessageCount + 40)
                                          .clamp(40, allRoomMessages.length);
                                    });
                                  },
                                  icon: const Icon(Icons.history_rounded, size: 16, color: AppColors.secondaryAccent),
                                  label: Text(
                                    'Load older messages (${allRoomMessages.length - messages.length} remaining)',
                                    style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            );
                          }

                          final msg = messages[hasOlderMessages ? index - 1 : index];
                          final isThisSpeaking = currentSpeakingId == msg.id;

                          return RepaintBoundary(
                            key: ValueKey('boundary_${msg.id}'),
                            child: ChatBubble(
                              key: ValueKey(msg.id),
                              message: msg,
                              isSpeaking: isThisSpeaking,
                              onToggleSpeak: () {
                                chatProv.toggleSpeakMessage(msg);
                              },
                              onToggleSpeakWithText: (translatedText) {
                                chatProv.toggleSpeakMessage(msg, customText: translatedText);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),

          // BOTTOM CONTROL BAR
          ValueListenableBuilder<bool>(
            valueListenable: chatProv.isListeningNotifier,
            builder: (context, isListening, _) {
              return ValueListenableBuilder<double>(
                valueListenable: chatProv.soundLevelNotifier,
                builder: (context, soundLevel, _) {
                  return VoiceControlBar(
                    textController: _textController,
                    isListening: isListening,
                    soundLevel: soundLevel,
                    autoSpeakEnabled: settingsProv.autoSpeak,
                    isGenerating: chatProv.isGenerating,
                    onStopGeneration: () => chatProv.stopGeneration(),
                    onToggleAutoSpeak: () {
                      settingsProv.toggleAutoSpeak();
                    },
                    onToggleVoiceInput: () {
                      chatProv.toggleVoiceInput(
                        onLiveTranscript: (liveWords) {
                          _textController.text = liveWords;
                          _textController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _textController.text.length),
                          );
                        },
                      );
                    },
                    onSendMessage: _handleSendMessage,
                    onScanPhoto: () => _processPhotoAttachment(isCamera: true),
                    onAttachDocument: () => _openAttachmentMenu(context),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPromptSuggestion(String text) {
    return ActionChip(
      backgroundColor: AppColors.surfaceElevated,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      label: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.textPrimary,
        ),
      ),
      onPressed: () {
        _textController.text = text;
        _handleSendMessage();
      },
    );
  }

  /// Opens unified BottomSheet for selecting PDF Notes or Photos (Camera / Gallery)
  Future<void> _openAttachmentMenu(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryAccent.withAlpha(35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.attach_file_rounded,
                        color: AppColors.primaryLight,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attach Notes & Study Material',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '100% Offline AI Analysis • PDF, Notes & Photos',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.accentGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryAccent.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.secondaryAccent),
                  ),
                  title: Text(
                    'Upload PDF / Text Notes',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Lecture slides, textbook notes ya study material (.pdf, .txt)',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tileColor: AppColors.surfaceCard,
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _pickPdfOrTxtFile();
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAccent.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryLight),
                  ),
                  title: Text(
                    'Take Photo from Camera',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Notebook, whiteboard ya textbook question ki photo',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tileColor: AppColors.surfaceCard,
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _processPhotoAttachment(isCamera: true);
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: AppColors.accentGreen),
                  ),
                  title: Text(
                    'Choose Photo from Gallery',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Saved problem screenshot ya notes gallery image',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tileColor: AppColors.surfaceCard,
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _processPhotoAttachment(isCamera: false);
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickPdfOrTxtFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        final fileName = files.first.name;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reading and extracting text from document...'),
              duration: Duration(milliseconds: 1400),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        final text = await _docService.extractTextFromFile(file);
        if (text.trim().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Document se readable text nahi mila. Kripya check karein.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        if (mounted) {
          _showAttachmentCaptionDialog(
            file: file,
            fileName: fileName,
            fileType: 'pdf',
            extractedText: text.trim(),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document read error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _processPhotoAttachment({required bool isCamera}) async {
    try {
      final ocrResult = isCamera
          ? await OcrService.scanFromCamera()
          : await OcrService.pickFromGallery();

      if (ocrResult == null) return; // User cancelled

      if (!ocrResult.hasText) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image mein text detect nahi hua. Kripya saaf photo lein.'),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final file = File(ocrResult.imagePath);
      final fileName = ocrResult.imagePath.split(Platform.pathSeparator).last;

      if (mounted) {
        _showAttachmentCaptionDialog(
          file: file,
          fileName: fileName,
          fileType: 'image',
          extractedText: ocrResult.extractedText,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo processing error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Displays preview of the attached document/photo and lets student enter an optional caption
  /// - With caption: AI focuses strictly on answering that specific question
  /// - Without caption: AI begins explaining the material
  void _showAttachmentCaptionDialog({
    required File file,
    required String fileName,
    required String fileType,
    required String extractedText,
  }) {
    final captionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasCaption = captionController.text.trim().isNotEmpty;

            return AlertDialog(
              backgroundColor: AppColors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: AppColors.border, width: 1.2),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: fileType == 'pdf'
                          ? AppColors.secondaryAccent.withAlpha(35)
                          : AppColors.primaryAccent.withAlpha(35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      fileType == 'pdf'
                          ? Icons.picture_as_pdf_rounded
                          : Icons.image_rounded,
                      color: fileType == 'pdf'
                          ? AppColors.secondaryAccent
                          : AppColors.primaryLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileType == 'pdf' ? 'Attached PDF Notes' : 'Attached Photo Note',
                          style: GoogleFonts.poppins(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          fileName,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preview Box
                      if (fileType == 'image') ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            color: Colors.black26,
                            child: Image.file(
                              file,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.description_rounded, color: AppColors.secondaryAccent, size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fileName,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${extractedText.split(RegExp(r'\s+')).length} words detected (${extractedText.length} characters)',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Caption Input Field
                      Text(
                        'Add a question or caption (Optional):',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasCaption ? AppColors.secondaryAccent : AppColors.border,
                            width: 1.2,
                          ),
                        ),
                        child: TextField(
                          controller: captionController,
                          maxLines: 3,
                          onChanged: (_) => setDialogState(() {}),
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Is formula ko derive karo / Explain question 2...',
                            hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Smart Mode Indicator Tip
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: hasCaption
                              ? AppColors.primaryAccent.withAlpha(20)
                              : AppColors.accentGreen.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasCaption
                                ? AppColors.primaryAccent.withAlpha(100)
                                : AppColors.accentGreen.withAlpha(100),
                            width: 0.9,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              hasCaption ? Icons.filter_center_focus_rounded : Icons.menu_book_rounded,
                              size: 16,
                              color: hasCaption ? AppColors.primaryLight : AppColors.accentGreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hasCaption
                                    ? 'With caption: AI will focus strictly on your specific question above.'
                                    : 'Without caption: AI will analyze and start explaining this material.',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: AppColors.textMuted),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasCaption ? AppColors.secondaryAccent : AppColors.primaryAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final captionText = captionController.text.trim();
                    Navigator.pop(dialogCtx);

                    final chatProv = context.read<ChatProvider>();
                    final settings = context.read<TutorSettingsProvider>();
                    final chapterProv = context.read<ChapterProvider>();

                    chatProv.sendAttachmentMessage(
                      file: file,
                      fileName: fileName,
                      fileType: fileType,
                      caption: captionText.isNotEmpty ? captionText : null,
                      extractedText: extractedText,
                      settings: settings,
                      onChapterCountIncrement: () {
                        chapterProv.incrementMessageCount(widget.chapterId);
                      },
                    );
                    _scrollToBottomSmooth();
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text(
                    hasCaption ? 'Ask with Question' : 'Explain Document',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
