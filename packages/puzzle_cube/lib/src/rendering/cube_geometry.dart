/// Model-space geometry of the 3x3 [Cube] widget, shared by the renderer and
/// every hit test so taps, drags and pixels always agree.
library;

/// Distance between neighbouring cubie centres.
const double kCubeSpacing = 2.2;

/// Half-size of a cubie body. Equal to half the spacing, so cubies touch
/// (no visible gaps), like a real speed cube.
const double kCubieHalf = kCubeSpacing / 2;

/// Outer half-extent of the whole cube.
const double kCubeHalfExtent = kCubeSpacing + kCubieHalf;

/// Model extent fitted to the viewport (`min(w, h) / 2` pixels).
const double kCubeFitSpread = 2 * kCubeHalfExtent;
