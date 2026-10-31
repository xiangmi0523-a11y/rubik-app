import 'dart:typed_data';

import '../../../../core/nxn/nxn_cube_state.dart';
import '../../../../core/nxn/nxn_facelets.dart';

/// A complete table of *pure* 3-cycles on one orbit of centre stickers: for
/// every ordered triple (a, b, c) of distinct slots of that orbit, a move
/// sequence that sends the sticker at a to b, b to c and c to a, and changes
/// no other sticker on the cube.
///
/// How it is built (all on [NxnMoveTable], i.e. the real engine):
///  1. Base cycles: commutators [A, B] = A B A' B' with A an inner-slice turn
///     or a conjugated slice (s o s', o s o'), B an outer or inner turn. Only
///     those that move exactly 3 stickers, all in the orbit, are kept.
///  2. Conjugates S C S' of the base cycles by setup sequences S of growing
///     length, until every directed 3-cycle of the orbit has a sequence.
///     Conjugation keeps a cycle pure, so every entry stays pure.
///
/// [build] throws if some 3-cycle cannot be reached within [maxSetupDepth];
/// the tests check the table exhaustively against the engine.
class CenterCycleLibrary {
  CenterCycleLibrary._(this.n, this.kind, this.orbit, this._table, this.table);

  final int n;
  final SlotKind kind;

  /// The orbit's slots, ascending.
  final List<int> orbit;
  final Map<int, List<int>> _table;
  final NxnMoveTable table;

  static final Map<(int, SlotKind), CenterCycleLibrary> _cache = {};

  /// The library for [kind] on an order-[n] cube (built once, then cached).
  static CenterCycleLibrary forOrbit(int n, SlotKind kind) =>
      _cache.putIfAbsent((n, kind), () => build(n, kind));

  static int _key(int a, int b, int c) => (a << 16) | (b << 8) | c;

  /// Number of directed 3-cycles the table covers.
  int get cycleCount => _table.length ~/ 3;

  /// Move ids sending a → b → c → a.
  List<int> cycleIds(int a, int b, int c) {
    final seq = _table[_key(a, b, c)];
    if (seq == null) {
      throw ArgumentError('No 3-cycle ($a $b $c) in the $kind orbit');
    }
    return seq;
  }

  /// Engine moves sending a → b → c → a.
  List<NxnMove> cycle(int a, int b, int c) =>
      [for (final m in cycleIds(a, b, c)) table.moves[m]];

  static CenterCycleLibrary build(int n, SlotKind kind, {int maxSetupDepth = 3}) {
    final t = NxnMoveTable(n);
    final f = t.facelets;
    final orbit = f.slotsOfKind(kind);
    if (orbit.length < 3) {
      throw ArgumentError('$kind has fewer than 3 slots on a ${n}x$n cube');
    }
    final inOrbit = orbit.toSet();
    final m = n - 1;
    final count = f.count;

    Int32List compose(List<int> seq) {
      var p = Int32List.fromList([for (var i = 0; i < count; i++) i]);
      for (final mv in seq) {
        final q = t.perms[mv];
        final r = Int32List(count);
        for (var i = 0; i < count; i++) {
          r[i] = q[p[i]];
        }
        p = r;
      }
      return p;
    }

    List<int> inv(List<int> s) => [for (final mv in s.reversed) t.inverse[mv]];

    final outer = [
      for (var i = 0; i < t.moves.length; i++)
        if (t.moves[i].layer.abs() == m) i,
    ];
    final inner = [
      for (var i = 0; i < t.moves.length; i++)
        if (t.moves[i].layer.abs() != m) i,
    ];

    // ── 1. Base cycles, shortest sequence per directed cycle ─────────────
    final aCands = <List<int>>[
      for (final s in inner) [s],
      for (final s in inner)
        for (final o in outer) [s, o, t.inverse[s]],
      for (final o in outer)
        for (final s in inner) [o, s, t.inverse[o]],
    ];
    final bCands = <List<int>>[
      for (final o in outer) [o],
      for (final s in inner) [s],
    ];
    // directed cycle (a→b→c, rotated so a is smallest) → sequence
    final base = <int, List<int>>{};
    void addBase(List<int> seq) {
      final p = compose(seq);
      final moved = <int>[];
      for (var i = 0; i < count; i++) {
        if (p[i] != i) {
          if (!inOrbit.contains(i) || moved.length == 3) return;
          moved.add(i);
        }
      }
      if (moved.length != 3) return;
      final a = moved.reduce((x, y) => x < y ? x : y);
      final b = p[a], c = p[b];
      if (p[c] != a) return; // not a single 3-cycle
      final key = _key(a, b, c);
      final existing = base[key];
      if (existing == null || existing.length > seq.length) base[key] = seq;
    }

    for (final a in aCands) {
      for (final b in bCands) {
        final seq = [...a, ...b, ...inv(a), ...inv(b)];
        addBase(seq);
        addBase(inv(seq));
      }
    }
    if (base.isEmpty) throw StateError('No pure 3-cycles for $kind on ${n}x$n');

    // ── 2. Conjugate by setups of increasing length ──────────────────────
    final target = orbit.length * (orbit.length - 1) * (orbit.length - 2) ~/ 3;
    final table = <int, List<int>>{};
    final baseList = base.entries.toList()
      ..sort((x, y) => x.value.length.compareTo(y.value.length));

    void cover(List<int> setup) {
      // Conjugate S C S' maps σ⁻¹(u) → σ⁻¹(v) where C maps u → v, σ = S.
      final sigma = compose(setup);
      final sigmaInv = Int32List(count);
      for (var i = 0; i < count; i++) {
        sigmaInv[sigma[i]] = i;
      }
      for (final e in baseList) {
        final k = e.key;
        final a = sigmaInv[k >> 16], b = sigmaInv[(k >> 8) & 0xFF],
            c = sigmaInv[k & 0xFF];
        if (table.containsKey(_key(a, b, c))) continue;
        final seq = [...setup, ...e.value, ...inv(setup)];
        table[_key(a, b, c)] = seq;
        table[_key(b, c, a)] = seq;
        table[_key(c, a, b)] = seq;
      }
    }

    var frontier = <List<int>>[[]];
    for (var depth = 0; depth <= maxSetupDepth; depth++) {
      for (final setup in frontier) {
        cover(setup);
        if (table.length ~/ 3 == target) break;
      }
      if (table.length ~/ 3 == target) break;
      frontier = [
        for (final s in frontier)
          for (var mv = 0; mv < t.moves.length; mv++)
            // Skip a move on the same axis+layer as the previous one.
            if (s.isEmpty ||
                t.moves[s.last].axis != t.moves[mv].axis ||
                t.moves[s.last].layer != t.moves[mv].layer)
              [...s, mv],
      ];
    }
    if (table.length ~/ 3 != target) {
      throw StateError('Only ${table.length ~/ 3} of $target 3-cycles of '
          '$kind reachable with setups up to $maxSetupDepth moves');
    }
    return CenterCycleLibrary._(n, kind, orbit, table, t);
  }
}
