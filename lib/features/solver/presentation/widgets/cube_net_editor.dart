import 'package:flutter/material.dart';

import '../../../../core/cube/cube_facelets.dart';

/// Unfolded cube net:
///        [U]
///   [L]  [F]  [R]  [B]
///        [D]
class CubeNetEditor extends StatelessWidget {
  const CubeNetEditor({super.key, required this.colors, required this.onTap});

  final List<Color> colors;
  final ValueChanged<int> onTap;

  static const _layout = <List<CubeSide?>>[
    [null, CubeSide.u, null, null],
    [CubeSide.l, CubeSide.f, CubeSide.r, CubeSide.b],
    [null, CubeSide.d, null, null],
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 4.0;
        final faceSize = ((constraints.maxWidth - gap * 3) / 4).clamp(0.0, 120.0);
        return Column(
          children: [
            for (final row in _layout)
              Padding(
                padding: const EdgeInsets.only(bottom: gap),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < row.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      SizedBox.square(
                        dimension: faceSize,
                        child: row[i] == null ? null : _face(row[i]!),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _face(CubeSide side) {
    return Column(
      children: [
        for (var r = 0; r < 3; r++)
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < 3; c++)
                  Expanded(child: _cell(side, r * 3 + c)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(CubeSide side, int i) {
    final index = CubeFacelets.indexOf(side, i);
    final color = colors[index];
    final isCenter = i == 4;
    return GestureDetector(
      onTap: isCenter ? null : () => onTap(index),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.black, width: 1),
        ),
        alignment: Alignment.center,
        child: isCenter
            ? Text(
                side.letter,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
                ),
              )
            : null,
      ),
    );
  }
}
