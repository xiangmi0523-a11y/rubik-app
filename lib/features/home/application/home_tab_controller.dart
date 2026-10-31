import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom-navigation tabs.
abstract final class HomeTab {
  static const freePlay = 0;
  static const solver = 1;
  static const stats = 2;
}

class HomeTabNotifier extends Notifier<int> {
  @override
  int build() => HomeTab.freePlay;

  void select(int index) => state = index;
}

final homeTabProvider = NotifierProvider<HomeTabNotifier, int>(
  HomeTabNotifier.new,
);
