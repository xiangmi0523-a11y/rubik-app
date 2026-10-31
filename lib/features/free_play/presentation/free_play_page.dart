import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../../../core/nxn/nxn_cube_view.dart';
import '../../patterns/presentation/pattern_picker_sheet.dart';
import '../../puzzles/application/puzzle_type_controller.dart';
import '../../puzzles/domain/puzzle_type.dart';
import '../../puzzles/presentation/puzzle_type_selector.dart';
import '../../../core/pyraminx/pyraminx_view.dart';
import '../application/free_play_controller.dart';
import '../application/inspection_setting.dart';
import 'widgets/timer_display.dart';

class FreePlayPage extends ConsumerWidget {
  const FreePlayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(puzzleTypeProvider);
    final timer = ref.watch(freePlayControllerProvider);
    final notifier = ref.read(freePlayControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('自由玩'),
        actions: [
          TextButton.icon(
              onPressed: () => showPatternPicker(context, type),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('花式'),
            ),
          PopupMenuButton<String>(
            onSelected: (_) =>
                ref.read(inspectionEnabledProvider.notifier).toggle(),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'inspection',
                checked: ref.read(inspectionEnabledProvider),
                child: const Text('15 秒观察时间'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const PuzzleTypeSelector(),
            const SizedBox(height: 4),
            TimerDisplay(
              state: timer,
              onTap: notifier.toggleManual,
              onPenalty: notifier.setLastPenalty,
            ),
            if (timer.scramble.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: SelectableText(
                  timer.scramble,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 14, letterSpacing: 0.5),
                ),
              ),
            Expanded(child: _PuzzleArea(type: type, onMove: notifier.onCubeMove)),
            const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('在魔方上拖动转层，在空白处拖动旋转视角',
                    style: TextStyle(fontSize: 12, color: Colors.white54)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: notifier.scramble,
                      icon: const Icon(Icons.shuffle),
                      label: const Text('打乱'),
                    ),
                  ),
                  const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: notifier.resetCube,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('复原'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: '视角复位',
                      onPressed: () => _resetCamera(ref, type),
                      icon: const Icon(Icons.center_focus_strong),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetCamera(WidgetRef ref, PuzzleType type) {
    if (type == PuzzleType.cube3) {
      ref.read(freePlayCubeProvider).resetCamera();
    } else if (type.usesNxnEngine) {
      ref.read(nxnCubeProvider(type.order!)).resetCamera();
    } else {
      ref.read(pyraminxProvider).resetCamera();
    }
  }
}

/// The 3D puzzle for the selected type.
class _PuzzleArea extends ConsumerWidget {
  const _PuzzleArea({required this.type, required this.onMove});

  final PuzzleType type;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (type == PuzzleType.cube3) {
      final cube = ref.watch(freePlayCubeProvider);
      return Cube(
        controller: cube,
        onMove: (move) {
          cube.applyMoveInstant(move);
          onMove();
        },
      );
    }
    if (type.usesNxnEngine) {
      return NxnCubeView(
        key: ValueKey(type),
        controller: ref.watch(nxnCubeProvider(type.order!)),
        onMove: (_) => onMove(),
      );
    }
    return PyraminxView(
      controller: ref.watch(pyraminxProvider),
      onMove: (_) => onMove(),
    );
  }
}
