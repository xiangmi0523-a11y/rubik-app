import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/prefs/shared_prefs_provider.dart';
import '../domain/solve_record.dart';

class StatsRepository {
  StatsRepository(this._prefs);

  static const _key = 'solve_records_v1';
  final SharedPreferences _prefs;

  List<SolveRecord> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => SolveRecord.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<SolveRecord> records) =>
      _prefs.setString(_key, jsonEncode(records.map((r) => r.toJson()).toList()));
}

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(ref.watch(sharedPreferencesProvider)),
);
