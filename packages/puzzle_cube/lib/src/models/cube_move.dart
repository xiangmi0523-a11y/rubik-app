/// A single quarter-turn move in standard cube notation.
///
/// The plain letters are clockwise turns of the named face; the `i` suffix is
/// the inverse (counter-clockwise, e.g. `R'`). The trailing [m]/[e]/[s] entries
/// are middle-slice turns used by the drag-to-turn gesture.
enum CubeMove {
  /// Right face, clockwise (R).
  r,

  /// Right face, counter-clockwise (R').
  ri,

  /// Left face, clockwise (L).
  l,

  /// Left face, counter-clockwise (L').
  li,

  /// Up face, clockwise (U).
  u,

  /// Up face, counter-clockwise (U').
  ui,

  /// Down face, clockwise (D).
  d,

  /// Down face, counter-clockwise (D').
  di,

  /// Front face, clockwise (F).
  f,

  /// Front face, counter-clockwise (F').
  fi,

  /// Back face, clockwise (B).
  b,

  /// Back face, counter-clockwise (B').
  bi,

  /// Middle slice (between L and R), following L (M).
  m,

  /// Middle slice, counter-clockwise (M').
  mi,

  /// Equatorial slice (between U and D), following D (E).
  e,

  /// Equatorial slice, counter-clockwise (E').
  ei,

  /// Standing slice (between F and B), following F (S).
  s,

  /// Standing slice, counter-clockwise (S').
  si,
}

/// Inverse lookup for [CubeMove].
extension CubeMoveInverse on CubeMove {
  /// The move that undoes this one (e.g. `R` -> `R'`).
  CubeMove get inverse {
    switch (this) {
      case CubeMove.r:
        return CubeMove.ri;
      case CubeMove.ri:
        return CubeMove.r;
      case CubeMove.l:
        return CubeMove.li;
      case CubeMove.li:
        return CubeMove.l;
      case CubeMove.u:
        return CubeMove.ui;
      case CubeMove.ui:
        return CubeMove.u;
      case CubeMove.d:
        return CubeMove.di;
      case CubeMove.di:
        return CubeMove.d;
      case CubeMove.f:
        return CubeMove.fi;
      case CubeMove.fi:
        return CubeMove.f;
      case CubeMove.b:
        return CubeMove.bi;
      case CubeMove.bi:
        return CubeMove.b;
      case CubeMove.m:
        return CubeMove.mi;
      case CubeMove.mi:
        return CubeMove.m;
      case CubeMove.e:
        return CubeMove.ei;
      case CubeMove.ei:
        return CubeMove.e;
      case CubeMove.s:
        return CubeMove.si;
      case CubeMove.si:
        return CubeMove.s;
    }
  }
}
