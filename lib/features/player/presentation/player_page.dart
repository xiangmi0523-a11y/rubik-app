import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_background.dart';
import '../application/player_controller.dart';
import '../domain/puzzle_stepper.dart';

/// Plays a [PlayerScript] (solution or pattern) on any puzzle, step by step:
/// play / pause, single steps, jump to any move or phase, 1× / 2× / 4×.
class PlayerPage extends ConsumerWidget {
  const PlayerPage({
    super.key,
    required this.script,
    this.title,
    this.header,
    this.startText = '准备开始',
  });

  final PlayerScript script;

  /// App-bar title; defaults to "还原步骤（N 步）".
  final String? title;

  /// Optional widget shown above the step counter.
  final Widget? header;
  final String startText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = playerControllerProvider(script);
    final playback = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final stepper = ref.watch(playerStepperProvider(script));
    final moves = script.moves;
    final total = moves.length;
    final phases = script.phases;
    final phase = phaseIndexAt(phases, playback.index);

    String? detail() {
      if (phase == null || total == 0) return null;
      final p = phases[phase];
      // The formula of the next move (or of the last one at the end).
      var note = script.noteAt(playback.index < total ? playback.index : total - 1);
      // Notes often start with the phase name already shown.
      if (note != null && note.startsWith('${p.label}：')) {
        note = note.substring(p.label.length + 1);
      }
      return [
        '${p.label} ${playback.index - p.start}/${p.length}',
        ?note,
      ].join(' · ');
    }

    final info = detail();
    return AppBackground(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(title ?? '还原步骤（$total 步）')),
      body: SafeArea(
        child: Column(
          children: [
            ?header,
            if (phases.isNotEmpty)
              _PhaseBar(
                phases: phases,
                current: phase,
                onTap: notifier.jumpToPhase,
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                total == 0
                    ? '已经是还原状态'
                    : playback.index == 0
                        ? startText
                        : '第 ${playback.index} / $total 步：${moves[playback.index - 1]}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            if (info != null)
              Text(info, style: const TextStyle(color: Colors.white70)),
            if (playback.index < total)
              Text('下一步：${moves[playback.index]}',
                  style: const TextStyle(color: Colors.white70)),
            Expanded(child: stepper.buildView()),
            _MoveStrip(
              moves: moves,
              applied: playback.index,
              onTap: (i) => notifier.jumpTo(i + 1),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<double>(
                showSelectedIcon: false,
                segments: [
                  for (final s in playbackSpeeds)
                    ButtonSegment(value: s, label: Text('${s.toInt()}×')),
                ],
                selected: {playback.speed},
                onSelectionChanged: (v) => notifier.setSpeed(v.first),
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
    ));
  }
}

/// One tile per phase (name and move count), all visible at once; tapping
/// jumps to the start of that phase.
class _PhaseBar extends StatelessWidget {
  const _PhaseBar({
    required this.phases,
    required this.current,
    required this.onTap,
  });

  final List<PlayerPhase> phases;
  final int? current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          for (var i = 0; i < phases.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Material(
                  key: ValueKey('phase$i'),
                  color: i == current
                      ? scheme.primaryContainer
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onTap(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          Text(phases[i].label,
                              maxLines: 1,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('${phases[i].length} 步',
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// All moves as chips in a bounded, scrollable area that keeps the current
/// move in view; tapping a chip jumps to just after that move.
class _MoveStrip extends StatefulWidget {
  const _MoveStrip({
    required this.moves,
    required this.applied,
    required this.onTap,
  });

  final List<String> moves;
  final int applied;
  final ValueChanged<int> onTap;

  @override
  State<_MoveStrip> createState() => _MoveStripState();
}

class _MoveStripState extends State<_MoveStrip> {
  final _currentKey = GlobalKey();

  @override
  void didUpdateWidget(covariant _MoveStrip old) {
    super.didUpdateWidget(old);
    if (old.applied != widget.applied) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _currentKey.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx, alignment: 0.5);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final moves = widget.moves;
    final current = widget.applied == 0 ? 0 : widget.applied - 1;
    return ConstrainedBox(
      // Shorter on small phones, so the puzzle keeps its room.
      constraints: BoxConstraints(
          maxHeight: (MediaQuery.sizeOf(context).height * 0.16).clamp(72, 132)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < moves.length; i++)
              ChoiceChip(
                key: i == current ? _currentKey : null,
                label: Text(moves[i]),
                selected: i == widget.applied - 1,
                onSelected: (_) => widget.onTap(i),
                backgroundColor: i < widget.applied ? Colors.white10 : null,
              ),
          ],
        ),
      ),
    );
  }
}
