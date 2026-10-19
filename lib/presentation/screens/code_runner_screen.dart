import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/code_snippet_model.dart';
import '../../data/services/code_runner_service.dart';
import '../widgets/code_highlight_controller.dart';

/// Interactive Multi-Language Code Runner & Playground Screen
/// Supports Python, C, C++, Java, JS, PHP, SQL, TypeScript, Rust, Kotlin, C#, Dart, Go, Ruby, Bash, R
/// Features pinned RUN button, sleek bottom-sheet language picker, and 100% offline execution!
class CodeRunnerScreen extends StatefulWidget {
  final String initialLanguage;
  final String? initialCode;

  const CodeRunnerScreen({
    super.key,
    this.initialLanguage = 'python',
    this.initialCode,
  });

  @override
  State<CodeRunnerScreen> createState() => _CodeRunnerScreenState();
}

class _CodeRunnerScreenState extends State<CodeRunnerScreen> {
  late String _selectedLanguage;
  late CodeHighlightController _codeController;
  final TextEditingController _stdinController = TextEditingController();
  final TextEditingController _terminalInputController = TextEditingController();
  final FocusNode _terminalInputFocusNode = FocusNode();
  final ScrollController _terminalScrollController = ScrollController();

  bool _isRunning = false;
  bool _showStdinPanel = false;
  CompilerEngineMode _engineMode = CompilerEngineMode.auto; // Smart auto compiler by default
  CodeExecutionResult? _lastResult;
  String? _echoedInput;
  final List<String> _accumulatedInputs = [];

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    final defaultCode = CodeRunnerService.supportedLanguages[_selectedLanguage]?['sampleCode'] as String? ?? '';
    _codeController = CodeHighlightController(
      text: widget.initialCode ?? defaultCode,
      languageKey: _selectedLanguage,
    );
    _codeController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _stdinController.dispose();
    _terminalInputController.dispose();
    _terminalInputFocusNode.dispose();
    _terminalScrollController.dispose();
    super.dispose();
  }

  void _onLanguageChanged(String newLang) {
    if (newLang == _selectedLanguage) return;
    setState(() {
      _selectedLanguage = newLang;
      _codeController.languageKey = newLang;
      final sample = CodeRunnerService.supportedLanguages[newLang]?['sampleCode'] as String? ?? '';
      _codeController.text = sample;
      _lastResult = null;
      _echoedInput = null;
      _accumulatedInputs.clear();
    });
  }

  Future<void> _runCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or paste code to run!'),
          backgroundColor: AppColors.surfaceElevated,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Clicking RUN initiates a fresh recompile & execution
    setState(() {
      _accumulatedInputs.clear();
      _echoedInput = null;
    });

    final terminalText = _terminalInputController.text.trim();
    final panelText = _showStdinPanel ? _stdinController.text.trim() : '';
    final initialStdin = terminalText.isNotEmpty ? terminalText : panelText;

    if (initialStdin.isNotEmpty) {
      final tokens = initialStdin.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      if (tokens.isNotEmpty) {
        _accumulatedInputs.addAll(tokens);
      } else {
        _accumulatedInputs.add(initialStdin);
      }
      setState(() {
        _echoedInput = _accumulatedInputs.join(' ');
      });
    }

    _terminalInputController.clear();
    await _executeCodeRun(customStdin: _accumulatedInputs.join('\n'));
  }

  void _sendTerminalInput([String? val]) {
    final rawInput = (val ?? _terminalInputController.text).trim();
    if (rawInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an input value to send!'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Support entering multiple tokens at once (e.g. "10 20") or one by one
    final tokens = rawInput.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isNotEmpty) {
      _accumulatedInputs.addAll(tokens);
    } else {
      _accumulatedInputs.add(rawInput);
    }

    final combinedStdin = _accumulatedInputs.join('\n');
    setState(() {
      _echoedInput = _accumulatedInputs.join(' ');
      _stdinController.text = combinedStdin;
    });
    _terminalInputController.clear();
    _terminalInputFocusNode.unfocus();

    _executeCodeRun(customStdin: combinedStdin);
  }

  Future<void> _executeCodeRun({String? customStdin}) async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final stdinValue = (customStdin ?? _stdinController.text).trim();

    setState(() {
      _isRunning = true;
    });

    try {
      final result = await CodeRunnerService().executeCode(
        languageKey: _selectedLanguage,
        code: _codeController.text,
        stdin: stdinValue,
        engineMode: _engineMode,
      );

      if (mounted) {
        setState(() {
          _lastResult = result;
          _isRunning = false;
        });

        if (result.isAwaitingInput) {
          _terminalInputFocusNode.requestFocus();
        }

        // Scroll terminal to bottom on new result
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_terminalScrollController.hasClients) {
            _terminalScrollController.animateTo(
              _terminalScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastResult = CodeExecutionResult(
            output: '',
            error: e.toString(),
            exitCode: 1,
            executionTimeMs: 0,
            engine: 'Execution Failed',
            isSuccess: false,
          );
          _isRunning = false;
        });
      }
    }
  }

  Future<void> _pasteCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _codeController.text = data.text!;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code pasted from clipboard!'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _clearCode() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text('Clear Code?', style: GoogleFonts.poppins(color: AppColors.textPrimary)),
        content: Text('Are you sure you want to clear the editor?', style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              setState(() {
                _codeController.clear();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _loadSampleTemplate() {
    final sample = CodeRunnerService.supportedLanguages[_selectedLanguage]?['sampleCode'] as String? ?? '';
    setState(() {
      _codeController.text = sample;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded ${CodeRunnerService.supportedLanguages[_selectedLanguage]?['name']} Starter Template'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Opens the modern, beautiful bottom sheet for selecting from 16 languages
  void _openLanguagePickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _LanguagePickerSheet(
          selectedLanguage: _selectedLanguage,
          onSelectLanguage: (newLang) {
            _onLanguageChanged(newLang);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Text(
                      CodeRunnerService.supportedLanguages[newLang]?['icon'] as String? ?? '💻',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Switched to ${CodeRunnerService.supportedLanguages[newLang]?['name']} • Starter Template Loaded',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                backgroundColor: AppColors.surfaceElevated,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
    );
  }

  String get _engineToolbarLabel {
    switch (_engineMode) {
      case CompilerEngineMode.auto:
        return 'Auto 🚀';
      case CompilerEngineMode.offline:
        return 'Offline ⚡';
      case CompilerEngineMode.cloud:
        return 'Cloud 🌐';
    }
  }

  void _openSnippetsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SnippetsPickerSheet(
        languageKey: _selectedLanguage,
        onSelectSnippet: (snippet) {
          setState(() {
            _codeController.text = snippet.code;
            if (snippet.defaultStdin != null) {
              _stdinController.text = snippet.defaultStdin!;
              _showStdinPanel = true;
            }
            _lastResult = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded snippet: ${snippet.title}'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _openEngineSelectorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EngineSelectorSheet(
        currentMode: _engineMode,
        onSelectMode: (mode) {
          setState(() {
            _engineMode = mode;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langInfo = CodeRunnerService.supportedLanguages[_selectedLanguage] ?? {};
    final langName = langInfo['name'] as String? ?? 'Python';
    final langIcon = langInfo['icon'] as String? ?? '💻';
    final fileExt = langInfo['fileExt'] as String? ?? 'txt';
    final lineCount = _codeController.text.isEmpty ? 1 : _codeController.text.split('\n').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.terminal_rounded, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text(
              'Code Runner',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          // Sleek, Modern Language Selector Button in AppBar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: InkWell(
              onTap: _openLanguagePickerModal,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primaryAccent.withAlpha(150), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryAccent.withAlpha(35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(langIcon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      langName,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.secondaryAccent, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Quick Editor Toolbar (Horizontally Scrollable Tools + PERMANENTLY PINNED RUN BUTTON)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                // Scrollable Tools Row (Never pushes the RUN button off!)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Snippets Button (DSA Algorithms & Templates)
                        _buildToolbarButton(
                          icon: Icons.menu_book_rounded,
                          label: 'Snippets 📚',
                          onTap: _openSnippetsModal,
                          tooltip: 'Load DSA algorithms and practical programs',
                        ),
                        const SizedBox(width: 6),

                        // Paste Button
                        _buildToolbarButton(
                          icon: Icons.content_paste_rounded,
                          label: 'Paste',
                          onTap: _pasteCode,
                          tooltip: 'Paste from clipboard',
                        ),
                        const SizedBox(width: 6),

                        // Template Button
                        _buildToolbarButton(
                          icon: Icons.code_rounded,
                          label: 'Template',
                          onTap: _loadSampleTemplate,
                          tooltip: 'Load starter code',
                        ),
                        const SizedBox(width: 6),

                        // Clear Button
                        _buildToolbarButton(
                          icon: Icons.delete_outline_rounded,
                          label: 'Clear',
                          onTap: _clearCode,
                          tooltip: 'Clear editor',
                        ),
                        const SizedBox(width: 6),

                        // Stdin Toggle Button
                        _buildToolbarButton(
                          icon: Icons.input_rounded,
                          label: 'Input',
                          isActive: _showStdinPanel,
                          onTap: () {
                            setState(() {
                              _showStdinPanel = !_showStdinPanel;
                            });
                          },
                          tooltip: 'Program stdin input',
                        ),
                        const SizedBox(width: 6),

                        // Compiler Engine Selector Button
                        _buildToolbarButton(
                          icon: Icons.tune_rounded,
                          label: _engineToolbarLabel,
                          isActive: true,
                          onTap: _openEngineSelectorModal,
                          tooltip: 'Compiler Engine Settings',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // PINNED RUN BUTTON (PROMINENT, UNMISSABLE, NEVER CUT OFF!)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGreen.withAlpha(90),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isRunning ? null : _runCode,
                    icon: _isRunning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.black),
                    label: Text(
                      _isRunning ? 'Running' : 'RUN',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Optional Stdin input Drawer
          if (_showStdinPanel)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceCard,
              child: Row(
                children: [
                  const Icon(Icons.input_rounded, size: 16, color: AppColors.secondaryAccent),
                  const SizedBox(width: 8),
                  Text('Program Stdin: ', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  Expanded(
                    child: TextField(
                      controller: _stdinController,
                      style: GoogleFonts.firaCode(fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Enter inputs (e.g. 10 20)...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 2. Code Editor Field (Zero Top Gap & Integrated File Header)
          Expanded(
            flex: 6,
            child: Container(
              color: const Color(0xFF13151F),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // File tab / status bar above code
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F111A),
                      border: Border(bottom: BorderSide(color: Color(0xFF1E2235), width: 0.8)),
                    ),
                    child: Row(
                      children: [
                        Text(langIcon, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          'main.$fileExt',
                          style: GoogleFonts.firaCode(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryAccent,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$lineCount lines • UTF-8',
                          style: GoogleFonts.firaCode(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actual Code Editor TextField (Aligned to Top - Zero Gap!)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: TextField(
                        controller: _codeController,
                        textAlignVertical: TextAlignVertical.top,
                        maxLines: null,
                        expands: true,
                        keyboardType: TextInputType.multiline,
                        style: GoogleFonts.firaCode(
                          fontSize: 13.5,
                          color: const Color(0xFFE2E8F0),
                          height: 1.45,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: '// Write or paste your $langName code here...',
                          hintStyle: GoogleFonts.firaCode(color: Colors.white24, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Divider Bar between Editor and Terminal
          Container(
            height: 1.5,
            color: AppColors.border,
          ),

          // 3. Interactive Terminal Console (Takes bottom portion)
          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFF0C0E14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Terminal Header Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF151821),
                      border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.terminal_rounded, size: 15, color: AppColors.accentGreen),
                        const SizedBox(width: 6),
                        Text(
                          'Terminal Console',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),

                        // Status Badge
                        if (_lastResult != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _lastResult!.isSuccess
                                  ? AppColors.accentGreen.withAlpha(35)
                                  : AppColors.error.withAlpha(35),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _lastResult!.isSuccess ? 'Exit: 0' : 'Exit: ${_lastResult!.exitCode}',
                              style: GoogleFonts.firaCode(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _lastResult!.isSuccess ? AppColors.accentGreen : AppColors.error,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_lastResult!.executionTimeMs}ms',
                            style: GoogleFonts.firaCode(fontSize: 10, color: AppColors.textMuted),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // Copy Terminal Output
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.textMuted),
                          tooltip: 'Copy Output',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          onPressed: () {
                            if (_lastResult != null) {
                              Clipboard.setData(ClipboardData(text: _lastResult!.output));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Terminal output copied!'),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 6),

                        // Clear Console
                        IconButton(
                          icon: const Icon(Icons.clear_all_rounded, size: 16, color: AppColors.textMuted),
                          tooltip: 'Clear Console',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          onPressed: () {
                            setState(() {
                              _lastResult = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // Terminal Output View
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _terminalScrollController,
                      padding: const EdgeInsets.all(12),
                      child: _lastResult == null
                          ? Text(
                              'Hit "RUN" to compile and execute $langName code on your device.\n'
                              'Output will appear here with execution time and exit status.',
                              style: GoogleFonts.firaCode(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                height: 1.5,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Engine badge header
                                Row(
                                  children: [
                                    Icon(
                                      _lastResult!.isSuccess ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                                      size: 13,
                                      color: _lastResult!.isSuccess ? AppColors.accentGreen : AppColors.error,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '[Engine: ${_lastResult!.engine}]',
                                      style: GoogleFonts.firaCode(
                                        fontSize: 11,
                                        color: AppColors.secondaryAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (_lastResult!.isAwaitingInput) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.warning.withAlpha(40),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.warning, width: 0.8),
                                        ),
                                        child: Text(
                                          'PAUSED: INPUT REQUIRED',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.warning,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Echo of user-provided input in terminal
                                if (_echoedInput != null) ...[
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryAccent.withAlpha(25),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.secondaryAccent.withAlpha(80), width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.subdirectory_arrow_right_rounded, size: 13, color: AppColors.secondaryAccent),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Stdin Fed: $_echoedInput',
                                          style: GoogleFonts.firaCode(
                                            fontSize: 11,
                                            color: AppColors.secondaryAccent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Output text
                                SelectableText(
                                  _lastResult!.output,
                                  style: GoogleFonts.firaCode(
                                    fontSize: 12.5,
                                    color: _lastResult!.isSuccess ? const Color(0xFFE2E8F0) : AppColors.error,
                                    height: 1.45,
                                  ),
                                ),

                                // If currently awaiting next input, show interactive indicator
                                if (_lastResult?.isAwaitingInput == true) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryAccent.withAlpha(20),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.secondaryAccent.withAlpha(100), width: 1),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondaryAccent),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '[Program awaiting input #${_accumulatedInputs.length + 1} ↵]',
                                          style: GoogleFonts.firaCode(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.secondaryAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Stderr if separate
                                if (_lastResult!.error != null && _lastResult!.error!.isNotEmpty && _lastResult!.error != _lastResult!.output) ...[
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    'Error Details:\n${_lastResult!.error}',
                                    style: GoogleFonts.firaCode(
                                      fontSize: 12,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),

                  // Live Interactive Terminal Input Console
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E111A),
                      border: Border(
                        top: BorderSide(
                          color: _lastResult?.isAwaitingInput == true
                              ? AppColors.secondaryAccent
                              : const Color(0xFF1F2438),
                          width: _lastResult?.isAwaitingInput == true ? 1.5 : 0.8,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '> ',
                          style: TextStyle(
                            color: _lastResult?.isAwaitingInput == true ? AppColors.accentGreen : AppColors.secondaryAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _terminalInputController,
                            focusNode: _terminalInputFocusNode,
                            style: GoogleFonts.firaCode(fontSize: 12.5, color: Colors.white),
                            textInputAction: TextInputAction.send,
                            decoration: InputDecoration(
                              hintText: _lastResult?.isAwaitingInput == true
                                  ? (_accumulatedInputs.isNotEmpty
                                      ? 'Type input #${_accumulatedInputs.length + 1} & tap Send ↵...'
                                      : 'Type program input & tap Send ↵ (e.g. 5)...')
                                  : 'Enter input for program (e.g. 10 20)...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 11,
                                color: _lastResult?.isAwaitingInput == true
                                    ? AppColors.secondaryAccent.withAlpha(200)
                                    : AppColors.textMuted,
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (val) => _sendTerminalInput(val),
                          ),
                        ),
                        InkWell(
                          onTap: () => _sendTerminalInput(),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                if (_lastResult?.isAwaitingInput == true)
                                  BoxShadow(
                                    color: AppColors.secondaryAccent.withAlpha(140),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.send_rounded, size: 12, color: Colors.white),
                                const SizedBox(width: 5),
                                Text(
                                  'Send ↵',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required String tooltip,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primaryAccent.withAlpha(40) : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? AppColors.secondaryAccent : AppColors.border,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: isActive ? AppColors.secondaryAccent : AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppColors.secondaryAccent : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Beautiful Modal Bottom Sheet for selecting from 16 Programming Languages
class _LanguagePickerSheet extends StatefulWidget {
  final String selectedLanguage;
  final ValueChanged<String> onSelectLanguage;

  const _LanguagePickerSheet({
    required this.selectedLanguage,
    required this.onSelectLanguage,
  });

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Popular',
    'Web & Backend',
    'Systems',
    'Database',
    'Mobile & JVM',
    'Scripting',
    'Data & AI',
  ];

  @override
  Widget build(BuildContext context) {
    final allEntries = CodeRunnerService.supportedLanguages.entries.toList();
    final filtered = allEntries.where((e) {
      final name = (e.value['name'] as String? ?? '').toLowerCase();
      final desc = (e.value['description'] as String? ?? '').toLowerCase();
      final cat = (e.value['category'] as String? ?? '');
      final matchesQuery = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase()) ||
          e.key.contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' ||
          cat.toLowerCase().contains(_selectedCategory.toLowerCase());
      return matchesQuery && matchesCategory;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Handle pill
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.code_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Programming Language',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${CodeRunnerService.supportedLanguages.length} Languages • 100% Offline Ready',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: AppColors.accentGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search Python, PHP, SQL, Rust, C++...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
                  icon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Category Chips Horizontal Scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      cat,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primaryAccent,
                    backgroundColor: AppColors.surfaceElevated,
                    side: BorderSide(
                      color: isSelected ? AppColors.secondaryAccent : AppColors.border,
                      width: 0.8,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (_) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          const Divider(height: 1, color: AppColors.border),

          // Languages List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matching languages found',
                      style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final item = filtered[idx];
                      final isSelected = item.key == widget.selectedLanguage;
                      final name = item.value['name'] as String? ?? item.key;
                      final icon = item.value['icon'] as String? ?? '💻';
                      final desc = item.value['description'] as String? ?? '';
                      final cat = item.value['category'] as String? ?? 'General';

                      return InkWell(
                        onTap: () {
                          widget.onSelectLanguage(item.key);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryAccent.withAlpha(35)
                                : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppColors.secondaryAccent : AppColors.border,
                              width: isSelected ? 1.5 : 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceCard,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border),
                                ),
                                alignment: Alignment.center,
                                child: Text(icon, style: const TextStyle(fontSize: 20)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected ? Colors.white : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: AppColors.accentGreen.withAlpha(25),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '⚡ Offline',
                                            style: GoogleFonts.firaCode(
                                              fontSize: 9.5,
                                              color: AppColors.accentGreen,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      desc.isNotEmpty ? desc : cat,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.accentGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_rounded, size: 14, color: Colors.black),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Compiler Engine Settings Bottom Sheet
class _EngineSelectorSheet extends StatelessWidget {
  final CompilerEngineMode currentMode;
  final ValueChanged<CompilerEngineMode> onSelectMode;

  const _EngineSelectorSheet({
    required this.currentMode,
    required this.onSelectMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141721),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.memory_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compiler Engine Settings',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Choose how your code compiles and runs',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Options List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // 1. Auto-Smart Mode
                _buildModeCard(
                  context: context,
                  mode: CompilerEngineMode.auto,
                  title: 'Auto-Smart Compiler',
                  badge: 'RECOMMENDED',
                  badgeColor: AppColors.accentGreen,
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppColors.accentGreen,
                  description:
                      'Automatically compiles via Native Cloud Sandbox (GCC / Clang / JDK) when online, and seamlessly runs On-Device in 0ms when offline or without internet.',
                  latency: '15ms (Offline) / ~200ms (Online)',
                  internet: 'Auto-detects network',
                ),
                const SizedBox(height: 10),

                // 2. 100% Offline On-Device Engine
                _buildModeCard(
                  context: context,
                  mode: CompilerEngineMode.offline,
                  title: '100% On-Device Engine',
                  badge: 'ZERO DATA',
                  badgeColor: AppColors.secondaryAccent,
                  icon: Icons.offline_bolt_rounded,
                  iconColor: AppColors.secondaryAccent,
                  description:
                      'Runs entirely on your smartphone CPU without touching the internet. 0ms network latency, zero mobile data consumed. Supports all 16 languages, loops, arrays & math libraries.',
                  latency: '5ms - 25ms (Instant)',
                  internet: 'No internet required (100% Offline)',
                ),
                const SizedBox(height: 10),

                // 3. Native Cloud Sandbox (Piston SDK)
                _buildModeCard(
                  context: context,
                  mode: CompilerEngineMode.cloud,
                  title: 'Native Cloud Sandbox',
                  badge: 'STRICT GCC / JVM',
                  badgeColor: AppColors.primaryAccent,
                  icon: Icons.cloud_done_rounded,
                  iconColor: AppColors.primaryAccent,
                  description:
                      'Executes inside isolated Linux container with official GCC 10.2, Python 3.10, OpenJDK 17. Provides exact compiler warnings, memory pointers & linker diagnostics.',
                  latency: '~180ms - 350ms',
                  internet: 'Internet required',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Educational Architecture Info Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.secondaryAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Why Hybrid Engine? Desktop GCC and JDK compilers require 2GB to 4GB of disk space and cannot run natively on Android due to OS security (W^X binary execution). My Tutor gives you an instant on-device offline engine plus an official cloud compiler!',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required CompilerEngineMode mode,
    required String title,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required Color iconColor,
    required String description,
    required String latency,
    required String internet,
  }) {
    final isSelected = currentMode == mode;

    return InkWell(
      onTap: () {
        onSelectMode(mode);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceElevated : const Color(0xFF191C27),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? badgeColor : AppColors.border,
            width: isSelected ? 1.5 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: badgeColor.withAlpha(30),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withAlpha(90), width: 0.6),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.firaCode(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: isSelected ? badgeColor : AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.speed_rounded, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  latency,
                  style: GoogleFonts.firaCode(fontSize: 10, color: AppColors.textMuted),
                ),
                const Spacer(),
                const Icon(Icons.wifi_rounded, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  internet,
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Code Snippets & DSA Algorithms Bottom Sheet
class _SnippetsPickerSheet extends StatelessWidget {
  final String languageKey;
  final ValueChanged<CodeSnippet> onSelectSnippet;

  const _SnippetsPickerSheet({
    required this.languageKey,
    required this.onSelectSnippet,
  });

  @override
  Widget build(BuildContext context) {
    final langInfo = CodeRunnerService.supportedLanguages[languageKey] ?? {};
    final langName = langInfo['name'] as String? ?? 'Language';
    final langIcon = langInfo['icon'] as String? ?? '💻';
    final snippets = CodeSnippetsData.getSnippetsForLanguage(languageKey);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF141721),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(langIcon, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$langName Algorithms & Snippets',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Classic DSA & Practical Programs (100% Offline Ready)',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Snippet list
          Expanded(
            child: snippets.isEmpty
                ? Center(
                    child: Text(
                      'No snippets found for $langName',
                      style: GoogleFonts.inter(color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: snippets.length,
                    itemBuilder: (ctx, index) {
                      final snippet = snippets[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF191C27),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border, width: 0.8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      snippet.title,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryAccent.withAlpha(30),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.primaryAccent.withAlpha(90), width: 0.6),
                                    ),
                                    child: Text(
                                      snippet.category,
                                      style: GoogleFonts.firaCode(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.secondaryAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                snippet.description,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      onSelectSnippet(snippet);
                                    },
                                    icon: const Icon(Icons.code_rounded, size: 14),
                                    label: Text(
                                      'Load Snippet',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Interactive Program Input Prompt Modal Sheet
class _StdinPromptSheet extends StatefulWidget {
  final TextEditingController controller;
  final String languageKey;
  final ValueChanged<String> onRun;

  const _StdinPromptSheet({
    required this.controller,
    required this.languageKey,
    required this.onRun,
  });

  @override
  State<_StdinPromptSheet> createState() => _StdinPromptSheetState();
}

class _StdinPromptSheetState extends State<_StdinPromptSheet> {
  final List<String> _quickPresets = ['10 20', '5', 'Hello', '100', '1 2 3 4 5'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141721),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.input_rounded, size: 20, color: AppColors.secondaryAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Program Input Required (stdin)',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    Text(
                      'Your code requires user input (e.g. scanf, input(), cin, Scanner).',
                      style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Enter Values (Separate multiple inputs with spaces or newlines):',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.secondaryAccent.withAlpha(120), width: 1),
            ),
            child: TextField(
              controller: widget.controller,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              style: GoogleFonts.firaCode(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. 10 20 or Alice',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                contentPadding: const EdgeInsets.all(12),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Text('Quick Presets: ', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
              ..._quickPresets.map(
                (p) => InkWell(
                  onTap: () {
                    setState(() {
                      widget.controller.text = p;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border, width: 0.8),
                    ),
                    child: Text(p, style: GoogleFonts.firaCode(fontSize: 11, color: AppColors.secondaryAccent)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    widget.onRun(widget.controller.text.trim());
                  },
                  child: const Text('Run as Is'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      widget.onRun(widget.controller.text.trim());
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      'Submit & Run 🚀',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
