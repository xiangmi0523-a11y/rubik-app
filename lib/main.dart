import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/prefs/shared_prefs_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Phones stay upright: the pages are laid out for portrait, and in
  // landscape there is no room left for the puzzle. Tablets rotate freely.
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  if (view.physicalSize.shortestSide / view.devicePixelRatio < 600) {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const RubikApp(),
    ),
  );
}
