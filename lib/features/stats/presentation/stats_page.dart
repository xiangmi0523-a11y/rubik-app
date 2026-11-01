import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_background.dart';
import '../../../core/utils/time_format.dart';
import '../../puzzles/presentation/puzzle_type_selector.dart';
import '../application/stats_controller.dart';
import '../domain/averages.dart';
import '../domain/solve_record.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(filteredRecordsProvider);
    final summary = ref.watch(statsSummaryProvider);
    final puzzle = ref.watch(statsFilterProvider);
    final times = records.map((r) => r.effectiveMs).toList();

    return AppBackground(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('成绩统计'),
        actions: [
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.delete_sweep),
            onPressed: records.isEmpty ? null : () => _confirmClear(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          PuzzleTypeSelector(
            value: puzzle,
            onChanged: ref.read(statsFilterProvider.notifier).select,
          ),
          // Summary, divider and rows scroll together, so big text or a
          // small screen never squeezes the list to nothing.
          Expanded(
            child: ListView.builder(
              itemCount: records.isEmpty ? 2 : records.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return _Summary(summary: summary);
                if (records.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 48, color: Colors.white38),
                        const SizedBox(height: 8),
                        Text('还没有${puzzle.label}成绩，去「自由玩」计时吧',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  );
                }
                // newest first
                final idx = records.length - i;
                final r = records[idx];
                final upTo = times.sublist(0, idx + 1);
                final ao5 = averageOfLast(upTo, 5);
                final ao12 = averageOfLast(upTo, 12);
                return Dismissible(
                  key: ValueKey(r.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete),
                  ),
                  onDismissed: (_) => _removeWithUndo(context, ref, r),
                  child: ListTile(
                    onTap: () => _editPenalty(context, ref, r),
                    leading: Text('#${idx + 1}'),
                    title: Text(
                      recordLabel(r),
                      style: const TextStyle(
                        fontSize: 20,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    subtitle: Text(
                      'ao5 ${formatMs(ao5)}   ao12 ${formatMs(ao12)}'
                      '${r.scramble.isEmpty ? '' : '\n${r.scramble}'}',
                    ),
                    isThreeLine: r.scramble.isNotEmpty,
                    trailing: Text(_date(r.createdAt)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ));
  }

  Future<void> _editPenalty(
      BuildContext context, WidgetRef ref, SolveRecord r) async {
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('成绩 ${formatMs(r.durationMs)}',
                style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final p in Penalty.values)
              ListTile(
                leading: Icon(p == r.penalty
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                title: Text(p.label),
                onTap: () => Navigator.pop(c, p),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除这条成绩'),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
          ],
        ),
      ),
    );
    final notifier = ref.read(statsControllerProvider.notifier);
    if (choice is Penalty) notifier.setPenalty(r.id, choice);
    if (choice == 'delete' && context.mounted) _removeWithUndo(context, ref, r);
  }

  /// Deletes a solve and offers to take it back.
  void _removeWithUndo(BuildContext context, WidgetRef ref, SolveRecord r) {
    final notifier = ref.read(statsControllerProvider.notifier);
    notifier.remove(r.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('已删除成绩 ${recordLabel(r)}'),
        action: SnackBarAction(label: '撤销', onPressed: () => notifier.restore(r)),
      ));
  }

  String _date(DateTime d) =>
      '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('清空所有${ref.read(statsFilterProvider).label}成绩？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok == true) {
      ref
          .read(statsControllerProvider.notifier)
          .clear(ref.read(statsFilterProvider));
    }
  }
}

/// Seven summary tiles in three equal columns, then a divider.
class _Summary extends StatelessWidget {
  const _Summary({required this.summary});
  final StatsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatTile('次数', '${summary.count}', w),
                  _StatTile('最佳', formatMs(summary.best), w),
                  _StatTile('平均', formatMs(summary.mean), w),
                  _StatTile('当前 ao5', formatMs(summary.ao5), w),
                  _StatTile('当前 ao12', formatMs(summary.ao12), w),
                  _StatTile('最佳 ao5', formatMs(summary.bestAo5), w),
                  _StatTile('最佳 ao12', formatMs(summary.bestAo12), w),
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.width);
  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// "12.34", "14.34+" (with +2) or "DNF(12.34)".
String recordLabel(SolveRecord r) => switch (r.penalty) {
      Penalty.none => formatMs(r.durationMs),
      Penalty.plus2 => '${formatMs(r.effectiveMs)}+',
      Penalty.dnf => 'DNF(${formatMs(r.durationMs)})',
    };
