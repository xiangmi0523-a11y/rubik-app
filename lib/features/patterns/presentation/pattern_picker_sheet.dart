import 'package:flutter/material.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../../../core/cube/cube_facelets.dart';
import '../../solver/domain/solve_result.dart';
import '../../solver/presentation/solution_page.dart';
import '../domain/cube_pattern.dart';

/// Bottom sheet listing the built-in patterns; picking one opens the animated
/// tutorial.
Future<void> showPatternPicker(BuildContext context) {
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
          Text('花式魔方',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('从还原状态开始，跟着动画一步步拧出图案',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          for (final pattern in cubePatterns)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(10),
                leading: PatternThumbnail(definition: pattern.definition),
                title: Text(pattern.name),
                subtitle: Text(
                  '${pattern.description}\n${pattern.moves.length} 步：${pattern.algorithm}',
                ),
                isThreeLine: true,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  openPatternDemo(context, pattern);
                },
              ),
            ),
        ],
      ),
    ),
  );
}

void openPatternDemo(BuildContext context, CubePattern pattern) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SolutionPage(
        title: '花式：${pattern.name}',
        startText: '从还原状态开始',
        result: SolveResult(
          colors: CubeFacelets.read(PuzzleCubeState.solved()),
          moves: pattern.moves,
        ),
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              PatternThumbnail(definition: pattern.definition, size: 56),
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

/// Flat preview of the pattern's front (F) face.
class PatternThumbnail extends StatelessWidget {
  const PatternThumbnail({super.key, required this.definition, this.size = 48});

  final String definition;
  final double size;

  @override
  Widget build(BuildContext context) {
    final centers = CubeFacelets.centerColors;
    Color colorOf(String letter) => centers[CubeSide.values
        .firstWhere((s) => s.letter == letter)]!;
    final start = CubeSide.f.index * 9;
    return SizedBox.square(
      dimension: size,
      child: Column(
        children: [
          for (var r = 0; r < 3; r++)
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < 3; c++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: colorOf(definition[start + r * 3 + c]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
