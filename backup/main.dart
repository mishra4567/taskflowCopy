import 'package:flutter/material.dart';
import 'package:taskflow/theme/app_theme.dart';
import 'package:taskflow/widgets/main_shell.dart';

void main() {
  runApp(const TaskFlowApp());
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      // App theme is full black / OLED, fetched from system per the design
      // spec. themeMode is fixed to dark for now — wire to system brightness
      // once a light variant exists.
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const MainShell(),
    );
  }
}
