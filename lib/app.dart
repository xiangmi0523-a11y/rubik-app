import 'package:flutter/material.dart';

import 'features/home/presentation/home_shell.dart';

class RubikApp extends StatelessWidget {
  const RubikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '魔方',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
        // Pages draw the shared gradient (AppBackground); bars let it show.
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
        ),
      ),
      home: const HomeShell(),
    );
  }
}
