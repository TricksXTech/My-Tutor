import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// High-Performance Offline Syntax Highlighting TextEditingController
/// Renders code with authentic VS Code Dark+ theme colors for all supported languages!
class CodeHighlightController extends TextEditingController {
  String languageKey;

  CodeHighlightController({
    super.text,
    this.languageKey = 'python',
  });

  // VS Code Dark+ Signature Color Palette
  static const Color colorDefault = Color(0xFFD4D4D4);      // Default Off-White
  static const Color colorComment = Color(0xFF6A9955);      // VS Code Sage Green
  static const Color colorString = Color(0xFFCE9178);       // VS Code Warm Orange / Terracotta
  static const Color colorNumber = Color(0xFFB5CEA8);       // VS Code Mint / Lime Green
  static const Color colorKeyword = Color(0xFFC586C0);      // VS Code Control Flow Pink / Magenta
  static const Color colorControl = Color(0xFF569CD6);      // VS Code Keyword Blue
  static const Color colorType = Color(0xFF4EC9B0);         // VS Code Turquoise / Teal
  static const Color colorFunction = Color(0xFFDCDCAA);     // VS Code Gold / Warm Yellow
  static const Color colorPreprocessor = Color(0xFF9CDCFE); // VS Code Light Sky Blue
  static const Color colorOperator = Color(0xFFD4D4D4);     // Operators & Braces

  // Control Flow Keywords (Purple/Magenta in VS Code)
  static final Set<String> _keywordsControl = {
    'if', 'else', 'elif', 'switch', 'case', 'default', 'break', 'continue',
    'return', 'for', 'while', 'do', 'goto', 'try', 'catch', 'finally',
    'throw', 'throws', 'raise', 'except', 'yield', 'await', 'async',
    'pass', 'match', 'when', 'in', 'is', 'not', 'and', 'or',
    // SQL
    'SELECT', 'FROM', 'WHERE', 'INSERT', 'INTO', 'VALUES', 'UPDATE',
    'DELETE', 'CREATE', 'TABLE', 'DROP', 'ALTER', 'JOIN', 'LEFT',
    'RIGHT', 'INNER', 'OUTER', 'ON', 'GROUP', 'BY', 'ORDER', 'HAVING',
    'LIMIT', 'DISTINCT', 'select', 'from', 'where', 'insert', 'into',
    'values', 'update', 'delete', 'create', 'table', 'drop', 'join',
  };

  // Declaration, Storage & Modifiers (Blue in VS Code)
  static final Set<String> _keywordsStorage = {
    'class', 'struct', 'union', 'enum', 'interface', 'trait', 'impl',
    'type', 'public', 'private', 'protected', 'internal', 'abstract',
    'virtual', 'override', 'static', 'final', 'const', 'var', 'let', 'val',
    'package', 'import', 'export', 'using', 'namespace', 'typedef',
    'def', 'fn', 'fun', 'func', 'function', 'new', 'delete', 'this',
    'self', 'super', 'extends', 'implements', 'sizeof', 'typeof',
    'instanceof', 'true', 'false', 'null', 'nil', 'None', 'True',
    'False', 'nullptr', 'undefined', 'NaN', 'echo', 'print', 'println',
  };

  // Types & Data Structures (Teal/Turquoise in VS Code)
  static final Set<String> _keywordsTypes = {
    'int', 'long', 'short', 'byte', 'float', 'double', 'char', 'bool',
    'boolean', 'void', 'signed', 'unsigned', 'size_t', 'auto',
    'String', 'Integer', 'Double', 'Boolean', 'List', 'Map', 'Set',
    'vector', 'string', 'Scanner', 'Math', 'System', 'std', 'cout', 'cin',
    'endl', 'u8', 'u16', 'u32', 'u64', 'i8', 'i16', 'i32', 'i64',
    'f32', 'f64', 'usize', 'isize', 'fmt', 'Array', 'Object',
  };

  // Combined Token Scanner Pattern
  static final RegExp _tokenRegex = RegExp(
    r'(/\*[\s\S]*?\*/)' // 1. Block comment
    r'|(//[^\n]*)' // 2. Line comment //
    r'|(#[^\n]*)' // 3. Line comment / Hash #
    r'|(--[^\n]*)' // 4. SQL comment --
    r'|("(?:[^"\\]|\\.)*")' // 5. Double-quoted string
    r"|('(?:[^'\\]|\\.)*')" // 6. Single-quoted string
    r'|(`(?:[^`\\]|\\.)*`)' // 7. Backtick string
    r'|(\b0[xX][0-9a-fA-F]+\b|\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b)' // 8. Number
    r'|([a-zA-Z_$][a-zA-Z0-9_$]*)' // 9. Identifier / Word
    r'|([+\-*/%&=!<>|?:;.,~^(){}\[\]]+)', // 10. Operators / Punctuation
    multiLine: true,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ??
        GoogleFonts.firaCode(
          fontSize: 13.5,
          color: colorDefault,
          height: 1.45,
        );

    final rawText = value.text;
    if (rawText.isEmpty) {
      return TextSpan(style: baseStyle, text: '');
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    final lang = languageKey.toLowerCase();
    final isHashCommentLang = lang == 'python' || lang == 'ruby' || lang == 'bash' || lang == 'r';
    final isSqlLang = lang == 'sql';

    for (final match in _tokenRegex.allMatches(rawText)) {
      if (match.start > lastEnd) {
        // Unmatched gaps (whitespace, newlines, tabs)
        spans.add(TextSpan(
          text: rawText.substring(lastEnd, match.start),
          style: baseStyle.copyWith(color: colorDefault),
        ));
      }

      final token = match.group(0)!;
      final end = match.end;

      // 1. Comments
      if (token.startsWith('/*')) {
        spans.add(TextSpan(
          text: token,
          style: baseStyle.copyWith(color: colorComment, fontStyle: FontStyle.italic),
        ));
      } else if (token.startsWith('//')) {
        spans.add(TextSpan(
          text: token,
          style: baseStyle.copyWith(color: colorComment, fontStyle: FontStyle.italic),
        ));
      } else if (token.startsWith('--') && isSqlLang) {
        spans.add(TextSpan(
          text: token,
          style: baseStyle.copyWith(color: colorComment, fontStyle: FontStyle.italic),
        ));
      } else if (token.startsWith('#')) {
        if (isHashCommentLang) {
          spans.add(TextSpan(
            text: token,
            style: baseStyle.copyWith(color: colorComment, fontStyle: FontStyle.italic),
          ));
        } else if (token.contains('include') || token.contains('define') || token.contains('import') || token.contains('pragma')) {
          // Preprocessor directive in C/C++/C#
          spans.add(TextSpan(
            text: token,
            style: baseStyle.copyWith(color: colorPreprocessor, fontWeight: FontWeight.w600),
          ));
        } else {
          spans.add(TextSpan(
            text: token,
            style: baseStyle.copyWith(color: colorPreprocessor),
          ));
        }
      }
      // 2. Strings
      else if (token.startsWith('"') || token.startsWith("'") || token.startsWith('`')) {
        spans.add(TextSpan(
          text: token,
          style: baseStyle.copyWith(color: colorString),
        ));
      }
      // 3. Numbers
      else if (RegExp(r'^\d|^0[xX]').hasMatch(token)) {
        spans.add(TextSpan(
          text: token,
          style: baseStyle.copyWith(color: colorNumber),
        ));
      }
      // 4. Identifiers / Keywords / Functions
      else if (RegExp(r'^[a-zA-Z_$]').hasMatch(token)) {
        if (_keywordsControl.contains(token)) {
          spans.add(TextSpan(
            text: token,
            style: baseStyle.copyWith(color: colorKeyword, fontWeight: FontWeight.w600),
          ));
        } else if (_keywordsStorage.contains(token)) {
          spans.add(TextSpan(
            text: token,
            style: baseStyle.copyWith(color: colorControl, fontWeight: FontWeight.w600),
          ));
        } else if (_keywordsTypes.contains(token)) {
          spans.add(TextSpan(
            text: token,
            style: baseStyle.copyWith(color: colorType, fontWeight: FontWeight.w600),
          ));
        } else {
          // Check if followed by '(' to color as a Function Call in VS Code Gold
          bool isFuncCall = false;
          int peekIdx = end;
          while (peekIdx < rawText.length && (rawText[peekIdx] == ' ' || rawText[peekIdx] == '\t')) {
            peekIdx++;
          }
          if (peekIdx < rawText.length && rawText[peekIdx] == '(') {
            isFuncCall = true;
          }

          if (isFuncCall) {
            spans.add(TextSpan(
              text: token,
              style: baseStyle.copyWith(color: colorFunction, fontWeight: FontWeight.w600),
            ));
          } else {
            spans.add(TextSpan(
              text: token,
              style: baseStyle.copyWith(color: colorDefault),
            ));
          }
        }
      }
      // 5. Operators & Punctuation
      else {
        spans.add(TextSpan(
          text: token,
          style: baseStyle.copyWith(color: colorOperator),
        ));
      }

      lastEnd = end;
    }

    // Trailing characters after last match
    if (lastEnd < rawText.length) {
      spans.add(TextSpan(
        text: rawText.substring(lastEnd),
        style: baseStyle.copyWith(color: colorDefault),
      ));
    }

    return TextSpan(style: baseStyle, children: spans);
  }
}
