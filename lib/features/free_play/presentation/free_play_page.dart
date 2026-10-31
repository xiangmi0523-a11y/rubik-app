import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../application/free_play_controller.dart';
import 'widgets/timer_display.dart';

class FreePlayPage extends ConsumerWidget {
  const FreePlayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cube = ref.watch(freePlayCubeProvider);
    final timer = ref.watch(freePlayControllerProvider);
    final notifier = ref.read(freePlayControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('自由玩')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            TimerDisplay(state: timer, onTap: notifier.toggleManual),
            if (timer.scramble.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: SelectableText(
                  timer.scramble,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, letterSpacing: 0.5),
                ),
              ),
            Expanded(
              child: Cube(
                controller: cube,
                onMove: (move) {
                  cube.applyMoveInstant(move);
                  notifier.onCubeMove();
                },
              ),
            ),
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
                    onPressed: cube.resetCamera,
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
}
