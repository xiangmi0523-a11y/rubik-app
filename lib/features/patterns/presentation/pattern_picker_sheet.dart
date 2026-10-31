import 'package:flutter/material.dart';

import '../../../core/nxn/nxn_cube_controller.dart';
import '../../../core/nxn/nxn_cube_view.dart';
import '../../../core/pyraminx/pyraminx_controller.dart';
import '../../../core/pyraminx/pyraminx_view.dart';
import '../../player/presentation/player_page.dart';
import '../../puzzles/domain/puzzle_type.dart';
import '../domain/cube_pattern.dart';
import '../domain/pattern_scripts.dart';

/// Bottom sheet listing the patterns of [type]; picking one opens the
/// animated tutorial.
Future<void> showPatternPicker(BuildContext context, PuzzleType type) {
  final patterns = patternsFor(type);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text('${type.label}花式',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('从还原状态开始，跟着动画一步步拧出图案',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          for (final pattern in patterns)
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  openPatternDemo(context, pattern);
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      PatternPreview(pattern: pattern, size: 76),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pattern.name,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(pattern.description,
                                style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 2),
                            Text(
                              '${pattern.moves.length} 步：${pattern.algorithm}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

void openPatternDemo(BuildContext context, PuzzlePattern pattern) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PlayerPage(
        title: '${pattern.puzzle.label}花式：${pattern.name}',
        startText: '从还原状态开始',
        script: patternScript(pattern),
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              PatternPreview(pattern: pattern, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${pattern.description}\n公式：${pattern.algorithm}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Small static 3D render of the finished pattern.
class PatternPreview extends StatefulWidget {
  const PatternPreview({super.key, required this.pattern, this.size = 64});

  final PuzzlePattern pattern;
  final double size;

  @override
  State<PatternPreview> createState() => _PatternPreviewState();
}

class _PatternPreviewState extends State<PatternPreview> {
  NxnCubeController? _cube;
  PyraminxController? _pyraminx;

  @override
  void initState() {
    super.initState();
    final p = widget.pattern;
    if (p.puzzle == PuzzleType.pyraminx) {
      _pyraminx = PyraminxController(initial: pyraminxPatternState(p));
    } else {
      _cube = NxnCubeController(p.puzzle.order!, initial: cubePatternState(p));
    }
  }

  @override
  void dispose() {
    _cube?.dispose();
    _pyraminx?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: widget.size,
        child: _cube != null
            ? NxnCubeView(controller: _cube!)
            : PyraminxView(controller: _pyraminx!),
      ),
    );
  }
}
