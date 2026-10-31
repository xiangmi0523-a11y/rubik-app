import '../../../../core/nxn/nxn_cube_state.dart';
import '../../../../core/nxn/nxn_facelets.dart';

/// The face colours a cube must end up with, in face order U R F D L B
/// (ARGB values).
///
/// Even cubes have no fixed centres. The *colour scheme* (which colours are
/// opposite, and their handedness) comes from the corners: the corner in the
/// down-back-left position gives D, L and B, and the standard opposite pairs
/// give U, R and F. The cube may be held any way, so the scheme may end up in
/// any of its 24 orientations; [bestFor] picks the orientation that already
/// matches the most centres, so finished centres are never redone.
class TargetScheme {
  const TargetScheme._(this.faceColors);

  /// ARGB colour per face, order U R F D L B.
  final List<int> faceColors;

  /// Standard-scheme opposite of each colour (from the engine's solved cube).
  static final Map<int, int> _opposite = {
    for (final e in NxnCubeState.faceColors.entries)
      e.value.toARGB32():
          NxnCubeState.faceColors[(-e.key.$1, -e.key.$2, -e.key.$3)]!
              .toARGB32(),
  };

  /// Reads the target from the down-back-left corner, or returns null if that
  /// corner isn't a legal piece of the standard scheme.
  static TargetScheme? fromCorner(NxnCubeState state) {
    final f = NxnFacelets(state.n);
    final colors = f.read(state);
    final m = state.n - 1;
    final corner = (-m, -m, -m);
    final d = colors[f.slotAt(corner, (0, -1, 0))];
    final l = colors[f.slotAt(corner, (-1, 0, 0))];
    final b = colors[f.slotAt(corner, (0, 0, -1))];
    if (!_opposite.containsKey(d) ||
        !_opposite.containsKey(l) ||
        !_opposite.containsKey(b)) {
      return null;
    }
    if ({d, l, b}.length != 3 ||
        _opposite[d] == l ||
        _opposite[d] == b ||
        _opposite[l] == b) {
      return null;
    }
    // U R F D L B
    return TargetScheme._([_opposite[d]!, _opposite[l]!, _opposite[b]!, d, l, b]);
  }

  /// Odd cubes: the colours of the fixed centres, which no turn can change
  /// relative to each other. Null for even cubes, or if they aren't six
  /// different scheme colours with the standard opposite pairs.
  static TargetScheme? fromFixedCenters(NxnCubeState state) {
    if (state.n.isEven) return null;
    final f = NxnFacelets(state.n);
    final colors = f.read(state);
    final m = state.n - 1;
    final faces = [
      for (final nv in NxnFacelets.faceNormals)
        colors[f.slotAt((nv.$1 * m, nv.$2 * m, nv.$3 * m), nv)],
    ];
    if (faces.toSet().length != 6 || !faces.every(_opposite.containsKey)) {
      return null;
    }
    for (var i = 0; i < 3; i++) {
      if (_opposite[faces[i]] != faces[i + 3]) return null;
    }
    return TargetScheme._(faces);
  }

  /// The 24 orientations of this scheme (this one first): the face colours
  /// of a cube coloured with this scheme after each whole-cube rotation.
  List<TargetScheme> orientations() {
    // Face colours permute like the face normals under a rotation.
    final normals = NxnFacelets.faceNormals;
    final seen = <String>{};
    final out = <TargetScheme>[];
    var frontier = [faceColors];
    while (frontier.isNotEmpty) {
      final next = <List<int>>[];
      for (final colors in frontier) {
        if (!seen.add(colors.join(','))) continue;
        out.add(TargetScheme._(colors));
        for (var axis = 0; axis < 3; axis++) {
          // Colour on face i moves to the face whose normal is rot(normal_i).
          final rotated = List<int>.filled(6, 0);
          for (var i = 0; i < 6; i++) {
            rotated[normals.indexOf(rotateIVec(normals[i], axis, 1))] = colors[i];
          }
          next.add(rotated);
        }
      }
      frontier = next;
    }
    return out;
  }

  /// The scheme read from the corners, in the orientation that matches the
  /// most centre stickers of [kind] on [state] (ties keep the corner's own
  /// orientation). Null if the reference corner is illegal.
  static TargetScheme? bestFor(NxnCubeState state, SlotKind kind) {
    final base = fromCorner(state);
    if (base == null) return null;
    final f = NxnFacelets(state.n);
    final colors = f.read(state);
    final centres = f.slotsOfKind(kind);
    int score(TargetScheme t) =>
        centres.where((s) => colors[s] == t.faceColors[f.faceOf[s]]).length;
    var best = base;
    var bestScore = score(base);
    for (final t in base.orientations()) {
      final sc = score(t);
      if (sc > bestScore) {
        best = t;
        bestScore = sc;
      }
    }
    return best;
  }
}
