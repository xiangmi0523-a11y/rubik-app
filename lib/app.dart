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
      ),
      home: const HomeShell(),
    );
  }
}
