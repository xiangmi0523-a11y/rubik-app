import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'cube_colors.dart';
import 'cubie_model.dart';
import 'puzzle_cube_state.dart';

/// What part of the cube a [CubeValidationIssue] refers to.
enum CubeValidationIssueType {
  /// A whole cubie (e.g. an impossible colour combination).
  cubie,

  /// A single sticker (e.g. a colour that isn't a cube colour).
  sticker,

  /// The cube as a whole (e.g. a colour appearing the wrong number of times).
  global,
}

/// A single problem found while validating a cube's colouring.
class CubeValidationIssue extends Equatable {
  /// Creates a validation issue. [x], [y], [z] and [face] locate the problem
  /// when applicable.
  const CubeValidationIssue({
    required this.type,
    required this.message,
    this.x,
    this.y,
    this.z,
    this.face,
  });

  /// What the issue refers to.
  final CubeValidationIssueType type;

  /// A human-readable description of the problem.
  final String message;

  /// X position of the offending cubie, if any.
  final int? x;

  /// Y position of the offending cubie, if any.
  final int? y;

  /// Z position of the offending cubie, if any.
  final int? z;

  /// The offending face, if the issue is sticker-scoped.
  final CubieFace? face;

  /// Whether this issue is located at cubie ([targetX], [targetY], [targetZ]).
  bool matchesCubie(int targetX, int targetY, int targetZ) {
    return x == targetX && y == targetY && z == targetZ;
  }

  /// Whether this issue covers the sticker [targetFace] on cubie
  /// ([targetX], [targetY], [targetZ]).
  bool matchesSticker(
    int targetX,
    int targetY,
    int targetZ,
    CubieFace targetFace,
  ) {
    if (!matchesCubie(targetX, targetY, targetZ)) {
      return false;
    } else {
      return face == null || face == targetFace;
    }
  }

  @override
  List<Object?> get props => [type, message, x, y, z, face];
}

/// The outcome of validating a cube: whether it is [isValid] and the list of
/// [issues] found.
class CubeValidationResult extends Equatable {
  /// Creates a validation result.
  const CubeValidationResult({
    required this.isValid,
    this.issues = const [],
  });

  /// Whether the cube passed every check.
  final bool isValid;

  /// The problems found (empty when [isValid] is true).
  final List<CubeValidationIssue> issues;

  @override
  List<Object?> get props => [isValid, issues];
}

/// The number of stickers each colour must appear exactly once-per-face times
/// on a 3x3 cube (9).
const int kStickersPerColor = 9;

/// Checks whether a cube's colouring could belong to a real, solvable 3x3 cube.
///
/// It verifies that centres are unchanged, that each piece has the right number
/// of stickers with no duplicate or opposite colours, that every edge/corner
/// colour combination physically exists, and that each colour appears exactly
/// [kStickersPerColor] times.
class CubeColorValidator {
  /// Creates a validator.
  const CubeColorValidator();

  /// How many times each colour must appear on a valid cube.
  static const int expectedStickerCountPerColor = kStickersPerColor;

  static final Set<String> _validEdgeSignatures = {
    _signatureFromNames(['White', 'Green']),
    _signatureFromNames(['White', 'Red']),
    _signatureFromNames(['White', 'Blue']),
    _signatureFromNames(['White', 'Orange']),
    _signatureFromNames(['Yellow', 'Green']),
    _signatureFromNames(['Yellow', 'Red']),
    _signatureFromNames(['Yellow', 'Blue']),
    _signatureFromNames(['Yellow', 'Orange']),
    _signatureFromNames(['Green', 'Red']),
    _signatureFromNames(['Red', 'Blue']),
    _signatureFromNames(['Blue', 'Orange']),
    _signatureFromNames(['Orange', 'Green']),
  };

  static final Set<String> _validCornerSignatures = {
    _signatureFromNames(['White', 'Green', 'Red']),
    _signatureFromNames(['White', 'Red', 'Blue']),
    _signatureFromNames(['White', 'Blue', 'Orange']),
    _signatureFromNames(['White', 'Orange', 'Green']),
    _signatureFromNames(['Yellow', 'Green', 'Red']),
    _signatureFromNames(['Yellow', 'Red', 'Blue']),
    _signatureFromNames(['Yellow', 'Blue', 'Orange']),
    _signatureFromNames(['Yellow', 'Orange', 'Green']),
  };

  /// Validates [cube] and returns the result.
  CubeValidationResult validate(PuzzleCubeState cube) {
    final issues = <CubeValidationIssue>[];

    _validateCenters(cube, issues);
    _validatePieces(cube, issues);
    _validateGlobalColorCounts(cube, issues);

    return CubeValidationResult(
      isValid: issues.isEmpty,
      issues: issues,
    );
  }

  void _validateCenters(PuzzleCubeState cube, List<CubeValidationIssue> issues) {
    for (final cubie in cube.cubies) {
      if (!_isCenter(cubie.x, cubie.y, cubie.z)) {
        continue;
      }
      final expectedFaces =
          CubieModel.solved(x: cubie.x, y: cubie.y, z: cubie.z).faces;

      if (!_sameFaces(cubie.faces, expectedFaces)) {
        issues.add(
          CubeValidationIssue(
            type: CubeValidationIssueType.cubie,
            x: cubie.x,
            y: cubie.y,
            z: cubie.z,
            message: 'Center colors must stay fixed.',
          ),
        );
      }
    }
  }

  void _validatePieces(PuzzleCubeState cube, List<CubeValidationIssue> issues) {
    for (final cubie in cube.cubies) {
      if (_isCore(cubie.x, cubie.y, cubie.z) ||
          _isCenter(cubie.x, cubie.y, cubie.z)) {
        continue;
      }

      final colors = cubie.faces.values.toList();
      final uniqueArgb = colors.map((c) => c.toARGB32()).toSet();
      final expectedVisibleFaces = _expectedVisibleFaces(
        cubie.x,
        cubie.y,
        cubie.z,
      );

      if (colors.length != expectedVisibleFaces) {
        issues.add(
          CubeValidationIssue(
            type: CubeValidationIssueType.cubie,
            x: cubie.x,
            y: cubie.y,
            z: cubie.z,
            message: 'This piece has an invalid number of visible stickers.',
          ),
        );
        continue;
      }

      if (uniqueArgb.length != colors.length) {
        issues.add(
          CubeValidationIssue(
            type: CubeValidationIssueType.cubie,
            x: cubie.x,
            y: cubie.y,
            z: cubie.z,
            message: 'A cubie contains the same color twice.',
          ),
        );
      }

      if (_containOppositePair(colors)) {
        issues.add(
          CubeValidationIssue(
            type: CubeValidationIssueType.cubie,
            x: cubie.x,
            y: cubie.y,
            z: cubie.z,
            message: 'A cubie cannot contain opposite colors like '
                'green/blue, white/yellow, red/orange.',
          ),
        );
      }

      final unknownColors = colors.where((c) => !CubeColors.isAllowed(c));
      for (final color in unknownColors) {
        issues.add(
          CubeValidationIssue(
            type: CubeValidationIssueType.sticker,
            x: cubie.x,
            y: cubie.y,
            z: cubie.z,
            message: '${CubeColors.nameOf(color)} is not an allowed cube color.',
          ),
        );
      }

      final signature = _signature(colors);
      if (_isEdge(cubie.x, cubie.y, cubie.z) &&
          !_validEdgeSignatures.contains(signature)) {
        issues.add(
          CubeValidationIssue(
            type: CubeValidationIssueType.cubie,
            x: cubie.x,
            y: cubie.y,
            z: cubie.z,
            message: 'This edge combination is impossible in a real cube.',
          ),
        );
      }
      if (_isCorner(cubie.x, cubie.y, cubie.z) &&
          !_validCornerSignatures.contains(signature)) {
        issues.add(
          CubeValidationIssue(
            type: CubeValidationIssueType.cubie,
            x: cubie.x,
            y: cubie.y,
            z: cubie.z,
            message: 'This corner combination is impossible in a real cube.',
          ),
        );
      }
    }
  }

  void _validateGlobalColorCounts(
    PuzzleCubeState cube,
    List<CubeValidationIssue> issues,
  ) {
    final counts = <int, int>{
      for (final color in CubeColors.palette) color.toARGB32(): 0,
    };

    for (final cubie in cube.cubies) {
      for (final color in cubie.faces.values) {
        if (CubeColors.isAllowed(color)) {
          final key = color.toARGB32();
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
    }

    for (final color in CubeColors.palette) {
      final key = color.toARGB32();
      final count = counts[key] ?? 0;

      if (count != expectedStickerCountPerColor) {
        issues.add(
          CubeValidationIssue(
            type: CubeValidationIssueType.global,
            message: '${CubeColors.nameOf(color)} appears $count times. '
                'Expected $expectedStickerCountPerColor.',
          ),
        );
      }
    }
  }

  bool _sameFaces(Map<CubieFace, Color> a, Map<CubieFace, Color> b) {
    if (a.length != b.length) {
      return false;
    }

    for (final entry in a.entries) {
      final other = b[entry.key];

      if (other == null) {
        return false;
      }
      if (other.toARGB32() != entry.value.toARGB32()) {
        return false;
      }
    }

    return true;
  }

  bool _containOppositePair(List<Color> colors) {
    for (int i = 0; i < colors.length; i++) {
      for (int j = i + 1; j < colors.length; j++) {
        if (CubeColors.areOpposites(colors[i], colors[j])) {
          return true;
        }
      }
    }
    return false;
  }

  int _expectedVisibleFaces(int x, int y, int z) {
    if (_isCorner(x, y, z)) {
      return 3;
    }
    if (_isEdge(x, y, z)) {
      return 2;
    }
    if (_isCenter(x, y, z)) {
      return 1;
    }
    return 0;
  }

  bool _isCore(int x, int y, int z) {
    return x == 0 && y == 0 && z == 0;
  }

  bool _isCorner(int x, int y, int z) {
    return x != 0 && y != 0 && z != 0;
  }

  bool _isEdge(int x, int y, int z) {
    final zeros = (x == 0 ? 1 : 0) + (y == 0 ? 1 : 0) + (z == 0 ? 1 : 0);
    return zeros == 1;
  }

  bool _isCenter(int x, int y, int z) {
    final zeros = (x == 0 ? 1 : 0) + (y == 0 ? 1 : 0) + (z == 0 ? 1 : 0);
    return zeros == 2;
  }

  String _signature(Iterable<Color> colors) {
    final names = colors.map(CubeColors.nameOf).toList()..sort();
    return names.join('|');
  }

  static String _signatureFromNames(List<String> names) {
    final sorted = [...names]..sort();
    return sorted.join('|');
  }
}
