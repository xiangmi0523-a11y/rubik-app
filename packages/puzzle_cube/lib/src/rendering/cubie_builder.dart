import 'package:ditredi/ditredi.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import '../models/cubie_model.dart';

/// Builds the DiTreDi 3D geometry for a single [CubieModel]: a black body cube
/// plus one coloured plane per visible sticker.
class CubieBuilder {
  /// Returns the [Group3D] that renders [cubie] at its grid position.
  static Group3D build(CubieModel cubie) {
    const spacing = 2.2;
    const faceOffset = 1.01;

    final center = Vector3(
      cubie.x * spacing,
      cubie.y * spacing,
      cubie.z * spacing,
    );

    final figures = <Model3D>[
      Cube3D(2, center, color: Colors.black),
    ];

    cubie.faces.forEach((face, color) {
      switch (face) {
        case CubieFace.xPos:
          figures.add(
            Plane3D(
              1,
              Axis3D.x,
              false,
              center + Vector3(faceOffset, 0, 0),
              color: color,
            ),
          );
          break;
        case CubieFace.xNeg:
          figures.add(
            Plane3D(
              1,
              Axis3D.x,
              true,
              center + Vector3(-faceOffset, 0, 0),
              color: color,
            ),
          );
          break;
        case CubieFace.yPos:
          figures.add(
            Plane3D(
              1,
              Axis3D.y,
              false,
              center + Vector3(0, faceOffset, 0),
              color: color,
            ),
          );
          break;
        case CubieFace.yNeg:
          figures.add(
            Plane3D(
              1,
              Axis3D.y,
              true,
              center + Vector3(0, -faceOffset, 0),
              color: color,
            ),
          );
          break;
        case CubieFace.zPos:
          figures.add(
            Plane3D(
              1,
              Axis3D.z,
              true,
              center + Vector3(0, 0, faceOffset),
              color: color,
            ),
          );
          break;
        case CubieFace.zNeg:
          figures.add(
            Plane3D(
              1,
              Axis3D.z,
              false,
              center + Vector3(0, 0, -faceOffset),
              color: color,
            ),
          );
          break;
      }
    });

    return Group3D(figures);
  }
}
