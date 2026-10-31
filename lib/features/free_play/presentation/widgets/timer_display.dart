import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/utils/time_format.dart';
import '../../application/free_play_controller.dart';

/// Shows the timer, repainting every frame while running.
class TimerDisplay extends StatefulWidget {
  const TimerDisplay({
    super.key,
    required this.state,
    required this.onTap,
    this.manualOnly = false,
  });

  final TimerState state;
  final VoidCallback onTap;

  /// Physical-puzzle mode: the timer only starts/stops on tap.
  final bool manualOnly;

  @override
  State<TimerDisplay> createState() => _TimerDisplayState();
}

class _TimerDisplayState extends State<TimerDisplay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}));

  @override
  void didUpdateWidget(covariant TimerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    final running = widget.state.status == TimerStatus.running;
    if (running && !_ticker.isActive) _ticker.start();
    if (!running && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final color = switch (s.status) {
      TimerStatus.running => Colors.greenAccent,
      TimerStatus.ready => Colors.amberAccent,
      TimerStatus.stopped => Colors.lightBlueAccent,
      TimerStatus.idle => Colors.white,
    };
    final hint = switch (s.status) {
      TimerStatus.idle => '点「打乱」开始，或点这里手动计时',
      TimerStatus.ready =>
        widget.manualOnly ? '按打乱公式打乱后，点这里开始计时' : '转动第一下即开始计时',
      TimerStatus.running =>
        widget.manualOnly ? '还原后点这里停止' : '还原后自动停止（点这里手动停止）',
      TimerStatus.stopped => '成绩已记录',
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Column(
        children: [
          Text(
            formatDuration(s.current),
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w300,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(hint, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
