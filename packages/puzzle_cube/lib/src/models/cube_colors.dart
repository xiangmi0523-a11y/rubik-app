import 'package:flutter/material.dart';

/// The six sticker colours of a standard cube, plus helpers for snapping,
/// naming and validating colours.
///
/// The default scheme is the western (BOY) layout: green opposite blue,
/// white opposite yellow and red opposite orange.
abstract final class CubeColors {
  /// The +x face colour.
  static const Color green = Colors.green;

  /// The -x face colour.
  static const Color blue = Colors.blue;

  /// The +y face colour.
  static const Color white = Colors.white;

  /// The -y face colour.
  static const Color yellow = Colors.yellow;

  /// The +z face colour.
  static const Color red = Colors.red;

  /// The -z face colour.
  static const Color orange = Colors.orange;

  /// All six valid cube colours.
  static const List<Color> palette = [white, yellow, red, orange, green, blue];

  /// Neutral grey used for stickers that haven't been coloured yet
  /// (the "colour my cube" flow starts every non-centre sticker like this).
  static const Color colorless = Color(0xFF4D4D55);

  /// Snaps an arbitrary (e.g. camera-sampled) colour to the closest cube
  /// colour. Uses HSV so red/orange/yellow and white separate reliably under
  /// uneven lighting; callers can still correct any wrong sticker by hand.
  static Color nearest(Color input) {
    final hsv = HSVColor.fromColor(input);
    final hue = hsv.hue;

    // Whites read as low-saturation, bright pixels regardless of hue.
    if (hsv.saturation < 0.25 && hsv.value > 0.45) return white;

    if (hue >= 45 && hue < 70) return yellow;
    if (hue >= 70 && hue < 170) return green;
    if (hue >= 170 && hue < 265) return blue;
    if (hue >= 20 && hue < 45) return orange;
    // 0..20 and the magenta wrap-around (>=265) fall back to red.
    return red;
  }

  /// Whether [color] is one of the six valid cube colours.
  static bool isAllowed(Color color) {
    final argb = color.toARGB32();
    return palette.any((c) => c.toARGB32() == argb);
  }

  /// The English name of [color], or `'Unknown'` if it isn't a cube colour.
  static String nameOf(Color color) {
    final argb = color.toARGB32();

    if (argb == green.toARGB32()) return 'Green';
    if (argb == blue.toARGB32()) return 'Blue';
    if (argb == white.toARGB32()) return 'White';
    if (argb == yellow.toARGB32()) return 'Yellow';
    if (argb == red.toARGB32()) return 'Red';
    if (argb == orange.toARGB32()) return 'Orange';
    return 'Unknown';
  }

  /// Whether [a] and [b] sit on opposite faces of a solved cube
  /// (green/blue, white/yellow or red/orange).
  static bool areOpposites(Color a, Color b) {
    final av = a.toARGB32();
    final bv = b.toARGB32();

    return (av == green.toARGB32() && bv == blue.toARGB32() ||
        av == blue.toARGB32() && bv == green.toARGB32() ||
        av == white.toARGB32() && bv == yellow.toARGB32() ||
        av == yellow.toARGB32() && bv == white.toARGB32() ||
        av == red.toARGB32() && bv == orange.toARGB32() ||
        av == orange.toARGB32() && bv == red.toARGB32());
  }
}
