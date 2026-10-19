import 'cube_state.dart';

class CubeMoveEngine {
  /// Applies a move notation string to the cube state
  static void applyMove(RubiksCubeState state, String notation) {
    final clean = notation.trim();
    if (clean.isEmpty) return;
    if (clean == 'FLIP' || clean == 'TWIST' || clean.startsWith('PHYSICAL')) {
      // Physical piece adjustment on physical cube; does not rotate virtual faces
      return;
    }

    // Whole cube rotations
    if (clean.startsWith('x') || clean.startsWith('y') || clean.startsWith('z')) {
      _applyCubeRotation(state, clean);
      return;
    }

    // Slice moves: M, E, S
    if (clean.startsWith('M') || clean.startsWith('E') || clean.startsWith('S')) {
      _applySliceMove(state, clean);
      return;
    }

    // Standard face turns, wide turns (Rw, Uw...), or slice numbers (2R, 3Rw...)
    _applyLayeredMove(state, clean);
  }

  static void _applyCubeRotation(RubiksCubeState state, String notation) {
    final char = notation[0];
    final isPrime = notation.contains("'");
    final isDouble = notation.contains('2');
    final turns = isDouble ? 2 : (isPrime ? 3 : 1);

    for (int t = 0; t < turns; t++) {
      if (char == 'x') {
        // Rotation following R: all layers along R axis
        for (int layer = 0; layer < state.size; layer++) {
          _cycleAxisRL(state, layer, isR: true);
        }
        _rotateMatrixClockwise(state, CubeFace.right);
        _rotateMatrixCounterClockwise(state, CubeFace.left);
      } else if (char == 'y') {
        // Rotation following U: all layers along U axis
        for (int layer = 0; layer < state.size; layer++) {
          _cycleAxisUD(state, layer, isU: true);
        }
        _rotateMatrixClockwise(state, CubeFace.up);
        _rotateMatrixCounterClockwise(state, CubeFace.down);
      } else if (char == 'z') {
        // Rotation following F: all layers along F axis
        for (int layer = 0; layer < state.size; layer++) {
          _cycleAxisFB(state, layer, isF: true);
        }
        _rotateMatrixClockwise(state, CubeFace.front);
        _rotateMatrixCounterClockwise(state, CubeFace.back);
      }
    }
  }

  static void _applySliceMove(RubiksCubeState state, String notation) {
    if (state.size < 3) return; // Slice moves only meaningful for N >= 3
    final char = notation[0];
    final isPrime = notation.contains("'");
    final isDouble = notation.contains('2');
    final turns = isDouble ? 2 : (isPrime ? 3 : 1);

    // For N = 3, middle layer index is 1. For general N, middle slices are between 1 and size-2.
    final middleSlice = state.size ~/ 2;

    for (int t = 0; t < turns; t++) {
      if (char == 'M') {
        // M moves in the same direction as L (downwards on Front face)
        _cycleAxisRL(state, middleSlice, isR: false);
      } else if (char == 'E') {
        // E moves in the same direction as D (rightwards on Front face)
        _cycleAxisUD(state, middleSlice, isU: false);
      } else if (char == 'S') {
        // S moves in the same direction as F (clockwise on middle slice)
        _cycleAxisFB(state, middleSlice, isF: true);
      }
    }
  }

  static void _applyLayeredMove(RubiksCubeState state, String notation) {
    final isPrime = notation.contains("'");
    final isDouble = notation.contains('2');
    final turns = isDouble ? 2 : (isPrime ? 3 : 1);

    int startLayer = 0;
    int endLayer = 0; // inclusive
    String baseFace = '';

    // Check for prefix number, e.g. "2R", "3Rw"
    int idx = 0;
    while (idx < notation.length && notation[idx].codeUnitAt(0) >= 48 && notation[idx].codeUnitAt(0) <= 57) {
      idx++;
    }

    int prefixNum = 1;
    if (idx > 0) {
      prefixNum = int.parse(notation.substring(0, idx));
    }

    final remaining = notation.substring(idx);
    final isWide = remaining.contains('w') || (remaining.isNotEmpty && remaining[0] == remaining[0].toLowerCase());

    if (remaining.isNotEmpty) {
      baseFace = remaining[0].toUpperCase();
    }

    if (baseFace.isEmpty) return;

    if (isWide) {
      // Wide turn: e.g. "Rw" (layers 0..1), "3Rw" (layers 0..2)
      startLayer = 0;
      endLayer = idx > 0 ? (prefixNum - 1) : 1;
      if (endLayer >= state.size) endLayer = state.size - 1;
    } else if (idx > 0) {
      // Inner slice turn: e.g. "2R" (turns layer index 1 alone)
      startLayer = prefixNum - 1;
      endLayer = startLayer;
      if (startLayer >= state.size) return;
    } else {
      // Standard face turn: layer 0 alone
      startLayer = 0;
      endLayer = 0;
    }

    CubeFace? face;
    switch (baseFace) {
      case 'U': face = CubeFace.up; break;
      case 'D': face = CubeFace.down; break;
      case 'F': face = CubeFace.front; break;
      case 'B': face = CubeFace.back; break;
      case 'L': face = CubeFace.left; break;
      case 'R': face = CubeFace.right; break;
    }

    if (face == null) return;

    for (int t = 0; t < turns; t++) {
      // 1. If outer face (layer 0) is turned, rotate that face's 2D matrix
      if (startLayer == 0) {
        _rotateMatrixClockwise(state, face);
      }
      // 2. If innermost face is turned (e.g. wide turn affecting all layers)
      if (endLayer == state.size - 1 && startLayer == 0) {
        CubeFace oppositeFace;
        switch (face) {
          case CubeFace.up: oppositeFace = CubeFace.down; break;
          case CubeFace.down: oppositeFace = CubeFace.up; break;
          case CubeFace.front: oppositeFace = CubeFace.back; break;
          case CubeFace.back: oppositeFace = CubeFace.front; break;
          case CubeFace.left: oppositeFace = CubeFace.right; break;
          case CubeFace.right: oppositeFace = CubeFace.left; break;
        }
        _rotateMatrixCounterClockwise(state, oppositeFace);
      }

      // 3. Cycle the adjacent edges for all layers in [startLayer..endLayer]
      for (int layer = startLayer; layer <= endLayer; layer++) {
        switch (face) {
          case CubeFace.up:
            _cycleAxisUD(state, layer, isU: true);
            break;
          case CubeFace.down:
            _cycleAxisUD(state, layer, isU: false);
            break;
          case CubeFace.front:
            _cycleAxisFB(state, layer, isF: true);
            break;
          case CubeFace.back:
            _cycleAxisFB(state, layer, isF: false);
            break;
          case CubeFace.right:
            _cycleAxisRL(state, layer, isR: true);
            break;
          case CubeFace.left:
            _cycleAxisRL(state, layer, isR: false);
            break;
        }
      }
    }
  }

  // ===========================================================================
  // 2D MATRIX ROTATIONS
  // ===========================================================================

  static void _rotateMatrixClockwise(RubiksCubeState state, CubeFace face) {
    final size = state.size;
    final cur = state.faces[face]!;
    final next = List<CubeColor>.from(cur);
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        // Clockwise: (r, c) -> (c, size - 1 - r)
        next[c * size + (size - 1 - r)] = cur[r * size + c];
      }
    }
    state.faces[face] = next;
  }

  static void _rotateMatrixCounterClockwise(RubiksCubeState state, CubeFace face) {
    final size = state.size;
    final cur = state.faces[face]!;
    final next = List<CubeColor>.from(cur);
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        // Counter-Clockwise: (r, c) -> (size - 1 - c, r)
        next[(size - 1 - c) * size + r] = cur[r * size + c];
      }
    }
    state.faces[face] = next;
  }

  // ===========================================================================
  // AXIS SLICE CYCLES (Rigorous, Verified for any Size N in 2..6)
  // ===========================================================================

  /// Cycles layers along the Up-Down vertical axis.
  /// If isU is true: clockwise rotation looking at Up face (layer from 0=top to size-1=bottom)
  /// If isU is false: clockwise rotation looking at Down face (layer from 0=bottom to size-1=top)
  static void _cycleAxisUD(RubiksCubeState state, int layer, {required bool isU}) {
    final size = state.size;
    final row = isU ? layer : (size - 1 - layer);

    final front = state.faces[CubeFace.front]!;
    final left = state.faces[CubeFace.left]!;
    final back = state.faces[CubeFace.back]!;
    final right = state.faces[CubeFace.right]!;

    final tempFront = List<CubeColor>.generate(size, (i) => front[row * size + i]);

    if (isU) {
      // U clockwise: Front <- Right, Right <- Back, Back <- Left, Left <- tempFront
      for (int i = 0; i < size; i++) {
        front[row * size + i] = right[row * size + i];
        right[row * size + i] = back[row * size + i];
        back[row * size + i] = left[row * size + i];
        left[row * size + i] = tempFront[i];
      }
    } else {
      // D clockwise: Front <- Left, Left <- Back, Back <- Right, Right <- tempFront
      for (int i = 0; i < size; i++) {
        front[row * size + i] = left[row * size + i];
        left[row * size + i] = back[row * size + i];
        back[row * size + i] = right[row * size + i];
        right[row * size + i] = tempFront[i];
      }
    }
  }

  /// Cycles layers along the Right-Left horizontal axis.
  /// If isR is true: clockwise rotation looking at Right face (layer from 0=rightmost to size-1=leftmost)
  /// If isR is false: clockwise rotation looking at Left face (layer from 0=leftmost to size-1=rightmost)
  static void _cycleAxisRL(RubiksCubeState state, int layer, {required bool isR}) {
    final size = state.size;
    final upCol = isR ? (size - 1 - layer) : layer;
    final downCol = isR ? (size - 1 - layer) : layer;
    final frontCol = isR ? (size - 1 - layer) : layer;
    final backCol = isR ? layer : (size - 1 - layer);

    final up = state.faces[CubeFace.up]!;
    final front = state.faces[CubeFace.front]!;
    final down = state.faces[CubeFace.down]!;
    final back = state.faces[CubeFace.back]!;

    final sliceUp = List<CubeColor>.generate(size, (r) => up[r * size + upCol]);
    final sliceFront = List<CubeColor>.generate(size, (r) => front[r * size + frontCol]);
    final sliceDown = List<CubeColor>.generate(size, (r) => down[r * size + downCol]);
    final sliceBack = List<CubeColor>.generate(size, (r) => back[r * size + backCol]);

    if (isR) {
      // R clockwise:
      // Up <- Front
      // Front <- Down
      // Down <- Back (inverted top-to-bottom)
      // Back <- Up (inverted top-to-bottom)
      for (int r = 0; r < size; r++) {
        up[r * size + upCol] = sliceFront[r];
        front[r * size + frontCol] = sliceDown[r];
        down[r * size + downCol] = sliceBack[size - 1 - r];
        back[r * size + backCol] = sliceUp[size - 1 - r];
      }
    } else {
      // L clockwise:
      // Up <- Back (inverted top-to-bottom)
      // Back <- Down (inverted top-to-bottom)
      // Down <- Front
      // Front <- Up
      for (int r = 0; r < size; r++) {
        up[r * size + upCol] = sliceBack[size - 1 - r];
        back[r * size + backCol] = sliceDown[size - 1 - r];
        down[r * size + downCol] = sliceFront[r];
        front[r * size + frontCol] = sliceUp[r];
      }
    }
  }

  /// Cycles layers along the Front-Back depth axis.
  /// If isF is true: clockwise rotation looking at Front face (layer from 0=front to size-1=back)
  /// If isF is false: clockwise rotation looking at Back face (layer from 0=back to size-1=front)
  static void _cycleAxisFB(RubiksCubeState state, int layer, {required bool isF}) {
    final size = state.size;
    final upRow = isF ? (size - 1 - layer) : layer;
    final downRow = isF ? layer : (size - 1 - layer);
    final rightCol = isF ? layer : (size - 1 - layer);
    final leftCol = isF ? (size - 1 - layer) : layer;

    final up = state.faces[CubeFace.up]!;
    final right = state.faces[CubeFace.right]!;
    final down = state.faces[CubeFace.down]!;
    final left = state.faces[CubeFace.left]!;

    final sliceUp = List<CubeColor>.generate(size, (c) => up[upRow * size + c]);
    final sliceRight = List<CubeColor>.generate(size, (r) => right[r * size + rightCol]);
    final sliceDown = List<CubeColor>.generate(size, (c) => down[downRow * size + c]);
    final sliceLeft = List<CubeColor>.generate(size, (r) => left[r * size + leftCol]);

    if (isF) {
      // F clockwise:
      // Up row <- Left col (inverted)
      // Right col <- Up row
      // Down row <- Right col (inverted)
      // Left col <- Down row
      for (int i = 0; i < size; i++) {
        up[upRow * size + i] = sliceLeft[size - 1 - i];
        right[i * size + rightCol] = sliceUp[i];
        down[downRow * size + i] = sliceRight[size - 1 - i];
        left[i * size + leftCol] = sliceDown[i];
      }
    } else {
      // B clockwise (looking at Back face):
      // Up row <- Right col
      // Left col <- Up row (inverted)
      // Down row <- Left col
      // Right col <- Down row (inverted)
      for (int i = 0; i < size; i++) {
        up[upRow * size + i] = sliceRight[i];
        left[i * size + leftCol] = sliceUp[size - 1 - i];
        down[downRow * size + i] = sliceLeft[i];
        right[i * size + rightCol] = sliceDown[size - 1 - i];
      }
    }
  }

  // ===========================================================================
  // INVERSE MOVE & STEP FACTORY
  // ===========================================================================

  static String getInverseMove(String move) {
    final clean = move.trim();
    if (clean.isEmpty) return '';
    if (clean == 'FLIP' || clean == 'TWIST' || clean.startsWith('PHYSICAL')) return clean;
    if (clean.endsWith('2')) return clean; // 180° move inverse is itself
    if (clean.endsWith("'")) return clean.replaceAll("'", "");
    return "$clean'";
  }

  static CubeStep createStep({
    required int stepNumber,
    required int totalSteps,
    required String moveNotation,
    required int size,
    String? customStage,
    String? customInstr,
    bool isPhysicalFix = false,
  }) {
    final clean = moveNotation.trim();
    if (clean == 'FLIP' || clean == 'TWIST' || clean.startsWith('PHYSICAL') || isPhysicalFix) {
      return CubeStep(
        stepNumber: stepNumber,
        totalSteps: totalSteps,
        moveNotation: clean,
        instruction: customInstr ??
            (clean == 'FLIP'
                ? 'Physical Edge Flip: Gently pop out and flip the physical edge piece in place.'
                : 'Physical Corner Twist: Gently twist the physical corner piece in place.'),
        stage: customStage ?? 'Physical Parity Adjustment',
        faceToRotate: CubeFace.front,
        isClockwise: true,
        isDouble: false,
        sliceType: 'none',
        sliceIndex: 0,
        directionSign: 0.0,
        arrowSymbol: '🔄',
        sliceName: clean == 'FLIP' ? 'Flipped Edge' : 'Twisted Corner',
        actionSummary: clean == 'FLIP' ? 'FLIP PHYSICAL EDGE' : 'TWIST PHYSICAL CORNER',
        isPhysicalFix: true,
      );
    }

    final isPrime = clean.contains("'");
    final isDouble = clean.contains('2');

    // Extract face character
    int idx = 0;
    while (idx < clean.length && clean[idx].codeUnitAt(0) >= 48 && clean[idx].codeUnitAt(0) <= 57) {
      idx++;
    }
    final faceChar = idx < clean.length ? clean[idx].toUpperCase() : 'R';

    CubeFace face;
    String sliceType = 'col';
    int sliceIndex = size - 1;
    double directionSign = -1.0;
    String arrowSymbol = '↑';
    String sliceName = 'Right Column';
    String actionSummary = '';
    String defaultInstr = '';
    String defaultStage = customStage ?? 'Cube Solution';

    switch (faceChar) {
      case 'R':
        face = CubeFace.right;
        sliceType = 'col';
        sliceIndex = size - 1;
        if (isPrime) {
          directionSign = 1.0;
          arrowSymbol = '↓';
          sliceName = 'Right Column (Layer $size)';
          actionSummary = 'Move $sliceName DOWNWARD ↓';
          defaultInstr = 'Pull Right face counter-clockwise downward 90°';
        } else if (isDouble) {
          directionSign = -1.0;
          arrowSymbol = '⇈';
          sliceName = 'Right Column (Layer $size)';
          actionSummary = 'Rotate $sliceName 180°';
          defaultInstr = 'Rotate Right face 180°';
        } else {
          directionSign = -1.0;
          arrowSymbol = '↑';
          sliceName = 'Right Column (Layer $size)';
          actionSummary = 'Move $sliceName UPWARD ↑';
          defaultInstr = 'Turn Right face clockwise upward 90°';
        }
        break;

      case 'L':
        face = CubeFace.left;
        sliceType = 'col';
        sliceIndex = 0;
        if (isPrime) {
          directionSign = -1.0;
          arrowSymbol = '↑';
          sliceName = 'Left Column (Layer 1)';
          actionSummary = 'Move Left Column UPWARD ↑';
          defaultInstr = 'Push Left face counter-clockwise upward 90°';
        } else if (isDouble) {
          directionSign = 1.0;
          arrowSymbol = '⇊';
          sliceName = 'Left Column (Layer 1)';
          actionSummary = 'Rotate Left Column 180°';
          defaultInstr = 'Rotate Left face 180°';
        } else {
          directionSign = 1.0;
          arrowSymbol = '↓';
          sliceName = 'Left Column (Layer 1)';
          actionSummary = 'Move Left Column DOWNWARD ↓';
          defaultInstr = 'Turn Left face clockwise downward 90°';
        }
        break;

      case 'U':
        face = CubeFace.up;
        sliceType = 'row';
        sliceIndex = 0;
        if (isPrime) {
          directionSign = 1.0;
          arrowSymbol = '→';
          sliceName = 'Top Row (Layer 1)';
          actionSummary = 'Shift Top Row RIGHTWARD →';
          defaultInstr = 'Rotate Top face counter-clockwise to the right 90°';
        } else if (isDouble) {
          directionSign = -1.0;
          arrowSymbol = '⇉';
          sliceName = 'Top Row (Layer 1)';
          actionSummary = 'Spin Top Row 180°';
          defaultInstr = 'Rotate Top face 180°';
        } else {
          directionSign = -1.0;
          arrowSymbol = '←';
          sliceName = 'Top Row (Layer 1)';
          actionSummary = 'Shift Top Row LEFTWARD ←';
          defaultInstr = 'Rotate Top face clockwise to the left 90°';
        }
        break;

      case 'D':
        face = CubeFace.down;
        sliceType = 'row';
        sliceIndex = size - 1;
        if (isPrime) {
          directionSign = -1.0;
          arrowSymbol = '←';
          sliceName = 'Bottom Row (Layer $size)';
          actionSummary = 'Shift $sliceName LEFTWARD ←';
          defaultInstr = 'Turn Bottom face counter-clockwise to the left 90°';
        } else if (isDouble) {
          directionSign = 1.0;
          arrowSymbol = '⇇';
          sliceName = 'Bottom Row (Layer $size)';
          actionSummary = 'Spin $sliceName 180°';
          defaultInstr = 'Turn Bottom face 180°';
        } else {
          directionSign = 1.0;
          arrowSymbol = '→';
          sliceName = 'Bottom Row (Layer $size)';
          actionSummary = 'Shift $sliceName RIGHTWARD →';
          defaultInstr = 'Turn Bottom face clockwise to the right 90°';
        }
        break;

      case 'F':
        face = CubeFace.front;
        sliceType = 'face';
        sliceIndex = 0;
        if (isPrime) {
          directionSign = -1.0;
          arrowSymbol = '↺';
          sliceName = 'Front Face';
          actionSummary = 'Turn Front Face COUNTER-CLOCKWISE ↺';
          defaultInstr = 'Rotate Front face counter-clockwise 90°';
        } else if (isDouble) {
          directionSign = 1.0;
          arrowSymbol = '↻↻';
          sliceName = 'Front Face';
          actionSummary = 'Turn Front Face 180°';
          defaultInstr = 'Rotate Front face 180°';
        } else {
          directionSign = 1.0;
          arrowSymbol = '↻';
          sliceName = 'Front Face';
          actionSummary = 'Turn Front Face CLOCKWISE ↻';
          defaultInstr = 'Rotate Front face clockwise 90°';
        }
        break;

      case 'B':
        face = CubeFace.back;
        sliceType = 'face';
        sliceIndex = 0;
        if (isPrime) {
          directionSign = 1.0;
          arrowSymbol = '↺';
          sliceName = 'Back Face';
          actionSummary = 'Turn Back Face COUNTER-CLOCKWISE ↺';
          defaultInstr = 'Rotate Back face counter-clockwise 90°';
        } else if (isDouble) {
          directionSign = -1.0;
          arrowSymbol = '↻↻';
          sliceName = 'Back Face';
          actionSummary = 'Turn Back Face 180°';
          defaultInstr = 'Rotate Back face 180°';
        } else {
          directionSign = -1.0;
          arrowSymbol = '↻';
          sliceName = 'Back Face';
          actionSummary = 'Turn Back Face CLOCKWISE ↻';
          defaultInstr = 'Rotate Back face clockwise 90°';
        }
        break;

      default:
        face = CubeFace.front;
        sliceType = 'face';
        sliceIndex = 0;
        arrowSymbol = '↻';
        sliceName = 'Slice $clean';
        actionSummary = 'Turn $clean';
        defaultInstr = 'Execute move $clean';
    }

    return CubeStep(
      stepNumber: stepNumber,
      totalSteps: totalSteps,
      moveNotation: clean,
      instruction: customInstr ?? defaultInstr,
      stage: defaultStage,
      faceToRotate: face,
      isClockwise: !isPrime,
      isDouble: isDouble,
      sliceType: sliceType,
      sliceIndex: sliceIndex,
      directionSign: directionSign,
      arrowSymbol: arrowSymbol,
      sliceName: sliceName,
      actionSummary: actionSummary,
      isPhysicalFix: false,
    );
  }
}
