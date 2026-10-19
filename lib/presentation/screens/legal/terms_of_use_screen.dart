import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../legal/terms_of_use.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimary : Colors.black87;
    final textMuted = isDark ? AppColors.textSecondary : Colors.black54;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Terms of Use',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Markdown(
          data: TermsOfUseText.content,
          selectable: true,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          styleSheet: MarkdownStyleSheet(
            h1: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
            h2: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            h3: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryLight,
            ),
            p: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.55,
              color: textColor,
            ),
            listBullet: GoogleFonts.inter(
              fontSize: 13.5,
              color: AppColors.secondaryAccent,
            ),
            strong: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            em: GoogleFonts.inter(
              fontStyle: FontStyle.italic,
              color: textMuted,
            ),
            horizontalRuleDecoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.border : Colors.black12,
                  width: 1,
                ),
              ),
            ),
            blockquote: GoogleFonts.inter(
              fontSize: 13,
              color: textMuted,
            ),
            blockquoteDecoration: BoxDecoration(
              color: isDark ? AppColors.surfaceElevated : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: const Border(
                left: BorderSide(color: AppColors.primaryAccent, width: 3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
