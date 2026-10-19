import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import 'terms_of_use_screen.dart';
import 'privacy_policy_screen.dart';

class TermsAcceptanceDialog extends StatelessWidget {
  const TermsAcceptanceDialog({super.key});

  /// Checks if user has accepted the current terms version. If not, displays the dialog.
  static Future<void> checkAndShow(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final acceptedVersion = prefs.getString(AppConstants.keyAcceptedTermsVersion);

      if (acceptedVersion != AppConstants.termsVersion) {
        if (!context.mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const TermsAcceptanceDialog(),
        );
      }
    } catch (e) {
      debugPrint('Error checking terms acceptance: $e');
    }
  }

  Future<void> _handleAgree(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyAcceptedTermsVersion, AppConstants.termsVersion);
    } catch (e) {
      debugPrint('Error recording terms agreement: $e');
    }
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent dismissing without acknowledging
      child: Dialog(
        backgroundColor: const Color(0xFF1B1B2C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.primaryAccent, width: 1.2),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withAlpha(35),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryAccent, width: 1.5),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.secondaryAccent,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome to ${AppConstants.appName}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                AppConstants.appTagline,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.secondaryAccent,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Text(
                'Before you begin, please review and accept our Terms of Use and Privacy Policy. All AI tutor models run 100% on your device, and your chats remain strictly private on your phone.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_rounded, color: AppColors.primaryLight, size: 20),
                      title: Text(
                        'Terms of Use',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfUseScreen()));
                      },
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.privacy_tip_rounded, color: AppColors.secondaryAccent, size: 20),
                      title: Text(
                        'Privacy Policy',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  onPressed: () => _handleAgree(context),
                  child: Text(
                    'I Agree & Continue',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
