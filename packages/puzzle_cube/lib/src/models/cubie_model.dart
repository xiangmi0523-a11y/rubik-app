import 'package:flutter/material.dart';

import 'cube_colors.dart';

/// The six outward faces of a single cubie, named by the axis they point along.
enum CubieFace {
  /// Points toward +x.
  xPos,

  /// Points toward -x.
  xNeg,

  /// Points toward +y.
  yPos,

  /// Points toward -y.
  yNeg,

  /// Points toward +z.
  zPos,

  /// Points toward -z.
  zNeg,
}

/// One of the 27 small cubes ("cubies") that make up the puzzle.
///
/// Its [x], [y] and [z] position each range over `{-1, 0, 1}`, and [faces]
/// maps each visible outward face to its sticker colour.
class CubieModel {
  /// Creates a cubie at ([x], [y], [z]) with the given [faces].
  CubieModel({
    required this.x,
    required this.y,
    required this.z,
    required this.faces,
  });

  /// Grid position along x, in `{-1, 0, 1}`.
  int x;

  /// Grid position along y, in `{-1, 0, 1}`.
  int y;

  /// Grid position along z, in `{-1, 0, 1}`.
  int z;

  /// Visible faces mapped to their current sticker colour.
  final Map<CubieFace, Color> faces;

  /// A cubie at ([x], [y], [z]) with the standard solved colour scheme.
  factory CubieModel.solved({required int x, required int y, required int z}) {
    final faces = <CubieFace, Color>{};
    if (x == 1) faces[CubieFace.xPos] = CubeColors.green;
    if (x == -1) faces[CubieFace.xNeg] = CubeColors.blue;
    if (y == 1) faces[CubieFace.yPos] = CubeColors.white;
    if (y == -1) faces[CubieFace.yNeg] = CubeColors.yellow;
    if (z == 1) faces[CubieFace.zPos] = CubeColors.red;
    if (z == -1) faces[CubieFace.zNeg] = CubeColors.orange;
    return CubieModel(x: x, y: y, z: z, faces: faces);
  }

  /// Like [CubieModel.solved] but every visible sticker is left "colorless"
  /// (grey) EXCEPT the centre piece of each face, which keeps its fixed colour
  /// to anchor the cube's orientation while the user fills the rest in.
  factory CubieModel.colorless({
    required int x,
    required int y,
    required int z,
  }) {
    final isCenter =
        ((x == 0 ? 1 : 0) + (y == 0 ? 1 : 0) + (z == 0 ? 1 : 0)) == 2;
    if (isCenter) return CubieModel.solved(x: x, y: y, z: z);

    final solved = CubieModel.solved(x: x, y: y, z: z);
    final faces = <CubieFace, Color>{
      for (final face in solved.faces.keys) face: CubeColors.colorless,
    };
    return CubieModel(x: x, y: y, z: z, faces: faces);
  }

  /// Restores a cubie from [toJson] output.
  factory CubieModel.fromJson(Map<String, dynamic> json) {
    final facesJson = (json['faces'] as Map).cast<String, dynamic>();
    return CubieModel(
      x: json['x'] as int,
      y: json['y'] as int,
      z: json['z'] as int,
      faces: {
        for (final entry in facesJson.entries)
          CubieFace.values.byName(entry.key): Color(entry.value as int),
      },
    );
  }

  /// A deep copy of this cubie.
  CubieModel copy() => CubieModel(
        x: x,
        y: y,
        z: z,
        faces: Map.of(faces),
      );

  /// A JSON-serialisable snapshot of this cubie.
  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'z': z,
        'faces': {
          for (final entry in faces.entries)
            entry.key.name: entry.value.toARGB32(),
        },
      };

  /// Rotates the sticker colours around the given [cycle] of faces by one step
  /// (used when a layer turn carries this cubie's stickers to new faces).
  void cycleFaces(List<CubieFace> cycle) {
    final last = faces[cycle.last];
    for (int i = cycle.length - 1; i > 0; i--) {
      final src = faces[cycle[i - 1]];
      if (src != null) {
        faces[cycle[i]] = src;
      } else {
        faces.remove(cycle[i]);
      }
    }
    if (last != null) {
      faces[cycle.first] = last;
    } else {
      faces.remove(cycle.first);
    }
  }
}
