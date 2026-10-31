import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/puzzle_type_controller.dart';
import '../domain/puzzle_type.dart';

/// Horizontal chip row for choosing the puzzle.
class PuzzleTypeSelector extends ConsumerWidget {
  const PuzzleTypeSelector({super.key, this.value, this.onChanged});

  /// Defaults to the global [puzzleTypeProvider].
  final PuzzleType? value;
  final ValueChanged<PuzzleType>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = value ?? ref.watch(puzzleTypeProvider);
    final change =
        onChanged ?? ref.read(puzzleTypeProvider.notifier).select;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final type in PuzzleType.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                label: Text(type.label),
                avatar: type == PuzzleType.pyraminx
                    ? const Icon(Icons.change_history, size: 16)
                    : null,
                selected: type == selected,
                onSelected: (_) => change(type),
              ),
            ),
        ],
      ),
    );
  }
}
