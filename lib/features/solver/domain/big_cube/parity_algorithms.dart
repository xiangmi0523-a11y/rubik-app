import '../../../../core/nxn/nxn_cube_state.dart';

/// Parity formulas, in SiGN notation (2R = second layer from the right).
///
/// Their effect is checked on the real engine by the tests (and every use is
/// re-checked by the solver): on a cube whose centres are solved and whose
/// edges are paired, each changes exactly the stickers listed below.
abstract final class ParityAlgorithms {
  /// 4x4 OLL parity: flips the UF dedge (swaps its two wings).
  static const ollFour = "2R2 B2 U2 2L U2 2R' U2 2R U2 F2 2R F2 2L' B2 2R2";

  /// 4x4 PLL parity: swaps the UF and UB dedges.
  static const pllFour = "2R2 U2 2R2 U2 2U2 2R2 2U2";

  /// 5x5 edge parity: swaps the two wings of the UF edge (the middle edge
  /// stays), i.e. fixes a "flipped wing pair" left after pairing.
  static const edgeFive = "2R2 B2 U2 2L U2 2R' U2 2R U2 F2 2R F2 2L' B2 2R2";

  static List<NxnMove> moves(String alg, int n) => NxnMove.parseAll(alg, n);

  /// 4x4, for the centre phase (edges and corners still free): keeps every
  /// centre colour and makes an odd wing permutation, so pairing afterwards
  /// leaves no OLL parity. 7 turns — the shortest such sequence (found by a
  /// meet-in-the-middle search over all turns; none has 6 or fewer):
  /// Lw2 2D' 2-3Rw2 Uw 2-3Rw2 Dw' Lw2.
  static const List<NxnBlockMove> centreParityFour = [
    NxnBlockMove(0, -3, -1, 2), // Lw2
    NxnBlockMove(1, -1, -1, -1), // 2D'
    NxnBlockMove(0, -1, 1, 2), // 2-3Rw2
    NxnBlockMove(1, 1, 3, -1), // Uw
    NxnBlockMove(0, -1, 1, 2), // 2-3Rw2
    NxnBlockMove(1, -3, -1, -1), // Dw'
    NxnBlockMove(0, -3, -1, 2), // Lw2
  ];
}
