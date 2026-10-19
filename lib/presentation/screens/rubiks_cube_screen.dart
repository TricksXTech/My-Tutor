import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/rubiks_cube_solver_service.dart';

class RubiksCubeScreen extends StatefulWidget {
  const RubiksCubeScreen({super.key});

  @override
  State<RubiksCubeScreen> createState() => _RubiksCubeScreenState();
}

class _RubiksCubeScreenState extends State<RubiksCubeScreen> with TickerProviderStateMixin {
  final RubiksCubeSolverService _solverService = RubiksCubeSolverService();

  late final WebViewController _webViewController;
  bool _isWebViewLoading = true;
  bool _useWebGlSolver = true;

  int _selectedSize = 3; // 2, 3, 4, 5, 6
  late RubiksCubeState _cubeState;
  CubeColor _selectedPaintColor = CubeColor.white;
  CubeFace _activeFaceView = CubeFace.front;

  // Solving State
  bool _isSolvingMode = false;
  List<CubeStep> _solutionSteps = [];
  int _currentStepIndex = 0;
  bool _isAutoPlaying = false;
  int _autoPlaySpeedMs = 2000;
  CubeFace? _inspectFace;

  late AnimationController _animController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _cubeState = RubiksCubeState.solved(_selectedSize);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 940),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize 100% Offline 3D WebGL Solver
    _initWebViewController();
  }

  void _initWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..addJavaScriptChannel(
        'CubeSolverBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (mounted) {
              setState(() => _isWebViewLoading = false);
              _injectTheme();
            }
          },
        ),
      )
      ..loadFlutterAsset('assets/cube_www/index.html');
  }

  Future<void> _handleBridgeMessage(String raw) async {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type == 'ready') {
        _injectTheme();
        return;
      }
      if (type == 'sound') {
        return;
      }

      final id = data['id'] as String?;
      final url = data['url'] as String?;
      final method = data['method'] as String? ?? 'GET';
      final body = data['body'] as String?;

      if (id != null && url != null) {
        final result = await OfflineSolverBridge.handleRequest(
          url: url,
          method: method,
          body: body,
        );
        final jsonStr = jsonEncode(result).replaceAll(r'\', r'\\').replaceAll("'", r"\'");
        await _webViewController.runJavaScript(
          "if (window['__solver_cb_$id']) window['__solver_cb_$id']($jsonStr);",
        );
      }
    } catch (e) {
      debugPrint('Solver bridge message error: $e');
    }
  }

  void _injectTheme() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? '#121212' : '#f8f9fa';
    final card = isDark ? '#1E1E2C' : '#ffffff';
    final card2 = isDark ? '#252538' : '#f1f3f5';
    final border = isDark ? '#33334A' : '#dee2e6';
    final cyan = isDark ? '#00CEC9' : '#0984e3';
    final orange = isDark ? '#6C5CE7' : '#6c5ce7';
    final text = isDark ? '#FFFFFF' : '#2d3436';

    final js = '''
      document.documentElement.style.setProperty('--app-bg', '$bg');
      document.documentElement.style.setProperty('--app-card', '$card');
      document.documentElement.style.setProperty('--app-card2', '$card2');
      document.documentElement.style.setProperty('--app-border', '$border');
      document.documentElement.style.setProperty('--app-cyan', '$cyan');
      document.documentElement.style.setProperty('--app-orange', '$orange');
      document.documentElement.style.setProperty('--app-text', '$text');
    ''';
    _webViewController.runJavaScript(js);
  }

  @override
  void dispose() {
    _animController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  bool _isComputingSolution = false;

  void _onSizeChanged(int newSize) {
    setState(() {
      _selectedSize = newSize;
      _cubeState = RubiksCubeState.solved(newSize);
      _isSolvingMode = false;
      _solutionSteps = [];
      _currentStepIndex = 0;
      _isAutoPlaying = false;
    });
  }

  void _resetSolved() {
    setState(() {
      _cubeState = RubiksCubeState.solved(_selectedSize);
      _isSolvingMode = false;
      _solutionSteps = [];
      _currentStepIndex = 0;
      _isAutoPlaying = false;
    });
  }

  void _scrambleCube() {
    final scrambleMoves = _solverService.generateScramble(_selectedSize, 14);
    final newState = RubiksCubeState.solved(_selectedSize);
    for (final m in scrambleMoves) {
      newState.applyMove(m);
    }
    newState.scrambleHistory = List.from(scrambleMoves);
    setState(() {
      _cubeState = newState;
      _isSolvingMode = false;
      _solutionSteps = [];
      _currentStepIndex = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cube scrambled with ${scrambleMoves.length} moves! Ready to solve.'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
  }

  void _startSolving() async {
    if (_cubeState.isSolved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cube is already solved!')),
      );
      return;
    }

    final validation = _solverService.validateCubeDetailed(_cubeState);
    if (validation.status == ValidationStatus.invalid) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF141724),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 26),
              SizedBox(width: 10),
              Text('Invalid Cube Colors', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Text(
            validation.reason,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Check Stickers', style: TextStyle(color: AppColors.secondaryAccent)),
            ),
          ],
        ),
      );
      return;
    }

    if (validation.status == ValidationStatus.fixable) {
      final suggestions = _solverService.repairSuggestions(_cubeState);
      if (suggestions.isNotEmpty) {
        _showRepairSelectionDialog(suggestions);
        return;
      }
    }

    _executeSolvingPipeline();
  }

  void _showRepairSelectionDialog(List<RepairSuggestion> candidates) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141724),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.build_circle_rounded, color: Colors.amberAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Physical Fix Required',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'Your cube has an unsolvable parity/twist state. Choose which piece to physically fix:',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final cand = candidates[idx];
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _applyRepairAndSolve(cand);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: idx == 0 ? Colors.amberAccent.withAlpha(160) : AppColors.border,
                            width: idx == 0 ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: idx == 0 ? Colors.amberAccent : Colors.white12,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                idx == 0 ? 'Best #1' : '#${idx + 1}',
                                style: TextStyle(
                                  color: idx == 0 ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cand.title,
                                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    cand.instruction,
                                    style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
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
      },
    );
  }

  void _applyRepairAndSolve(RepairSuggestion candidate) {
    setState(() {
      // 1. Update the displayed state immediately so it never diverges from solver input
      candidate.apply(_cubeState);
    });

    // 2. Physical fix is presented as Step 0
    final step0 = CubeStep(
      stepNumber: 0,
      totalSteps: 1,
      stage: 'Step 0: Physical Fix',
      moveNotation: 'PHYSICAL_FIX',
      instruction: candidate.instruction,
      actionSummary: 'Physical Cube Alignment',
      sliceType: 'none',
      directionSign: 0,
      arrowSymbol: '🔧',
      faceToRotate: CubeFace.front,
      isPhysicalFix: true,
    );

    _executeSolvingPipeline(prefixStep: step0);
  }

  void _executeSolvingPipeline({CubeStep? prefixStep}) async {
    setState(() => _isComputingSolution = true);

    try {
      List<CubeStep> steps = await _solverService.solveCubeAsync(_cubeState);
      if (steps.isEmpty) {
        steps = _solverService.solveCube(_cubeState);
      }

      if (prefixStep != null) {
        steps = [prefixStep, ...steps];
      }

      final total = steps.length;
      final renumbered = <CubeStep>[];
      for (int i = 0; i < steps.length; i++) {
        renumbered.add(steps[i].copyWith(
          stepNumber: prefixStep != null ? i : i + 1,
          totalSteps: prefixStep != null ? total - 1 : total,
        ));
      }

      setState(() {
        _solutionSteps = renumbered;
        _currentStepIndex = 0;
        _isSolvingMode = true;
        _isComputingSolution = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isComputingSolution = false);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF141724),
          title: const Text('Solver Notice', style: TextStyle(color: Colors.white)),
          content: Text('$e', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: AppColors.secondaryAccent)),
            )
          ],
        ),
      );
    }
  }

  Future<void> _nextStep() async {
    if (_currentStepIndex >= _solutionSteps.length) return;
    if (_animController.isAnimating) return;

    final currentStep = _solutionSteps[_currentStepIndex];

    if (currentStep.isPhysicalFix) {
      // Step 0 was a physical adjustment already applied to state
      setState(() {
        _currentStepIndex++;
      });
      return;
    }

    // Set animation duration dynamically: 1200ms for 180° double moves, 600ms for 90° single moves (measured omega = 2.6 rad/s)
    final isDouble = currentStep.moveNotation.contains('2');
    _animController.duration = Duration(milliseconds: isDouble ? 1200 : 600);

    // Trigger physical movement animation first
    await _animController.forward(from: 0.0);

    setState(() {
      _cubeState.applyMove(currentStep.moveNotation);
      // Requirement 8: Assert each color still appears exactly N*N times after move
      _cubeState.assertColorInvariants(
        stepNumber: currentStep.stepNumber,
        move: currentStep.moveNotation,
      );
      _currentStepIndex++;
    });

    _animController.reset();

    if (_currentStepIndex >= _solutionSteps.length) {
      setState(() {
        _isAutoPlaying = false;
      });
      _showSolvedCelebrationDialog();
    }
  }

  void _prevStep() {
    if (_currentStepIndex > 0) {
      final prevStep = _solutionSteps[_currentStepIndex - 1];
      if (prevStep.isPhysicalFix) {
        setState(() {
          _currentStepIndex--;
        });
        return;
      }

      final inverse = RubiksCubeSolverService.getInverseMove(prevStep.moveNotation);
      setState(() {
        _cubeState.applyMove(inverse);
        // Requirement 8: Assert each color still appears exactly N*N times
        _cubeState.assertColorInvariants(
          stepNumber: prevStep.stepNumber,
          move: inverse,
        );
        _currentStepIndex--;
      });
      _animController.reset();
    }
  }

  void _replayCurrentStepAnimation() {
    if (_currentStepIndex < _solutionSteps.length && !_animController.isAnimating) {
      final currentStep = _solutionSteps[_currentStepIndex];
      if (currentStep.isPhysicalFix) return;
      final isDouble = currentStep.moveNotation.contains('2');
      _animController.duration = Duration(milliseconds: isDouble ? 1200 : 600);
      _animController.forward(from: 0.0).then((_) {
        _animController.reset();
      });
    }
  }

  void _cycleAutoPlaySpeed() {
    setState(() {
      if (_autoPlaySpeedMs == 2000) {
        _autoPlaySpeedMs = 1000;
      } else if (_autoPlaySpeedMs == 1000) {
        _autoPlaySpeedMs = 3000;
      } else {
        _autoPlaySpeedMs = 2000;
      }
    });
  }

  void _toggleAutoPlay() async {
    setState(() => _isAutoPlaying = !_isAutoPlaying);
    while (_isAutoPlaying && _currentStepIndex < _solutionSteps.length && mounted) {
      await Future.delayed(Duration(milliseconds: _autoPlaySpeedMs));
      if (!_isAutoPlaying || !mounted) break;
      await _nextStep();
    }
  }

  void _showSolvedCelebrationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141724),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.stars_rounded, color: AppColors.accentGreen, size: 28),
            SizedBox(width: 10),
            Text('Cube Solved! 🎉', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Congratulations! You completed all steps to solve your ${_selectedSize}x$_selectedSize Rubik\'s Cube!',
          style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isSolvingMode = false;
                _cubeState = RubiksCubeState.solved(_selectedSize);
              });
            },
            child: const Text('Solve Another Cube'),
          ),
        ],
      ),
    );
  }

  Color _getFlutterColor(CubeColor color) {
    switch (color) {
      case CubeColor.white: return const Color(0xFFFFFFFF);
      case CubeColor.yellow: return const Color(0xFFFFD500);
      case CubeColor.green: return const Color(0xFF009B48);
      case CubeColor.blue: return const Color(0xFF0046AD);
      case CubeColor.red: return const Color(0xFFE51A24); // Distinct vibrant Red
      case CubeColor.orange: return const Color(0xFFFF8800); // Distinct bright safety Orange
    }
  }

  String _getColorName(CubeColor color) {
    switch (color) {
      case CubeColor.white: return 'White';
      case CubeColor.yellow: return 'Yellow';
      case CubeColor.green: return 'Green';
      case CubeColor.blue: return 'Blue';
      case CubeColor.red: return 'Red';
      case CubeColor.orange: return 'Orange';
    }
  }

  String _getFaceName(CubeFace face) {
    switch (face) {
      case CubeFace.up: return 'Up (White)';
      case CubeFace.down: return 'Down (Yellow)';
      case CubeFace.front: return 'Front (Green)';
      case CubeFace.back: return 'Back (Blue)';
      case CubeFace.left: return 'Left (Orange)';
      case CubeFace.right: return 'Right (Red)';
    }
  }

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _useWebGlSolver
              ? '3D Cube Solver (Kociemba)'
              : (_isSolvingMode ? 'Solving ${_selectedSize}x$_selectedSize Cube' : 'Rubik\'s Cube Solver'),
          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          // Toggle between 3D WebGL (Reverse Engineered) and Native Flutter Solver
          IconButton(
            icon: Icon(
              _useWebGlSolver ? Icons.view_in_ar_rounded : Icons.brush_rounded,
              color: _useWebGlSolver ? AppColors.secondaryAccent : Colors.white70,
            ),
            tooltip: _useWebGlSolver ? 'Switch to Step-by-Step Editor' : 'Switch to 3D WebGL Solver',
            onPressed: () {
              setState(() => _useWebGlSolver = !_useWebGlSolver);
            },
          ),
          if (!_useWebGlSolver && !_isSolvingMode) ...[
            IconButton(
              icon: const Icon(Icons.shuffle_rounded),
              tooltip: 'Random Scramble',
              onPressed: _scrambleCube,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reset Solved',
              onPressed: _resetSolved,
            ),
          ] else if (!_useWebGlSolver && _isSolvingMode) ...[
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Exit Solver',
              onPressed: () {
                setState(() => _isSolvingMode = false);
              },
            ),
          ],
        ],
      ),
      body: _useWebGlSolver
          ? Stack(
              children: [
                WebViewWidget(controller: _webViewController),
                if (_isWebViewLoading)
                  Container(
                    color: AppColors.background,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.secondaryAccent),
                          SizedBox(height: 16),
                          Text(
                            'Loading 3D Rubik\'s Cube Solver...',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : Column(
              children: [
                // Top Size Selector: ONLY 2x2, 3x3, 4x4, 5x5, 6x6
                _buildTopSizeSelector(),

                // Main View: 3D Face View / Unfolded Net
                Expanded(
                  child: _isSolvingMode ? _buildSolvingView() : _buildEditorView(),
                ),

                // Bottom Controls: Color Palette (in Editor) or Step Navigator (in Solving)
                if (!_isSolvingMode)
                  _buildBottomColorPalette()
                else
                  _buildSolvingControlsBar(),
              ],
            ),
    );
  }

  // ===========================================================================
  // TOP SIZE SELECTOR
  // ===========================================================================

  Widget _buildTopSizeSelector() {
    final sizes = [2, 3, 4, 5, 6];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: sizes.map((size) {
          final isSelected = _selectedSize == size;
          return ChoiceChip(
            label: Text('${size}x$size'),
            selected: isSelected,
            onSelected: _isSolvingMode ? null : (_) => _onSizeChanged(size),
            selectedColor: AppColors.primaryAccent,
            backgroundColor: AppColors.surfaceElevated,
            labelStyle: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // EDITOR VIEW
  // ===========================================================================

  String _getAdjacentFaceGuide(CubeFace face, String position) {
    switch (face) {
      case CubeFace.up:
        switch (position) {
          case 'top': return 'Back (Blue)';
          case 'bottom': return 'Front (Green)';
          case 'left': return 'Left (Orange)';
          case 'right': return 'Right (Red)';
        }
        break;
      case CubeFace.down:
        switch (position) {
          case 'top': return 'Front (Green)';
          case 'bottom': return 'Back (Blue)';
          case 'left': return 'Left (Orange)';
          case 'right': return 'Right (Red)';
        }
        break;
      case CubeFace.front:
        switch (position) {
          case 'top': return 'Up (White)';
          case 'bottom': return 'Down (Yellow)';
          case 'left': return 'Left (Orange)';
          case 'right': return 'Right (Red)';
        }
        break;
      case CubeFace.back:
        switch (position) {
          case 'top': return 'Up (White)';
          case 'bottom': return 'Down (Yellow)';
          case 'left': return 'Right (Red)';
          case 'right': return 'Left (Orange)';
        }
        break;
      case CubeFace.left:
        switch (position) {
          case 'top': return 'Up (White)';
          case 'bottom': return 'Down (Yellow)';
          case 'left': return 'Back (Blue)';
          case 'right': return 'Front (Green)';
        }
        break;
      case CubeFace.right:
        switch (position) {
          case 'top': return 'Up (White)';
          case 'bottom': return 'Down (Yellow)';
          case 'left': return 'Front (Green)';
          case 'right': return 'Back (Blue)';
        }
        break;
    }
    return '';
  }

  Widget _buildCenterColorReferenceCheck() {
    if (_selectedSize % 2 == 0) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.secondaryAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Even cube (${_selectedSize}x$_selectedSize): No fixed centers. Orientation normalized by DBL corner.',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final stdCenter = CubeColor.values[_activeFaceView.index];
    final centerIdx = (_selectedSize * _selectedSize) ~/ 2;
    final actualCenter = _cubeState.faces[_activeFaceView]![centerIdx];
    final isMatch = stdCenter == actualCenter;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMatch ? AppColors.accentGreen.withAlpha(20) : Colors.amber.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMatch ? AppColors.accentGreen.withAlpha(80) : Colors.amberAccent.withAlpha(120),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isMatch ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
            size: 18,
            color: isMatch ? AppColors.accentGreen : Colors.amberAccent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white),
                children: [
                  const TextSpan(text: 'Center Reference: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(
                    text: isMatch
                        ? 'Center is correctly ${_getColorName(stdCenter)}'
                        : 'Center is ${_getColorName(actualCenter)}, expected ${_getColorName(stdCenter)}',
                    style: TextStyle(
                      color: isMatch ? AppColors.accentGreen : Colors.amberAccent,
                      fontWeight: FontWeight.w600,
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

  Widget _buildFaceOrientationGuide() {
    final isUDB = _activeFaceView == CubeFace.up || _activeFaceView == CubeFace.down || _activeFaceView == CubeFace.back;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUDB ? AppColors.primaryAccent.withAlpha(25) : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUDB ? AppColors.secondaryAccent.withAlpha(120) : AppColors.border,
          width: isUDB ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.explore_rounded,
                size: 16,
                color: isUDB ? AppColors.secondaryAccent : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                'Face Orientation Guide (${_getFaceName(_activeFaceView)})',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isUDB ? AppColors.secondaryAccent : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Viewing cube from outside (standard unfolded net):\n'
            '• Top edge aligns with: ${_getAdjacentFaceGuide(_activeFaceView, 'top')}\n'
            '• Bottom edge aligns with: ${_getAdjacentFaceGuide(_activeFaceView, 'bottom')}\n'
            '• Left edge aligns with: ${_getAdjacentFaceGuide(_activeFaceView, 'left')}\n'
            '• Right edge aligns with: ${_getAdjacentFaceGuide(_activeFaceView, 'right')}',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Face Selector Carousel / Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: CubeFace.values.map((face) {
                final isSelected = _activeFaceView == face;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _activeFaceView = face),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.secondaryAccent.withAlpha(40) : AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.secondaryAccent : AppColors.border,
                        ),
                      ),
                      child: Text(
                        _getFaceName(face),
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.secondaryAccent : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // Center-Color Reference Check
          _buildCenterColorReferenceCheck(),

          // Face Orientation Guide for U/D/B
          _buildFaceOrientationGuide(),

          // Main Face Matrix to Color with Direction Markers
          Text(
            'Tap any square to paint with ${_getColorName(_selectedPaintColor)}',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '▲ ${_getAdjacentFaceGuide(_activeFaceView, 'top')}',
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white60),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        '◀ ${_getAdjacentFaceGuide(_activeFaceView, 'left')}',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white60),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1118),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(150),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: _buildFaceGrid(_activeFaceView, isInteractive: true),
                    ),
                    const SizedBox(width: 8),
                    RotatedBox(
                      quarterTurns: 1,
                      child: Text(
                        '▶ ${_getAdjacentFaceGuide(_activeFaceView, 'right')}',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white60),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '▼ ${_getAdjacentFaceGuide(_activeFaceView, 'bottom')}',
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white60),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick Start Button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryAccent.withAlpha(120),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isComputingSolution ? null : _startSolving,
              icon: _isComputingSolution
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(
                _isComputingSolution ? 'Calculating Solution...' : 'Start Solving 🚀',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceGrid(CubeFace face, {required bool isInteractive, double sizeMultiplier = 1.0}) {
    final facelets = _cubeState.faces[face]!;
    final baseTileSize = (220.0 / _selectedSize) * sizeMultiplier;
    final isOddCube = _selectedSize % 2 == 1;
    final centerIdx = (_selectedSize * _selectedSize) ~/ 2;

    return SizedBox(
      width: baseTileSize * _selectedSize + (_selectedSize - 1) * 3,
      height: baseTileSize * _selectedSize + (_selectedSize - 1) * 3,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _selectedSize,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
        ),
        itemCount: facelets.length,
        itemBuilder: (ctx, idx) {
          final color = facelets[idx];
          final isCenterTile = isOddCube && idx == centerIdx;

          return InkWell(
            onTap: isInteractive
                ? () {
                    if (isCenterTile) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Center pieces are fixed on ${_selectedSize}x$_selectedSize. This is the ${_getColorName(color)} face.',
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppColors.surfaceElevated,
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _cubeState.setColor(face, idx, _selectedPaintColor);
                    });
                  }
                : null,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              decoration: BoxDecoration(
                color: _getFlutterColor(color),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isCenterTile ? Colors.white70 : Colors.black.withAlpha(100),
                  width: isCenterTile ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
              child: isCenterTile
                  ? const Center(
                      child: Icon(Icons.lock_outline_rounded, size: 14, color: Colors.black54),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // BOTTOM COLOR PALETTE
  // ===========================================================================

  Widget _buildBottomColorPalette() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Color Palette:',
                style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              Text(
                'Selected: ${_getColorName(_selectedPaintColor)}',
                style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.secondaryAccent, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: CubeColor.values.map((col) {
              final isSelected = _selectedPaintColor == col;
              return GestureDetector(
                onTap: () => setState(() => _selectedPaintColor = col),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 44 : 36,
                  height: isSelected ? 44 : 36,
                  decoration: BoxDecoration(
                    color: _getFlutterColor(col),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.black.withAlpha(120),
                      width: isSelected ? 3 : 1.5,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: _getFlutterColor(col).withAlpha(180),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, size: 20, color: Colors.black)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SOLVING VIEW & ANIMATION
  // ===========================================================================

  Widget _buildSolvingView() {
    if (_solutionSteps.isEmpty) return const SizedBox();

    final isDone = _currentStepIndex >= _solutionSteps.length;
    final currentStep = isDone
        ? _solutionSteps.last
        : _solutionSteps[_currentStepIndex];

    final progress = (_currentStepIndex) / _solutionSteps.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Step Progress Bar
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppColors.surfaceCard,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondaryAccent),
            minHeight: 6,
          ),
          const SizedBox(height: 12),

          // Stage Title & Step Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryAccent.withAlpha(80), width: 0.8),
                ),
                child: Text(
                  currentStep.stage,
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondaryAccent),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currentStep.moveNotation,
                      style: GoogleFonts.firaCode(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentStep.isPhysicalFix
                        ? 'Step 0'
                        : '${currentStep.stepNumber} / ${_solutionSteps.where((s) => !s.isPhysicalFix).length}',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action Directive Banner (Highlighting exact moving slice and direction)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondaryAccent.withAlpha(35),
                  AppColors.primaryAccent.withAlpha(25),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.secondaryAccent.withAlpha(160), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondaryAccent.withAlpha(40),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    currentStep.arrowSymbol,
                    style: const TextStyle(fontSize: 20, color: Colors.black, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentStep.actionSummary.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondaryAccent,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentStep.instruction,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!currentStep.isPhysicalFix)
                  IconButton(
                    tooltip: 'Replay Animation',
                    icon: const Icon(Icons.replay_circle_filled_rounded, color: AppColors.secondaryAccent, size: 26),
                    onPressed: _replayCurrentStepAnimation,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Interactive 3D Perspective Cube with Slice Highlight & Physics Animation
          _buildSolvingCubeDisplay(currentStep),

          const SizedBox(height: 12),
          Text(
            currentStep.isPhysicalFix
                ? 'Physically adjust the piece on your cube, then tap continue 🔧'
                : 'Tap moving slice or replay button to re-watch movement animation 🎬',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  String _getOrdinal(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  Widget _buildTile(CubeColor color, double tileSize) {
    return Container(
      margin: const EdgeInsets.all(1.5),
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(
        color: _getFlutterColor(color),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black.withAlpha(140), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
    );
  }


  Map<String, AdjacentStripInfo> _getAdjacentStrips(CubeFace face) {
    final size = _selectedSize;
    final up = _cubeState.faces[CubeFace.up]!;
    final down = _cubeState.faces[CubeFace.down]!;
    final front = _cubeState.faces[CubeFace.front]!;
    final back = _cubeState.faces[CubeFace.back]!;
    final left = _cubeState.faces[CubeFace.left]!;
    final right = _cubeState.faces[CubeFace.right]!;

    switch (face) {
      case CubeFace.front:
        return {
          'top': AdjacentStripInfo(
            label: 'TOP (White)',
            labelColor: Colors.white70,
            colors: List.generate(size, (c) => up[(size - 1) * size + c]),
          ),
          'bottom': AdjacentStripInfo(
            label: 'DOWN (Yellow)',
            labelColor: const Color(0xFFFFD500),
            colors: List.generate(size, (c) => down[0 * size + c]),
          ),
          'left': AdjacentStripInfo(
            label: 'L',
            labelColor: const Color(0xFFFF8800),
            colors: List.generate(size, (r) => left[r * size + (size - 1)]),
          ),
          'right': AdjacentStripInfo(
            label: 'R',
            labelColor: const Color(0xFFE51A24),
            colors: List.generate(size, (r) => right[r * size + 0]),
          ),
        };
      case CubeFace.back:
        return {
          'top': AdjacentStripInfo(
            label: 'TOP (White)',
            labelColor: Colors.white70,
            colors: List.generate(size, (c) => up[0 * size + (size - 1 - c)]),
          ),
          'bottom': AdjacentStripInfo(
            label: 'DOWN (Yellow)',
            labelColor: const Color(0xFFFFD500),
            colors: List.generate(size, (c) => down[(size - 1) * size + (size - 1 - c)]),
          ),
          'left': AdjacentStripInfo(
            label: 'R (Red)',
            labelColor: const Color(0xFFE51A24),
            colors: List.generate(size, (r) => right[r * size + (size - 1)]),
          ),
          'right': AdjacentStripInfo(
            label: 'L (Orange)',
            labelColor: const Color(0xFFFF8800),
            colors: List.generate(size, (r) => left[r * size + 0]),
          ),
        };
      case CubeFace.up:
        return {
          'top': AdjacentStripInfo(
            label: 'BACK (Blue)',
            labelColor: const Color(0xFF0046AD),
            colors: List.generate(size, (c) => back[0 * size + (size - 1 - c)]),
          ),
          'bottom': AdjacentStripInfo(
            label: 'FRONT (Green)',
            labelColor: const Color(0xFF009B48),
            colors: List.generate(size, (c) => front[0 * size + c]),
          ),
          'left': AdjacentStripInfo(
            label: 'L (Orange)',
            labelColor: const Color(0xFFFF8800),
            colors: List.generate(size, (c) => left[0 * size + c]),
          ),
          'right': AdjacentStripInfo(
            label: 'R (Red)',
            labelColor: const Color(0xFFE51A24),
            colors: List.generate(size, (c) => right[0 * size + (size - 1 - c)]),
          ),
        };
      case CubeFace.down:
        return {
          'top': AdjacentStripInfo(
            label: 'FRONT (Green)',
            labelColor: const Color(0xFF009B48),
            colors: List.generate(size, (c) => front[(size - 1) * size + c]),
          ),
          'bottom': AdjacentStripInfo(
            label: 'BACK (Blue)',
            labelColor: const Color(0xFF0046AD),
            colors: List.generate(size, (c) => back[(size - 1) * size + (size - 1 - c)]),
          ),
          'left': AdjacentStripInfo(
            label: 'L (Orange)',
            labelColor: const Color(0xFFFF8800),
            colors: List.generate(size, (c) => left[(size - 1) * size + (size - 1 - c)]),
          ),
          'right': AdjacentStripInfo(
            label: 'R (Red)',
            labelColor: const Color(0xFFE51A24),
            colors: List.generate(size, (c) => right[(size - 1) * size + c]),
          ),
        };
      case CubeFace.left:
        return {
          'top': AdjacentStripInfo(
            label: 'TOP (White)',
            labelColor: Colors.white70,
            colors: List.generate(size, (r) => up[r * size + 0]),
          ),
          'bottom': AdjacentStripInfo(
            label: 'DOWN (Yellow)',
            labelColor: const Color(0xFFFFD500),
            colors: List.generate(size, (r) => down[(size - 1 - r) * size + 0]),
          ),
          'left': AdjacentStripInfo(
            label: 'BACK (Blue)',
            labelColor: const Color(0xFF0046AD),
            colors: List.generate(size, (r) => back[r * size + (size - 1)]),
          ),
          'right': AdjacentStripInfo(
            label: 'FRONT (Green)',
            labelColor: const Color(0xFF009B48),
            colors: List.generate(size, (r) => front[r * size + 0]),
          ),
        };
      case CubeFace.right:
        return {
          'top': AdjacentStripInfo(
            label: 'TOP (White)',
            labelColor: Colors.white70,
            colors: List.generate(size, (r) => up[(size - 1 - r) * size + (size - 1)]),
          ),
          'bottom': AdjacentStripInfo(
            label: 'DOWN (Yellow)',
            labelColor: const Color(0xFFFFD500),
            colors: List.generate(size, (r) => down[r * size + (size - 1)]),
          ),
          'left': AdjacentStripInfo(
            label: 'FRONT (Green)',
            labelColor: const Color(0xFF009B48),
            colors: List.generate(size, (r) => front[r * size + (size - 1)]),
          ),
          'right': AdjacentStripInfo(
            label: 'BACK (Blue)',
            labelColor: const Color(0xFF0046AD),
            colors: List.generate(size, (r) => back[r * size + 0]),
          ),
        };
    }
  }

  Widget _buildSolvingCubeDisplay(CubeStep currentStep) {
    if (currentStep.isPhysicalFix) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1A24),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.amberAccent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.amberAccent.withAlpha(50),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amberAccent.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.build_circle_rounded, color: Colors.amberAccent, size: 44),
            ),
            const SizedBox(height: 14),
            Text(
              'Step 0: Physical Cube Alignment',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amberAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              currentStep.instruction,
              style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                'Once adjusted on your physical cube, tap "Continue to Next Step" below to begin turning.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    final double tileSize = (190.0 / _selectedSize).clamp(28.0, 56.0);
    final bool isBackMove = currentStep.moveNotation.startsWith('B');
    final CubeFace activeFace = _inspectFace ?? (isBackMove ? CubeFace.back : CubeFace.front);
    final strips = _getAdjacentStrips(activeFace);
    final displayedFacelets = _cubeState.faces[activeFace]!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Face Inspection Selector Chips during solve
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Inspect Face: ',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                ...CubeFace.values.map((f) {
                  final isSelected = activeFace == f;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: InkWell(
                      onTap: () => setState(() => _inspectFace = f),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.secondaryAccent : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getFaceName(f).split(' ')[0],
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.black : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                if (_inspectFace != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: InkWell(
                      onTap: () => setState(() => _inspectFace = null),
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Explicit Viewing Banner so user always knows which face is displayed
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: activeFace == CubeFace.back
                ? const Color(0xFF0046AD).withAlpha(50)
                : AppColors.primaryAccent.withAlpha(35),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: activeFace == CubeFace.back ? const Color(0xFF0046AD) : AppColors.primaryAccent,
              width: 1,
            ),
          ),
          child: Text(
            activeFace == CubeFace.back
                ? '👀 Looking at BACK Face (Blue Center) — Rotate Back face'
                : '👀 Viewing: ${_getFaceName(activeFace)}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: activeFace == CubeFace.back ? Colors.lightBlueAccent : Colors.white,
            ),
          ),
        ),

        // Column Markers if move is column-based on Front face
        if (activeFace == CubeFace.front && currentStep.sliceType == 'col') ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_selectedSize, (c) {
                final isTarget = c == currentStep.sliceIndex;
                return Container(
                  width: tileSize + 3,
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isTarget ? AppColors.secondaryAccent : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        if (isTarget)
                          BoxShadow(
                            color: AppColors.secondaryAccent.withAlpha(150),
                            blurRadius: 6,
                          ),
                      ],
                    ),
                    child: Text(
                      isTarget ? '${c + 1}${_getOrdinal(c + 1)} ★' : '${c + 1}${_getOrdinal(c + 1)}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isTarget ? Colors.black : AppColors.textMuted,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],

        // Top Edge Strip
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xFF141724),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${strips['top']!.label}  ',
                  style: GoogleFonts.inter(fontSize: 9.5, color: strips['top']!.labelColor, fontWeight: FontWeight.w600)),
              ...List.generate(_selectedSize, (c) {
                final col = strips['top']!.colors[c];
                final isTargetCol = activeFace == CubeFace.front && currentStep.sliceType == 'col' && c == currentStep.sliceIndex;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: tileSize * 0.65,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getFlutterColor(col),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: isTargetCol ? AppColors.secondaryAccent : Colors.black45,
                      width: isTargetCol ? 1.5 : 0.5,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        // Middle Row: Left Edge + Center Face + Right Edge
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Edge strip
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF141724),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strips['left']!.label,
                      style: GoogleFonts.inter(fontSize: 10, color: strips['left']!.labelColor, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  ...List.generate(_selectedSize, (r) {
                    final col = strips['left']!.colors[r];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 1.5),
                      width: 14,
                      height: tileSize,
                      decoration: BoxDecoration(
                        color: _getFlutterColor(col),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.black54, width: 0.8),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Central Face Grid (With animation if on active move face)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0E14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(160),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: activeFace == CubeFace.front
                  ? _buildCentralFaceWithSliceAnimation(currentStep, tileSize, displayedFacelets)
                  : _buildFaceGrid(activeFace, isInteractive: false, sizeMultiplier: 0.85),
            ),

            // Right Edge strip
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF141724),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strips['right']!.label,
                      style: GoogleFonts.inter(fontSize: 10, color: strips['right']!.labelColor, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  ...List.generate(_selectedSize, (r) {
                    final col = strips['right']!.colors[r];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 1.5),
                      width: 14,
                      height: tileSize,
                      decoration: BoxDecoration(
                        color: _getFlutterColor(col),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.black54, width: 0.8),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),

        // Bottom Edge Strip
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xFF141724),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${strips['bottom']!.label}  ',
                  style: GoogleFonts.inter(fontSize: 9.5, color: strips['bottom']!.labelColor, fontWeight: FontWeight.w600)),
              ...List.generate(_selectedSize, (c) {
                final col = strips['bottom']!.colors[c];
                final isTargetCol = activeFace == CubeFace.front && currentStep.sliceType == 'col' && c == currentStep.sliceIndex;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: tileSize * 0.65,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getFlutterColor(col),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: isTargetCol ? AppColors.secondaryAccent : Colors.black45,
                      width: isTargetCol ? 1.5 : 0.5,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        // Row Markers if move is row-based on Front face
        if (activeFace == CubeFace.front && currentStep.sliceType == 'row') ...[
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_selectedSize, (r) {
                final isTarget = r == currentStep.sliceIndex;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isTarget ? AppColors.secondaryAccent : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      if (isTarget)
                        BoxShadow(
                          color: AppColors.secondaryAccent.withAlpha(150),
                          blurRadius: 6,
                        ),
                    ],
                  ),
                  child: Text(
                    isTarget ? 'Row ${r + 1} ★' : 'Row ${r + 1}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isTarget ? Colors.black : AppColors.textMuted,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCentralFaceWithSliceAnimation(CubeStep currentStep, double tileSize, List<CubeColor> frontFacelets) {
    final isDouble = currentStep.moveNotation.contains('2');
    final double targetAngle = isDouble ? pi : (pi / 2);

    if (currentStep.sliceType == 'col') {
      // Column slice 3D perspective animation (e.g. R rotates 3rd column around X axis)
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_selectedSize, (colIdx) {
          final isTargetCol = colIdx == currentStep.sliceIndex;
          if (isTargetCol) {
            return AnimatedBuilder(
              animation: _animController,
              builder: (ctx, child) {
                final double angle = _animController.value * currentStep.directionSign * targetAngle;
                final double slideDist = tileSize * 0.35;
                final double yOffset = _animController.value * currentStep.directionSign * slideDist;
                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..setTranslationRaw(0.0, yOffset, 0.0)
                    ..rotateX(angle),
                  alignment: Alignment.center,
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: _replayCurrentStepAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.secondaryAccent, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondaryAccent.withAlpha(160),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_selectedSize, (rowIdx) {
                          final color = frontFacelets[rowIdx * _selectedSize + colIdx];
                          return _buildTile(color, tileSize);
                        }),
                      ),
                      // Floating bouncing directional arrow indicator
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (ctx, _) {
                          final double bounce = currentStep.directionSign < 0 ? _pulseAnim.value : -_pulseAnim.value;
                          return Transform.translate(
                            offset: Offset(0, bounce),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(220),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.secondaryAccent, width: 1.5),
                              ),
                              child: Text(
                                currentStep.arrowSymbol,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.secondaryAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            return Opacity(
              opacity: 0.6,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_selectedSize, (rowIdx) {
                  final color = frontFacelets[rowIdx * _selectedSize + colIdx];
                  return _buildTile(color, tileSize);
                }),
              ),
            );
          }
        }),
      );
    } else if (currentStep.sliceType == 'row') {
      // Row slice 3D perspective animation (e.g. U rotates Top row around Y axis)
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_selectedSize, (rowIdx) {
          final isTargetRow = rowIdx == currentStep.sliceIndex;
          if (isTargetRow) {
            return AnimatedBuilder(
              animation: _animController,
              builder: (ctx, child) {
                final double angle = _animController.value * currentStep.directionSign * targetAngle;
                final double slideDist = tileSize * 0.35;
                final double xOffset = _animController.value * currentStep.directionSign * slideDist;
                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..setTranslationRaw(xOffset, 0.0, 0.0)
                    ..rotateY(-angle),
                  alignment: Alignment.center,
                  child: child,
                );
              },
              child: GestureDetector(
                onTap: _replayCurrentStepAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.secondaryAccent, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondaryAccent.withAlpha(160),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_selectedSize, (colIdx) {
                          final color = frontFacelets[rowIdx * _selectedSize + colIdx];
                          return _buildTile(color, tileSize);
                        }),
                      ),
                      // Floating bouncing directional arrow indicator
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (ctx, _) {
                          final double bounce = currentStep.directionSign < 0 ? _pulseAnim.value : -_pulseAnim.value;
                          return Transform.translate(
                            offset: Offset(bounce, 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(220),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.secondaryAccent, width: 1.5),
                              ),
                              child: Text(
                                currentStep.arrowSymbol,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.secondaryAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            return Opacity(
              opacity: 0.6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_selectedSize, (colIdx) {
                  final color = frontFacelets[rowIdx * _selectedSize + colIdx];
                  return _buildTile(color, tileSize);
                }),
              ),
            );
          }
        }),
      );
    } else {
      // Face 3D perspective rotation animation (e.g. F rotates Front face clockwise)
      return AnimatedBuilder(
        animation: _animController,
        builder: (ctx, child) {
          final double angle = _animController.value * currentStep.directionSign * targetAngle;
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateZ(angle),
            alignment: Alignment.center,
            child: child,
          );
        },
        child: GestureDetector(
          onTap: _replayCurrentStepAnimation,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.secondaryAccent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondaryAccent.withAlpha(140),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildFaceGrid(currentStep.faceToRotate, isInteractive: false, sizeMultiplier: 0.85),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(210),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.secondaryAccent, width: 2),
                  ),
                  child: Text(
                    currentStep.arrowSymbol,
                    style: const TextStyle(
                      fontSize: 32,
                      color: AppColors.secondaryAccent,
                      fontWeight: FontWeight.bold,
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

  // ===========================================================================
  // SOLVING CONTROLS BAR (CONTINUE TO NEXT STEP)
  // ===========================================================================

  Widget _buildSolvingControlsBar() {
    final isDone = _currentStepIndex >= _solutionSteps.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Previous Step
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, size: 28),
                color: _currentStepIndex > 0 ? Colors.white : AppColors.textMuted,
                tooltip: 'Previous Step',
                onPressed: _currentStepIndex > 0 ? _prevStep : null,
              ),

              // Replay Animation Button
              IconButton(
                icon: const Icon(Icons.replay_circle_filled_rounded, size: 28),
                color: AppColors.secondaryAccent,
                tooltip: 'Replay Move Animation',
                onPressed: isDone ? null : _replayCurrentStepAnimation,
              ),

              // Auto-play button
              IconButton(
                icon: Icon(_isAutoPlaying ? Icons.pause_circle_rounded : Icons.play_circle_rounded, size: 28),
                color: Colors.white,
                tooltip: _isAutoPlaying ? 'Pause Auto-Play' : 'Auto-Play Solution',
                onPressed: isDone ? null : _toggleAutoPlay,
              ),

              // Auto-Play Speed Selector Chip (Matching Cube Solver 1s, 2s, 3s cycle)
              InkWell(
                onTap: _cycleAutoPlaySpeed,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.secondaryAccent.withAlpha(140), width: 1),
                  ),
                  child: Text(
                    '⚡ ${(_autoPlaySpeedMs / 1000).toStringAsFixed(0)}s',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondaryAccent,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Prominent "Continue to Next Step" Button
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDone
                          ? [AppColors.accentGreen, const Color(0xFF00B894)]
                          : [const Color(0xFF6C5CE7), const Color(0xFF00CEC9)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryAccent.withAlpha(100),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: isDone ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: isDone ? _showSolvedCelebrationDialog : _nextStep,
                    icon: Icon(isDone ? Icons.check_circle_rounded : Icons.arrow_forward_rounded, size: 20),
                    label: Text(
                      isDone ? 'Solved! 🎉' : 'Continue to Next Step ⏭️',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
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

class AdjacentStripInfo {
  final String label;
  final Color labelColor;
  final List<CubeColor> colors;

  AdjacentStripInfo({
    required this.label,
    required this.labelColor,
    required this.colors,
  });
}
