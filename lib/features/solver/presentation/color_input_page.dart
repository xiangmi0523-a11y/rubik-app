import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cube/cube_facelets.dart';
import '../../home/application/home_tab_controller.dart';
import '../application/color_input_controller.dart';
import '../application/hold_guide_controller.dart';
import '../application/solve_controller.dart';
import '../domain/cube_input_validator.dart';
import 'solution_page.dart';
import 'widgets/color_palette_bar.dart';
import 'widgets/hold_guide_sheet.dart';
import 'widgets/sticker_paint_cube.dart';
import 'widgets/unsolvable_dialog.dart';

class ColorInputPage extends ConsumerWidget {
  const ColorInputPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(colorInputProvider);
    final inputNotifier = ref.read(colorInputProvider.notifier);
    final solve = ref.watch(solveControllerProvider);
    final cube = ref.watch(colorInputCubeProvider);
    final solving = solve.status == SolveStatus.solving;

    // First visit to this tab -> hand-hold guide.
    ref.listen<int>(homeTabProvider, (_, tab) {
      if (tab == HomeTab.solver && !ref.read(holdGuideSeenProvider)) {
        ref.read(holdGuideSeenProvider.notifier).markSeen();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) showHoldGuideSheet(context);
        });
      }
    });

    ref.listen<SolveState>(solveControllerProvider, (_, next) {
      if (next.status == SolveStatus.done && next.result != null) {
        final result = next.result!;
        ref.read(solveControllerProvider.notifier).acknowledge();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SolutionPage(result: result)),
        );
      } else if (next.status == SolveStatus.invalid) {
        ref.read(solveControllerProvider.notifier).acknowledge();
        if (next.issue == CubeInputIssue.incomplete) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(next.errors.join('\n'))));
        } else {
          showUnsolvableDialog(context, next.errors);
        }
      }
    });

    final filled = 48 - input.blankCount;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('填色求解'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '手持姿势',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showHoldGuideSheet(context),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'random' => inputNotifier.randomExample(),
              _ => inputNotifier.clear(),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'random', child: Text('随机示例')),
              PopupMenuItem(value: 'clear', child: Text('清空重填')),
            ],
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF26243F), Color(0xFF1C4450), Color(0xFF2B2A47)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: StickerPaintCube(
                          controller: cube,
                          onFaceletTap: (i) {
                            if (inputNotifier.paint(i)) {
                              HapticFeedback.selectionClick();
                            }
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Column(
                        children: [
                          _ViewButton(
                            label: '正面',
                            icon: Icons.flip_to_front,
                            onTap: cube.resetCamera,
                          ),
                          const SizedBox(height: 8),
                          _ViewButton(
                            label: '背面',
                            icon: Icons.flip_to_back,
                            onTap: () {
                              // Shows D, L and B.
                              cube.setView(
                                rotationX: CubeNotation.viewRotationX + 1.0,
                                rotationY: CubeNotation.viewRotationY + math.pi,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  input.isComplete
                      ? '已全部填完，点击「开始求解」'
                      : '请根据手上魔方各面颜色，点击图中色块填色\n'
                          '拖动可旋转查看，再次点击同色块可擦除（$filled/48）',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
              ColorPaletteBar(
                selected: input.selected,
                remaining: input.remaining,
                onSelect: inputNotifier.select,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: solving
                        ? null
                        : ref.read(solveControllerProvider.notifier).solve,
                    icon: solving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high),
                    label: Text(solving ? '求解中…' : '开始求解'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white12,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            children: [
              Icon(icon, size: 20),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
