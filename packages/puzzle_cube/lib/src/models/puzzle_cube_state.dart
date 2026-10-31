import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cube_move.dart';
import 'cubie_model.dart';

/// The full state of a 3x3 cube: its 27 [cubies] and the operations that turn
/// layers, scramble, serialise and check for a solved state.
class PuzzleCubeState {
  PuzzleCubeState._(this.cubies);

  /// The 27 cubies that make up the cube.
  final List<CubieModel> cubies;

  /// A cube in the standard solved colour scheme.
  factory PuzzleCubeState.solved() {
    final cubies = <CubieModel>[];
    for (int x = -1; x <= 1; x++) {
      for (int y = -1; y <= 1; y++) {
        for (int z = -1; z <= 1; z++) {
          cubies.add(CubieModel.solved(x: x, y: y, z: z));
        }
      }
    }
    return PuzzleCubeState._(cubies);
  }

  /// A cube with fixed centre colours and every other sticker left blank,
  /// used as the starting point for a "colour my cube" flow.
  factory PuzzleCubeState.colorless() {
    final cubies = <CubieModel>[];
    for (int x = -1; x <= 1; x++) {
      for (int y = -1; y <= 1; y++) {
        for (int z = -1; z <= 1; z++) {
          cubies.add(CubieModel.colorless(x: x, y: y, z: z));
        }
      }
    }
    return PuzzleCubeState._(cubies);
  }

  /// A solved cube scrambled by [moves] random outer turns. Pass a [seed] for a
  /// reproducible scramble.
  factory PuzzleCubeState.random({int moves = 25, int? seed}) {
    final state = PuzzleCubeState.solved();
    final rng = math.Random(seed);
    const all = [
      CubeMove.r, CubeMove.ri, CubeMove.l, CubeMove.li,
      CubeMove.u, CubeMove.ui, CubeMove.d, CubeMove.di,
      CubeMove.f, CubeMove.fi, CubeMove.b, CubeMove.bi,
    ];
    for (int i = 0; i < moves; i++) {
      state.applyMove(all[rng.nextInt(all.length)]);
    }
    return state;
  }

  /// Restores a cube from [toJson] output.
  factory PuzzleCubeState.fromJson(Map<String, dynamic> json) {
    final cubies = (json['cubies'] as List)
        .map((e) => CubieModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return PuzzleCubeState._(cubies);
  }

  /// The cubie at grid position ([x], [y], [z]), or null if none matches.
  CubieModel? cubieAt(int x, int y, int z) {
    for (final cubie in cubies) {
      if (cubie.x == x && cubie.y == y && cubie.z == z) return cubie;
    }
    return null;
  }

  /// Paints a single sticker. Returns false (and changes nothing) if the cubie
  /// or face doesn't exist, or if it's a centre piece (which is fixed).
  bool setStickerColor({
    required int x,
    required int y,
    required int z,
    required CubieFace face,
    required Color color,
  }) {
    final cubie = cubieAt(x, y, z);
    if (cubie == null || !cubie.faces.containsKey(face)) return false;
    if (_isCenter(x, y, z)) return false;
    cubie.faces[face] = color;
    return true;
  }

  static bool _isCenter(int x, int y, int z) {
    final zeros = (x == 0 ? 1 : 0) + (y == 0 ? 1 : 0) + (z == 0 ? 1 : 0);
    return zeros == 2;
  }

  /// A deep copy of this cube state.
  PuzzleCubeState copy() {
    return PuzzleCubeState._(cubies.map((c) => c.copy()).toList());
  }

  /// A JSON-serialisable snapshot of this cube state.
  Map<String, dynamic> toJson() => {
        'cubies': cubies.map((c) => c.toJson()).toList(),
      };

  /// Whether every cubie matches the solved colour scheme for its position.
  ///
  /// Stickers are compared by ARGB value, not [Color] equality: the solved
  /// reference uses `MaterialColor` constants whose `==` is runtimeType
  /// sensitive, so a [PuzzleCubeState.fromJson]-restored cube (plain [Color]s)
  /// would otherwise never report solved.
  bool get isSolved {
    for (final cubie in cubies) {
      final reference = CubieModel.solved(x: cubie.x, y: cubie.y, z: cubie.z);
      if (cubie.faces.length != reference.faces.length) return false;
      for (final entry in reference.faces.entries) {
        final color = cubie.faces[entry.key];
        if (color == null || color.toARGB32() != entry.value.toARGB32()) {
          return false;
        }
      }
    }
    return true;
  }

  /// Applies a single quarter-turn [move] in place.
  void applyMove(CubeMove move) {
    switch (move) {
      case CubeMove.r:
        _rotateLayerX(1, true);
        break;
      case CubeMove.ri:
        _rotateLayerX(1, false);
        break;
      case CubeMove.l:
        _rotateLayerX(-1, false);
        break;
      case CubeMove.li:
        _rotateLayerX(-1, true);
        break;
      case CubeMove.u:
        _rotateLayerY(-1, true);
        break;
      case CubeMove.ui:
        _rotateLayerY(-1, false);
        break;
      case CubeMove.d:
        _rotateLayerY(1, false);
        break;
      case CubeMove.di:
        _rotateLayerY(1, true);
        break;
      case CubeMove.f:
        _rotateLayerZ(1, true);
        break;
      case CubeMove.fi:
        _rotateLayerZ(1, false);
        break;
      case CubeMove.b:
        _rotateLayerZ(-1, false);
        break;
      case CubeMove.bi:
        _rotateLayerZ(-1, true);
        break;
      // Middle slices (M follows L, E follows D, S follows F).
      case CubeMove.m:
        _rotateLayerX(0, false);
        break;
      case CubeMove.mi:
        _rotateLayerX(0, true);
        break;
      case CubeMove.e:
        _rotateLayerY(0, false);
        break;
      case CubeMove.ei:
        _rotateLayerY(0, true);
        break;
      case CubeMove.s:
        _rotateLayerZ(0, true);
        break;
      case CubeMove.si:
        _rotateLayerZ(0, false);
        break;
    }
  }

  void _rotateLayerX(int layer, bool clockwise) {
    final cycle = clockwise
        ? [CubieFace.zPos, CubieFace.yNeg, CubieFace.zNeg, CubieFace.yPos]
        : [CubieFace.zPos, CubieFace.yPos, CubieFace.zNeg, CubieFace.yNeg];
    for (final cubie in cubies.where((c) => c.x == layer)) {
      final oldY = cubie.y;
      final oldZ = cubie.z;
      if (clockwise) {
        cubie.y = -oldZ;
        cubie.z = oldY;
      } else {
        cubie.y = oldZ;
        cubie.z = -oldY;
      }
      cubie.cycleFaces(cycle);
    }
  }

  void _rotateLayerY(int layer, bool clockwise) {
    final cycle = clockwise
        ? [CubieFace.xPos, CubieFace.zNeg, CubieFace.xNeg, CubieFace.zPos]
        : [CubieFace.xPos, CubieFace.zPos, CubieFace.xNeg, CubieFace.zNeg];
    for (final cubie in cubies.where((c) => c.y == layer)) {
      final oldX = cubie.x;
      final oldZ = cubie.z;
      if (clockwise) {
        cubie.x = oldZ;
        cubie.z = -oldX;
      } else {
        cubie.x = -oldZ;
        cubie.z = oldX;
      }
      cubie.cycleFaces(cycle);
    }
  }

  void _rotateLayerZ(int layer, bool clockwise) {
    final cycle = clockwise
        ? [CubieFace.xPos, CubieFace.yPos, CubieFace.xNeg, CubieFace.yNeg]
        : [CubieFace.xPos, CubieFace.yNeg, CubieFace.xNeg, CubieFace.yPos];
    for (final cubie in cubies.where((c) => c.z == layer)) {
      final oldX = cubie.x;
      final oldY = cubie.y;
      if (clockwise) {
        cubie.x = -oldY;
        cubie.y = oldX;
      } else {
        cubie.x = oldY;
        cubie.y = -oldX;
      }
      cubie.cycleFaces(cycle);
    }
  }
}
