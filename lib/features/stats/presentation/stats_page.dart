import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/time_format.dart';
import '../../puzzles/presentation/puzzle_type_selector.dart';
import '../application/stats_controller.dart';
import '../domain/averages.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(filteredRecordsProvider);
    final summary = ref.watch(statsSummaryProvider);
    final puzzle = ref.watch(statsFilterProvider);
    final times = records.map((r) => r.durationMs).toList();

    return Scaffold(
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatTile('次数', '${summary.count}'),
                _StatTile('最佳', formatMs(summary.best)),
                _StatTile('平均', formatMs(summary.mean)),
                _StatTile('当前 ao5', formatMs(summary.ao5)),
                _StatTile('当前 ao12', formatMs(summary.ao12)),
                _StatTile('最佳 ao5', formatMs(summary.bestAo5)),
                _StatTile('最佳 ao12', formatMs(summary.bestAo12)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: records.isEmpty
                ? Center(child: Text('还没有${puzzle.label}成绩，去「自由玩」计时吧'))
                : ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, i) {
                      // newest first
                      final idx = records.length - 1 - i;
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
                        onDismissed: (_) => ref
                            .read(statsControllerProvider.notifier)
                            .remove(r.id),
                        child: ListTile(
                          leading: Text('#${idx + 1}'),
                          title: Text(
                            formatMs(r.durationMs),
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
    );
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

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 104,
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
