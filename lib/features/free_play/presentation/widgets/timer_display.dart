import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/utils/time_format.dart';
import '../../../stats/domain/solve_record.dart';
import '../../application/free_play_controller.dart';
import '../../application/inspection_setting.dart';

/// Timer with WCA inspection countdown and penalty chips after a solve.
class TimerDisplay extends StatefulWidget {
  const TimerDisplay({
    super.key,
    required this.state,
    required this.onTap,
    this.onPenalty,
  });

  final TimerState state;
  final VoidCallback onTap;

  /// Changes the penalty of the finished solve (shown when stopped).
  final ValueChanged<Penalty>? onPenalty;

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
    final live = widget.state.status == TimerStatus.running ||
        widget.state.status == TimerStatus.inspecting;
    if (live && !_ticker.isActive) _ticker.start();
    if (!live && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final String text;
    final Color color;
    final String hint;
    switch (s.status) {
      case TimerStatus.inspecting:
        final elapsed = s.inspectionElapsed;
        final left = inspectionSeconds - elapsed.inSeconds;
        final penalty = inspectionPenalty(elapsed);
        text = switch (penalty) {
          Penalty.none => '$left',
          Penalty.plus2 => '+2',
          Penalty.dnf => 'DNF',
        };
        // WCA calls at 8 s and 12 s.
        color = elapsed.inSeconds >= 12
            ? Colors.redAccent
            : elapsed.inSeconds >= 8
                ? Colors.orangeAccent
                : Colors.amberAccent;
        hint = '观察中：转动第一下或点这里开始计时';
      case TimerStatus.running:
        text = formatDuration(s.current);
        color = Colors.greenAccent;
        hint = s.penalty == Penalty.none
            ? '还原后自动停止（点这里手动停止）'
            : '观察超时，本次成绩${s.penalty.label}';
      case TimerStatus.stopped:
        text = switch (s.penalty) {
          Penalty.none => formatDuration(s.elapsed),
          Penalty.plus2 =>
            '${formatDuration(s.elapsed + const Duration(seconds: 2))}+',
          Penalty.dnf => 'DNF',
        };
        color = Colors.lightBlueAccent;
        hint = '成绩已记录';
      case TimerStatus.ready:
        text = formatDuration(Duration.zero);
        color = Colors.amberAccent;
        hint = '转动第一下即开始计时';
      case TimerStatus.idle:
        text = formatDuration(Duration.zero);
        color = Colors.white;
        hint = '点「打乱」开始，或点这里手动计时';
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Column(
        children: [
          Semantics(
            button: true,
            label: '计时器 $text',
            excludeSemantics: true,
            onTap: widget.onTap,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w300,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (s.status == TimerStatus.stopped && widget.onPenalty != null)
            Wrap(
              spacing: 8,
              children: [
                for (final p in Penalty.values)
                  ChoiceChip(
                    label: Text(p == Penalty.none ? 'OK' : p.label),
                    selected: s.penalty == p,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => widget.onPenalty!(p),
                  ),
              ],
            )
          else
            Text(hint, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
