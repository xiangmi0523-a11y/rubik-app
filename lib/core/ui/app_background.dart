import 'package:flutter/material.dart';

/// The deep blue-teal gradient behind every page (the one the colouring page
/// always had), so all pages share one background.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  static const colors = [Color(0xFF26243F), Color(0xFF1C4450), Color(0xFF2B2A47)];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: child,
    );
  }
}
