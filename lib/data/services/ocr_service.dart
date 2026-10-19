import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// 100% On-Device Offline Text Recognition (OCR) Service
/// Allows students to take a photo of textbook questions, handwritten formulas,
/// or problem sheets and instantly extract text without internet!
class OcrService {
  static final ImagePicker _picker = ImagePicker();

  /// Captures a photo from the camera and performs offline text recognition
  static Future<OcrResult?> scanFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (photo == null) return null;
      return await recognizeTextFromFile(photo.path);
    } catch (e) {
      debugPrint('Error capturing photo from camera: $e');
      rethrow;
    }
  }

  /// Picks an image from the gallery and performs offline text recognition
  static Future<OcrResult?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null) return null;
      return await recognizeTextFromFile(image.path);
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      rethrow;
    }
  }

  /// Extracts text from a local image file using ML Kit's local on-device neural model
  static Future<OcrResult> recognizeTextFromFile(String filePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final RecognizedText recognized = await textRecognizer.processImage(inputImage);

      final buffer = StringBuffer();
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
        buffer.writeln(); // paragraph break between blocks
      }

      final extracted = buffer.toString().trim();
      return OcrResult(
        imagePath: filePath,
        extractedText: extracted,
        hasText: extracted.isNotEmpty,
      );
    } catch (e) {
      debugPrint('OCR Recognition error: $e');
      return OcrResult(
        imagePath: filePath,
        extractedText: '',
        hasText: false,
        error: e.toString(),
      );
    } finally {
      await textRecognizer.close();
    }
  }
}

class OcrResult {
  final String imagePath;
  final String extractedText;
  final bool hasText;
  final String? error;

  OcrResult({
    required this.imagePath,
    required this.extractedText,
    required this.hasText,
    this.error,
  });
}
