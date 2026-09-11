import 'package:flutter/material.dart';

/// App-wide theme mode controller. No state-management package yet, so this
/// is a plain ValueNotifier the app listens to at the root.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController(super.value);

  void set(ThemeMode mode) => value = mode;

  static String label(ThemeMode mode) => switch (mode) {
    ThemeMode.dark => 'Dark (OLED)',
    ThemeMode.light => 'Light',
    ThemeMode.system => 'System',
  };
}

/// Single shared instance for the whole app.
final themeController = ThemeController(ThemeMode.dark);
