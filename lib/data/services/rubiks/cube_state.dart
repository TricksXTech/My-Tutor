import 'cube_moves.dart';

enum CubeFace { up, down, front, back, left, right }

enum CubeColor { white, yellow, green, blue, red, orange }

class CubeStep {
  final int stepNumber;
  final int totalSteps;
  final String moveNotation;
  final String instruction;
  final String stage;
  final CubeFace faceToRotate;
  final bool isClockwise;
  final bool isDouble;
  final String sliceType; // 'col', 'row', 'face', 'none'
  final int sliceIndex; // 0 for left/top, (size - 1) for right/bottom
  final double directionSign; // -1.0 for up / left, 1.0 for down / right
  final String arrowSymbol; // '↑', '↓', '←', '→', '↻', '↺', '🔄'
  final String sliceName;
  final String actionSummary;
  final bool isPhysicalFix;

  CubeStep({
    required this.stepNumber,
    required this.totalSteps,
    required this.moveNotation,
    required this.instruction,
    required this.stage,
    required this.faceToRotate,
    this.isClockwise = true,
    this.isDouble = false,
    this.sliceType = 'col',
    this.sliceIndex = 0,
    this.directionSign = -1.0,
    this.arrowSymbol = '↑',
    this.sliceName = 'Slice',
    this.actionSummary = '',
    this.isPhysicalFix = false,
  });

  CubeStep copyWith({
    int? stepNumber,
    int? totalSteps,
    String? moveNotation,
    String? instruction,
    String? stage,
    CubeFace? faceToRotate,
    bool? isClockwise,
    bool? isDouble,
    String? sliceType,
    int? sliceIndex,
    double? directionSign,
    String? arrowSymbol,
    String? sliceName,
    String? actionSummary,
    bool? isPhysicalFix,
  }) {
    return CubeStep(
      stepNumber: stepNumber ?? this.stepNumber,
      totalSteps: totalSteps ?? this.totalSteps,
      moveNotation: moveNotation ?? this.moveNotation,
      instruction: instruction ?? this.instruction,
      stage: stage ?? this.stage,
      faceToRotate: faceToRotate ?? this.faceToRotate,
      isClockwise: isClockwise ?? this.isClockwise,
      isDouble: isDouble ?? this.isDouble,
      sliceType: sliceType ?? this.sliceType,
      sliceIndex: sliceIndex ?? this.sliceIndex,
      directionSign: directionSign ?? this.directionSign,
      arrowSymbol: arrowSymbol ?? this.arrowSymbol,
      sliceName: sliceName ?? this.sliceName,
      actionSummary: actionSummary ?? this.actionSummary,
      isPhysicalFix: isPhysicalFix ?? this.isPhysicalFix,
    );
  }
}

/// N×N×N facelet representation for N in 2..6.
/// Faces: Up(White), Down(Yellow), Front(Green), Back(Blue), Left(Orange), Right(Red).
class RubiksCubeState {
  final int size; // 2, 3, 4, 5, 6
  final Map<CubeFace, List<CubeColor>> faces;
  List<String> scrambleHistory = [];

  RubiksCubeState({
    required this.size,
    required this.faces,
    List<String>? scrambleHistory,
  }) : scrambleHistory = scrambleHistory ?? [];

  factory RubiksCubeState.solved(int size) {
    return RubiksCubeState(
      size: size,
      faces: {
        CubeFace.up: List.filled(size * size, CubeColor.white),
        CubeFace.down: List.filled(size * size, CubeColor.yellow),
        CubeFace.front: List.filled(size * size, CubeColor.green),
        CubeFace.back: List.filled(size * size, CubeColor.blue),
        CubeFace.left: List.filled(size * size, CubeColor.orange),
        CubeFace.right: List.filled(size * size, CubeColor.red),
      },
    );
  }

  RubiksCubeState clone() {
    final newFaces = <CubeFace, List<CubeColor>>{};
    faces.forEach((k, v) => newFaces[k] = List<CubeColor>.from(v));
    return RubiksCubeState(
      size: size,
      faces: newFaces,
      scrambleHistory: List<String>.from(scrambleHistory),
    );
  }

  CubeColor getColor(CubeFace face, int index) {
    return faces[face]![index];
  }

  void setColor(CubeFace face, int index, CubeColor color) {
    if (index >= 0 && index < faces[face]!.length) {
      faces[face]![index] = color;
    }
  }

  Map<CubeColor, int> get colorCounts {
    final counts = <CubeColor, int>{};
    for (final col in CubeColor.values) {
      counts[col] = 0;
    }
    for (final f in faces.values) {
      for (final c in f) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Invariant check: Assert each colour appears exactly size*size times.
  void assertColorInvariants({int? stepNumber, String? move}) {
    final expected = size * size;
    final counts = colorCounts;
    for (final entry in counts.entries) {
      if (entry.value != expected) {
        final stepInfo = stepNumber != null ? ' at Step $stepNumber' : '';
        final moveInfo = move != null ? ' after move "$move"' : '';
        throw StateError(
          'Color invariant broken$stepInfo$moveInfo: ${entry.key.name.toUpperCase()} has ${entry.value} stickers (expected $expected)!',
        );
      }
    }
  }

  /// Checks if all faces have uniform colors.
  bool get isSolved {
    for (final face in faces.keys) {
      final list = faces[face]!;
      if (list.isEmpty) return false;
      final first = list.first;
      for (final color in list) {
        if (color != first) return false;
      }
    }
    return true;
  }

  /// Canonical compact string representation of the cube state
  String toStateString() {
    final buffer = StringBuffer();
    for (final face in CubeFace.values) {
      final list = faces[face]!;
      for (final c in list) {
        buffer.write(c.index);
      }
    }
    return buffer.toString();
  }

  /// Applies a move or sequence using the move engine
  void applyMove(String notation) {
    CubeMoveEngine.applyMove(this, notation);
  }

  void applyMoves(Iterable<String> moves) {
    for (final m in moves) {
      applyMove(m);
    }
  }
}
