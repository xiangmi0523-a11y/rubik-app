import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/shared_prefs_provider.dart';

/// Whether the "how to hold the cube" guide has been shown once.
class HoldGuideController extends Notifier<bool> {
  static const _key = 'hold_guide_seen_v1';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  void markSeen() {
    state = true;
    ref.read(sharedPreferencesProvider).setBool(_key, true);
  }
}

final holdGuideSeenProvider =
    NotifierProvider<HoldGuideController, bool>(HoldGuideController.new);
