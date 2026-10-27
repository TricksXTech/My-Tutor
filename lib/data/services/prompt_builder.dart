import '../models/saved_document_model.dart';
import 'bm25_retriever.dart';
import 'llm_service.dart';
import 'token_budget_manager.dart';

/// Single place responsible for constructing clean, role-isolated prompts
/// adhering to the model's canonical chat template (Gemma 4, Qwen 2.5, Llama 3.2).
/// Enforces Cause 10: 300-500 token chunking, Okapi BM25 retrieval, and strict token budgeting.
class PromptBuilder {
  PromptBuilder._();

  /// Builds a complete prompt string fresh each turn in the exact requested order:
  /// 1. Short, constant system prompt.
  /// 2. Labeled [ATTACHMENT] block (only if attachments are non-empty), retrieved via BM25.
  /// 3. Conversation history (user/assistant turns) pruned by TokenBudgetManager to fit context budget.
  /// 4. Latest user query.
  ///
  /// Never puts attachment text inside the system prompt or inside a user message body.
  static String buildPrompt({
    required String systemPrompt,
    required List<SavedDocumentModel> attachments,
    required List<Map<String, String>> conversationHistory,
    required String userQuery,
    required LlmMode mode,
    bool isGemma4 = true,
    int contextWindow = TokenBudgetManager.defaultContextWindow,
    int reservedGeneration = TokenBudgetManager.defaultReservedGenerationTokens,
  }) {
    // 1. Build attachment block via BM25 retrieval
    final attachmentBlock = buildAttachmentBlock(
      attachments,
      userQuery: userQuery,
      maxAttachmentTokens: TokenBudgetManager.maxAttachmentTokens,
    );

    // 2. Strict Token Budgeting: compute available budget for history
    final attachmentTokens = attachmentBlock != null
        ? TokenBudgetManager.estimateTokens(attachmentBlock)
        : 0;

    final availableHistoryBudget = TokenBudgetManager.calculateAvailableHistoryBudget(
      systemPrompt: systemPrompt,
      userQuery: userQuery,
      attachmentTokens: attachmentTokens,
      contextWindow: contextWindow,
      reservedGeneration: reservedGeneration,
    );

    // 3. Prune history to strictly fit within the remaining budget
    final budgetedHistory = TokenBudgetManager.pruneHistory(
      history: conversationHistory,
      maxTokens: availableHistoryBudget,
    );

    switch (mode) {
      case LlmMode.gemmaGguf:
        return _formatGemma(
          systemPrompt: systemPrompt,
          attachmentBlock: attachmentBlock,
          history: budgetedHistory,
          userQuery: userQuery,
          isGemma4: isGemma4,
        );
      case LlmMode.qwenGguf:
        return _formatChatML(
          systemPrompt: systemPrompt,
          attachmentBlock: attachmentBlock,
          history: budgetedHistory,
          userQuery: userQuery,
        );
      case LlmMode.llamaGguf:
        return _formatLlama3(
          systemPrompt: systemPrompt,
          attachmentBlock: attachmentBlock,
          history: budgetedHistory,
          userQuery: userQuery,
        );
      case LlmMode.builtinHinglish:
        return _formatStructuredFallback(
          systemPrompt: systemPrompt,
          attachmentBlock: attachmentBlock,
          history: budgetedHistory,
          userQuery: userQuery,
        );
    }
  }

  /// Builds the formatted labeled attachment block using Okapi BM25 chunk retrieval:
  /// [ATTACHMENTS]
  /// [ATTACHMENT id=1 name="chapter3.pdf"]
  /// ...relevant chunks...
  /// [/ATTACHMENT]
  /// Instruction: Use attachments only when the user's question is about them. If the question is unrelated, ignore them and answer normally. Never mix attachment content into unrelated answers.
  /// [/ATTACHMENTS]
  static String? buildAttachmentBlock(
    List<SavedDocumentModel> attachments, {
    String? userQuery,
    int maxAttachmentTokens = TokenBudgetManager.maxAttachmentTokens,
  }) {
    if (attachments.isEmpty) return null;

    final buffer = StringBuffer();
    buffer.writeln('[ATTACHMENTS]');
    final perDocTokens = maxAttachmentTokens ~/ attachments.length;

    for (int i = 0; i < attachments.length; i++) {
      final doc = attachments[i];
      final id = i + 1;

      // Retrieve Top-K relevant chunks using BM25
      final retrievedChunks = BM25Retriever.retrieveTopChunks(
        doc: doc,
        query: userQuery ?? '',
        maxTokens: perDocTokens > 0 ? perDocTokens : 400,
      );

      buffer.writeln('[ATTACHMENT id=$id name="${doc.fileName}"]');
      if (retrievedChunks.isNotEmpty) {
        for (final chunk in retrievedChunks) {
          if (retrievedChunks.length > 1) {
            buffer.writeln('--- [Section ${chunk.chunkIndex + 1}/${chunk.totalChunks}] ---');
          }
          buffer.writeln(chunk.text.trim());
        }
      } else {
        final fallbackExcerpt = doc.extractedText.length > 1200
            ? '${doc.extractedText.substring(0, 1200)}...[truncated for context]'
            : doc.extractedText;
        buffer.writeln(fallbackExcerpt.trim());
      }
      buffer.writeln('[/ATTACHMENT]');
    }
    buffer.writeln('Instruction: Use attachments only when the user\'s question is about them. If the question is unrelated, ignore them and answer normally. Never mix attachment content into unrelated answers.');
    buffer.write('[/ATTACHMENTS]');
    return buffer.toString();
  }

  /// Google Gemma canonical chat template:
  /// Uses official special tokens: `<start_of_turn>user\n...<end_of_turn>\n<start_of_turn>model\n...<end_of_turn>`
  static String _formatGemma({
    required String systemPrompt,
    required String? attachmentBlock,
    required List<Map<String, String>> history,
    required String userQuery,
    bool isGemma4 = true,
  }) {
    final buffer = StringBuffer();

    final header = StringBuffer();
    header.writeln(systemPrompt.trim());
    if (attachmentBlock != null && attachmentBlock.isNotEmpty) {
      header.writeln('\n$attachmentBlock');
    }

    if (history.isEmpty) {
      buffer.writeln('<start_of_turn>user');
      buffer.writeln(header.toString().trim());
      buffer.writeln('\n${userQuery.trim()}<end_of_turn>');
      buffer.write('<start_of_turn>model\n');
      return buffer.toString();
    }

    bool systemInjected = false;
    for (int i = 0; i < history.length; i++) {
      final turn = history[i];
      final role = turn['role'] == 'assistant' ? 'model' : 'user';
      final content = turn['content']?.trim();
      if (content != null && content.isNotEmpty) {
        buffer.writeln('<start_of_turn>$role');
        if (!systemInjected && role == 'user') {
          buffer.writeln(header.toString().trim());
          buffer.writeln('');
          systemInjected = true;
        }
        buffer.writeln(content);
        buffer.writeln('<end_of_turn>');
      }
    }

    buffer.writeln('<start_of_turn>user');
    if (!systemInjected) {
      buffer.writeln(header.toString().trim());
      buffer.writeln('');
    }
    buffer.writeln(userQuery.trim());
    buffer.writeln('<end_of_turn>');
    buffer.write('<start_of_turn>model\n');

    return buffer.toString();
  }

  /// Qwen 2.5 ChatML format:
  /// `<|im_start|>{role}\n{content}<|im_end|>`
  static String _formatChatML({
    required String systemPrompt,
    required String? attachmentBlock,
    required List<Map<String, String>> history,
    required String userQuery,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('<|im_start|>system');
    buffer.writeln(systemPrompt.trim());
    if (attachmentBlock != null && attachmentBlock.isNotEmpty) {
      buffer.writeln('\n$attachmentBlock');
    }
    buffer.writeln('<|im_end|>');

    for (final turn in history) {
      final role = turn['role'] == 'assistant' ? 'assistant' : 'user';
      final content = turn['content']?.trim();
      if (content != null && content.isNotEmpty) {
        buffer.writeln('<|im_start|>$role');
        buffer.writeln(content);
        buffer.writeln('<|im_end|>');
      }
    }

    buffer.writeln('<|im_start|>user');
    buffer.writeln(userQuery.trim());
    buffer.writeln('<|im_end|>');
    buffer.write('<|im_start|>assistant\n');

    return buffer.toString();
  }

  /// Meta Llama 3.2 format:
  /// `<|begin_of_text|><|start_header_id|>{role}<|end_header_id|>\n\n{content}<|eot_id|>`
  static String _formatLlama3({
    required String systemPrompt,
    required String? attachmentBlock,
    required List<Map<String, String>> history,
    required String userQuery,
  }) {
    final buffer = StringBuffer();
    buffer.write('<|begin_of_text|>');

    buffer.write('<|start_header_id|>system<|end_header_id|>\n\n');
    buffer.write(systemPrompt.trim());
    if (attachmentBlock != null && attachmentBlock.isNotEmpty) {
      buffer.write('\n\n$attachmentBlock');
    }
    buffer.write('<|eot_id|>');

    for (final turn in history) {
      final role = turn['role'] == 'assistant' ? 'assistant' : 'user';
      final content = turn['content']?.trim();
      if (content != null && content.isNotEmpty) {
        buffer.write('<|start_header_id|>$role<|end_header_id|>\n\n');
        buffer.write(content);
        buffer.write('<|eot_id|>');
      }
    }

    buffer.write('<|start_header_id|>user<|end_header_id|>\n\n');
    buffer.write(userQuery.trim());
    buffer.write('<|eot_id|>');
    buffer.write('<|start_header_id|>assistant<|end_header_id|>\n\n');

    return buffer.toString();
  }

  /// Clean structured block for offline fallback engine:
  static String _formatStructuredFallback({
    required String systemPrompt,
    required String? attachmentBlock,
    required List<Map<String, String>> history,
    required String userQuery,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('=== SYSTEM INSTRUCTIONS ===');
    buffer.writeln(systemPrompt.trim());

    if (attachmentBlock != null && attachmentBlock.isNotEmpty) {
      buffer.writeln('\n=== ATTACHMENTS ===');
      buffer.writeln(attachmentBlock.trim());
    }

    if (history.isNotEmpty) {
      buffer.writeln('\n=== CONVERSATION HISTORY ===');
      for (final turn in history) {
        final role = turn['role']?.toUpperCase() ?? 'USER';
        buffer.writeln('$role: ${turn['content']}');
      }
    }

    buffer.writeln('\n=== USER QUERY ===');
    buffer.write(userQuery.trim());

    return buffer.toString();
  }
}
