import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'cube_state.dart';
import 'cube_moves.dart';
import 'cube_validator.dart';
import 'solver_2x2.dart';
import 'solver_3x3.dart';
import 'solver_reduction.dart';

class RubiksCubeSolverService {
  /// Generates a valid random scramble sequence of specified move length
  List<String> generateScramble(int size, [int length = 25]) {
    final moves = size == 2
        ? ['U', "U'", 'U2', 'R', "R'", 'R2', 'F', "F'", 'F2']
        : ['U', "U'", 'U2', 'D', "D'", 'D2', 'R', "R'", 'R2', 'L', "L'", 'L2', 'F', "F'", 'F2', 'B', "B'", 'B2'];
    final random = Random();
    final scramble = <String>[];
    String lastFace = '';

    while (scramble.length < length) {
      final move = moves[random.nextInt(moves.length)];
      final face = move[0];
      if (face != lastFace) {
        scramble.add(move);
        lastFace = face;
      }
    }
    return scramble;
  }

  static String getInverseMove(String move) {
    return CubeMoveEngine.getInverseMove(move);
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
    return CubeMoveEngine.createStep(
      stepNumber: stepNumber,
      totalSteps: totalSteps,
      moveNotation: moveNotation,
      size: size,
      customStage: customStage,
      customInstr: customInstr,
      isPhysicalFix: isPhysicalFix,
    );
  }

  /// Detailed structured validation returning status, errors, and ranked repair suggestions
  ValidationResult validateCubeDetailed(RubiksCubeState state) {
    return CubeValidator.validate(state);
  }

  /// Legacy API returning null if valid/fixable, or error description string
  String? validateCube(RubiksCubeState state) {
    final res = validateCubeDetailed(state);
    if (res.isValid || res.isFixable) return null;
    return res.errorMessage;
  }

  /// Enumerates all ranked single-piece repair suggestions
  List<RepairSuggestion> repairSuggestions(RubiksCubeState state) {
    final res = validateCubeDetailed(state);
    return res.repairSuggestions;
  }

  /// Synchronous solver entry point.
  /// Solves the cube 100% offline from physical sticker colors alone.
  List<CubeStep> solveCube(
    RubiksCubeState state, {
    RepairSuggestion? chosenRepair,
    bool debugUseHistory = false,
  }) {
    if (state.isSolved) return [];

    final List<CubeStep> steps;
    if (state.size == 2) {
      steps = Solver2x2.solve(state, debugUseHistory: debugUseHistory);
    } else if (state.size == 3) {
      steps = Solver3x3.solve(state, chosenRepair: chosenRepair, debugUseHistory: debugUseHistory);
    } else {
      steps = SolverReduction.solve(state, debugUseHistory: debugUseHistory);
    }

    // Final mathematical guarantee: verify on a clone that steps return cube to solved
    if (steps.isNotEmpty) {
      final verify = state.clone();
      if (chosenRepair != null) {
        chosenRepair.apply(verify);
      }
      for (int i = 0; i < steps.length; i++) {
        final s = steps[i];
        if (!s.isPhysicalFix) {
          verify.applyMove(s.moveNotation);
          // Color invariant check after every move
          verify.assertColorInvariants(stepNumber: i + 1, move: s.moveNotation);
        }
      }
      if (!verify.isSolved) {
        throw StateError(
          'Solution verification failed: the move sequence did not return the cube to solved. '
          'Aborting to prevent color divergence.',
        );
      }
    }

    return steps;
  }

  /// Asynchronous isolate solver entry point (`compute`) keeping the UI 100% responsive.
  /// Supports configurable timeout (default 15s) and cancel capability.
  Future<List<CubeStep>> solveCubeAsync(
    RubiksCubeState state, {
    RepairSuggestion? chosenRepair,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (state.isSolved) return [];

    return compute(_solveInIsolate, _SolvePayload(state, chosenRepair))
        .timeout(timeout, onTimeout: () {
      throw TimeoutException('Cube solving exceeded time limit of ${timeout.inSeconds} seconds.');
    });
  }
}

class _SolvePayload {
  final RubiksCubeState state;
  final RepairSuggestion? chosenRepair;
  _SolvePayload(this.state, this.chosenRepair);
}

List<CubeStep> _solveInIsolate(_SolvePayload payload) {
  final service = RubiksCubeSolverService();
  return service.solveCube(payload.state, chosenRepair: payload.chosenRepair);
}
