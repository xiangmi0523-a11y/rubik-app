import 'dart:typed_data';

import '../../../../core/nxn/nxn_cube_state.dart';
import '../../../../core/nxn/nxn_facelets.dart';

/// A complete table of *pure* 3-cycles of the pieces of one orbit: for every
/// ordered triple (a, b, c) of distinct piece positions of that orbit, a move
/// sequence that sends the piece at a to b, b to c and c to a, and changes no
/// other sticker on the cube.
///
/// Positions are named by one sticker slot each ([orbit]); all of those slots
/// lie in one sticker orbit, so a piece's named sticker always lands on a
/// named slot. A centre piece has one sticker; a wing has two (its second
/// sticker is in the twin orbit and simply follows).
///
/// How it is built (all on [NxnMoveTable], i.e. the real engine):
///  1. Base cycles: commutators [A, B] = A B A' B' with A an inner-slice turn
///     or a conjugated turn (s o s', o s o'), B an outer or inner turn. Only
///     those that move exactly 3 pieces of the orbit, and nothing else, are
///     kept.
///  2. Conjugates S C S' of the base cycles by setup sequences S of growing
///     length, until every directed 3-cycle of the orbit has a sequence.
///     Conjugation keeps a cycle pure, so every entry stays pure.
///
/// [build] throws if some 3-cycle cannot be reached within [maxSetupDepth];
/// the tests check every entry against the engine.
class PieceCycleLibrary {
  PieceCycleLibrary._(this.n, this.name, this.orbit, this._table, this.table);

  final int n;
  final String name;

  /// One slot per piece position of the orbit, ascending.
  final List<int> orbit;
  final Map<int, List<int>> _table;
  final NxnMoveTable table;

  static final Map<String, PieceCycleLibrary> _cache = {};

  /// Pure 3-cycles of the centre pieces of [kind] (cached).
  static PieceCycleLibrary centers(int n, SlotKind kind) =>
      _cache.putIfAbsent('$n:${kind.name}',
          () => build(n, kind.name, NxnFacelets(n).slotsOfKind(kind)));

  /// Pure 3-cycles of the 24 wing pieces of a 4x4 or 5x5 (cached).
  static PieceCycleLibrary wings(int n) =>
      _cache.putIfAbsent('$n:wing', () => build(n, 'wing', wingOrbit(n)));

  /// The sticker orbits of an order-[n] cube under all turns, each ascending,
  /// ordered by their smallest slot.
  static List<List<int>> stickerOrbits(int n) {
    final t = NxnMoveTable(n);
    final count = t.facelets.count;
    final parent = List<int>.generate(count, (i) => i);
    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }

    for (final p in t.perms) {
      for (var i = 0; i < count; i++) {
        final a = find(i), b = find(p[i]);
        if (a != b) parent[a] = b;
      }
    }
    final groups = <int, List<int>>{};
    for (var i = 0; i < count; i++) {
      groups.putIfAbsent(find(i), () => []).add(i);
    }
    return groups.values.toList()..sort((a, b) => a.first.compareTo(b.first));
  }

  /// The wing sticker orbit that contains the lowest wing slot: one sticker of
  /// every wing piece (24 slots on 4x4 and 5x5).
  static List<int> wingOrbit(int n) {
    final f = NxnFacelets(n);
    final first = f.slotsOfKind(SlotKind.wing).first;
    return stickerOrbits(n).firstWhere((o) => o.contains(first));
  }

  static int _key(int a, int b, int c) => (a << 20) | (b << 10) | c;

  /// Number of directed 3-cycles the table covers.
  int get cycleCount => _table.length ~/ 3;

  /// Move ids sending the piece at a → b → c → a.
  List<int> cycleIds(int a, int b, int c) {
    final seq = _table[_key(a, b, c)];
    if (seq == null) {
      throw ArgumentError('No 3-cycle ($a $b $c) in the $name orbit');
    }
    return seq;
  }

  /// Engine moves sending the piece at a → b → c → a.
  List<NxnMove> cycle(int a, int b, int c) =>
      [for (final m in cycleIds(a, b, c)) table.moves[m]];

  static PieceCycleLibrary build(
    int n,
    String name,
    List<int> slots, {
    int maxSetupDepth = 3,
  }) {
    final t = NxnMoveTable(n);
    final f = t.facelets;
    final orbit = [...slots]..sort();
    if (orbit.length < 3) {
      throw ArgumentError('$name has fewer than 3 pieces on a ${n}x$n cube');
    }
    final count = f.count;

    // Every sticker of every piece of the orbit → the orbit slot naming it.
    final ownerOf = Int32List(count)..fillRange(0, count, -1);
    int? stickers;
    for (final r in orbit) {
      final piece = f.slotsOfPiece(f.pieceOf[r]);
      stickers ??= piece.length;
      if (piece.length != stickers) {
        throw ArgumentError('$name mixes pieces of different sizes');
      }
      for (final s in piece) {
        if (ownerOf[s] != -1) {
          throw ArgumentError('$name names one piece twice');
        }
        ownerOf[s] = r;
      }
    }
    final isNamed = List<bool>.filled(count, false);
    for (final r in orbit) {
      isNamed[r] = true;
    }
    final perPiece = stickers!;
    final m = n - 1;

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
      var moved = 0;
      final names = <int>[];
      for (var i = 0; i < count; i++) {
        if (p[i] == i) continue;
        if (ownerOf[i] == -1 || ++moved > 3 * perPiece) return;
        if (isNamed[i]) names.add(i);
      }
      if (names.length != 3 || moved != 3 * perPiece) return;
      // Every moved sticker must belong to one of the three moved pieces.
      for (var i = 0; i < count; i++) {
        if (p[i] != i && !names.contains(ownerOf[i])) return;
      }
      final a = names.reduce((x, y) => x < y ? x : y);
      final b = p[a], c = p[b];
      if (!isNamed[b] || !isNamed[c] || p[c] != a) return; // not one 3-cycle
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
    if (base.isEmpty) throw StateError('No pure 3-cycles for $name on ${n}x$n');

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
        final a = sigmaInv[k >> 20],
            b = sigmaInv[(k >> 10) & 0x3FF],
            c = sigmaInv[k & 0x3FF];
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
          '$name reachable with setups up to $maxSetupDepth moves');
    }
    return PieceCycleLibrary._(n, name, orbit, table, t);
  }
}
