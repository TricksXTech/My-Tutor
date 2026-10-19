import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class AddSubjectDialog extends StatefulWidget {
  final Future<String?> Function({
    required String title,
    required String code,
    required String description,
    required int colorValue,
    required String iconCode,
  }) onAdd;

  const AddSubjectDialog({super.key, required this.onAdd});

  @override
  State<AddSubjectDialog> createState() => _AddSubjectDialogState();
}

class _AddSubjectDialogState extends State<AddSubjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _codeController = TextEditingController();
  final _descController = TextEditingController();

  int _selectedColor = 0xFF6C5CE7;
  String _selectedIcon = 'science';
  bool _isSubmitting = false;

  final List<int> _availableColors = [
    0xFF6C5CE7, // Indigo
    0xFF00CEC9, // Cyan
    0xFFFD79A8, // Pink
    0xFF00B894, // Emerald
    0xFFFDCB6E, // Amber
    0xFFE17055, // Coral
    0xFF0984E3, // Blue
  ];

  final List<Map<String, dynamic>> _availableIcons = [
    {'code': 'science', 'icon': Icons.science_rounded, 'name': 'Physics'},
    {'code': 'biotech', 'icon': Icons.biotech_rounded, 'name': 'Chemistry'},
    {'code': 'functions', 'icon': Icons.functions_rounded, 'name': 'Math'},
    {'code': 'account_tree', 'icon': Icons.account_tree_rounded, 'name': 'DSA'},
    {'code': 'code', 'icon': Icons.terminal_rounded, 'name': 'Coding'},
    {'code': 'psychology', 'icon': Icons.psychology_rounded, 'name': 'AI/ML'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _codeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final error = await widget.onAdd(
      title: _titleController.text,
      code: _codeController.text,
      description: _descController.text,
      colorValue: _selectedColor,
      iconCode: _selectedIcon,
    );
    setState(() => _isSubmitting = false);

    if (mounted) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(_selectedColor).withAlpha(35),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.library_add_rounded,
                        color: Color(_selectedColor),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Add New Subject',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Subject Title
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Subject Name *',
                    hintText: 'e.g. Discrete Mathematics',
                    prefixIcon: Icon(Icons.menu_book_rounded, size: 20),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter subject name' : null,
                ),

                const SizedBox(height: 14),

                // Subject Code
                TextFormField(
                  controller: _codeController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Subject Code',
                    hintText: 'e.g. CSE-204',
                    prefixIcon: Icon(Icons.tag_rounded, size: 20),
                  ),
                ),

                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Description / Topics',
                    hintText: 'e.g. Logic, Graph Theory, Combinatorics',
                    prefixIcon: Icon(Icons.description_outlined, size: 20),
                  ),
                ),

                const SizedBox(height: 18),

                // Icon Selection
                Text(
                  'Choose Icon',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableIcons.map((item) {
                    final isSelected = _selectedIcon == item['code'];
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedIcon = item['code']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryAccent.withAlpha(40)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryAccent
                                : AppColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item['icon'] as IconData,
                              size: 16,
                              color: isSelected
                                  ? AppColors.primaryLight
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              item['name'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected
                                    ? AppColors.primaryLight
                                    : AppColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                // Color Selection
                Text(
                  'Card Accent Color',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _availableColors.map((colorVal) {
                    final isSelected = _selectedColor == colorVal;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = colorVal),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Color(colorVal),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Color(colorVal).withAlpha(150),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 18, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(_selectedColor),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Add Subject'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
