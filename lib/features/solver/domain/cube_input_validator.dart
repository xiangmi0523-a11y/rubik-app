import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter/material.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../../../core/cube/cube_facelets.dart';

/// Why a colouring can't be solved yet.
enum CubeInputIssue {
  /// Some stickers are still blank.
  incomplete,

  /// A colour doesn't appear exactly 9 times.
  colorCount,

  /// Every sticker is filled but the state breaks the cube's physical rules
  /// (impossible piece, twisted corner, flipped edge, parity).
  unsolvable,
}

class CubeInputCheck {
  const CubeInputCheck.ok()
      : issue = null,
        messages = const [];
  const CubeInputCheck(this.issue, this.messages);

  final CubeInputIssue? issue;
  final List<String> messages;

  bool get isValid => issue == null;
}

/// Validates 54 user-entered colours (cuber facelet order).
abstract final class CubeInputValidator {
  static const _names = {
    0xFFFFFFFF: '白',
    0xFFFFEB3B: '黄',
    0xFFF44336: '红',
    0xFFFF9800: '橙',
    0xFF4CAF50: '绿',
    0xFF2196F3: '蓝',
  };

  static String colorName(Color c) =>
      _names[c.toARGB32()] ?? CubeColors.nameOf(c);

  static bool isBlank(Color c) =>
      c.toARGB32() == CubeColors.colorless.toARGB32();

  static CubeInputCheck validate(List<Color> colors) {
    // 1. Every sticker filled.
    final blank = colors.where(isBlank).length;
    if (blank > 0) {
      return CubeInputCheck(
          CubeInputIssue.incomplete, ['还有 $blank 个色块没有填色']);
    }

    // 2. Nine of each colour.
    final counts = <String>[];
    for (final color in CubeColors.palette) {
      final n = colors.where((c) => c.toARGB32() == color.toARGB32()).length;
      if (n != 9) counts.add('${colorName(color)}色有 $n 个，应为 9 个');
    }
    if (counts.isNotEmpty) {
      return CubeInputCheck(CubeInputIssue.colorCount, counts);
    }

    // 3. Physically possible pieces (puzzle_cube validator).
    final result =
        const CubeColorValidator().validate(CubeFacelets.build(colors));
    if (!result.isValid) {
      return CubeInputCheck(
        CubeInputIssue.unsolvable,
        result.issues.map((i) => _translate(i.message)).toSet().toList(),
      );
    }

    // 4. Orientation / parity (cuber).
    final definition = CubeFacelets.toDefinition(colors);
    if (definition == null) {
      return const CubeInputCheck(CubeInputIssue.unsolvable, ['存在无法识别的颜色']);
    }
    final message = switch (cuber.Cube.from(definition).verify()) {
      cuber.CubeStatus.ok => null,
      cuber.CubeStatus.missingEdge => '棱块缺失或重复，请检查棱块颜色',
      cuber.CubeStatus.twistedEdge => '有一个棱块被单独翻转了（单棱翻色）',
      cuber.CubeStatus.missingCorner => '角块缺失或重复，请检查角块颜色',
      cuber.CubeStatus.twistedCorner => '有角块被单独拧转了（单角翻转）',
      cuber.CubeStatus.parityError => '奇偶校验失败（两个块的位置被互换了）',
    };
    if (message == null) return const CubeInputCheck.ok();
    return CubeInputCheck(CubeInputIssue.unsolvable, [message]);
  }

  static String _translate(String message) {
    final m = message.toLowerCase();
    if (m.contains('center')) return '中心块颜色不能改变';
    if (m.contains('same color twice')) return '同一个块上出现了两个相同颜色';
    if (m.contains('opposite')) return '同一个块上出现了相对面的颜色（如白和黄）';
    if (m.contains('edge combination')) return '存在不可能的棱块颜色组合';
    if (m.contains('corner combination')) return '存在不可能的角块颜色组合';
    if (m.contains('not an allowed')) return '存在不允许的颜色';
    return message;
  }
}
