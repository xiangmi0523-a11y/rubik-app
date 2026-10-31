import 'package:flutter/material.dart';
import '../../../../core/cube/app_cube_controller.dart';
import 'package:puzzle_cube/puzzle_cube.dart';


/// Half-screen guide: how to hold the physical cube while colouring.
Future<void> showHoldGuideSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.62,
      child: _HoldGuide(),
    ),
  );
}

class _HoldGuide extends StatefulWidget {
  const _HoldGuide();

  @override
  State<_HoldGuide> createState() => _HoldGuideState();
}

class _HoldGuideState extends State<_HoldGuide> {
  // Only the centres are coloured, like the reference app.
  final _cube = AppCubeController(
    initialState: PuzzleCubeState.colorless(),
  );

  @override
  void dispose() {
    _cube.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('手持姿势',
              textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('请按下图拿好实体魔方，填色过程中保持不动',
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          Expanded(child: Cube(controller: _cube, enableGestures: false)),
          const _Rule(CubeColors.white, '白色中心', '朝上'),
          const _Rule(CubeColors.green, '绿色中心', '朝前（面向自己）'),
          const _Rule(CubeColors.red, '红色中心', '朝右'),
          const SizedBox(height: 6),
          Text(
            '需要看背面时，请拖动屏幕上的魔方旋转视角，不要转动手里的魔方。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.color, this.label, this.direction);

  final Color color;
  final String label;
  final String direction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            direction,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
