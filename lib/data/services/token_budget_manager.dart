/// Manages strict token budgeting across prompt components:
/// - Fixed: System Prompt + Latest User Query
/// - Dynamic: Attachments (BM25 retrieved chunks)
/// - Sliding: Conversation History (pruned from oldest turns when context budget fills)
/// - Reserved: Generation / output tokens (1024 tokens)
class TokenBudgetManager {
  TokenBudgetManager._();

  /// Default model context window limit (2048 for fast on-device inference on mobile)
  static const int defaultContextWindow = 2048;

  /// Default reserved tokens for model completion (512 tokens guarantees fast responses)
  static const int defaultReservedGenerationTokens = 512;

  /// Maximum tokens dedicated to retrieved document attachment chunks
  static const int maxAttachmentTokens = 600;

  /// Fast token estimation: ~4 characters per token
  static int estimateTokens(String text) {
    if (text.isEmpty) return 0;
    return (text.length / 4.0).ceil();
  }

  /// Calculates the token budget available for conversation history after accounting
  /// for system prompt, user query, attachments, and reserved generation tokens.
  static int calculateAvailableHistoryBudget({
    required String systemPrompt,
    required String userQuery,
    required int attachmentTokens,
    int contextWindow = defaultContextWindow,
    int reservedGeneration = defaultReservedGenerationTokens,
  }) {
    final promptBudget = contextWindow - reservedGeneration;
    final systemTokens = estimateTokens(systemPrompt);
    final queryTokens = estimateTokens(userQuery);
    final fixedTokens = systemTokens + queryTokens + attachmentTokens;

    final available = promptBudget - fixedTokens;
    // Keep at least 400 tokens for recent history if possible
    return available > 0 ? available : 400;
  }

  /// Prunes [history] from oldest to newest so total history tokens stay strictly
  /// within [maxTokens], preserving chronological order and valid turn pairs.
  static List<Map<String, String>> pruneHistory({
    required List<Map<String, String>> history,
    required int maxTokens,
  }) {
    if (history.isEmpty) return [];

    final result = <Map<String, String>>[];
    int accumulatedTokens = 0;

    // Walk backwards from most recent message towards older messages
    for (int i = history.length - 1; i >= 0; i--) {
      final turn = history[i];
      final content = turn['content'] ?? '';
      if (content.trim().isEmpty) continue;

      final turnTokens = estimateTokens(content);
      if (accumulatedTokens + turnTokens <= maxTokens || result.isEmpty) {
        result.add(turn);
        accumulatedTokens += turnTokens;
      } else {
        break; // Budget exhausted
      }
    }

    // Reverse back to chronological order (oldest to newest)
    final chronological = result.reversed.toList();

    // Ensure history starts cleanly on a user message if an assistant message is first
    if (chronological.isNotEmpty && chronological.first['role'] == 'assistant') {
      chronological.removeAt(0);
    }

    return chronological;
  }
}
