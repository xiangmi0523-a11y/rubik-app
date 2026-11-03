import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_background.dart';
import '../../../core/nxn/nxn_cube_view.dart';
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
import '../domain/fill_view_plan.dart';
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

/// A puzzle's camera as the colouring page drives it.
class _PuzzleCamera {
  const _PuzzleCamera({required this.read, required this.write});

  /// Current (rotationX, rotationY).
  final (double, double) Function() read;

  /// Moves the camera to absolute angles (never touches the puzzle state).
  final void Function(double rotationX, double rotationY) write;
}

/// Shared layout: 3D puzzle with view buttons, hint, palette, solve button.
///
/// The camera is not orbited by hand: [plan] lists the fixed views and the
/// ◀ ▶ buttons (and 「正面」/「背面」) move between them with a smooth turn.
class _InputLayout extends StatefulWidget {
  const _InputLayout({
    super.key,
    required this.puzzle,
    required this.plan,
    required this.camera,
    required this.hint,
    required this.palette,
    required this.onSolve,
    this.solving = false,
  });

  final Widget puzzle;
  final FillViewPlan plan;
  final _PuzzleCamera camera;
  final String hint;
  final Widget palette;
  final VoidCallback? onSolve;
  final bool solving;

  @override
  State<_InputLayout> createState() => _InputLayoutState();
}

class _InputLayoutState extends State<_InputLayout>
    with SingleTickerProviderStateMixin {
  static const double _stepButtonSize = 40;
  static const double _stepButtonEdge = 2;

  late final AnimationController _anim = AnimationController(vsync: this)
    ..addListener(_onTick);

  /// The view the user is on (or heading to, while the camera is turning).
  late int _index;
  double _fromX = 0, _fromY = 0, _toX = 0, _toY = 0;

  FillViewPlan get _plan => widget.plan;

  @override
  void initState() {
    super.initState();
    // The controller outlives this widget (puzzle switch, tab switch): carry
    // on from the view its camera is actually at.
    final (x, y) = widget.camera.read();
    _index = _plan.nearestIndex(x, y);
    if (!_plan.isOnStop(x, y)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _anim.isAnimating) return;
        final stop = _plan.stops[_index];
        widget.camera.write(stop.rotationX, stop.rotationY);
      });
    }
  }

  @override
  void dispose() {
    // Left in the middle of a turn (e.g. the puzzle type was switched): land
    // on the view it was heading to, so the next visit starts on a real view.
    if (_anim.isAnimating) widget.camera.write(_toX, _toY);
    _anim.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    final target = index.clamp(0, _plan.lastIndex);
    if (target == _index) return;
    final (x, y) = widget.camera.read();
    final stop = _plan.stops[target];
    _fromX = x;
    _fromY = y;
    _toX = stop.rotationX;
    _toY = _plan.yawToward(target, y);
    setState(() => _index = target);

    if (MediaQuery.disableAnimationsOf(context)) {
      _anim.stop();
      widget.camera.write(_toX, _toY);
      return;
    }
    // A quarter turn takes ~0.4 s; the flip under the puzzle takes longer.
    final turn = _plan.travel(target, x, y);
    _anim.duration = Duration(
      milliseconds: (260 + 280 * turn / (math.pi / 2)).clamp(320, 760).round(),
    );
    _anim.forward(from: 0);
  }

  void _onTick() {
    final t = Curves.easeInOutCubic.transform(_anim.value);
    widget.camera.write(
      _fromX + (_toX - _fromX) * t,
      _fromY + (_toY - _fromY) * t,
    );
  }

  /// Where the ◀ ▶ buttons sit: centred beside the puzzle, but never on top
  /// of the 「正面」/「背面」 shortcuts (which matters on short screens).
  ({double top, double rightInset}) _stepButtonSpot(
      Size area, TextScaler textScaler) {
    final label = textScaler.scale(11);
    final shortcutsBottom = 8 + 2 * (32 + label * 1.4) + 8;
    final shortcutsWidth = 8 + 20 + math.max(20, label * 2);
    final centred = (area.height - _stepButtonSize) / 2;
    if (centred >= shortcutsBottom + 4) {
      return (top: centred, rightInset: _stepButtonEdge);
    }
    if (shortcutsBottom + 4 + _stepButtonSize <= area.height) {
      return (top: shortcutsBottom + 4, rightInset: _stepButtonEdge);
    }
    // No room below the shortcuts: sit beside them, over the empty margin.
    return (
      top: math.max(0, centred),
      rightInset: shortcutsWidth + 4,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final spot = _stepButtonSpot(box.biggest, textScaler);
              return Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                        padding: const EdgeInsets.all(8), child: widget.puzzle),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Column(
                      children: [
                        _ViewButton(
                          label: '正面',
                          icon: Icons.flip_to_front,
                          onTap: () => _goTo(_plan.frontIndex),
                        ),
                        const SizedBox(height: 8),
                        _ViewButton(
                          label: '背面',
                          icon: Icons.flip_to_back,
                          onTap: () => _goTo(_plan.backIndex),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: _stepButtonEdge,
                    top: spot.top,
                    child: _StepButton(
                      icon: Icons.chevron_left,
                      tooltip: '上一个视角',
                      size: _stepButtonSize,
                      onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                    ),
                  ),
                  Positioned(
                    right: spot.rightInset,
                    top: spot.top,
                    child: _StepButton(
                      icon: Icons.chevron_right,
                      tooltip: '下一个视角',
                      size: _stepButtonSize,
                      onPressed: _index < _plan.lastIndex
                          ? () => _goTo(_index + 1)
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            widget.hint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        const SizedBox(height: 12),
        widget.palette,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: widget.solving ? null : widget.onSolve,
              icon: widget.solving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high),
              label: Text(widget.solving ? '求解中…' : '开始求解'),
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
        '点击两侧箭头切换视角，再次点击同色块可擦除（$filled/$total）';

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
      key: const ValueKey('fill-cube3'),
      puzzle: StickerPaintCube(
        controller: cube,
        onFaceletTap: (i) {
          if (inputNotifier.paint(i)) HapticFeedback.selectionClick();
        },
      ),
      plan: FillViewPlan.cube3,
      camera: _PuzzleCamera(
        read: () => (cube.viewRotationX, cube.viewRotationY),
        write: (x, y) => cube.setView(rotationX: x, rotationY: y),
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
      key: ValueKey('fill-cube$n'),
      puzzle: NxnCubeView(
        key: ValueKey('input$n'),
        controller: cube,
        dragEnabled: false,
        onStickerTap: (hit) {
          if (notifier.paint(hit)) HapticFeedback.selectionClick();
        },
      ),
      plan: FillViewPlan.nxn,
      camera: _PuzzleCamera(
        read: () => (cube.rotationX, cube.rotationY),
        write: (x, y) => cube.setView(rotationX: x, rotationY: y),
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
      key: const ValueKey('fill-pyraminx'),
      puzzle: PyraminxView(
        controller: puzzle,
        dragEnabled: false,
        onSlotTap: (slot) {
          if (notifier.paint(slot)) HapticFeedback.selectionClick();
        },
      ),
      plan: FillViewPlan.pyraminx,
      camera: _PuzzleCamera(
        read: () => (puzzle.rotationX, puzzle.rotationY),
        write: (x, y) => puzzle.setView(rotationX: x, rotationY: y),
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

/// Semi-transparent round ◀ / ▶ button floating beside the puzzle. Disabled
/// (faded, inert) at the first / last view.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final double size;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      style: IconButton.styleFrom(
        fixedSize: Size.square(size),
        minimumSize: Size.square(size),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        foregroundColor: Colors.white.withValues(alpha: 0.85),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.04),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.22),
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

