import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cube/cube_facelets.dart';
import '../../../core/ui/app_background.dart';
import '../../../core/nxn/nxn_cube_controller.dart';
import '../../../core/nxn/nxn_cube_view.dart';
import '../../../core/pyraminx/pyraminx_controller.dart';
import '../../../core/pyraminx/pyraminx_model.dart';
import '../../../core/pyraminx/pyraminx_view.dart';
import '../../home/application/home_tab_controller.dart';
import '../../player/domain/puzzle_stepper.dart';
import '../../player/presentation/player_page.dart';
import '../../puzzles/domain/puzzle_type.dart';
import '../../puzzles/presentation/puzzle_type_selector.dart';
import '../application/color_input_controller.dart';
import '../application/hold_guide_controller.dart';
import '../application/puzzle_color_input.dart';
import '../application/solve_controller.dart';
import '../domain/cube_input_validator.dart';
import 'widgets/color_palette_bar.dart';
import 'widgets/hold_guide_sheet.dart';
import 'widgets/sticker_paint_cube.dart';
import 'widgets/unsolvable_dialog.dart';

class ColorInputPage extends ConsumerWidget {
  const ColorInputPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(solverPuzzleProvider);

    // First visit to this tab -> hand-hold guide.
    ref.listen<int>(homeTabProvider, (_, tab) {
      if (tab == HomeTab.solver && !ref.read(holdGuideSeenProvider)) {
        ref.read(holdGuideSeenProvider.notifier).markSeen();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) showHoldGuideSheet(context, type);
        });
      }
    });

    void random() => switch (type) {
          PuzzleType.cube3 =>
            ref.read(colorInputProvider.notifier).randomExample(),
          PuzzleType.pyraminx =>
            ref.read(pyraminxColorInputProvider.notifier).randomExample(),
          _ => ref.read(nxnColorInputProvider(type.order!).notifier)
              .randomExample(),
        };
    void clear() => switch (type) {
          PuzzleType.cube3 => ref.read(colorInputProvider.notifier).clear(),
          PuzzleType.pyraminx =>
            ref.read(pyraminxColorInputProvider.notifier).clear(),
          _ => ref.read(nxnColorInputProvider(type.order!).notifier).clear(),
        };

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('填色求解'),
        actions: [
          IconButton(
            tooltip: '手持姿势',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showHoldGuideSheet(context, type),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'random' ? random() : clear(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'random', child: Text('随机示例')),
              PopupMenuItem(value: 'clear', child: Text('清空重填')),
            ],
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              PuzzleTypeSelector(
                value: type,
                onChanged: ref.read(solverPuzzleProvider.notifier).select,
              ),
              Expanded(
                child: switch (type) {
                  PuzzleType.cube3 => const _Cube3Input(),
                  PuzzleType.pyraminx => const _PyraminxInput(),
                  _ => _NxnInput(n: type.order!),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared layout: 3D puzzle with view buttons, hint, palette, solve button.
class _InputLayout extends StatelessWidget {
  const _InputLayout({
    required this.puzzle,
    required this.onFront,
    required this.onBack,
    required this.hint,
    required this.palette,
    required this.onSolve,
    this.solving = false,
  });

  final Widget puzzle;
  final VoidCallback onFront;
  final VoidCallback onBack;
  final String hint;
  final Widget palette;
  final VoidCallback? onSolve;
  final bool solving;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(padding: const EdgeInsets.all(8), child: puzzle),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Column(
                  children: [
                    _ViewButton(
                        label: '正面', icon: Icons.flip_to_front, onTap: onFront),
                    const SizedBox(height: 8),
                    _ViewButton(
                        label: '背面', icon: Icons.flip_to_back, onTap: onBack),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        const SizedBox(height: 12),
        palette,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: solving ? null : onSolve,
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
    );
  }
}

String _hint(int filled, int total) => filled >= total
    ? '已全部填完，点击「开始求解」'
    : '请根据手上魔方各面颜色，点击图中色块填色\n'
        '拖动可旋转查看，再次点击同色块可擦除（$filled/$total）';

Future<void> _handleOutcome(
    BuildContext context, PuzzleSolveOutcome outcome) async {
  switch (outcome) {
    case PuzzleSolveOk(:final script):
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlayerPage(script: script),
      ));
    case PuzzleSolveIncomplete(:final message):
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    case PuzzleSolveInvalid(:final reasons):
      await showUnsolvableDialog(context, reasons);
    case PuzzleSolveFailed(:final title, :final message):
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.error_outline, size: 36),
          title: Text(title),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
  }
}

// ── 3x3 ────────────────────────────────────────────────────────────────────

class _Cube3Input extends ConsumerWidget {
  const _Cube3Input();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final input = ref.watch(colorInputProvider);
    final inputNotifier = ref.read(colorInputProvider.notifier);
    final solve = ref.watch(solveControllerProvider);
    final cube = ref.watch(colorInputCubeProvider);

    ref.listen<SolveState>(solveControllerProvider, (_, next) {
      if (next.status == SolveStatus.done && next.result != null) {
        final result = next.result!;
        ref.read(solveControllerProvider.notifier).acknowledge();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerPage(
              script: Cube3Script(colors: result.colors, moves: result.moves),
            ),
          ),
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

    return _InputLayout(
      puzzle: StickerPaintCube(
        controller: cube,
        onFaceletTap: (i) {
          if (inputNotifier.paint(i)) HapticFeedback.selectionClick();
        },
      ),
      onFront: cube.resetCamera,
      onBack: () => cube.setView(
        rotationX: CubeNotation.viewRotationX + 1.0,
        rotationY: CubeNotation.viewRotationY + math.pi,
      ),
      hint: _hint(48 - input.blankCount, 48),
      palette: ColorPaletteBar(
        selected: input.selected,
        remaining: input.remaining,
        onSelect: inputNotifier.select,
      ),
      solving: solve.status == SolveStatus.solving,
      onSolve: ref.read(solveControllerProvider.notifier).solve,
    );
  }
}

// ── 2x2 / 4x4 / 5x5 ────────────────────────────────────────────────────────

class _NxnInput extends ConsumerStatefulWidget {
  const _NxnInput({required this.n});
  final int n;

  @override
  ConsumerState<_NxnInput> createState() => _NxnInputState();
}

class _NxnInputState extends ConsumerState<_NxnInput> {
  bool _solving = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.n;
    final provider = nxnColorInputProvider(n);
    final input = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final cube = notifier.cube;
    final fixed = n.isOdd ? 6 : 0;
    final total = 6 * n * n - fixed;

    return _InputLayout(
      puzzle: NxnCubeView(
        key: ValueKey('input$n'),
        controller: cube,
        onStickerTap: (hit) {
          if (notifier.paint(hit)) HapticFeedback.selectionClick();
        },
      ),
      onFront: cube.resetCamera,
      onBack: () => cube.setView(
        rotationX: -NxnCubeController.initialRotationX,
        rotationY: NxnCubeController.initialRotationY + math.pi,
      ),
      hint: _hint(total - notifier.blankCount, total),
      palette: ColorPaletteBar(
        key: ValueKey(input.version),
        selected: input.selected,
        remaining: notifier.remaining,
        onSelect: notifier.select,
      ),
      solving: _solving,
      onSolve: () async {
        setState(() => _solving = true);
        final outcome = await notifier.solve();
        if (!context.mounted) return;
        setState(() => _solving = false);
        await _handleOutcome(context, outcome);
      },
    );
  }
}

// ── Pyraminx ───────────────────────────────────────────────────────────────

class _PyraminxInput extends ConsumerStatefulWidget {
  const _PyraminxInput();

  @override
  ConsumerState<_PyraminxInput> createState() => _PyraminxInputState();
}

class _PyraminxInputState extends ConsumerState<_PyraminxInput> {
  bool _solving = false;

  @override
  Widget build(BuildContext context) {
    final input = ref.watch(pyraminxColorInputProvider);
    final notifier = ref.read(pyraminxColorInputProvider.notifier);
    final puzzle = notifier.puzzle;
    const palette = PyraminxGeometry.faceColors;

    return _InputLayout(
      puzzle: PyraminxView(
        controller: puzzle,
        onSlotTap: (slot) {
          if (notifier.paint(slot)) HapticFeedback.selectionClick();
        },
      ),
      onFront: puzzle.resetCamera,
      onBack: () => puzzle.setView(
        rotationX: -0.7,
        rotationY: PyraminxController.initialRotationY + math.pi,
      ),
      hint: _hint(36 - notifier.blankCount, 36),
      palette: ColorPaletteBar(
        key: ValueKey(input.version),
        palette: palette,
        selected: palette[input.selected],
        remaining: (c) => notifier.remaining(palette.indexOf(c)),
        onSelect: (c) => notifier.select(palette.indexOf(c)),
      ),
      solving: _solving,
      onSolve: () async {
        setState(() => _solving = true);
        final outcome = await notifier.solve();
        if (!context.mounted) return;
        setState(() => _solving = false);
        await _handleOutcome(context, outcome);
      },
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

