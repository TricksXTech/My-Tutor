import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/llm_service.dart';
import '../../providers/subject_provider.dart';
import '../../providers/chapter_provider.dart';
import '../widgets/subject_card.dart';
import '../widgets/add_subject_dialog.dart';
import 'subject_detail_screen.dart';
import 'chat_room_screen.dart';
import 'settings_screen.dart';
import 'code_runner_screen.dart';
import 'quiz_screen.dart';
import 'rubiks_cube_screen.dart';
import 'legal/terms_acceptance_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LlmService _llmService = LlmService();
  bool _isModelInstalled = false;

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TermsAcceptanceDialog.checkAndShow(context);
    });
  }

  Future<void> _checkModelStatus() async {
    final ready = await _llmService.isAnyModelReady();
    if (mounted) {
      setState(() {
        _isModelInstalled = ready;
      });
    }
  }

  void _openGeneralDoubtMode(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ChatRoomScreen(
          chapterId: AppConstants.generalDoubtChapterId,
          subjectTitle: 'General Doubt Mode',
          chapterTitle: 'Universal CSE Tutor',
          accentColor: AppColors.secondaryAccent,
        ),
      ),
    );
  }

  Future<void> _handleQuizTap() async {
    final ready = await _llmService.isAnyModelReady();
    if (!mounted) return;

    if (!ready) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF141724),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.download_for_offline_rounded, color: AppColors.warning, size: 24),
              SizedBox(width: 10),
              Text(
                'Download AI Model First',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'To generate personalized quizzes from your notes or chapter chats, please download the AI model first (Qwen 2.5 or Llama 3.2).',
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                }
              },
              child: const Text('Download Model'),
            ),
          ],
        ),
      );
      return;
    }

    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizScreen()));
    }
  }

  void _handleCubeTap() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RubiksCubeScreen()));
  }

  void _onAddSubjectPressed(BuildContext context, SubjectProvider subjectProv) {
    if (!subjectProv.canAddSubject) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppConstants.maxLimitWarning,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.surfaceElevated,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AddSubjectDialog(
        onAdd: ({
          required title,
          required code,
          required description,
          required colorValue,
          required iconCode,
        }) async {
          return await subjectProv.addSubject(
            title: title,
            code: code,
            description: description,
            colorValue: colorValue,
            iconCode: iconCode,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subjectProv = context.watch<SubjectProvider>();
    final chapterProv = context.watch<ChapterProvider>();
    final count = subjectProv.currentCount;
    final maxLimit = subjectProv.maxLimit;
    final isLimitReached = !subjectProv.canAddSubject;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(
          children: [
            // App Logo
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryAccent.withAlpha(120), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryAccent.withAlpha(80),
                    blurRadius: 10,
                  ),
                ],
                image: const DecorationImage(
                  image: AssetImage('assets/images/app_logo.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.appName,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'B.Tech Voice Tutor',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.secondaryAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // GENERAL DOUBT MODE BUTTON (On App Bar)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openGeneralDoubtMode(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00CEC9), Color(0xFF6C5CE7)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondaryAccent.withAlpha(80),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        'General Doubt',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Settings Button
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            tooltip: 'Tutor & Model Settings',
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SettingsScreen()))
                  .then((_) => _checkModelStatus());
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // FALLBACK BANNER IF NO MODEL DETECTED
          if (!_isModelInstalled)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const SettingsScreen()))
                          .then((_) => _checkModelStatus());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.accentOrange.withAlpha(25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accentOrange.withAlpha(120),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accentOrange.withAlpha(40),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_download_rounded,
                              color: AppColors.accentOrange,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI Model not installed.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap here to download (1.1 GB) for 100% offline usage.',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: AppColors.accentYellow,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppColors.accentOrange,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Hero Banner & Limit Status Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border, width: 1.2),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF222238), Color(0xFF191928)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(100),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accentGreen.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.accentGreen.withAlpha(100)),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.wifi_off_rounded, size: 12, color: AppColors.accentGreen),
                                  SizedBox(width: 4),
                                  Text(
                                    '100% OFFLINE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accentGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryAccent.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primaryAccent.withAlpha(100)),
                              ),
                              child: const Text(
                                'HINGLISH PROFESSOR',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Subjects Limit Badge (e.g. 5/7)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isLimitReached
                                ? AppColors.warning.withAlpha(30)
                                : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isLimitReached ? AppColors.warning : AppColors.border,
                            ),
                          ),
                          child: Text(
                            '$count / $maxLimit Subjects',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isLimitReached ? AppColors.warning : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Pareshaan mat ho, har concept samjhenge!',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Physics, Chemistry, Engineering Maths aur C/Python logic line-by-line bolo aur suno.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // CODE RUNNER OPTION (Positioned directly above "Your Semester Subjects + Add Subject")
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CodeRunnerScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.surfaceElevated,
                          AppColors.surfaceCard,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.secondaryAccent.withAlpha(120),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondaryAccent.withAlpha(20),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.terminal_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Runner',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.accentGreen.withAlpha(30),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.accentGreen.withAlpha(100), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.play_circle_fill_rounded, size: 11, color: AppColors.accentGreen),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Execute on Device',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accentGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Write, paste & run code: Python, C, C++, Java, JS, C# & more',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildLanguageBadge('🐍 Python'),
                            _buildLanguageBadge('⚡ C'),
                            _buildLanguageBadge('🚀 C++'),
                            _buildLanguageBadge('☕ Java'),
                            _buildLanguageBadge('💛 JS'),
                            _buildLanguageBadge('🔷 C#'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Section Title & Add Subject Action
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Semester Subjects',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  // ADD SUBJECT BUTTON (Disables or triggers warning snackbar if limit 7 reached)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _onAddSubjectPressed(context, subjectProv),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isLimitReached
                              ? AppColors.surfaceElevated
                              : AppColors.primaryAccent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isLimitReached ? AppColors.border : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isLimitReached ? Icons.block_rounded : Icons.add_rounded,
                              size: 16,
                              color: isLimitReached ? AppColors.textMuted : Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isLimitReached ? 'Limit Reached' : 'Add Subject',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isLimitReached ? AppColors.textMuted : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Subjects Grid / List
          if (subjectProv.subjects.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school_outlined, size: 54, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'No Subjects Added Yet',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap "Add Subject" above to create your first course.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.88,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final subject = subjectProv.subjects[index];
                    final chapters = chapterProv.getChaptersForSubject(subject.id);

                    return SubjectCard(
                      subject: subject,
                      chapterCount: chapters.length,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SubjectDetailScreen(subject: subject),
                          ),
                        );
                      },
                      onDelete: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Subject?'),
                            content: Text(
                              'Are you sure you want to remove "${subject.title}" and its chapters?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await subjectProv.deleteSubject(subject.id);
                        }
                      },
                    );
                  },
                  childCount: subjectProv.subjects.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Quiz Button
            _buildQuizFab(context),
            // Right: Cube Icon Button
            _buildCubeFab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizFab(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withAlpha(120),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: _handleQuizTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.assignment_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Quiz 📝',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCubeFab(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7675), Color(0xFFFD79A8)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7675).withAlpha(120),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _handleCubeTap,
          child: const Center(
            child: Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Text(
        text,
        style: GoogleFonts.firaCode(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
