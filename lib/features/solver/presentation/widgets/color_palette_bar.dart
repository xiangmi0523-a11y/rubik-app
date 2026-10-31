import 'package:flutter/material.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../../domain/cube_input_validator.dart';

/// Six colour balls showing how many stickers of each colour are left.
/// A colour that has all 9 stickers placed is dimmed and disabled.
class ColorPaletteBar extends StatelessWidget {
  const ColorPaletteBar({
    super.key,
    required this.selected,
    required this.remaining,
    required this.onSelect,
  });

  final Color selected;
  final int Function(Color color) remaining;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final color in CubeColors.palette) _ball(color),
      ],
    );
  }

  Widget _ball(Color color) {
    final left = remaining(color);
    final done = left <= 0;
    final isSelected = color.toARGB32() == selected.toARGB32() && !done;
    final textColor =
        color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return Semantics(
      button: true,
      enabled: !done,
      label: '${CubeInputValidator.colorName(color)}色，剩余 $left 个',
      child: GestureDetector(
        onTap: done ? null : () => onSelect(color),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.tealAccent : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: Opacity(
                opacity: done ? 0.25 : 1,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: done
                      ? Icon(Icons.check, color: textColor)
                      : Text(
                          '$left',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              CubeInputValidator.colorName(color),
              style: TextStyle(
                fontSize: 12,
                color: done ? Colors.white30 : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
