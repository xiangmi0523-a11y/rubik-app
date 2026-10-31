import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../application/color_input_controller.dart';
import '../application/solve_controller.dart';
import 'solution_page.dart';
import 'widgets/cube_net_editor.dart';

class ColorInputPage extends ConsumerWidget {
  const ColorInputPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(colorInputProvider);
    final inputNotifier = ref.read(colorInputProvider.notifier);
    final solve = ref.watch(solveControllerProvider);
    final preview = ref.watch(colorPreviewCubeProvider);

    ref.listen<SolveState>(solveControllerProvider, (_, next) {
      if (next.status == SolveStatus.done && next.result != null) {
        final result = next.result!;
        ref.read(solveControllerProvider.notifier).acknowledge();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SolutionPage(result: result)),
        );
      } else if (next.status == SolveStatus.invalid) {
        ref.read(solveControllerProvider.notifier).acknowledge();
        _showErrors(context, next.errors);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('填色求解'),
        actions: [
          IconButton(
            tooltip: '随机示例',
            icon: const Icon(Icons.casino),
            onPressed: inputNotifier.randomExample,
          ),
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.layers_clear),
            onPressed: inputNotifier.clear,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text(
            '白色中心朝上、绿色中心朝前拿好魔方，按展开图逐面填色。'
            '上面(U)：从上往下看，靠近你的一边贴着前面；'
            '下面(D)：从下往上看，靠近前面的一边在上方。',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          CubeNetEditor(colors: input.colors, onTap: inputNotifier.paint),
          const SizedBox(height: 8),
          _Palette(selected: input.selected, onSelect: inputNotifier.select),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: Cube(controller: preview), // drag to orbit only
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: solve.status == SolveStatus.solving
                ? null
                : ref.read(solveControllerProvider.notifier).solve,
            icon: solve.status == SolveStatus.solving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high),
            label: Text(solve.status == SolveStatus.solving ? '求解中…' : '校验并求解'),
          ),
        ],
      ),
    );
  }

  void _showErrors(BuildContext context, List<String> errors) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('颜色不合法'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final e in errors) Text('• $e')],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('知道了')),
        ],
      ),
    );
  }
}

class _Palette extends StatelessWidget {
  const _Palette({required this.selected, required this.onSelect});

  final Color selected;
  final ValueChanged<Color> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final color in [...CubeColors.palette, CubeColors.colorless])
          GestureDetector(
            onTap: () => onSelect(color),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.toARGB32() == selected.toARGB32()
                      ? Colors.white
                      : Colors.black,
                  width: color.toARGB32() == selected.toARGB32() ? 4 : 1,
                ),
              ),
              child: color.toARGB32() == CubeColors.colorless.toARGB32()
                  ? const Icon(Icons.cleaning_services, size: 18)
                  : null,
            ),
          ),
      ],
    );
  }
}
