import 'package:flutter/material.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../../../../core/cube/app_cube_controller.dart';
import '../../../../core/nxn/nxn_cube_controller.dart';
import '../../../../core/nxn/nxn_cube_view.dart';
import '../../../../core/pyraminx/pyraminx_controller.dart';
import '../../../../core/pyraminx/pyraminx_model.dart';
import '../../../../core/pyraminx/pyraminx_view.dart';
import '../../../puzzles/domain/puzzle_type.dart';
import '../../application/puzzle_color_input.dart';

/// Half-screen guide: how to hold the physical puzzle while colouring.
Future<void> showHoldGuideSheet(BuildContext context, PuzzleType type) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.62,
      child: _HoldGuide(type: type),
    ),
  );
}

class _HoldGuide extends StatefulWidget {
  const _HoldGuide({required this.type});
  final PuzzleType type;

  @override
  State<_HoldGuide> createState() => _HoldGuideState();
}

class _HoldGuideState extends State<_HoldGuide> {
  AppCubeController? _cube3;
  NxnCubeController? _nxn;
  PyraminxController? _pyraminx;

  @override
  void initState() {
    super.initState();
    final type = widget.type;
    if (type == PuzzleType.cube3) {
      // Only the centres are coloured, like the reference app.
      _cube3 = AppCubeController(initialState: PuzzleCubeState.colorless());
    } else if (type.isPyraminx) {
      _pyraminx = PyraminxController(initial: PyraminxState.solved());
    } else {
      _nxn = NxnCubeController(type.order!,
          initial: NxnColorInput.blank(type.order!));
    }
  }

  @override
  void dispose() {
    _cube3?.dispose();
    _nxn?.dispose();
    _pyraminx?.dispose();
    super.dispose();
  }

  bool get _hasFixedCenters =>
      widget.type == PuzzleType.cube3 || widget.type == PuzzleType.cube5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _cube3 != null
        ? Cube(controller: _cube3!, enableGestures: false)
        : _nxn != null
            ? IgnorePointer(child: NxnCubeView(controller: _nxn!))
            : IgnorePointer(child: PyraminxView(controller: _pyraminx!));

    // Content scrolls when a small screen or large text leaves too little
    // room; the button stays pinned at the bottom.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('手持姿势',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('请按下图拿好实体${widget.type.label}，填色过程中保持不动',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall),
                      SizedBox(
                        height: (constraints.maxHeight * 0.45).clamp(120.0, 320.0),
                        child: preview,
                      ),
                      if (_hasFixedCenters) ...const [
                        _Rule(CubeColors.white, '白色中心', '朝上'),
                        _Rule(CubeColors.green, '绿色中心', '朝前（面向自己）'),
                        _Rule(CubeColors.red, '红色中心', '朝右'),
                      ] else
                        Text(
                          widget.type.isPyraminx
                              ? '金字塔可以任意一面朝向自己，程序会根据中心块自动识别各面颜色。'
                              : '${widget.type.label}没有固定的中心块，任意姿势拿好即可，'
                                  '程序会自动识别各面颜色。',
                          style: const TextStyle(fontSize: 15),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        '需要看背面时，请拖动屏幕上的模型旋转视角，不要转动手里的魔方。',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 16),
                children: [
                  TextSpan(text: '$label  '),
                  TextSpan(
                    text: direction,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
