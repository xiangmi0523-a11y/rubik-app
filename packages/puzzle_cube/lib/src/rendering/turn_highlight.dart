/// Brightness of each piece while turns play: the pieces of the turning
/// layer(s) stay bright, the rest of the puzzle is dimmed, and everything
/// returns to normal once nothing turns any more.
///
/// Pieces are named by any key with value equality (a cubie position, a
/// sticker slot, ...). A layer maps onto itself when it turns, so keys taken
/// before a turn still name that layer afterwards.
///
/// The view calls [begin] when a turn starts animating (with the keys of the
/// pieces that turn — the same test the painter uses to rotate them), [end]
/// when it finishes, [reset] when the puzzle state is replaced, and [tick]
/// every frame while [idle] is false. All changes are smooth:
///
/// * the dimming fades in over [fadeFraction] of the turn;
/// * after a turn ends, the dimming is held for [holdFraction] of a turn, so
///   back-to-back turns (continuous playback) don't flash bright in between;
///   the highlight then cross-fades from the old layer to the new one;
/// * if no turn follows, everything fades back to full brightness.
///
/// A piece that becomes part of the turn only ever gets brighter, and a piece
/// that leaves it only ever gets darker, so nothing flickers.
class TurnHighlight {
  /// Creates a highlight. [dim] is the brightness of the pieces that don't
  /// turn, once fully dimmed (1 = no dimming).
  TurnHighlight({
    this.dim = 0.35,
    this.fadeFraction = 0.25,
    this.holdFraction = 0.7,
  }) : assert(dim > 0 && dim <= 1);

  /// Brightness (0..1] of non-turning pieces at full dimming.
  final double dim;

  /// Fade time as a fraction of the turn's duration.
  final double fadeFraction;

  /// How long (fraction of a turn) the dimming outlasts a finished turn.
  final double holdFraction;

  /// How strongly non-turning pieces are dimmed, 0..1.
  double _dimming = 0;
  double _dimTarget = 0;

  /// Per piece: how much it is lifted out of the dimming, 0..1.
  final Map<Object, double> _lift = {};
  Set<Object> _active = const {};

  bool _turning = false;
  double? _holdLeft;
  double _fade = 0.1;
  double _hold = 0.2;

  /// Nothing is dimmed and nothing is going to change until the next [begin].
  bool get idle =>
      !_turning && _holdLeft == null && _dimming == 0 && _dimTarget == 0;

  /// Whether a turn is animating (between [begin] and [end]).
  bool get turning => _turning;

  /// The pieces of the current (or, during the hold, the last) turn.
  Set<Object> get active => _active;

  /// Current dimming of the non-turning pieces, 0..1.
  double get dimming => _dimming;

  /// Brightness of piece [key], in [dim, 1].
  double brightnessOf(Object key) =>
      1 - (1 - dim) * _dimming * (1 - (_lift[key] ?? 0));

  /// A turn of the pieces [turning] starts; it animates for [duration].
  void begin(Iterable<Object> turning, Duration duration) {
    final seconds = duration.inMicroseconds / 1e6;
    _fade = (seconds * fadeFraction).clamp(0.016, 1.0);
    _hold = seconds * holdFraction;
    _active = turning.toSet();
    for (final key in _active) {
      // Start at least as bright as the piece is now, then only brighten.
      final now = _lift[key] ?? 0;
      _lift[key] = now > 1 - _dimming ? now : 1 - _dimming;
    }
    _turning = true;
    _holdLeft = null;
    _dimTarget = 1;
  }

  /// The current turn finished: keep the dimming briefly, then fade out.
  void end() {
    if (!_turning) return;
    _turning = false;
    _holdLeft = _hold;
  }

  /// Back to full brightness at once (the puzzle state was replaced).
  void reset() {
    _dimming = 0;
    _dimTarget = 0;
    _lift.clear();
    _active = const {};
    _turning = false;
    _holdLeft = null;
  }

  /// Advances by [elapsed]. Returns whether anything is still changing.
  bool tick(Duration elapsed) {
    var dt = elapsed.inMicroseconds / 1e6;
    if (dt < 0) dt = 0;
    final hold = _holdLeft;
    if (hold != null) {
      final left = hold - dt;
      if (left <= 0) {
        _holdLeft = null;
        _dimTarget = 0;
      } else {
        _holdLeft = left;
      }
    }
    final step = dt / _fade;
    _dimming = _approach(_dimming, _dimTarget, step);
    for (final key in [..._lift.keys]) {
      final v = _approach(_lift[key]!, _active.contains(key) ? 1 : 0, step);
      if (v == 0) {
        _lift.remove(key);
      } else {
        _lift[key] = v;
      }
    }
    if (!_turning && _holdLeft == null && _dimming == 0) {
      _lift.clear();
      _active = const {};
    }
    return !idle;
  }

  static double _approach(double v, double target, double step) {
    if (v < target) return v + step >= target ? target : v + step;
    if (v > target) return v - step <= target ? target : v - step;
    return v;
  }
}
