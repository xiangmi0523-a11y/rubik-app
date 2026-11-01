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
    this.palette = CubeColors.palette,
  });

  /// Colours to offer (Pyraminx uses four).
  final List<Color> palette;

  final Color selected;
  final int Function(Color color) remaining;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    // Balls shrink on narrow screens (6 × 55 pt doesn't fit a 320 pt iPhone).
    return LayoutBuilder(
      builder: (context, c) {
        final size = (c.maxWidth / palette.length - 11).clamp(30.0, 44.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final color in palette) _ball(color, size),
          ],
        );
      },
    );
  }

  Widget _ball(Color color, double size) {
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
                  width: size,
                  height: size,
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
                            fontSize: size * 0.5,
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
