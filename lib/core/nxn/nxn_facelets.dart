import 'dart:typed_data';

import 'package:flutter/painting.dart';

import 'nxn_cube_state.dart';

/// What kind of piece a sticker belongs to. Derived only from the cube order
/// `n` and the sticker's position, so 4x4 and 5x5 each get their own rules.
enum SlotKind {
  /// 3 stickers per piece.
  corner,

  /// A non-middle edge piece (2 per edge on 4x4 and 5x5).
  wing,

  /// The middle edge piece of an odd cube (3x3, 5x5).
  midEdge,

  /// A centre piece on a diagonal of its face (4 per face on 4x4 and 5x5).
  centerX,

  /// A centre piece on a face's middle row/column, off the very centre
  /// (5x5 only).
  centerT,

  /// The fixed centre of an odd cube.
  centerFixed,
}

/// Dense numbering of every sticker slot of an n×n cube, taken from the real
/// [NxnCubeState] engine, plus piece/face/kind lookups.
///
/// A *slot* is a (cubie position, outward normal) pair of the solved cube; a
/// cube's colouring is then a `List<int>` of ARGB values indexed by slot.
/// Turns permute slots; see [NxnMoveTable].
class NxnFacelets {
  NxnFacelets._(this.n)
      : _slots = _enumerate(n) {
    count = _slots.length;
    posOf = [for (final s in _slots) s.$1];
    normalOf = [for (final s in _slots) s.$2];
    _index = {for (var i = 0; i < _slots.length; i++) _slots[i]: i};
    faceOf = [for (final s in _slots) _faceIndex(s.$2)];
    kindOf = [for (final s in _slots) _classify(n, s.$1, s.$2)];

    final pieces = <IVec, int>{};
    pieceOf = [
      for (final s in _slots) pieces.putIfAbsent(s.$1, () => pieces.length),
    ];
    pieceCount = pieces.length;
  }

  static final Map<int, NxnFacelets> _cache = {};

  /// Facelet numbering for an order-[n] cube (cached).
  factory NxnFacelets(int n) {
    if (n < 2) throw ArgumentError('n must be >= 2, got $n');
    return _cache.putIfAbsent(n, () => NxnFacelets._(n));
  }

  /// Face order used everywhere: U R F D L B.
  static const List<IVec> faceNormals = [
    (0, 1, 0),
    (1, 0, 0),
    (0, 0, 1),
    (0, -1, 0),
    (-1, 0, 0),
    (0, 0, -1),
  ];

  static int _faceIndex(IVec normal) => faceNormals.indexOf(normal);

  final int n;
  final List<(IVec, IVec)> _slots;
  late final Map<(IVec, IVec), int> _index;

  /// Number of stickers: 6·n².
  late final int count;

  /// Number of pieces that carry at least one sticker (hidden core excluded).
  late final int pieceCount;

  late final List<IVec> posOf;
  late final List<IVec> normalOf;

  /// 0..5 in the order U R F D L B.
  late final List<int> faceOf;
  late final List<SlotKind> kindOf;

  /// Dense piece id of each slot; all stickers of one piece share it.
  late final List<int> pieceOf;

  /// Doubled layer coordinates, ascending: -(n-1), -(n-3), ..., n-1.
  List<int> get layers => [for (var i = 0; i < n; i++) -(n - 1) + 2 * i];

  /// Slot of the sticker on the cubie at [pos] facing [normal].
  int slotAt(IVec pos, IVec normal) {
    final i = _index[(pos, normal)];
    if (i == null) {
      throw ArgumentError('No sticker at $pos facing $normal on a ${n}x$n cube');
    }
    return i;
  }

  /// Slots of one kind, ascending.
  List<int> slotsOfKind(SlotKind kind) => [
        for (var i = 0; i < count; i++)
          if (kindOf[i] == kind) i,
      ];

  /// Slots of one face (0..5 = U R F D L B), ascending.
  List<int> slotsOfFace(int face) => [
        for (var i = 0; i < count; i++)
          if (faceOf[i] == face) i,
      ];

  /// Slots of one piece, ascending.
  List<int> slotsOfPiece(int piece) => [
        for (var i = 0; i < count; i++)
          if (pieceOf[i] == piece) i,
      ];

  // ── State conversion ────────────────────────────────────────────────────

  /// Reads the ARGB colour of every slot of [state].
  List<int> read(NxnCubeState state) {
    if (state.n != n) {
      throw ArgumentError('State is order ${state.n}, expected $n');
    }
    final byPos = {for (final c in state.cubies) c.pos: c};
    return [
      for (var i = 0; i < count; i++)
        (byPos[posOf[i]]?.stickers[normalOf[i]] ??
                (throw StateError(
                    'Missing sticker ${posOf[i]} ${normalOf[i]}')))
            .toARGB32(),
    ];
  }

  /// Builds an engine state from slot colours (inverse of [read]).
  NxnCubeState build(List<int> colors) {
    if (colors.length != count) {
      throw ArgumentError('Expected $count colours, got ${colors.length}');
    }
    final state = NxnCubeState.solved(n);
    for (final c in state.cubies) {
      for (final normal in [...c.stickers.keys]) {
        c.stickers[normal] = Color(colors[slotAt(c.pos, normal)]);
      }
    }
    return state;
  }

  /// Colours of the solved cube.
  List<int> solvedColors() => read(NxnCubeState.solved(n));

  /// A colouring where every sticker is unique (slot index in the low bits),
  /// used to read a turn's permutation straight off the engine.
  List<int> identityLabels() => [for (var i = 0; i < count; i++) 0xFF000000 | i];

  // ── Enumeration / classification ───────────────────────────────────────

  static List<(IVec, IVec)> _enumerate(int n) {
    final solved = NxnCubeState.solved(n);
    final slots = <(IVec, IVec)>[
      for (final c in solved.cubies)
        for (final normal in c.stickers.keys) (c.pos, normal),
    ];
    slots.sort((a, b) {
      final f = _faceIndex(a.$2).compareTo(_faceIndex(b.$2));
      if (f != 0) return f;
      final x = a.$1.$1.compareTo(b.$1.$1);
      if (x != 0) return x;
      final y = a.$1.$2.compareTo(b.$1.$2);
      if (y != 0) return y;
      return a.$1.$3.compareTo(b.$1.$3);
    });
    return slots;
  }

  static SlotKind _classify(int n, IVec pos, IVec normal) {
    final m = n - 1;
    final coords = [pos.$1, pos.$2, pos.$3];
    final border = [for (final c in coords) c.abs() == m];
    final borderCount = border.where((b) => b).length;
    if (borderCount == 3) return SlotKind.corner;
    if (borderCount == 2) {
      final free = coords[border.indexOf(false)];
      return free == 0 ? SlotKind.midEdge : SlotKind.wing;
    }
    // Face centre area: classify by the two in-plane coordinates.
    final normalAxis = normal.$1 != 0 ? 0 : (normal.$2 != 0 ? 1 : 2);
    final inPlane = [
      for (var a = 0; a < 3; a++)
        if (a != normalAxis) coords[a],
    ];
    final zeros = inPlane.where((c) => c == 0).length;
    return switch (zeros) {
      2 => SlotKind.centerFixed,
      1 => SlotKind.centerT,
      _ => SlotKind.centerX,
    };
  }
}

/// Every layer turn of an order-n cube as a sticker permutation, read from
/// the real [NxnCubeState] engine so the engine stays the single source of
/// truth.
///
/// The universe is 3 axes × n layers × {+90°, −90°, 180°} = 9n moves.
/// Applying move `m` to a colouring `s` gives `out[perm[i]] = s[i]`.
class NxnMoveTable {
  NxnMoveTable._(this.facelets) {
    final n = facelets.n;
    moves = [
      for (var axis = 0; axis < 3; axis++)
        for (final layer in facelets.layers)
          for (final turns in const [1, -1, 2]) NxnMove(axis, layer, turns),
    ];
    _indexOf = {for (var i = 0; i < moves.length; i++) moves[i]: i};
    inverse = [for (final m in moves) _indexOf[m.inverse]!];

    final labels = facelets.identityLabels();
    perms = [
      for (final move in moves)
        () {
          final state = facelets.build(labels)..apply(move);
          final after = facelets.read(state);
          final perm = Int32List(facelets.count);
          for (var j = 0; j < after.length; j++) {
            perm[after[j] & 0xFFFFFF] = j;
          }
          return perm;
        }(),
    ];
    assert(moves.length == 9 * n);
  }

  static final Map<int, NxnMoveTable> _cache = {};

  /// Move table for an order-[n] cube (cached).
  factory NxnMoveTable(int n) =>
      _cache.putIfAbsent(n, () => NxnMoveTable._(NxnFacelets(n)));

  final NxnFacelets facelets;

  /// The move universe, indexed by move id.
  late final List<NxnMove> moves;

  /// Permutation of each move: the sticker in slot i goes to `perm[i]`.
  late final List<Int32List> perms;

  /// Id of each move's inverse.
  late final List<int> inverse;
  late final Map<NxnMove, int> _indexOf;

  /// Id of [move]; throws [ArgumentError] if it isn't a legal move of this
  /// order (e.g. layer 0 on a 4x4, or layer 4 on a 3x3).
  int indexOf(NxnMove move) {
    final i = _indexOf[move];
    if (i == null) {
      throw ArgumentError('$move is not a move of a ${facelets.n}x${facelets.n} cube');
    }
    return i;
  }

  /// Applies move id [move] to [state], returning a new list.
  List<int> apply(List<int> state, int move) {
    final perm = perms[move];
    final out = List<int>.filled(state.length, 0);
    for (var i = 0; i < state.length; i++) {
      out[perm[i]] = state[i];
    }
    return out;
  }

  /// Applies a sequence of engine moves.
  List<int> applyMoves(List<int> state, Iterable<NxnMove> sequence) {
    var s = state;
    for (final m in sequence) {
      s = apply(s, indexOf(m));
    }
    return s;
  }
}
