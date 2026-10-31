import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// One visible face of a cubie, ready to paint.
///
/// [at] maps face-local coordinates (a, b) in [-1, 1]² to screen pixels, so
/// rounded shapes stay correct under perspective. [normal] is the face normal
/// in *screen space*: x right, y down, z towards the viewer (unit length).
class CubieFaceDraw {
  /// Creates a face draw.
  const CubieFaceDraw({required this.at, required this.normal, this.sticker});

  /// Maps face-local (a, b) in [-1, 1]² to screen pixels.
  final Offset Function(double a, double b) at;

  /// Screen-space unit normal (x right, y down, z towards the viewer).
  final Vector3 normal;

  /// Sticker colour, or null for a bare (inner) plastic face.
  final Color? sticker;
}

/// A cubie: its visible faces and a depth for back-to-front sorting.
class CubieDraw {
  /// Creates a cubie draw.
  const CubieDraw({required this.depth, required this.faces, this.group = 0});

  /// Larger = nearer to the viewer.
  final double depth;

  /// Cubies in the same group form one rigid convex block (e.g. the slabs on
  /// either side of a turning layer). Groups are drawn back to front as a
  /// whole, so a turning layer never cuts through the rest of the cube.
  final int group;

  /// Faces turned towards the viewer.
  final List<CubieFaceDraw> faces;
}

/// Look of the cube.
class CubeRenderStyle {
  /// Creates a style.
  const CubeRenderStyle({
    this.bodyColor = const Color(0xFF1B1B1E),
    this.stickerInset = 0.85,
    this.stickerRadius = 0.26,
    this.bodyRadius = 0.06,
    this.shadow = true,
  });

  /// Plastic colour.
  final Color bodyColor;

  /// Sticker half-size relative to the cubie face (1 = edge to edge).
  final double stickerInset;

  /// Corner radius in face-local units.
  final double stickerRadius;

  /// Corner radius of the plastic face, in face-local units.
  final double bodyRadius;

  /// Soft contact shadow under the cube.
  final bool shadow;
}

/// Paints cubies with Lambert + Blinn-Phong lighting, rounded stickers with a
/// glossy gradient, and a soft ground shadow. Shared by the 3x3 and the N×N
/// engine so every puzzle looks the same.
class RealisticCubeRenderer {
  /// Creates a renderer with [style].
  RealisticCubeRenderer([this.style = const CubeRenderStyle()]);

  /// Look of the cube.
  final CubeRenderStyle style;

  /// Light from the upper left, slightly in front (screen space).
  static final Vector3 _light = Vector3(-0.4, -0.7, 0.8)..normalize();
  static final Vector3 _half = (_light + Vector3(0, 0, 1))..normalize();

  static const _ambient = 0.68;
  static const _diffuse = 0.42;

  /// Paints [cubies] (any order; they are sorted here). [extent] is the
  /// cube's on-screen radius in pixels, used for the shadow.
  void paint(Canvas canvas, Size size, List<CubieDraw> cubies,
      {double? extent,}) {
    if (style.shadow) _paintShadow(canvas, size, extent);
    // Average depth per group, then back-to-front within each group.
    final sums = <int, double>{};
    final counts = <int, int>{};
    for (final c in cubies) {
      sums[c.group] = (sums[c.group] ?? 0) + c.depth;
      counts[c.group] = (counts[c.group] ?? 0) + 1;
    }
    double groupDepth(int g) => sums[g]! / counts[g]!;
    final sorted = [...cubies]
      ..sort((a, b) {
        if (a.group != b.group) {
          return groupDepth(a.group).compareTo(groupDepth(b.group));
        }
        return a.depth.compareTo(b.depth);
      });
    for (final cubie in sorted) {
      for (final face in cubie.faces) {
        _paintFace(canvas, face);
      }
    }
  }

  void _paintShadow(Canvas canvas, Size size, double? extent) {
    final r = extent ?? math.min(size.width, size.height) * 0.36;
    final center = Offset(size.width / 2, size.height / 2 + r * 1.1);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: r * 1.9, height: r * 0.34),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );
  }

  double _diffuseTerm(Vector3 n) => math.max(0, n.dot(_light));

  double _specular(Vector3 n, double shininess) =>
      math.pow(math.max(0, n.dot(_half)), shininess).toDouble();

  Color _shade(Color base, Vector3 n,
      {double spec = 0, double shininess = 40,}) {
    final k = _ambient + _diffuse * _diffuseTerm(n);
    final s = spec * _specular(n, shininess);
    int ch(double c) => ((c * k + s) * 255).round().clamp(0, 255);
    return Color.fromARGB(255, ch(base.r), ch(base.g), ch(base.b));
  }

  void _paintFace(Canvas canvas, CubieFaceDraw face) {
    // Plastic body: fills the whole cell so neighbouring cubies touch; the
    // seam between them is a hairline groove, like a real speed cube.
    final body = _roundedRect(face.at, 1.0, style.bodyRadius);
    canvas.drawPath(
      body,
      Paint()
        ..color =
            _shade(style.bodyColor, face.normal, spec: 0.3, shininess: 16),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = Colors.black.withValues(alpha: 0.9),
    );

    final color = face.sticker;
    if (color == null) return;

    final sticker =
        _roundedRect(face.at, style.stickerInset, style.stickerRadius);
    final lit = _shade(color, face.normal);
    // Glossy gradient: brighter towards the light, darker away from it.
    final towards = Offset(_light.x, _light.y);
    final c = face.at(0, 0);
    final reach = (face.at(1, 1) - face.at(-1, -1)).distance / 2;
    final from = c + towards * reach;
    final to = c - towards * reach;
    canvas.drawPath(
      sticker,
      Paint()
        ..shader = ui.Gradient.linear(from, to, [
          Color.lerp(lit, Colors.white, 0.16)!,
          lit,
          Color.lerp(lit, Colors.black, 0.14)!,
        ], [
          0,
          0.55,
          1,
        ]),
    );
    // Specular sheen on faces turned toward the light.
    final spec = _specular(face.normal, 36);
    if (spec > 0.02) {
      canvas.drawPath(
        sticker,
        Paint()
          ..shader = ui.Gradient.radial(
            c + towards * reach * 0.35,
            reach * 1.1,
            [
              Colors.white.withValues(alpha: 0.38 * spec),
              Colors.white.withValues(alpha: 0),
            ],
          ),
      );
    }
    // Sticker edge: subtle dark outline for depth.
    canvas.drawPath(
      sticker,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = Colors.black.withValues(alpha: 0.35),
    );
  }

  /// Rounded square of half-size [half] and corner radius [radius] in
  /// face-local units, mapped through [at].
  Path _roundedRect(
      Offset Function(double, double) at, double half, double radius,) {
    const steps = 5;
    final r = math.min(radius, half);
    final inner = half - r;
    final pts = <Offset>[];
    // Corner centres in order, with the arc start angle of each.
    const corners = [(1, 1, 0.0), (-1, 1, 0.5), (-1, -1, 1.0), (1, -1, 1.5)];
    for (final (sa, sb, start) in corners) {
      final ca = sa * inner;
      final cb = sb * inner;
      for (var i = 0; i <= steps; i++) {
        final t = (start + 0.5 * i / steps) * math.pi;
        pts.add(at(ca + r * math.cos(t), cb + r * math.sin(t)));
      }
    }
    return Path()..addPolygon(pts, true);
  }
}
