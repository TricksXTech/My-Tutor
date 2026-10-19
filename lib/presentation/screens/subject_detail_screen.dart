import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/subject_model.dart';
import '../../providers/chapter_provider.dart';
import '../widgets/chapter_tile.dart';
import '../widgets/add_chapter_dialog.dart';
import 'chat_room_screen.dart';

class SubjectDetailScreen extends StatelessWidget {
  final SubjectModel subject;

  const SubjectDetailScreen({super.key, required this.subject});

  void _showAddChapterDialog(BuildContext context, ChapterProvider chapterProv) {
    final existingChapters = chapterProv.getChaptersForSubject(subject.id);
    showDialog(
      context: context,
      builder: (_) => AddChapterDialog(
        nextUnitIndex: existingChapters.length + 1,
        onAdd: ({
          required title,
          required unitNumber,
          required description,
        }) async {
          await chapterProv.addChapter(
            subjectId: subject.id,
            title: title,
            unitNumber: unitNumber,
            description: description,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapterProv = context.watch<ChapterProvider>();
    final chapters = chapterProv.getChaptersForSubject(subject.id);
    final accentColor = Color(subject.colorValue);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          subject.title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withAlpha(100)),
            ),
            child: Text(
              subject.code,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Course Header Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(80),
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.school_rounded, color: accentColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            subject.title,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subject.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        subject.description,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${chapters.length} ${chapters.length == 1 ? 'Unit' : 'Units'} Added',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.record_voice_over_rounded,
                                size: 14, color: AppColors.secondaryAccent),
                            const SizedBox(width: 5),
                            Text(
                              'Voice Tutoring Active',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondaryAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Section Title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Text(
                'Syllabus Units & Voice Rooms',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),

          // Chapters List
          if (chapters.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.post_add_rounded, size: 50, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'No Units Added Yet',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap (+) below to add your first chapter or unit.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final chapter = chapters[index];
                    return ChapterTile(
                      chapter: chapter,
                      accentColor: accentColor,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatRoomScreen(
                              chapterId: chapter.id,
                              subjectTitle: subject.title,
                              chapterTitle: '${chapter.unitNumber}: ${chapter.title}',
                              accentColor: accentColor,
                            ),
                          ),
                        );
                      },
                      onDelete: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Unit?'),
                            content: Text(
                              'Remove "${chapter.title}" and its chat history?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await chapterProv.deleteChapter(chapter.id);
                        }
                      },
                    );
                  },
                  childCount: chapters.length,
                ),
              ),
            ),
        ],
      ),
      // FLOATING ACTION BUTTON (+) to open dialog to add new Chapter/Unit names
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accentColor,
        onPressed: () => _showAddChapterDialog(context, chapterProv),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Add Unit',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
