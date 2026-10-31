import 'dart:typed_data';

import '../../../../core/nxn/nxn_cube_state.dart';
import '../../../../core/nxn/nxn_facelets.dart';
import 'cycle_library.dart';

/// Block-turn search for the centre phase.
///
/// While the centres are being solved, nothing else needs to be kept:
/// edges are paired and corners solved later, from whatever state they are
/// in. So instead of pure 3-cycles, any legal turn may be used — a single
/// layer, a wide turn (Rw, 3Rw), an inner block (2-3Rw) — and the cost is
/// counted in turns, the way the player shows them.
///
/// [greedy] repeatedly looks at every sequence of up to three turns and takes
/// the one that solves the most centres per turn, as long as it solves more
/// than it breaks. Each such step solves at least one more centre, so it
/// always ends; whatever it leaves (typically a few pieces that need a
/// commutator) is finished by the pure 3-cycles of [PieceCycleLibrary].
///
/// On a 5x5 the X- and T-centres are solved together, against the colours
/// of the fixed centres wherever they are (turns of the middle layer move
/// them; the colour scheme is unaffected).
class CenterSearch {
  CenterSearch._(this.n) {
    final t = NxnMoveTable(n);
    final f = t.facelets;
    final solvable = [
      ...f.slotsOfKind(SlotKind.centerX),
      if (n.isOdd) ...f.slotsOfKind(SlotKind.centerT),
    ];
    final fixed = n.isOdd ? f.slotsOfKind(SlotKind.centerFixed) : <int>[];
    slots = [...solvable, ...fixed];
    solvableCount = solvable.length;
    final index = Int32List(f.count)..fillRange(0, f.count, -1);
    for (var i = 0; i < slots.length; i++) {
      index[slots[i]] = i;
    }
    face = [for (final s in slots) f.faceOf[s]];
    fixedOfFace = [
      if (n.isOdd)
        for (var fc = 0; fc < 6; fc++)
          solvable.length + fixed.indexWhere((s) => f.faceOf[s] == fc),
    ];
    final wings = PieceCycleLibrary.wingOrbit(n);
    final layers = f.layers;
    for (var axis = 0; axis < 3; axis++) {
      for (var a = 0; a < n; a++) {
        for (var b = a; b < n; b++) {
          if (a == 0 && b == n - 1) continue; // whole-cube rotation
          final mid = n.isOdd && a <= n ~/ 2 && b >= n ~/ 2;
          // A block through the middle that reaches a face is, for the
          // centres, its complement plus a rotation: nothing new.
          if (mid && (a == 0 || b == n - 1)) continue;
          for (final turns in const [1, -1, 2]) {
            final block = NxnBlockMove(axis, layers[a], layers[b], turns);
            var full = Int32List.fromList([for (var i = 0; i < f.count; i++) i]);
            for (final m in block.moves) {
              final q = t.perms[t.indexOf(m)];
              final r = Int32List(f.count);
              for (var i = 0; i < f.count; i++) {
                r[i] = q[full[i]];
              }
              full = r;
            }
            final p = Int32List(slots.length);
            for (var i = 0; i < slots.length; i++) {
              p[i] = index[full[slots[i]]];
            }
            moves.add(block);
            perms.add(p);
            moved.add(Int32List.fromList(
                [for (var i = 0; i < slots.length; i++) if (p[i] != i) i]));
            touchesFixed.add(mid);
            wingOdd.add(_odd(wings, full));
          }
        }
      }
    }
  }

  static final Map<int, CenterSearch> _cache = {};

  /// The search for an order-[n] cube (n = 4 or 5), cached.
  factory CenterSearch(int n) {
    if (n != 4 && n != 5) throw ArgumentError('Centre search is for 4x4 / 5x5');
    return _cache.putIfAbsent(n, () => CenterSearch._(n));
  }

  final int n;

  /// Tracked engine slots: centres to solve, then (5x5) the fixed centres.
  late final List<int> slots;
  late final int solvableCount;

  /// Face (0..5, U R F D L B) of each tracked slot.
  late final List<int> face;

  /// 5x5: tracked index of each face's fixed centre.
  late final List<int> fixedOfFace;

  /// Candidate turns and their effect on the tracked slots.
  final List<NxnBlockMove> moves = [];
  final List<Int32List> perms = [];
  final List<Int32List> moved = [];
  final List<bool> touchesFixed = [];

  /// Whether the turn is an odd permutation of the wings.
  final List<bool> wingOdd = [];

  static bool _odd(List<int> named, Int32List full) {
    final pos = {for (var i = 0; i < named.length; i++) named[i]: i};
    final seen = List<bool>.filled(named.length, false);
    var parity = 0;
    for (var i = 0; i < named.length; i++) {
      if (seen[i]) continue;
      var len = 0;
      for (var j = i; !seen[j]; j = pos[full[named[j]]]!) {
        seen[j] = true;
        len++;
      }
      parity ^= (len - 1) & 1;
    }
    return parity == 1;
  }

  /// Colour index of each tracked slot of [state]; [colorIndex] maps ARGB to
  /// 0..5. Null if a sticker has another colour.
  Uint8List? read(NxnCubeState state, Map<int, int> colorIndex) {
    final colors = NxnFacelets(n).read(state);
    final out = Uint8List(slots.length);
    for (var i = 0; i < slots.length; i++) {
      final c = colorIndex[colors[slots[i]]];
      if (c == null) return null;
      out[i] = c;
    }
    return out;
  }

  int _target(Uint8List c, List<int>? target, int i) =>
      target == null ? c[fixedOfFace[face[i]]] : target[face[i]];

  /// Number of solved centres in [c].
  int solved(Uint8List c, List<int>? target) {
    var k = 0;
    for (var i = 0; i < solvableCount; i++) {
      if (c[i] == _target(c, target, i)) k++;
    }
    return k;
  }

  /// Applies move [mi] to [c] in place.
  void apply(Uint8List c, int mi) {
    final src = Uint8List.fromList(c);
    final p = perms[mi];
    for (final i in moved[mi]) {
      c[p[i]] = src[i];
    }
  }

  /// Index of each move's inverse.
  late final List<int> inverse = [
    for (final m in moves) moves.indexOf(m.inverse),
  ];

  /// Every commutator [A, B] = A B A' B' of two turns on different axes
  /// that moves some centres but no fixed centre, as sparse (from → to)
  /// pairs on the tracked slots.
  late final List<(int, int, Int32List, Int32List)> _commutators = () {
    final out = <(int, int, Int32List, Int32List)>[];
    final len = slots.length;
    for (var a = 0; a < moves.length; a++) {
      for (var b = 0; b < moves.length; b++) {
        if (moves[a].axis == moves[b].axis) continue;
        var pos = Int32List.fromList([for (var i = 0; i < len; i++) i]);
        for (final m in [a, b, inverse[a], inverse[b]]) {
          final p = perms[m];
          final r = Int32List(len);
          for (var i = 0; i < len; i++) {
            r[i] = p[pos[i]];
          }
          pos = r;
        }
        final from = <int>[], to = <int>[];
        var fixedMoved = false;
        for (var i = 0; i < len; i++) {
          if (pos[i] == i) continue;
          if (i >= solvableCount) fixedMoved = true;
          from.add(i);
          to.add(pos[i]);
        }
        if (from.isEmpty || fixedMoved) continue;
        // Keep one commutator per distinct effect on the centres.
        final key = '${from.join(',')}>${to.join(',')}';
        if (!seenEffects.add(key)) continue;
        var mask = 0;
        for (final i in from) {
          mask |= 1 << i; // ≤ 54 tracked slots: fits a 64-bit int
        }
        _commMasks.add(mask);
        out.add((a, b, Int32List.fromList(from), Int32List.fromList(to)));
      }
    }
    return out;
  }();
  final Set<String> seenEffects = {};
  final List<int> _commMasks = [];

  /// Tracked slots each move changes, as a bit mask.
  late final List<int> _moveMasks = [
    for (final mv in moved) mv.fold(0, (m, i) => m | (1 << i)),
  ];

  /// Greedy short-sequence solving (see the class doc). [colors] is updated
  /// in place; returns the chosen sequences, each a list of move indices.
  /// [target]: colour index per face (4x4), null to use the fixed centres.
  ///
  /// Candidates: every sequence of up to [maxDepth] turns (no two in a row
  /// on one axis), and every commutator A B A' B' of two turns.
  List<List<int>> greedy(
    Uint8List colors,
    List<int>? target, {
    required DateTime deadline,
    int maxDepth = 2,
  }) {
    final out = <List<int>>[];
    final c = colors;
    final tmps = List.generate(maxDepth + 4, (_) => Uint8List(slots.length));
    final path = List<int>.filled(maxDepth, -1);

    void applyAt(int mi, Uint8List tmp) {
      final mv = moved[mi], p = perms[mi];
      for (var k = 0; k < mv.length; k++) {
        tmp[k] = c[mv[k]];
      }
      for (var k = 0; k < mv.length; k++) {
        c[p[mv[k]]] = tmp[k];
      }
    }

    void undoAt(int mi, Uint8List tmp) {
      final mv = moved[mi], p = perms[mi];
      for (var k = 0; k < mv.length; k++) {
        tmp[k] = c[p[mv[k]]];
      }
      for (var k = 0; k < mv.length; k++) {
        c[mv[k]] = tmp[k];
      }
    }

    var base = solved(c, target);
    while (base < solvableCount && DateTime.now().isBefore(deadline)) {
      List<int>? best;
      var bestGain = 0, bestLen = 1;
      void consider(List<int> seq, int gain) {
        final len = seq.length;
        // Most centres per turn; on a tie, more centres.
        if (gain > 0 &&
            (best == null ||
                gain * bestLen > bestGain * len ||
                (gain * bestLen == bestGain * len && gain > bestGain))) {
          best = [...seq];
          bestGain = gain;
          bestLen = len;
        }
      }

      void rec(int level, int score, int lastAxis, int limit) {
        final tmp = tmps[level];
        for (var mi = 0; mi < moves.length; mi++) {
          final axis = moves[mi].axis;
          if (axis == lastAxis) continue;
          final mv = moved[mi];
          int s;
          if (touchesFixed[mi]) {
            applyAt(mi, tmp);
            s = solved(c, target);
          } else {
            var before = 0;
            for (final i in mv) {
              if (i < solvableCount && c[i] == _target(c, target, i)) before++;
            }
            applyAt(mi, tmp);
            var after = 0;
            for (final i in mv) {
              if (i < solvableCount && c[i] == _target(c, target, i)) after++;
            }
            s = score - before + after;
          }
          path[level] = mi;
          if (s > base) consider(path.sublist(0, level + 1), s - base);
          if (level + 1 < limit) rec(level + 1, s, axis, limit);
          undoAt(mi, tmp);
        }
      }

      rec(0, base, -1, maxDepth < 2 ? maxDepth : 2);
      if (best == null || bestGain < bestLen) {
        // Commutators [A, B], bare (4 turns) or behind one setup turn S:
        // S [A, B] S' (6 turns) moves σ⁻¹(u) → σ⁻¹(v) for each u → v.
        // Evaluated on the sparse pairs, without touching the colours.
        final tg = Int32List(slots.length);
        var unsolved = 0;
        for (var i = 0; i < solvableCount; i++) {
          tg[i] = _target(c, target, i);
          if (c[i] != tg[i]) unsolved |= 1 << i;
        }
        // [setup] (null = none) as a permutation σ of the tracked slots.
        void macros(List<int> setup, Int32List? sigma) {
          Int32List? inv;
          var reach = unsolved;
          if (sigma != null) {
            inv = Int32List(sigma.length);
            for (var i = 0; i < sigma.length; i++) {
              inv[sigma[i]] = i;
            }
            // A candidate that only touches solved pieces can't gain: its
            // pieces σ⁻¹(supp) must meet the unsolved set U.
            reach = 0;
            for (var i = 0; i < solvableCount; i++) {
              if (unsolved & (1 << i) != 0) reach |= 1 << sigma[i];
            }
          }
          final setupMask = setup.isEmpty ? 0 : _moveMasks[setup.last];
          final comms = _commutators;
          for (var ci = 0; ci < comms.length; ci++) {
            final (a, b, from, to) = comms[ci];
            if (_commMasks[ci] & reach == 0) continue;
            if (setup.isNotEmpty) {
              if (moves[setup.last].axis == moves[a].axis) continue;
              // A last setup turn that misses the pieces changes nothing.
              if (setupMask & _commMasks[ci] == 0) continue;
            }
            var gain = 0;
            for (var k = 0; k < from.length; k++) {
              final x = inv == null ? from[k] : inv[from[k]];
              final y = inv == null ? to[k] : inv[to[k]];
              gain += (c[x] == tg[y] ? 1 : 0) - (c[x] == tg[x] ? 1 : 0);
            }
            if (gain <= 0) continue;
            consider([
              ...setup,
              a, b, inverse[a], inverse[b],
              for (final m in setup.reversed) inverse[m],
            ], gain);
          }
        }

        macros(const [], null);
        for (var s1 = 0; s1 < moves.length; s1++) {
          if (!touchesFixed[s1]) macros([s1], perms[s1]);
        }
        if (maxDepth > 2 && best == null) rec(0, base, -1, maxDepth);
      }
      final chosen = best;
      if (chosen == null) break;
      for (final mi in chosen) {
        applyAt(mi, tmps[0]);
      }
      out.add(chosen);
      base = solved(c, target);
    }
    return out;
  }
}
