import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/quiz_model.dart';
import '../../data/services/document_text_service.dart';
import '../../data/services/quiz_generator_service.dart';
import '../../data/services/storage_service.dart';
import '../../providers/chapter_provider.dart';
import '../../providers/subject_provider.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DocumentTextService _docService = DocumentTextService();
  final QuizGeneratorService _quizService = QuizGeneratorService();
  StorageService? _storageService;

  // Notes tab state
  String? _uploadedFileName;
  String _extractedNotesText = '';
  bool _isExtractingFile = false;

  // Chat tab state (Course Subject / General Doubt)
  bool _isGeneralDoubtSelected = false;
  int _generalDoubtMsgCount = 0;
  String? _selectedSubjectId;
  String? _selectedChapterId;
  String _chapterChatText = '';
  int _chatMessageCount = 0;
  bool _isLoadingChat = false;

  // Quiz config
  int _selectedQuestionCount = 5;
  String _selectedDifficulty = 'Medium';
  bool _isGeneratingQuiz = false;
  String _generationStatus = '';
  double _generationProgress = 0.0;
  int _estimatedSecondsRemaining = 6;
  Timer? _countdownTimer;

  // Active Quiz taking state
  QuizModel? _activeQuiz;
  int _currentQuestionIndex = 0;
  bool _isQuizSubmitted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    StorageService.getInstance().then((s) {
      if (mounted) {
        final msgs = s.getMessages();
        final gdCount = msgs.where((m) => m.chapterId == AppConstants.generalDoubtChapterId).length;
        setState(() {
          _storageService = s;
          _generalDoubtMsgCount = gdCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // FILE / NOTE PICKING METHODS
  // ===========================================================================

  Future<void> _pickPdfOrTxtFile() async {
    try {
      setState(() => _isExtractingFile = true);
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        final text = await _docService.extractTextFromFile(file);

        setState(() {
          _uploadedFileName = files.first.name;
          _extractedNotesText = text.trim();
          _isExtractingFile = false;
        });
      } else {
        setState(() => _isExtractingFile = false);
      }
    } catch (e) {
      setState(() => _isExtractingFile = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read file: $e')),
        );
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      setState(() => _isExtractingFile = true);
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();

      if (images.isNotEmpty) {
        final files = images.map((x) => File(x.path)).toList();
        final text = await _docService.extractTextFromImages(files);

        setState(() {
          _uploadedFileName = '${images.length} Image(s) Attached';
          _extractedNotesText = text.trim();
          _isExtractingFile = false;
        });
      } else {
        setState(() => _isExtractingFile = false);
      }
    } catch (e) {
      setState(() => _isExtractingFile = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read images: $e')),
        );
      }
    }
  }

  // ===========================================================================
  // CHAPTER & GENERAL DOUBT CHAT SELECTION
  // ===========================================================================

  Future<void> _selectGeneralDoubt() async {
    setState(() {
      _isGeneralDoubtSelected = true;
      _selectedSubjectId = AppConstants.generalDoubtSubjectId;
      _selectedChapterId = AppConstants.generalDoubtChapterId;
      _isLoadingChat = true;
    });

    try {
      final storage = _storageService ?? await StorageService.getInstance();
      final allMessages = storage.getMessages();
      final gdMessages = allMessages
          .where((m) => m.chapterId == AppConstants.generalDoubtChapterId)
          .toList();

      final combined = gdMessages
          .map((m) => '${m.isUser ? "Student" : "Professor"}: ${m.text}')
          .join('\n\n');

      setState(() {
        _chatMessageCount = gdMessages.length;
        _generalDoubtMsgCount = gdMessages.length;
        _chapterChatText = combined;
        _isLoadingChat = false;
      });
    } catch (_) {
      setState(() => _isLoadingChat = false);
    }
  }

  Future<void> _selectSubject(String subjectId) async {
    final chapterProv = context.read<ChapterProvider>();
    final chapters = chapterProv.getChaptersForSubject(subjectId);
    setState(() {
      _isGeneralDoubtSelected = false;
      _selectedSubjectId = subjectId;
      _selectedChapterId = chapters.isNotEmpty ? chapters.first.id : null;
      _chapterChatText = '';
      _chatMessageCount = 0;
    });

    if (chapters.isNotEmpty) {
      await _onChapterSelected(chapters.first.id);
    }
  }

  Future<void> _onChapterSelected(String? chapterId) async {
    if (chapterId == null) return;
    setState(() {
      _isGeneralDoubtSelected = false;
      _selectedChapterId = chapterId;
      _isLoadingChat = true;
    });

    try {
      final storage = _storageService ?? await StorageService.getInstance();
      final allMessages = storage.getMessages();
      final chapterMessages = allMessages.where((m) => m.chapterId == chapterId).toList();

      final combined = chapterMessages
          .map((m) => '${m.isUser ? "Student" : "Professor"}: ${m.text}')
          .join('\n\n');

      setState(() {
        _chatMessageCount = chapterMessages.length;
        _chapterChatText = combined;
        _isLoadingChat = false;
      });
    } catch (_) {
      setState(() => _isLoadingChat = false);
    }
  }

  String _detectSubjectTitle(String text, String? fileName) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).take(15);
    for (final line in lines) {
      final clean = line.replaceAll(RegExp(r'^(unit|chapter|module)\s*[\d\-_:\s]+', caseSensitive: false), '').trim();
      if (clean.length >= 3 && clean.length <= 40 && !clean.contains(':') && !clean.contains('=')) {
        if (RegExp(r'(wave|physics|electromagnet|circuit|calculus|mechanic|thermo|data|network|database|system|software|algorithm|chemistry|fluid|optics|biology|microprocessor)', caseSensitive: false).hasMatch(clean)) {
          return _formatCleanTitle(clean);
        }
      }
    }

    if (fileName != null && fileName.isNotEmpty) {
      var name = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      name = name.replaceAll(RegExp(r'^(unit|chap|ch|module)[\s\-_0-9]*', caseSensitive: false), '');
      name = name.replaceAll(RegExp(r'[\-_]+'), ' ').trim();
      if (name.length >= 3) {
        return _formatCleanTitle(name);
      }
    }

    final subjectProv = context.read<SubjectProvider>();
    if (_selectedSubjectId != null && subjectProv.subjects.any((s) => s.id == _selectedSubjectId)) {
      return subjectProv.subjects.firstWhere((s) => s.id == _selectedSubjectId).title;
    }

    return 'Study Notes';
  }

  String _cleanFileNameForDisplay(String fileName) {
    var name = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    name = name.replaceAll(RegExp(r'[\-_]+'), ' ').trim();
    return _formatCleanTitle(name);
  }

  String _formatCleanTitle(String raw) {
    final words = raw.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.map((w) {
      if (w.length <= 3) return w.toUpperCase();
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  String _getPreviewSnippet(String raw) {
    final clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length > 220) {
      return '${clean.substring(0, 220)}...';
    }
    return clean;
  }

  // ===========================================================================
  // GENERATE QUIZ
  // ===========================================================================

  Future<void> _generateQuiz({bool instant = false}) async {
    final isNotesTab = _tabController.index == 0;
    final sourceText = isNotesTab ? _extractedNotesText : _chapterChatText;
    final subjectProv = context.read<SubjectProvider>();
    final chapterProv = context.read<ChapterProvider>();

    String subjectTitle = 'Study Notes';
    String unitTitle = 'Study Material';

    if (isNotesTab) {
      if (sourceText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload a PDF, TXT, or images first!')),
        );
        return;
      }
      unitTitle = _cleanFileNameForDisplay(_uploadedFileName ?? 'Uploaded Notes');
      subjectTitle = _detectSubjectTitle(sourceText, _uploadedFileName);
    } else {
      if (_selectedChapterId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select General Doubt or a Course Subject unit!')),
        );
        return;
      }
      if (sourceText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No messages found in this chat yet. Please chat with the tutor first or upload notes!')),
        );
        return;
      }
      if (_isGeneralDoubtSelected || _selectedChapterId == AppConstants.generalDoubtChapterId) {
        subjectTitle = 'Universal CSE AI Tutor';
        unitTitle = 'General Doubt Mode';
      } else {
        final curSub = subjectProv.subjects.firstWhere(
          (s) => s.id == _selectedSubjectId,
          orElse: () => subjectProv.subjects.first,
        );
        final chapters = chapterProv.getChaptersForSubject(curSub.id);
        final curChap = chapters.firstWhere(
          (c) => c.id == _selectedChapterId,
          orElse: () => chapters.first,
        );
        subjectTitle = curSub.title;
        unitTitle = curChap.title;
      }
    }

    _countdownTimer?.cancel();
    setState(() {
      _isGeneratingQuiz = true;
      _generationProgress = instant ? 0.6 : 0.1;
      _estimatedSecondsRemaining = instant ? 1 : 8;
      _generationStatus = instant ? 'Creating real-time contextual quiz...' : 'Initializing AI quiz generator...';
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isGeneratingQuiz) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_estimatedSecondsRemaining > 1) {
          _estimatedSecondsRemaining--;
        }
        if (_generationProgress < 0.90) {
          _generationProgress += 0.08;
        }
      });
    });

    try {
      final quiz = await _quizService.generateQuiz(
        sourceText: sourceText,
        subjectTitle: subjectTitle,
        unitOrSourceTitle: unitTitle,
        questionCount: _selectedQuestionCount,
        difficulty: _selectedDifficulty,
        instantMode: instant,
        onStatusUpdate: (status) {
          if (mounted) setState(() => _generationStatus = status);
        },
        onProgressUpdate: (progress, status, estSec) {
          if (mounted) {
            setState(() {
              _generationProgress = progress;
              _generationStatus = status;
              _estimatedSecondsRemaining = estSec;
            });
          }
        },
      );

      _countdownTimer?.cancel();
      if (mounted) {
        setState(() {
          _activeQuiz = quiz;
          _currentQuestionIndex = 0;
          _isQuizSubmitted = false;
          _isGeneratingQuiz = false;
          _generationProgress = 1.0;
        });
      }
    } catch (e) {
      _countdownTimer?.cancel();
      if (mounted) {
        setState(() => _isGeneratingQuiz = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate quiz: $e')),
        );
      }
    }
  }

  // ===========================================================================
  // UI BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _activeQuiz == null ? 'AI Quiz Generator' : _activeQuiz!.title,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_activeQuiz != null)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Exit Quiz',
              onPressed: () {
                setState(() {
                  _activeQuiz = null;
                  _isQuizSubmitted = false;
                });
              },
            ),
        ],
      ),
      body: _activeQuiz == null ? _buildCreationView() : _buildQuizTakerView(),
    );
  }

  Widget _buildCreationView() {
    return Column(
      children: [
        // Tab Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.8),
          ),
          child: TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            indicator: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withAlpha(80),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              Tab(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.upload_file_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'From Notes',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Tab(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.forum_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'From Chat / Doubts',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFromNotesTab(),
              _buildFromChatTab(),
            ],
          ),
        ),

        // Bottom Configuration & Generate Bar
        _buildConfigAndGenerateBar(),
      ],
    );
  }

  Widget _buildFromNotesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Study Notes or Material',
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload a PDF, text document, or photos of your handwritten notes.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildUploadCard(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'PDF / Text',
                  subtitle: '.pdf or .txt file',
                  color: const Color(0xFFFF7675),
                  onTap: _pickPdfOrTxtFile,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUploadCard(
                  icon: Icons.photo_library_rounded,
                  title: 'Note Images',
                  subtitle: 'Single or Multi-page',
                  color: const Color(0xFF00CEC9),
                  onTap: _pickImages,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Uploaded File Status
          if (_isExtractingFile)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondaryAccent),
                  ),
                  const SizedBox(width: 12),
                  Text('Extracting text from notes...', style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
                ],
              ),
            )
          else if (_uploadedFileName != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accentGreen.withAlpha(100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _uploadedFileName!,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${_extractedNotesText.length} chars',
                        style: GoogleFonts.firaCode(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryAccent.withAlpha(35),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.secondaryAccent.withAlpha(80), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.secondaryAccent),
                            const SizedBox(width: 4),
                            Text(
                              _detectSubjectTitle(_extractedNotesText, _uploadedFileName),
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryAccent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getPreviewSnippet(_extractedNotesText),
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(90), width: 1.2),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getSubjectIcon(String iconCode) {
    switch (iconCode) {
      case 'science': return Icons.science_rounded;
      case 'biotech': return Icons.biotech_rounded;
      case 'functions': return Icons.functions_rounded;
      case 'account_tree': return Icons.account_tree_rounded;
      case 'code': return Icons.terminal_rounded;
      case 'psychology': return Icons.psychology_rounded;
      default: return Icons.menu_book_rounded;
    }
  }

  Widget _buildFromChatTab() {
    final subjectProv = context.watch<SubjectProvider>();
    final chapterProv = context.watch<ChapterProvider>();
    final subjects = subjectProv.subjects;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Chat Source for Quiz',
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'The AI will read the complete discussion history to create personalized test questions.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // 1. GENERAL DOUBT CHAT OPTION CARD
          InkWell(
            onTap: _selectGeneralDoubt,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isGeneralDoubtSelected ? const Color(0xFF1E1E34) : AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isGeneralDoubtSelected ? AppColors.secondaryAccent : AppColors.border,
                  width: _isGeneralDoubtSelected ? 1.8 : 1.0,
                ),
                boxShadow: [
                  if (_isGeneralDoubtSelected)
                    BoxShadow(
                      color: AppColors.secondaryAccent.withAlpha(50),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'General Doubt Mode',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryAccent.withAlpha(35),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Universal AI',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondaryAccent),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$_generalDoubtMsgCount msgs',
                                style: GoogleFonts.firaCode(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Generate quiz from your Universal AI Doubt conversations',
                          style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isGeneralDoubtSelected ? AppColors.secondaryAccent : AppColors.border,
                        width: 2,
                      ),
                      color: _isGeneralDoubtSelected ? AppColors.secondaryAccent : Colors.transparent,
                    ),
                    child: _isGeneralDoubtSelected
                        ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                        : null,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 2. OR SELECT FROM COURSE SUBJECTS
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.border, thickness: 0.8)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'OR COURSE SUBJECTS',
                  style: GoogleFonts.firaCode(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                ),
              ),
              const Expanded(child: Divider(color: AppColors.border, thickness: 0.8)),
            ],
          ),

          const SizedBox(height: 14),

          // Horizontal Subject Cards Carousel
          Text(
            'Select Course Subject:',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),

          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: subjects.length,
              separatorBuilder: (_, index) => const SizedBox(width: 12),
              itemBuilder: (ctx, index) {
                final s = subjects[index];
                final isSelected = !_isGeneralDoubtSelected && _selectedSubjectId == s.id;
                final subChapters = chapterProv.getChaptersForSubject(s.id);
                final color = Color(s.colorValue);

                return InkWell(
                  onTap: () => _selectSubject(s.id),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withAlpha(35) : AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: color.withAlpha(60),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: color.withAlpha(40),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_getSubjectIcon(s.iconCode), color: color, size: 20),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                s.code,
                                style: GoogleFonts.firaCode(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          s.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          '${subChapters.length} Unit(s)',
                          style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 18),

          // 3. UNIT / CHAPTER SELECTOR
          if (!_isGeneralDoubtSelected && _selectedSubjectId != null) ...[
            Text(
              'Select Unit / Chapter:',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),

            Builder(
              builder: (ctx) {
                final chapters = chapterProv.getChaptersForSubject(_selectedSubjectId!);
                if (chapters.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No units added for this subject yet.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                    ),
                  );
                }

                return Column(
                  children: chapters.map((c) {
                    final isSelected = _selectedChapterId == c.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _onChapterSelected(c.id),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryAccent.withAlpha(35) : AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.secondaryAccent : AppColors.border,
                              width: isSelected ? 1.6 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.secondaryAccent : AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${chapters.indexOf(c) + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isSelected ? Colors.black : Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  c.title,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: AppColors.secondaryAccent, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],

          const SizedBox(height: 16),

          // 4. LOADED CHAT STATUS PREVIEW
          if (_isLoadingChat)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_selectedChapterId != null) ...[
            if (_chatMessageCount > 0)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accentGreen.withAlpha(120), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: AppColors.accentGreen, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_chatMessageCount Messages Loaded',
                            style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'AI is ready to generate quiz from your discussion history.',
                            style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.warning.withAlpha(120), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No Messages in This Chat Yet',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Chat with the tutor in this room first, or generate a quiz from notes instead!',
                            style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfigAndGenerateBar() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selectors
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Count
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Questions:', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Row(
                    children: [3, 5, 10].map((c) {
                      final isSel = _selectedQuestionCount == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('$c'),
                          selected: isSel,
                          onSelected: (_) => setState(() => _selectedQuestionCount = c),
                          selectedColor: AppColors.primaryAccent,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSel ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // Difficulty
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Difficulty:', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Row(
                    children: ['Easy', 'Medium', 'Hard'].map((d) {
                      final isSel = _selectedDifficulty == d;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(d),
                          selected: isSel,
                          onSelected: (_) => setState(() => _selectedDifficulty = d),
                          selectedColor: AppColors.secondaryAccent,
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isSel ? Colors.black : AppColors.textSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_isGeneratingQuiz)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.secondaryAccent.withAlpha(120), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondaryAccent.withAlpha(30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.secondaryAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _generationStatus.isNotEmpty ? _generationStatus : 'Generating Real-time Quiz',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryAccent.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.secondaryAccent.withAlpha(80), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 12, color: AppColors.secondaryAccent),
                            const SizedBox(width: 3),
                            Text(
                              '${_estimatedSecondsRemaining}s',
                              style: GoogleFonts.firaCode(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondaryAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _generationProgress.clamp(0.05, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondaryAccent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Analyzing concepts & options',
                        style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                      Text(
                        '${(_generationProgress.clamp(0.0, 1.0) * 100).toInt()}%',
                        style: GoogleFonts.firaCode(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondaryAccent,
                        side: const BorderSide(color: AppColors.secondaryAccent, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _generateQuiz(instant: true),
                      icon: const Icon(Icons.flash_on_rounded, size: 16),
                      label: Text(
                        'Finish Instantly Real-time (⚡ <1s)',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00B894), Color(0xFF00CEC9)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00B894).withAlpha(100),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _generateQuiz(instant: true),
                      icon: const Icon(Icons.flash_on_rounded, size: 20, color: Colors.black),
                      label: Text(
                        '⚡ Real-time Quiz',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryAccent.withAlpha(90),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _generateQuiz(instant: false),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(
                        '🪄 AI Deep Quiz',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // INTERACTIVE QUIZ TAKER UI
  // ===========================================================================

  Widget _buildQuizTakerView() {
    if (_isQuizSubmitted) {
      return _buildScoreSummaryView();
    }

    final quiz = _activeQuiz!;
    final question = quiz.questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / quiz.totalQuestions;

    return Column(
      children: [
        // Progress Bar
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.surfaceCard,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondaryAccent),
          minHeight: 6,
        ),

        // Indicator Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} of ${quiz.totalQuestions}',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedDifficulty,
                  style: GoogleFonts.firaCode(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.secondaryAccent),
                ),
              ),
            ],
          ),
        ),

        // Question Card
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border, width: 0.8),
                  ),
                  child: Text(
                    question.question,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // 4 Option Cards
                ...List.generate(question.options.length, (optIdx) {
                  final isSelected = question.userSelectedIndex == optIdx;
                  final optionLetters = ['A', 'B', 'C', 'D'];
                  final letter = optIdx < optionLetters.length ? optionLetters[optIdx] : '$optIdx';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setState(() {
                            question.userSelectedIndex = optIdx;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryAccent.withAlpha(40) : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppColors.secondaryAccent : AppColors.border,
                              width: isSelected ? 1.5 : 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.secondaryAccent : AppColors.surfaceCard,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  letter,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.black : Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  question.options[optIdx],
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Navigation controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
          ),
          child: Row(
            children: [
              if (_currentQuestionIndex > 0)
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _currentQuestionIndex--);
                  },
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Back'),
                )
              else
                const SizedBox(width: 80),

              const Spacer(),

              if (_currentQuestionIndex < quiz.totalQuestions - 1)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() => _currentQuestionIndex++);
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Next'),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() => _isQuizSubmitted = true);
                  },
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: Text('Submit Quiz', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SCORE SUMMARY & REVIEW VIEW
  // ===========================================================================

  Widget _buildScoreSummaryView() {
    final quiz = _activeQuiz!;
    final score = quiz.score;
    final total = quiz.totalQuestions;
    final pct = quiz.percentage.round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Score Celebration Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E2438), Color(0xFF141724)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.secondaryAccent.withAlpha(120), width: 1.5),
            ),
            child: Column(
              children: [
                Text(
                  pct >= 80 ? '🎉 Outstanding!' : (pct >= 50 ? '👍 Good Job!' : '📚 Keep Practicing!'),
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  '$score / $total',
                  style: GoogleFonts.poppins(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.secondaryAccent),
                ),
                Text(
                  '$pct% Score',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceCard,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          for (final q in quiz.questions) {
                            q.userSelectedIndex = null;
                          }
                          _currentQuestionIndex = 0;
                          _isQuizSubmitted = false;
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retake'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _activeQuiz = null;
                          _isQuizSubmitted = false;
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('New Quiz'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Detailed Review Title
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Detailed Question Review:',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),

          const SizedBox(height: 12),

          // All Questions Review
          ...quiz.questions.asMap().entries.map((entry) {
            final idx = entry.key;
            final q = entry.value;
            final isCorrect = q.isCorrect;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCorrect ? AppColors.accentGreen.withAlpha(120) : AppColors.error.withAlpha(120),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: isCorrect ? AppColors.accentGreen : AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Question ${idx + 1}',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    q.question,
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your Answer: ${q.userSelectedIndex != null ? q.options[q.userSelectedIndex!] : "Unanswered"}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isCorrect ? AppColors.accentGreen : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isCorrect)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Correct Answer: ${q.options[q.answerIndex]}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.accentGreen, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Explanation: ${q.explanation}',
                      style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
