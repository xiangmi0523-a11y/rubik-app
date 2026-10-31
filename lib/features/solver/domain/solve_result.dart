import 'package:flutter/material.dart';

/// Colours entered by the user (54, cuber facelet order) and the solution
/// as cuber notation (e.g. ["R", "U2", "F'"]).
class SolveResult {
  const SolveResult({required this.colors, required this.moves});

  final List<Color> colors;
  final List<String> moves;
}
