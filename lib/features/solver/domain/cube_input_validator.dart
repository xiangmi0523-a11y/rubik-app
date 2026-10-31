import 'package:cuber/cuber.dart' as cuber;
import 'package:flutter/material.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../../../core/cube/cube_facelets.dart';

/// Validates 54 user-entered colours. Returns Chinese error messages; an empty
/// list means the cube can be solved.
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

  static List<String> validate(List<Color> colors) {
    // 1. Every sticker filled.
    final blank = colors
        .where((c) => c.toARGB32() == CubeColors.colorless.toARGB32())
        .length;
    if (blank > 0) return ['还有 $blank 个格子没有填色'];

    // 2. Nine of each colour.
    final errors = <String>[];
    for (final color in CubeColors.palette) {
      final n = colors.where((c) => c.toARGB32() == color.toARGB32()).length;
      if (n != 9) errors.add('${colorName(color)}色有 $n 个，应为 9 个');
    }
    if (errors.isNotEmpty) return errors;

    // 3. Physically possible pieces (puzzle_cube validator).
    final state = CubeFacelets.build(colors);
    final result = const CubeColorValidator().validate(state);
    if (!result.isValid) {
      return result.issues.map((i) => _translate(i.message)).toSet().toList();
    }

    // 4. Orientation / parity (cuber).
    final definition = CubeFacelets.toDefinition(colors);
    if (definition == null) return ['存在无法识别的颜色'];
    final status = cuber.Cube.from(definition).verify();
    switch (status) {
      case cuber.CubeStatus.ok:
        return const [];
      case cuber.CubeStatus.missingEdge:
        return ['棱块缺失或重复，请检查棱块颜色'];
      case cuber.CubeStatus.twistedEdge:
        return ['有一个棱块被翻转了（单棱翻色），这种状态无法还原'];
      case cuber.CubeStatus.missingCorner:
        return ['角块缺失或重复，请检查角块颜色'];
      case cuber.CubeStatus.twistedCorner:
        return ['有角块被单独拧转了，这种状态无法还原'];
      case cuber.CubeStatus.parityError:
        return ['奇偶校验失败（两个块位置被互换），这种状态无法还原'];
    }
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
