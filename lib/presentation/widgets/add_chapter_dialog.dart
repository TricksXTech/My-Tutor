import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class AddChapterDialog extends StatefulWidget {
  final int nextUnitIndex;
  final Function({
    required String title,
    required String unitNumber,
    required String description,
  }) onAdd;

  const AddChapterDialog({
    super.key,
    required this.nextUnitIndex,
    required this.onAdd,
  });

  @override
  State<AddChapterDialog> createState() => _AddChapterDialogState();
}

class _AddChapterDialogState extends State<AddChapterDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _unitController;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _unitController =
        TextEditingController(text: 'Unit ${widget.nextUnitIndex}');
  }

  @override
  void dispose() {
    _unitController.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onAdd(
      title: _titleController.text.trim(),
      unitNumber: _unitController.text.trim(),
      description: _descController.text.trim(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAccent.withAlpha(35),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.post_add_rounded,
                      color: AppColors.primaryLight,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Chapter / Unit',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _unitController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Unit / Module Tag',
                  hintText: 'e.g. Unit 3 or Module 2',
                  prefixIcon: Icon(Icons.layers_rounded, size: 20),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter unit number' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Chapter Name *',
                  hintText: 'e.g. Binary Search Trees & AVL',
                  prefixIcon: Icon(Icons.bookmark_border_rounded, size: 20),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter chapter title' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descController,
                maxLines: 2,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Key Topics / Description',
                  hintText: 'e.g. Rotations, Traversal, Complexity',
                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 22),
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
                    onPressed: _submit,
                    child: const Text('Add Chapter'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
