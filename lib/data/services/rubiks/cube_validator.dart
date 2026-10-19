import 'package:cuber/cuber.dart' as cb;
import 'cube_state.dart';

enum ValidationStatus { valid, fixable, invalid }

enum RepairType {
  edgeFlip,
  cornerTwist,
  edgeSwap,
  cornerSwap,
  stickerSwap,
}

class RepairSuggestion {
  final RepairType type;
  final String title;
  final String description;
  final String pieceLocation;
  final List<CubeColor> colors;
  final int rank; // 1 = highest priority / minimal change
  final RubiksCubeState Function(RubiksCubeState current) apply;

  RepairSuggestion({
    required this.type,
    required this.title,
    required this.description,
    required this.pieceLocation,
    required this.colors,
    required this.rank,
    required this.apply,
  });

  String get instruction => description;
}

class ValidationResult {
  final ValidationStatus status;
  final String? errorMessage;
  final List<RepairSuggestion> repairSuggestions;
  final Map<CubeColor, int> colorCounts;
  final bool hasInvalidStickerCounts;
  final bool hasCenterMismatch;
  final bool hasEdgeFlipParity;
  final bool hasCornerTwistParity;
  final bool hasPermutationParity;
  final bool isPhysicallyPossible;

  ValidationResult({
    required this.status,
    this.errorMessage,
    this.repairSuggestions = const [],
    required this.colorCounts,
    this.hasInvalidStickerCounts = false,
    this.hasCenterMismatch = false,
    this.hasEdgeFlipParity = false,
    this.hasCornerTwistParity = false,
    this.hasPermutationParity = false,
    this.isPhysicallyPossible = true,
  });

  bool get isValid => status == ValidationStatus.valid;
  bool get isFixable => status == ValidationStatus.fixable;
  String get reason => errorMessage ?? 'Cube state is invalid';
}

class CubeValidator {
  static const List<List<int>> edgeFaceletIndices = [
    [5, 10],  // UR: U6, R2
    [7, 19],  // UF: U8, F2
    [3, 37],  // UL: U4, L2
    [1, 46],  // UB: U2, B2
    [32, 16], // DR: D6, R8
    [28, 25], // DF: D2, F8
    [30, 43], // DL: D4, L8
    [34, 52], // DB: D8, B8
    [23, 12], // FR: F6, R4
    [21, 41], // FL: F4, L6
    [50, 39], // BL: B6, L4
    [48, 14], // BR: B4, R6
  ];

  static const List<String> edgeNames = [
    'Top-Right (White/Red)',
    'Top-Front (White/Green)',
    'Top-Left (White/Orange)',
    'Top-Back (White/Blue)',
    'Bottom-Right (Yellow/Red)',
    'Bottom-Front (Yellow/Green)',
    'Bottom-Left (Yellow/Orange)',
    'Bottom-Back (Yellow/Blue)',
    'Front-Right (Green/Red)',
    'Front-Left (Green/Orange)',
    'Back-Left (Blue/Orange)',
    'Back-Right (Blue/Red)',
  ];

  static const List<List<int>> cornerFaceletIndices = [
    [8, 9, 20],   // URF: U9, R1, F3
    [6, 18, 38],  // UFL: U7, F1, L3
    [0, 36, 47],  // ULB: U1, L1, B3
    [2, 45, 11],  // UBR: U3, B1, R3
    [29, 26, 15], // DFR: D3, F9, R7
    [27, 44, 24], // DLF: D1, L9, F7
    [33, 53, 42], // DBL: D7, B9, L7
    [35, 17, 51], // DRB: D9, R9, B7
  ];

  static const List<String> cornerNames = [
    'Top-Front-Right (White/Green/Red)',
    'Top-Front-Left (White/Green/Orange)',
    'Top-Back-Left (White/Orange/Blue)',
    'Top-Back-Right (White/Blue/Red)',
    'Bottom-Front-Right (Yellow/Green/Red)',
    'Bottom-Front-Left (Yellow/Orange/Green)',
    'Bottom-Back-Left (Yellow/Blue/Orange)',
    'Bottom-Back-Right (Yellow/Red/Blue)',
  ];

  /// Mapping from state to 54-char Kociemba definition string
  static String stateToCuberDefinition(RubiksCubeState state) {
    final buffer = StringBuffer();
    final faces = [CubeFace.up, CubeFace.right, CubeFace.front, CubeFace.down, CubeFace.left, CubeFace.back];

    final centerUp = state.faces[CubeFace.up]![4];
    final centerRight = state.faces[CubeFace.right]![4];
    final centerFront = state.faces[CubeFace.front]![4];
    final centerDown = state.faces[CubeFace.down]![4];
    final centerLeft = state.faces[CubeFace.left]![4];
    final centerBack = state.faces[CubeFace.back]![4];

    final centers = {centerUp, centerRight, centerFront, centerDown, centerLeft, centerBack};
    final Map<CubeColor, String> colorToFaceChar;

    if (centers.length == 6) {
      colorToFaceChar = {
        centerUp: 'U',
        centerRight: 'R',
        centerFront: 'F',
        centerDown: 'D',
        centerLeft: 'L',
        centerBack: 'B',
      };
    } else {
      colorToFaceChar = {
        CubeColor.white: 'U',
        CubeColor.red: 'R',
        CubeColor.green: 'F',
        CubeColor.yellow: 'D',
        CubeColor.orange: 'L',
        CubeColor.blue: 'B',
      };
    }

    for (final f in faces) {
      for (final c in state.faces[f]!) {
        buffer.write(colorToFaceChar[c] ?? 'U');
      }
    }
    return buffer.toString();
  }

  /// Full structural and physical validation for cubes of size N = 2..6.
  static ValidationResult validate(RubiksCubeState state) {
    final counts = state.colorCounts;
    final expectedStickers = state.size * state.size;

    // 1. Sticker Counts Check
    final mismatchColors = <CubeColor, int>{};
    for (final col in CubeColor.values) {
      final count = counts[col] ?? 0;
      if (count != expectedStickers) {
        mismatchColors[col] = count;
      }
    }

    if (mismatchColors.isNotEmpty) {
      final details = mismatchColors.entries.map((e) {
        final diff = e.value - expectedStickers;
        final sign = diff > 0 ? '+$diff' : '$diff';
        return '${e.key.name.toUpperCase()} has ${e.value} ($sign)';
      }).join(', ');

      return ValidationResult(
        status: ValidationStatus.invalid,
        errorMessage: 'Sticker count error: each color must have exactly $expectedStickers stickers. Current: $details.',
        colorCounts: counts,
        hasInvalidStickerCounts: true,
        isPhysicallyPossible: false,
      );
    }

    // 2. Center Alignment Check for Odd N (3x3, 5x5)
    if (state.size % 2 == 1) {
      final centerIdx = (state.size * state.size) ~/ 2;
      final upCenter = state.faces[CubeFace.up]![centerIdx];
      final downCenter = state.faces[CubeFace.down]![centerIdx];
      final frontCenter = state.faces[CubeFace.front]![centerIdx];
      final backCenter = state.faces[CubeFace.back]![centerIdx];
      final leftCenter = state.faces[CubeFace.left]![centerIdx];
      final rightCenter = state.faces[CubeFace.right]![centerIdx];

      if (upCenter != CubeColor.white ||
          downCenter != CubeColor.yellow ||
          frontCenter != CubeColor.green ||
          backCenter != CubeColor.blue ||
          leftCenter != CubeColor.orange ||
          rightCenter != CubeColor.red) {
        // Report center reference
        return ValidationResult(
          status: ValidationStatus.invalid,
          errorMessage: 'Center piece mismatch: Fixed centers must follow standard speedcube orientation: White=Top, Yellow=Bottom, Green=Front, Blue=Back, Orange=Left, Red=Right.',
          colorCounts: counts,
          hasCenterMismatch: true,
          isPhysicallyPossible: false,
        );
      }
    }

    // 3. For 3x3: Full Piece-Level & Parity Validation with Multi-Candidate Repair Enumeration
    if (state.size == 3) {
      return _validateAndEnumerate3x3(state, counts);
    }

    // 4. For 2x2: Corner Twists Check
    if (state.size == 2) {
      return _validate2x2(state, counts);
    }

    // 5. For 4x4, 5x5, 6x6: Valid by sticker counts & centers
    return ValidationResult(
      status: ValidationStatus.valid,
      colorCounts: counts,
    );
  }

  static ValidationResult _validate2x2(RubiksCubeState state, Map<CubeColor, int> counts) {
    // A 2x2 cube has 8 corners. Sum of corner twists must be 0 mod 3.
    // Check corner twists:
    int twistSum = 0;
    // Inspect 8 corners on 2x2
    final corners2x2 = [
      [(CubeFace.up, 3), (CubeFace.right, 0), (CubeFace.front, 1)], // URF
      [(CubeFace.up, 2), (CubeFace.front, 0), (CubeFace.left, 1)],  // UFL
      [(CubeFace.up, 0), (CubeFace.left, 0), (CubeFace.back, 1)],   // ULB
      [(CubeFace.up, 1), (CubeFace.back, 0), (CubeFace.right, 1)],  // UBR
      [(CubeFace.down, 1), (CubeFace.front, 3), (CubeFace.right, 2)],// DFR
      [(CubeFace.down, 0), (CubeFace.left, 3), (CubeFace.front, 2)], // DLF
      [(CubeFace.down, 2), (CubeFace.back, 3), (CubeFace.left, 2)],  // DBL
      [(CubeFace.down, 3), (CubeFace.right, 3), (CubeFace.back, 2)], // DRB
    ];

    for (final c in corners2x2) {
      final col0 = state.faces[c[0].$1]![c[0].$2];
      final col1 = state.faces[c[1].$1]![c[1].$2];
      final col2 = state.faces[c[2].$1]![c[2].$2];

      if (col0 == CubeColor.white || col0 == CubeColor.yellow) {
        twistSum += 0;
      } else if (col1 == CubeColor.white || col1 == CubeColor.yellow) {
        twistSum += 1;
      } else if (col2 == CubeColor.white || col2 == CubeColor.yellow) {
        twistSum += 2;
      }
    }

    if (twistSum % 3 != 0) {
      final suggestions = <RepairSuggestion>[];
      final neededTwist = (3 - (twistSum % 3)) % 3;

      for (int i = 0; i < corners2x2.length; i++) {
        final c = corners2x2[i];
        final name = cornerNames[i];
        suggestions.add(RepairSuggestion(
          type: RepairType.cornerTwist,
          title: 'Twist $name Corner',
          description: 'Twist the $name corner piece ${neededTwist == 1 ? "1 time clockwise" : "1 time counter-clockwise"} in place on your physical cube.',
          pieceLocation: name,
          colors: [state.faces[c[0].$1]![c[0].$2], state.faces[c[1].$1]![c[1].$2], state.faces[c[2].$1]![c[2].$2]],
          rank: 1,
          apply: (cur) {
            final next = cur.clone();
            final f0 = c[0].$1; final i0 = c[0].$2;
            final f1 = c[1].$1; final i1 = c[1].$2;
            final f2 = c[2].$1; final i2 = c[2].$2;
            final t0 = next.faces[f0]![i0];
            final t1 = next.faces[f1]![i1];
            final t2 = next.faces[f2]![i2];
            if (neededTwist == 1) {
              next.faces[f0]![i0] = t2; next.faces[f1]![i1] = t0; next.faces[f2]![i2] = t1;
            } else {
              next.faces[f0]![i0] = t1; next.faces[f1]![i1] = t2; next.faces[f2]![i2] = t0;
            }
            return next;
          },
        ));
      }

      return ValidationResult(
        status: ValidationStatus.fixable,
        errorMessage: 'Corner twist parity error: 1 corner piece on your physical 2x2 cube is twisted in place.',
        repairSuggestions: suggestions,
        colorCounts: counts,
        hasCornerTwistParity: true,
        isPhysicallyPossible: false,
      );
    }

    return ValidationResult(status: ValidationStatus.valid, colorCounts: counts);
  }

  static ValidationResult _validateAndEnumerate3x3(RubiksCubeState state, Map<CubeColor, int> counts) {
    final def = stateToCuberDefinition(state);
    final cube = cb.Cube.from(def);
    final status = cube.verify();

    if (status == cb.CubeStatus.ok) {
      return ValidationResult(
        status: ValidationStatus.valid,
        colorCounts: counts,
      );
    }

    final suggestions = <RepairSuggestion>[];

    // Case A: Twisted Edge Parity (Enumerate ALL 12 single edge flip candidates!)
    if (status == cb.CubeStatus.twistedEdge) {
      for (int e = 0; e < edgeFaceletIndices.length; e++) {
        final pair = edgeFaceletIndices[e];
        final chars = def.split('');
        final tmp = chars[pair[0]];
        chars[pair[0]] = chars[pair[1]];
        chars[pair[1]] = tmp;

        final testCube = cb.Cube.from(chars.join(''));
        if (testCube.verify() == cb.CubeStatus.ok) {
          final edgeName = edgeNames[e];
          suggestions.add(RepairSuggestion(
            type: RepairType.edgeFlip,
            title: 'Flip $edgeName Edge',
            description: 'Flip the $edgeName edge piece 1 time in place on your physical cube.',
            pieceLocation: edgeName,
            colors: [
              _colorFromChar(chars[pair[0]]),
              _colorFromChar(chars[pair[1]]),
            ],
            rank: 1,
            apply: (cur) {
              final next = cur.clone();
              _flipEdgeInState(next, e);
              return next;
            },
          ));
        }
      }

      return ValidationResult(
        status: ValidationStatus.fixable,
        errorMessage: 'Edge parity error: an edge piece is flipped in place on your physical cube.',
        repairSuggestions: suggestions,
        colorCounts: counts,
        hasEdgeFlipParity: true,
        isPhysicallyPossible: false,
      );
    }

    // Case B: Twisted Corner Parity (Enumerate ALL 8 corner twist candidates!)
    if (status == cb.CubeStatus.twistedCorner) {
      for (int c = 0; c < cornerFaceletIndices.length; c++) {
        final trio = cornerFaceletIndices[c];
        for (int twist = 1; twist <= 2; twist++) {
          final chars = def.split('');
          if (twist == 1) {
            final t0 = chars[trio[0]]; final t1 = chars[trio[1]]; final t2 = chars[trio[2]];
            chars[trio[0]] = t2; chars[trio[1]] = t0; chars[trio[2]] = t1;
          } else {
            final t0 = chars[trio[0]]; final t1 = chars[trio[1]]; final t2 = chars[trio[2]];
            chars[trio[0]] = t1; chars[trio[1]] = t2; chars[trio[2]] = t0;
          }

          final testCube = cb.Cube.from(chars.join(''));
          if (testCube.verify() == cb.CubeStatus.ok) {
            final cornerName = cornerNames[c];
            final twistText = twist == 1 ? '1 time clockwise' : '1 time counter-clockwise (or 2 times clockwise)';
            suggestions.add(RepairSuggestion(
              type: RepairType.cornerTwist,
              title: 'Twist $cornerName Corner',
              description: 'Twist the $cornerName corner piece $twistText in place on your physical cube.',
              pieceLocation: cornerName,
              colors: [
                _colorFromChar(chars[trio[0]]),
                _colorFromChar(chars[trio[1]]),
                _colorFromChar(chars[trio[2]]),
              ],
              rank: 1,
              apply: (cur) {
                final next = cur.clone();
                _twistCornerInState(next, c, twist);
                return next;
              },
            ));
          }
        }
      }

      return ValidationResult(
        status: ValidationStatus.fixable,
        errorMessage: 'Corner twist parity error: a corner piece is twisted in place on your physical cube.',
        repairSuggestions: suggestions,
        colorCounts: counts,
        hasCornerTwistParity: true,
        isPhysicallyPossible: false,
      );
    }

    // Case C: Permutation Parity Error (Enumerate ALL valid edge swaps)
    if (status == cb.CubeStatus.parityError) {
      for (int i = 0; i < edgeFaceletIndices.length - 1; i++) {
        for (int j = i + 1; j < edgeFaceletIndices.length; j++) {
          final e1 = edgeFaceletIndices[i];
          final e2 = edgeFaceletIndices[j];
          final chars = def.split('');
          final t0 = chars[e1[0]]; final t1 = chars[e1[1]];
          chars[e1[0]] = chars[e2[0]]; chars[e1[1]] = chars[e2[1]];
          chars[e2[0]] = t0; chars[e2[1]] = t1;

          final testCube = cb.Cube.from(chars.join(''));
          if (testCube.verify() == cb.CubeStatus.ok) {
            final name1 = edgeNames[i];
            final name2 = edgeNames[j];
            suggestions.add(RepairSuggestion(
              type: RepairType.edgeSwap,
              title: 'Swap $name1 and $name2 Edges',
              description: 'Swap the $name1 and $name2 edge pieces in place on your physical cube.',
              pieceLocation: '$name1 ↔ $name2',
              colors: [
                _colorFromChar(chars[e1[0]]),
                _colorFromChar(chars[e1[1]]),
              ],
              rank: 2,
              apply: (cur) {
                final next = cur.clone();
                _swapEdgesInState(next, i, j);
                return next;
              },
            ));
          }
        }
      }

      return ValidationResult(
        status: ValidationStatus.fixable,
        errorMessage: 'Permutation parity error: two pieces were swapped during physical assembly.',
        repairSuggestions: suggestions,
        colorCounts: counts,
        hasPermutationParity: true,
        isPhysicallyPossible: false,
      );
    }

    // Case D: Missing / Duplicate Edge or Corner (Check single sticker swaps)
    if (status == cb.CubeStatus.missingEdge || status == cb.CubeStatus.missingCorner) {
      final allEdgeIndices = <int>[];
      for (final p in edgeFaceletIndices) {
        allEdgeIndices.addAll(p);
      }

      for (int i = 0; i < allEdgeIndices.length - 1 && suggestions.length < 5; i++) {
        for (int j = i + 1; j < allEdgeIndices.length && suggestions.length < 5; j++) {
          final chars = def.split('');
          final idx1 = allEdgeIndices[i];
          final idx2 = allEdgeIndices[j];
          if (chars[idx1] == chars[idx2]) continue;

          final tmp = chars[idx1];
          chars[idx1] = chars[idx2];
          chars[idx2] = tmp;

          final testCube = cb.Cube.from(chars.join(''));
          if (testCube.verify() == cb.CubeStatus.ok) {
            suggestions.add(RepairSuggestion(
              type: RepairType.stickerSwap,
              title: 'Correct 2 Swapped Stickers',
              description: 'Swap the ${_colorFromChar(tmp).name.toUpperCase()} sticker with the ${_colorFromChar(chars[idx1]).name.toUpperCase()} sticker on your cube layout.',
              pieceLocation: 'Edge stickers',
              colors: [_colorFromChar(chars[idx1]), _colorFromChar(chars[idx2])],
              rank: 3,
              apply: (cur) {
                final next = cur.clone();
                _swapFaceletsInState(next, idx1, idx2);
                return next;
              },
            ));
          }
        }
      }

      if (suggestions.isNotEmpty) {
        return ValidationResult(
          status: ValidationStatus.fixable,
          errorMessage: 'Sticker mismatch: 2 stickers on your cube appear to be entered in reverse positions.',
          repairSuggestions: suggestions,
          colorCounts: counts,
          isPhysicallyPossible: false,
        );
      }

      return ValidationResult(
        status: ValidationStatus.invalid,
        errorMessage: 'Invalid cube layout: missing or duplicate pieces detected. Please verify stickers.',
        colorCounts: counts,
        isPhysicallyPossible: false,
      );
    }

    return ValidationResult(
      status: ValidationStatus.invalid,
      errorMessage: 'Could not verify cube stickers. Please check for errors.',
      colorCounts: counts,
      isPhysicallyPossible: false,
    );
  }

  // ===========================================================================
  // STATE MANIPULATION HELPERS FOR REPAIRS
  // ===========================================================================

  static void _flipEdgeInState(RubiksCubeState state, int edgeIndex) {
    final edgeLocations = [
      (CubeFace.up, 5, CubeFace.right, 1),   // UR
      (CubeFace.up, 7, CubeFace.front, 1),   // UF
      (CubeFace.up, 3, CubeFace.left, 1),    // UL
      (CubeFace.up, 1, CubeFace.back, 1),    // UB
      (CubeFace.down, 5, CubeFace.right, 7), // DR
      (CubeFace.down, 1, CubeFace.front, 7), // DF
      (CubeFace.down, 3, CubeFace.left, 7),  // DL
      (CubeFace.down, 7, CubeFace.back, 7),  // DB
      (CubeFace.front, 5, CubeFace.right, 3),// FR
      (CubeFace.front, 3, CubeFace.left, 5), // FL
      (CubeFace.back, 5, CubeFace.left, 3),  // BL
      (CubeFace.back, 3, CubeFace.right, 5), // BR
    ];

    final loc = edgeLocations[edgeIndex];
    final c1 = state.faces[loc.$1]![loc.$2];
    final c2 = state.faces[loc.$3]![loc.$4];
    state.faces[loc.$1]![loc.$2] = c2;
    state.faces[loc.$3]![loc.$4] = c1;
  }

  static void _twistCornerInState(RubiksCubeState state, int cornerIndex, int twist) {
    final cornerLocations = [
      (CubeFace.up, 8, CubeFace.right, 0, CubeFace.front, 2),   // URF
      (CubeFace.up, 6, CubeFace.front, 0, CubeFace.left, 2),    // UFL
      (CubeFace.up, 0, CubeFace.left, 0, CubeFace.back, 2),     // ULB
      (CubeFace.up, 2, CubeFace.back, 0, CubeFace.right, 2),    // UBR
      (CubeFace.down, 2, CubeFace.front, 8, CubeFace.right, 6), // DFR
      (CubeFace.down, 0, CubeFace.left, 8, CubeFace.front, 6),  // DLF
      (CubeFace.down, 6, CubeFace.back, 8, CubeFace.left, 6),   // DBL
      (CubeFace.down, 8, CubeFace.right, 8, CubeFace.back, 6),  // DRB
    ];

    final loc = cornerLocations[cornerIndex];
    final c0 = state.faces[loc.$1]![loc.$2];
    final c1 = state.faces[loc.$3]![loc.$4];
    final c2 = state.faces[loc.$5]![loc.$6];

    if (twist == 1) {
      // Clockwise twist
      state.faces[loc.$1]![loc.$2] = c2;
      state.faces[loc.$3]![loc.$4] = c0;
      state.faces[loc.$5]![loc.$6] = c1;
    } else {
      // Counter-clockwise twist
      state.faces[loc.$1]![loc.$2] = c1;
      state.faces[loc.$3]![loc.$4] = c2;
      state.faces[loc.$5]![loc.$6] = c0;
    }
  }

  static void _swapEdgesInState(RubiksCubeState state, int edge1, int edge2) {
    final edgeLocations = [
      (CubeFace.up, 5, CubeFace.right, 1),
      (CubeFace.up, 7, CubeFace.front, 1),
      (CubeFace.up, 3, CubeFace.left, 1),
      (CubeFace.up, 1, CubeFace.back, 1),
      (CubeFace.down, 5, CubeFace.right, 7),
      (CubeFace.down, 1, CubeFace.front, 7),
      (CubeFace.down, 3, CubeFace.left, 7),
      (CubeFace.down, 7, CubeFace.back, 7),
      (CubeFace.front, 5, CubeFace.right, 3),
      (CubeFace.front, 3, CubeFace.left, 5),
      (CubeFace.back, 5, CubeFace.left, 3),
      (CubeFace.back, 3, CubeFace.right, 5),
    ];

    final loc1 = edgeLocations[edge1];
    final loc2 = edgeLocations[edge2];

    final c1_0 = state.faces[loc1.$1]![loc1.$2];
    final c1_1 = state.faces[loc1.$3]![loc1.$4];
    final c2_0 = state.faces[loc2.$1]![loc2.$2];
    final c2_1 = state.faces[loc2.$3]![loc2.$4];

    state.faces[loc1.$1]![loc1.$2] = c2_0;
    state.faces[loc1.$3]![loc1.$4] = c2_1;
    state.faces[loc2.$1]![loc2.$2] = c1_0;
    state.faces[loc2.$3]![loc2.$4] = c1_1;
  }

  static void _swapFaceletsInState(RubiksCubeState state, int idx1, int idx2) {
    final faces = [CubeFace.up, CubeFace.right, CubeFace.front, CubeFace.down, CubeFace.left, CubeFace.back];
    final f1 = faces[idx1 ~/ 9];
    final i1 = idx1 % 9;
    final f2 = faces[idx2 ~/ 9];
    final i2 = idx2 % 9;

    final tmp = state.faces[f1]![i1];
    state.faces[f1]![i1] = state.faces[f2]![i2];
    state.faces[f2]![i2] = tmp;
  }

  static CubeColor _colorFromChar(String char) {
    switch (char.toUpperCase()) {
      case 'U': return CubeColor.white;
      case 'R': return CubeColor.red;
      case 'F': return CubeColor.green;
      case 'D': return CubeColor.yellow;
      case 'L': return CubeColor.orange;
      case 'B': return CubeColor.blue;
      default: return CubeColor.white;
    }
  }
}
