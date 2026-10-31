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
}
