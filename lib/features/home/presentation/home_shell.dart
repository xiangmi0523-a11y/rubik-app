import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../free_play/presentation/free_play_page.dart';
import '../../solver/presentation/color_input_page.dart';
import '../../stats/presentation/stats_page.dart';
import '../application/home_tab_controller.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(homeTabProvider);
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [FreePlayPage(), ColorInputPage(), StatsPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: ref.read(homeTabProvider.notifier).select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.view_in_ar), label: '自由玩'),
          NavigationDestination(icon: Icon(Icons.palette), label: '填色求解'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '成绩'),
        ],
      ),
    );
  }
}
