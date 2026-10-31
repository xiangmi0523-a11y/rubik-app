import 'package:flutter/material.dart';

/// Pyraminx screen until its 3D model lands: a flat face preview and a note
/// that the timer and scrambles already work with a physical puzzle.
class PyraminxPlaceholder extends StatelessWidget {
  const PyraminxPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 180,
            height: 160,
            child: CustomPaint(painter: _PyraminxFacePainter(Color(0xFF4CAF50))),
          ),
          const SizedBox(height: 16),
          Text('金字塔 3D 模型开发中',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            '现在可以配合实体金字塔使用：点「打乱」生成 WCA 打乱公式，'
            '点计时器开始 / 停止，成绩会单独计入金字塔的 ao5 / ao12。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// One Pyraminx face: a triangle split into 9 small triangles.
class _PyraminxFacePainter extends CustomPainter {
  const _PyraminxFacePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final top = Offset(size.width / 2, 0);
    final left = Offset(0, size.height);
    final right = Offset(size.width, size.height);
    Offset lerp(Offset a, Offset b, double t) => Offset.lerp(a, b, t)!;
    // Barycentric grid point: row r (0..3 from top), column c (0..r).
    Offset p(int r, int c) {
      final rowLeft = lerp(top, left, r / 3);
      final rowRight = lerp(top, right, r / 3);
      return r == 0 ? top : lerp(rowLeft, rowRight, c / r);
    }

    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c <= r; c++) {
        final up = Path()..addPolygon([p(r, c), p(r + 1, c), p(r + 1, c + 1)], true);
        canvas..drawPath(up, fill)..drawPath(up, stroke);
        if (c < r) {
          final down = Path()
            ..addPolygon([p(r, c), p(r, c + 1), p(r + 1, c + 1)], true);
          canvas..drawPath(down, fill)..drawPath(down, stroke);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PyraminxFacePainter old) => old.color != color;
}
