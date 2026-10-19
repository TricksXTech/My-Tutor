import 'dart:math' as math;
import '../models/saved_document_model.dart';
import 'document_chunker.dart';

/// Pure Dart Okapi BM25 implementation for on-device document chunk retrieval.
/// 100% offline, zero external dependencies.
class BM25Retriever {
  BM25Retriever._();

  static const double k1 = 1.2;
  static const double b = 0.75;

  static const Set<String> _stopWords = {
    'a', 'about', 'above', 'after', 'again', 'against', 'all', 'am', 'an', 'and',
    'any', 'are', 'aren\'t', 'as', 'at', 'be', 'because', 'been', 'before', 'being',
    'below', 'between', 'both', 'but', 'by', 'can', 'can\'t', 'cannot', 'could',
    'couldn\'t', 'did', 'didn\'t', 'do', 'does', 'doesn\'t', 'doing', 'don\'t', 'down',
    'during', 'each', 'few', 'for', 'from', 'further', 'had', 'hadn\'t', 'has', 'hasn\'t',
    'have', 'haven\'t', 'having', 'he', 'he\'d', 'he\'ll', 'he\'s', 'her', 'here',
    'here\'s', 'hers', 'herself', 'him', 'himself', 'his', 'how', 'how\'s', 'i', 'i\'d',
    'i\'ll', 'i\'m', 'i\'ve', 'if', 'in', 'into', 'is', 'isn\'t', 'it', 'it\'s', 'its',
    'itself', 'let\'s', 'me', 'more', 'most', 'mustn\'t', 'my', 'myself', 'no', 'nor',
    'not', 'of', 'off', 'on', 'once', 'only', 'or', 'other', 'ought', 'our', 'ours',
    'ourselves', 'out', 'over', 'own', 'same', 'shan\'t', 'she', 'she\'d', 'she\'ll',
    'she\'s', 'should', 'shouldn\'t', 'so', 'some', 'such', 'than', 'that', 'that\'s',
    'the', 'their', 'theirs', 'them', 'themselves', 'then', 'there', 'there\'s', 'these',
    'they', 'they\'d', 'they\'ll', 'they\'re', 'they\'ve', 'this', 'those', 'through',
    'to', 'too', 'under', 'until', 'up', 'very', 'was', 'wasn\'t', 'we', 'we\'d',
    'we\'ll', 'we\'re', 'we\'ve', 'were', 'weren\'t', 'what', 'what\'s', 'when',
    'when\'s', 'where', 'where\'s', 'which', 'while', 'who', 'who\'s', 'whom', 'why',
    'why\'s', 'with', 'won\'t', 'would', 'wouldn\'t', 'you', 'you\'d', 'you\'ll',
    'you\'re', 'you\'ve', 'your', 'yours', 'yourself', 'yourselves',
    // Common conversational & Hinglish fillers
    'kya', 'hai', 'h', 'ka', 'ki', 'ke', 'ko', 'se', 'mein', 'bhi', 'toh',
    'batao', 'bataiye', 'samjhao', 'explain', 'tell', 'show', 'please', 'give',
  };

  /// Tokenizes text into lowercase normalized terms, stripping punctuation.
  static List<String> tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_\-\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2 && !_stopWords.contains(t))
        .toList();
  }

  /// Retrieves the Top-K most relevant chunks from [doc] matching [query]
  /// constrained to fit within [maxTokens].
  static List<DocumentChunk> retrieveTopChunks({
    required SavedDocumentModel doc,
    required String query,
    int maxTokens = 1000,
  }) {
    final chunks = DocumentChunker.chunkDocument(doc);
    if (chunks.isEmpty) return [];
    if (chunks.length == 1) return chunks;

    return rankChunks(
      chunks: chunks,
      query: query,
      maxTokens: maxTokens,
    );
  }

  /// Ranks a list of [chunks] against [query] using Okapi BM25 and returns
  /// the highest-scoring chunks within [maxTokens], re-ordered in document order.
  static List<DocumentChunk> rankChunks({
    required List<DocumentChunk> chunks,
    required String query,
    int maxTokens = 1000,
  }) {
    if (chunks.isEmpty) return [];
    if (chunks.length <= 1) return chunks;

    final queryTerms = tokenize(query);

    // If query has no significant search terms (e.g. "explain", empty, generic),
    // return the initial overview chunks in sequential order up to maxTokens.
    if (queryTerms.isEmpty) {
      return _selectSequentialChunks(chunks, maxTokens);
    }

    // 1. Calculate Term Frequencies for each chunk
    final chunkTermFreqs = <Map<String, int>>[];
    final chunkLengths = <int>[];
    int totalWords = 0;

    for (final chunk in chunks) {
      final terms = tokenize(chunk.text);
      final freqMap = <String, int>{};
      for (final t in terms) {
        freqMap[t] = (freqMap[t] ?? 0) + 1;
      }
      chunkTermFreqs.add(freqMap);
      chunkLengths.add(terms.length);
      totalWords += terms.length;
    }

    final int nChunks = chunks.length;
    final double avgdl = totalWords / (nChunks > 0 ? nChunks : 1);

    // 2. Calculate Document Frequency (DF) for each query term
    final docFreq = <String, int>{};
    for (final q in queryTerms) {
      int count = 0;
      for (final tfMap in chunkTermFreqs) {
        if (tfMap.containsKey(q)) {
          count++;
        }
      }
      docFreq[q] = count;
    }

    // 3. Compute BM25 Score for each chunk
    final scoredChunks = <MapEntry<DocumentChunk, double>>[];

    for (int i = 0; i < nChunks; i++) {
      final chunk = chunks[i];
      final tfMap = chunkTermFreqs[i];
      final docLen = chunkLengths[i];
      double score = 0.0;

      for (final q in queryTerms) {
        final df = docFreq[q] ?? 0;
        final tf = tfMap[q] ?? 0;

        if (tf > 0) {
          // Standard Okapi BM25 IDF
          final idf = math.log(1.0 + (nChunks - df + 0.5) / (df + 0.5));
          final numerator = tf * (k1 + 1.0);
          final denominator = tf + k1 * (1.0 - b + b * (docLen / (avgdl > 0 ? avgdl : 1.0)));
          score += idf * (numerator / denominator);
        }
      }

      // Bonus boost for exact substring matches of technical IDs (e.g., 2N2222, PIR, circuit)
      final lowerText = chunk.text.toLowerCase();
      final lowerQ = query.toLowerCase();
      for (final q in queryTerms) {
        if (q.length >= 4 && lowerText.contains(q)) {
          score += 1.5;
        }
      }
      // Boost chunk 0 slightly for general topic match
      if (i == 0 && score > 0) {
        score += 0.5;
      }

      // Special section intent boosting (e.g., "viva", "step 2", "working principle")
      if (lowerQ.contains('viva') && (lowerText.contains('viva') || lowerText.contains('questions'))) {
        score += 3.0;
      }
      if ((lowerQ.contains('working') || lowerQ.contains('principle')) &&
          (lowerText.contains('working principle') || lowerText.contains('theory'))) {
        score += 3.0;
      }
      if ((lowerQ.contains('circuit') || lowerQ.contains('pin')) &&
          (lowerText.contains('circuit') || lowerText.contains('connection'))) {
        score += 3.0;
      }

      scoredChunks.add(MapEntry(chunk, score));
    }

    // 4. Sort by BM25 Score descending
    scoredChunks.sort((a, b) => b.value.compareTo(a.value));

    // If no chunk scored positively, fall back to initial overview chunks
    if (scoredChunks.first.value <= 0.0) {
      return _selectSequentialChunks(chunks, maxTokens);
    }

    // 5. Select Top-K chunks within token budget
    final selected = <DocumentChunk>[];
    int tokenAccum = 0;

    for (final entry in scoredChunks) {
      if (entry.value <= 0.0 && selected.isNotEmpty) break;
      final chunkTokens = entry.key.tokenCountEstimate;
      if (tokenAccum + chunkTokens <= maxTokens || selected.isEmpty) {
        selected.add(entry.key);
        tokenAccum += chunkTokens;
      }
      if (selected.length >= 3) break; // Limit to Top 3 most relevant chunks
    }

    // 6. Re-order selected chunks by natural document order (chunkIndex)
    selected.sort((a, b) => a.chunkIndex.compareTo(b.chunkIndex));
    return selected;
  }

  /// Fallback: selects sequential chunks from the start of the document up to [maxTokens]
  static List<DocumentChunk> _selectSequentialChunks(List<DocumentChunk> chunks, int maxTokens) {
    final result = <DocumentChunk>[];
    int tokenAccum = 0;
    for (final chunk in chunks) {
      final chunkTokens = chunk.tokenCountEstimate;
      if (tokenAccum + chunkTokens <= maxTokens || result.isEmpty) {
        result.add(chunk);
        tokenAccum += chunkTokens;
      } else {
        break;
      }
      if (result.length >= 3) break;
    }
    return result;
  }
}
