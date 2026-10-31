import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter/painting.dart';

import '../../../core/nxn/nxn_cube_state.dart';
import 'cube_input_validator.dart';
import 'two_by_two_solver.dart';

/// Piece-level validation of a coloured 4x4 / 5x5 (any orientation for 4x4).
///
/// Checks, in order: centre colour counts per centre type, wing edges (each
/// colour pair exactly twice, as a mirror-image pair — a lone flipped wing is
/// impossible), corners (as a 2x2: valid pieces and no twisted corner), and
/// for 5x5 the embedded 3x3 (corners + middle edges + fixed centres) via
/// cuber (twisted corner, flipped edge, parity).
abstract final class BigCubeValidator {
  static String _name(Color c) => CubeInputValidator.colorName(c);

  static List<String> validate(NxnCubeState s) {
    final n = s.n;
    final m = s.max;
    final errors = <String>[];
    final colors = NxnCubeState.faceColors.values.toList();
    final opposite = {
      for (final e in NxnCubeState.faceColors.entries)
        e.value.toARGB32():
            NxnCubeState.faceColors[(-e.key.$1, -e.key.$2, -e.key.$3)]!
                .toARGB32(),
    };

    // ── Centres ─────────────────────────────────────────────────────────
    final centreKinds = <String, Map<int, int>>{};
    for (final c in s.cubies) {
      if (c.stickers.length != 1) continue;
      final normal = c.stickers.keys.single;
      final inPlane = [c.pos.$1, c.pos.$2, c.pos.$3]
          .where((v) => v.abs() != m || v == 0)
          .toList();
      final kind = n == 4
          ? '中心块'
          : inPlane.every((v) => v == 0)
              ? '正中心'
              : inPlane.every((v) => v != 0)
                  ? '角中心块'
                  : '棱中心块';
      if (n == 5 && kind == '正中心') continue; // fixed, never painted
      final counts = centreKinds.putIfAbsent(kind, () => {});
      final argb = c.stickers[normal]!.toARGB32();
      counts[argb] = (counts[argb] ?? 0) + 1;
    }
    centreKinds.forEach((kind, counts) {
      for (final col in colors) {
        final k = counts[col.toARGB32()] ?? 0;
        if (k != 4) errors.add('$kind中${_name(col)}色有 $k 个，应为 4 个');
      }
    });

    // ── Wings ───────────────────────────────────────────────────────────
    // A wing's handedness h = sign((n_a × n_b) · p) for its colours a < b is
    // invariant under every turn; each colour pair needs one of each sign.
    final wings = <String, List<int>>{};
    for (final c in s.cubies) {
      if (c.stickers.length != 2) continue;
      final entries = c.stickers.entries.toList();
      final axis = [0, 1, 2].firstWhere((a) =>
          axisOf(entries[0].key, a) == 0 && axisOf(entries[1].key, a) == 0);
      if (axisOf(c.pos, axis) == 0) continue; // 5x5 middle edge: checked below
      final a = entries[0].value.toARGB32(), b = entries[1].value.toARGB32();
      if (a == b || opposite[a] == b) {
        errors.add('有棱块出现了不可能的颜色组合（${_name(entries[0].value)}+'
            '${_name(entries[1].value)}）');
        continue;
      }
      final (lo, hi) = a < b ? (entries[0], entries[1]) : (entries[1], entries[0]);
      final cross = _cross(lo.key, hi.key);
      final h = (cross.$1 * c.pos.$1 + cross.$2 * c.pos.$2 + cross.$3 * c.pos.$3)
          .sign;
      final key = '${_name(lo.value)}${_name(hi.value)}';
      wings.putIfAbsent(key, () => []).add(h);
    }
    if (errors.isEmpty) {
      wings.forEach((pair, hs) {
        if (hs.length != 2) {
          errors.add('$pair色棱块出现了 ${hs.length} 块，应为 2 块');
        } else if (hs[0] == hs[1]) {
          errors.add('$pair色棱块有一块被翻转装反了（单个小棱块不可能翻转）');
        }
      });
    }

    // ── Corners (as a 2x2) ──────────────────────────────────────────────
    if (errors.isEmpty) {
      final corners = NxnCubeState.solved(2);
      for (final c in corners.cubies) {
        final big = (c.pos.$1 * m, c.pos.$2 * m, c.pos.$3 * m);
        for (final normal in [...c.stickers.keys]) {
          c.stickers[normal] = s.stickerAt(big, normal)!;
        }
      }
      final r = TwoByTwoSolver.solve(corners);
      if (!r.ok) {
        errors.add(r.error!.contains('拧转')
            ? '有角块被单独拧转了（单角翻转）'
            : '角块颜色组合不可能，请检查八个角');
      }
    }

    // ── 5x5: embedded 3x3 ───────────────────────────────────────────────
    if (errors.isEmpty && n == 5) {
      final status = cuber.Cube.from(_reduced3x3(s)).verify();
      final message = switch (status) {
        cuber.CubeStatus.ok => null,
        cuber.CubeStatus.twistedEdge => '有一个中棱被单独翻转了（单棱翻色）',
        cuber.CubeStatus.twistedCorner => '有角块被单独拧转了（单角翻转）',
        cuber.CubeStatus.parityError => '奇偶校验失败（两个块的位置被互换了）',
        _ => '中棱或角块的颜色组合不可能',
      };
      if (message != null) errors.add(message);
    }
    return errors.toSet().toList();
  }

  static IVec _cross(IVec a, IVec b) => (
        a.$2 * b.$3 - a.$3 * b.$2,
        a.$3 * b.$1 - a.$1 * b.$3,
        a.$1 * b.$2 - a.$2 * b.$1,
      );

  /// cuber definition of the 5x5's corners, middle edges and fixed centres.
  static String _reduced3x3(NxnCubeState s) {
    const frames = <(IVec, IVec, IVec)>[
      ((0, 1, 0), (0, 0, 1), (1, 0, 0)), // U
      ((1, 0, 0), (0, -1, 0), (0, 0, -1)), // R
      ((0, 0, 1), (0, -1, 0), (1, 0, 0)), // F
      ((0, -1, 0), (0, 0, -1), (1, 0, 0)), // D
      ((-1, 0, 0), (0, -1, 0), (0, 0, 1)), // L
      ((0, 0, -1), (0, -1, 0), (-1, 0, 0)), // B
    ];
    final m = s.max;
    final letters = <int, String>{};
    for (final (i, (n, _, _)) in frames.indexed) {
      letters[s.stickerAt((n.$1 * m, n.$2 * m, n.$3 * m), n)!.toARGB32()] =
          'URFDLB'[i];
    }
    final b = StringBuffer();
    for (final (n, r, c) in frames) {
      for (var row = -1; row <= 1; row++) {
        for (var col = -1; col <= 1; col++) {
          final pos = (
            m * (n.$1 + row * r.$1 + col * c.$1),
            m * (n.$2 + row * r.$2 + col * c.$2),
            m * (n.$3 + row * r.$3 + col * c.$3),
          );
          b.write(letters[s.stickerAt(pos, n)!.toARGB32()] ?? 'U');
        }
      }
    }
    return b.toString();
  }
}
