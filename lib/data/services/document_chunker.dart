import '../models/saved_document_model.dart';

/// Represents a single indexed chunk of an attached document.
class DocumentChunk {
  final String documentId;
  final String fileName;
  final int chunkIndex;
  final int totalChunks;
  final String text;
  final int characterCount;

  DocumentChunk({
    required this.documentId,
    required this.fileName,
    required this.chunkIndex,
    required this.totalChunks,
    required this.text,
  }) : characterCount = text.length;

  /// Approximate token count: ~4 characters per token
  int get tokenCountEstimate => (characterCount / 4).ceil();

  @override
  String toString() => 'DocumentChunk(doc: $fileName, idx: $chunkIndex/$totalChunks, chars: $characterCount)';
}

/// Splits documents into overlapping segments of ~300-500 tokens (1200-1800 chars)
/// respecting natural paragraph, sentence, and word boundaries.
class DocumentChunker {
  DocumentChunker._();

  /// Default chunk size in characters (~350 tokens)
  static const int defaultChunkSizeChars = 1400;

  /// Default overlap between consecutive chunks (~50 tokens)
  static const int defaultOverlapChars = 200;

  /// Splits [doc]'s extracted text into clean, boundary-aware chunks.
  static List<DocumentChunk> chunkDocument(
    SavedDocumentModel doc, {
    int chunkSizeChars = defaultChunkSizeChars,
    int overlapChars = defaultOverlapChars,
  }) {
    return chunkText(
      text: doc.extractedText,
      documentId: doc.id,
      fileName: doc.fileName,
      chunkSizeChars: chunkSizeChars,
      overlapChars: overlapChars,
    );
  }

  /// Splits arbitrary [text] into boundary-aware chunks.
  static List<DocumentChunk> chunkText({
    required String text,
    required String documentId,
    required String fileName,
    int chunkSizeChars = defaultChunkSizeChars,
    int overlapChars = defaultOverlapChars,
  }) {
    final clean = text.trim();
    if (clean.isEmpty) return [];

    // If text fits in a single chunk, return immediately
    if (clean.length <= chunkSizeChars) {
      return [
        DocumentChunk(
          documentId: documentId,
          fileName: fileName,
          chunkIndex: 0,
          totalChunks: 1,
          text: clean,
        ),
      ];
    }

    final rawChunks = <String>[];
    int start = 0;

    while (start < clean.length) {
      int end = start + chunkSizeChars;
      if (end >= clean.length) {
        final lastSegment = clean.substring(start).trim();
        if (lastSegment.isNotEmpty) {
          rawChunks.add(lastSegment);
        }
        break;
      }

      // Look for a natural split point within the last 25% of the window
      final searchStart = start + (chunkSizeChars * 0.75).toInt();
      final window = clean.substring(searchStart, end);

      int splitOffset = -1;

      // 1. Double newline (paragraph break)
      final paraIdx = window.lastIndexOf('\n\n');
      if (paraIdx != -1) {
        splitOffset = searchStart + paraIdx + 2;
      }

      // 2. Sentence boundary (. / ! / ?)
      if (splitOffset == -1) {
        final match = RegExp(r'[.!?]\s').allMatches(window).toList();
        if (match.isNotEmpty) {
          splitOffset = searchStart + match.last.end;
        }
      }

      // 3. Single newline
      if (splitOffset == -1) {
        final newlineIdx = window.lastIndexOf('\n');
        if (newlineIdx != -1) {
          splitOffset = searchStart + newlineIdx + 1;
        }
      }

      // 4. Space / word boundary
      if (splitOffset == -1) {
        final spaceIdx = window.lastIndexOf(' ');
        if (spaceIdx != -1) {
          splitOffset = searchStart + spaceIdx + 1;
        }
      }

      // Fallback: Hard cut at end
      final effectiveEnd = (splitOffset != -1 && splitOffset > start) ? splitOffset : end;
      final segment = clean.substring(start, effectiveEnd).trim();
      if (segment.isNotEmpty) {
        rawChunks.add(segment);
      }

      // Advance with overlap
      final nextStart = effectiveEnd - overlapChars;
      start = nextStart > start ? nextStart : effectiveEnd;
    }

    final total = rawChunks.length;
    return List.generate(
      total,
      (i) => DocumentChunk(
        documentId: documentId,
        fileName: fileName,
        chunkIndex: i,
        totalChunks: total,
        text: rawChunks[i],
      ),
    );
  }
}
