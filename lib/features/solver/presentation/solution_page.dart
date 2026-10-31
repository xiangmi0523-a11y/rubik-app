import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_cube/puzzle_cube.dart';

import '../application/playback_controller.dart';
import '../domain/solve_result.dart';

class SolutionPage extends ConsumerWidget {
  const SolutionPage({super.key, required this.result});

  final SolveResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = playbackControllerProvider(result);
    final playback = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final cube = ref.watch(playbackCubeProvider(result));
    final moves = result.moves;
    final total = moves.length;

    return Scaffold(
      appBar: AppBar(title: Text('还原步骤（$total 步）')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                total == 0
                    ? '已经是还原状态'
                    : playback.index == 0
                        ? '准备开始'
                        : '第 ${playback.index} / $total 步：${moves[playback.index - 1]}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            if (playback.index < total)
              Text('下一步：${moves[playback.index]}',
                  style: const TextStyle(color: Colors.white70)),
            Expanded(child: Cube(controller: cube)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < total; i++)
                    ChoiceChip(
                      label: Text(moves[i]),
                      selected: i == playback.index - 1,
                      onSelected: (_) => notifier.jumpTo(i + 1),
                      backgroundColor:
                          i < playback.index ? Colors.white10 : null,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton.filledTonal(
                    tooltip: '回到开始',
                    onPressed: () => notifier.jumpTo(0),
                    icon: const Icon(Icons.skip_previous),
                  ),
                  IconButton.filledTonal(
                    tooltip: '上一步',
                    onPressed: notifier.prev,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton.filled(
                    iconSize: 36,
                    tooltip: playback.playing ? '暂停' : '自动播放',
                    onPressed: total == 0 ? null : notifier.togglePlay,
                    icon: Icon(playback.playing ? Icons.pause : Icons.play_arrow),
                  ),
                  IconButton.filledTonal(
                    tooltip: '下一步',
                    onPressed: notifier.next,
                    icon: const Icon(Icons.chevron_right),
                  ),
                  IconButton.filledTonal(
                    tooltip: '直接到结尾',
                    onPressed: () => notifier.jumpTo(total),
                    icon: const Icon(Icons.skip_next),
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
