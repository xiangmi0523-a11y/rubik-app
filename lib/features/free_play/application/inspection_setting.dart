import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/shared_prefs_provider.dart';
import '../../stats/domain/solve_record.dart';

/// WCA inspection: 15 s; starting after 15 s is +2, after 17 s DNF.
const inspectionSeconds = 15;

Penalty inspectionPenalty(Duration elapsed) {
  if (elapsed <= const Duration(seconds: inspectionSeconds)) return Penalty.none;
  if (elapsed <= const Duration(seconds: inspectionSeconds + 2)) {
    return Penalty.plus2;
  }
  return Penalty.dnf;
}

/// Whether scrambling starts a 15-second inspection (persisted, default on).
class InspectionSetting extends Notifier<bool> {
  static const _key = 'inspection_enabled_v1';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  void toggle() {
    state = !state;
    ref.read(sharedPreferencesProvider).setBool(_key, state);
  }
}

final inspectionEnabledProvider =
    NotifierProvider<InspectionSetting, bool>(InspectionSetting.new);
