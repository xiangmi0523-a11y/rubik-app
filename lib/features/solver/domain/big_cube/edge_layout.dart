import '../../../../core/nxn/nxn_cube_state.dart';
import '../../../../core/nxn/nxn_facelets.dart';
import 'cycle_library.dart';

/// One wing position: its named sticker (in the [PieceCycleLibrary.wings]
/// orbit) and its other sticker.
class WingSlot {
  const WingSlot(this.named, this.other);
  final int named;
  final int other;
}

/// One of the 12 edge positions of a 4x4 / 5x5.
class EdgePosition {
  const EdgePosition({
    required this.index,
    required this.name,
    required this.faces,
    required this.wings,
    required this.faceSlots,
    this.midge,
  });

  final int index;

  /// Face letters of the edge, e.g. "UF".
  final String name;

  /// The two faces (0..5 = U R F D L B) the edge touches.
  final (int, int) faces;

  /// The two wing positions, by ascending free coordinate.
  final List<WingSlot> wings;

  /// All of the edge's stickers on [faces].$1 and on [faces].$2.
  final (List<int>, List<int>) faceSlots;

  /// 5x5 only: the middle edge's stickers on [faces].$1 and [faces].$2.
  final (int, int)? midge;
}

/// The 12 edges of an order-n cube (n = 4 or 5), derived from [NxnFacelets].
class EdgeLayout {
  EdgeLayout._(this.n, this.edges, this.wingIndexOfNamed);

  final int n;
  final List<EdgePosition> edges;

  /// Named wing slot → index into [wingSlots].
  final Map<int, int> wingIndexOfNamed;

  /// All 24 wing positions: edge by edge, two per edge.
  List<WingSlot> get wingSlots => [for (final e in edges) ...e.wings];

  /// Edge of wing position [wing] (an index into [wingSlots]).
  EdgePosition edgeOfWing(int wing) => edges[wing ~/ 2];

  static final Map<int, EdgeLayout> _cache = {};

  factory EdgeLayout(int n) {
    if (n != 4 && n != 5) {
      throw ArgumentError('Edge layout only for 4x4 and 5x5, got $n');
    }
    return _cache.putIfAbsent(n, () => _build(n));
  }

  static const _letters = 'URFDLB';

  static EdgeLayout _build(int n) {
    final f = NxnFacelets(n);
    final named = PieceCycleLibrary.wingOrbit(n).toSet();
    // Edge key: the wing position with its free coordinate set to 0.
    final byEdge = <IVec, List<int>>{}; // key → wing piece ids
    final pieceSlots = <int, List<int>>{};
    for (final s in f.slotsOfKind(SlotKind.wing)) {
      final piece = f.pieceOf[s];
      pieceSlots.putIfAbsent(piece, () => []).add(s);
    }
    IVec keyOf(IVec p) {
      final m = n - 1;
      return (p.$1.abs() == m ? p.$1 : 0, p.$2.abs() == m ? p.$2 : 0,
          p.$3.abs() == m ? p.$3 : 0);
    }

    int freeCoord(IVec p) {
      final m = n - 1;
      return p.$1.abs() != m ? p.$1 : (p.$2.abs() != m ? p.$2 : p.$3);
    }

    for (final piece in pieceSlots.keys) {
      final pos = f.posOf[pieceSlots[piece]!.first];
      byEdge.putIfAbsent(keyOf(pos), () => []).add(piece);
    }

    final edges = <EdgePosition>[];
    final keys = byEdge.keys.toList()
      ..sort((a, b) {
        // Order by face letters (URFDLB), e.g. UR UF UL UB, DR ..., FR ...
        final fa = _faces(a), fb = _faces(b);
        final c = fa.$1.compareTo(fb.$1);
        return c != 0 ? c : fa.$2.compareTo(fb.$2);
      });
    final wingIndexOfNamed = <int, int>{};
    for (final key in keys) {
      final pieces = byEdge[key]!
        ..sort((a, b) => freeCoord(f.posOf[pieceSlots[a]!.first])
            .compareTo(freeCoord(f.posOf[pieceSlots[b]!.first])));
      if (pieces.length != 2) throw StateError('Edge $key has ${pieces.length} wings');
      final wings = [
        for (final p in pieces)
          () {
            final slots = pieceSlots[p]!;
            final a = slots.firstWhere(named.contains);
            final b = slots.firstWhere((s) => !named.contains(s));
            return WingSlot(a, b);
          }(),
      ];
      final faces = _faces(key);
      // The two wings name stickers on different faces (mirror twins).
      if (f.faceOf[wings[0].named] == f.faceOf[wings[1].named]) {
        throw StateError('Wings of edge $key name the same face');
      }
      final edgeSlots = [
        for (final w in wings) ...[w.named, w.other],
        if (n == 5) ...[
          for (final s in f.slotsOfKind(SlotKind.midEdge))
            if (f.posOf[s] == key) s,
        ],
      ];
      final onA = [for (final s in edgeSlots) if (f.faceOf[s] == faces.$1) s];
      final onB = [for (final s in edgeSlots) if (f.faceOf[s] == faces.$2) s];
      (int, int)? midge;
      if (n == 5) {
        final mid = [
          for (final s in f.slotsOfKind(SlotKind.midEdge))
            if (f.posOf[s] == key) s,
        ];
        midge = (
          mid.firstWhere((s) => f.faceOf[s] == faces.$1),
          mid.firstWhere((s) => f.faceOf[s] == faces.$2),
        );
      }
      final index = edges.length;
      for (var k = 0; k < 2; k++) {
        wingIndexOfNamed[wings[k].named] = index * 2 + k;
      }
      edges.add(EdgePosition(
        index: index,
        name: '${_letters[faces.$1]}${_letters[faces.$2]}',
        faces: faces,
        wings: wings,
        faceSlots: (onA, onB),
        midge: midge,
      ));
    }
    if (edges.length != 12) throw StateError('Found ${edges.length} edges');
    return EdgeLayout._(n, edges, wingIndexOfNamed);
  }

  /// The two faces of the edge whose key (free coordinate 0) is [key],
  /// ordered U R F D L B.
  static (int, int) _faces(IVec key) {
    final normals = NxnFacelets.faceNormals;
    final found = <int>[];
    for (var i = 0; i < 6; i++) {
      final nv = normals[i];
      final dot = nv.$1 * key.$1 + nv.$2 * key.$2 + nv.$3 * key.$3;
      if (dot > 0) found.add(i);
    }
    found.sort();
    return (found[0], found[1]);
  }

  /// Edge with face letters [name] (either order), e.g. "UF".
  EdgePosition edgeNamed(String name) => edges.firstWhere((e) =>
      e.name == name || e.name == name.split('').reversed.join());

  /// Whether every edge shows one colour per face (wings, and on 5x5 the
  /// middle edge, all agree).
  bool allPaired(List<int> colors) => edges.every((e) => paired(colors, e));

  bool paired(List<int> colors, EdgePosition e) {
    final (a, b) = e.faceSlots;
    return a.every((s) => colors[s] == colors[a.first]) &&
        b.every((s) => colors[s] == colors[b.first]);
  }

  /// Engine-state convenience for [allPaired].
  bool allPairedState(NxnCubeState state) =>
      allPaired(NxnFacelets(n).read(state));
}
