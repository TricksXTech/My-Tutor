import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class VoiceControlBar extends StatefulWidget {
  final TextEditingController textController;
  final bool isListening;
  final double soundLevel;
  final bool autoSpeakEnabled;
  final bool isGenerating;
  final VoidCallback onToggleAutoSpeak;
  final VoidCallback onToggleVoiceInput;
  final VoidCallback onSendMessage;
  final VoidCallback? onScanPhoto;
  final VoidCallback? onAttachDocument;
  final VoidCallback? onStopGeneration;

  const VoiceControlBar({
    super.key,
    required this.textController,
    required this.isListening,
    required this.soundLevel,
    required this.autoSpeakEnabled,
    required this.isGenerating,
    required this.onToggleAutoSpeak,
    required this.onToggleVoiceInput,
    required this.onSendMessage,
    this.onScanPhoto,
    this.onAttachDocument,
    this.onStopGeneration,
  });

  @override
  State<VoiceControlBar> createState() => _VoiceControlBarState();
}

class _VoiceControlBarState extends State<VoiceControlBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Listening Indicator Banner
            if (widget.isListening)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.secondaryAccent.withAlpha(150)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bolo student! Hinglish/English listening...',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryAccent,
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Speaker Auto-Speak Toggle Button
                Tooltip(
                  message: widget.autoSpeakEnabled
                      ? 'AI Voice Output: ON'
                      : 'AI Voice Output: Muted',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: widget.onToggleAutoSpeak,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.autoSpeakEnabled
                              ? AppColors.primaryAccent.withAlpha(35)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: widget.autoSpeakEnabled
                                ? AppColors.primaryAccent
                                : AppColors.border,
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          widget.autoSpeakEnabled
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          color: widget.autoSpeakEnabled
                              ? AppColors.primaryLight
                              : AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // 2. Text Input Field (Seamless Pill Design, Zero Theme Breaks)
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44, maxHeight: 110),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: widget.textController.text.isNotEmpty
                            ? AppColors.primaryAccent.withAlpha(160)
                            : AppColors.border,
                        width: 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (widget.onAttachDocument != null)
                          Tooltip(
                            message: 'PDF ya Document Upload karo',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: widget.onAttachDocument,
                                child: const Padding(
                                  padding: EdgeInsets.only(right: 6, left: 2),
                                  child: Icon(
                                    Icons.attach_file_rounded,
                                    size: 20,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (widget.onScanPhoto != null)
                          Tooltip(
                            message: 'Photo se Doubt poocho (Offline OCR)',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: widget.onScanPhoto,
                                child: const Padding(
                                  padding: EdgeInsets.only(right: 6, left: 2),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    size: 19,
                                    color: AppColors.secondaryAccent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: TextField(
                            controller: widget.textController,
                            style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                            maxLines: 4,
                            minLines: 1,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText: 'Poocho professor se...',
                              hintStyle: GoogleFonts.inter(
                                color: AppColors.textMuted,
                                fontSize: 13.5,
                              ),
                              isDense: true,
                              filled: false,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                            ),
                          ),
                        ),

                        // Clear Button if text present
                        if (widget.textController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              widget.textController.clear();
                              setState(() {});
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // 3. Animated Microphone Button
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final scale = widget.isListening
                        ? _pulseAnimation.value * (1.0 + widget.soundLevel * 0.3)
                        : 1.0;

                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: widget.isListening
                              ? [
                                  BoxShadow(
                                    color: AppColors.secondaryAccent.withAlpha(120),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: widget.isListening
                              ? AppColors.secondaryAccent
                              : AppColors.surfaceElevated,
                          shape: CircleBorder(
                            side: BorderSide(
                              color: widget.isListening
                                  ? AppColors.secondaryAccent
                                  : AppColors.border,
                              width: 1.2,
                            ),
                          ),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: widget.onToggleVoiceInput,
                            child: Center(
                              child: Icon(
                                widget.isListening
                                    ? Icons.mic_rounded
                                    : Icons.mic_none_rounded,
                                color: widget.isListening
                                    ? Colors.black
                                    : AppColors.primaryLight,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(width: 8),

                // 4. Send / Stop Button
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: widget.isGenerating
                        ? const LinearGradient(
                            colors: [Color(0xFFE53935), Color(0xFFC62828)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: widget.isGenerating
                            ? Colors.redAccent.withAlpha(90)
                            : AppColors.primaryAccent.withAlpha(80),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: widget.isGenerating ? widget.onStopGeneration : widget.onSendMessage,
                      onDoubleTap: widget.isGenerating ? widget.onStopGeneration : null,
                      child: Center(
                        child: widget.isGenerating
                            ? Tooltip(
                                message: 'Double click to stop output',
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
