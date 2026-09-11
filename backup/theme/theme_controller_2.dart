import 'package:flutter/material.dart';

/// App-wide theme mode controller. No state-management package yet, so this
/// is a plain ValueNotifier the app listens to at the root.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController(super.value);

  bool get isDark => value == ThemeMode.dark;

  void toggle() {
    value = isDark ? ThemeMode.light : ThemeMode.dark;
  }

  void set(ThemeMode mode) => value = mode;
}

/// Single shared instance for the whole app.
final themeController = ThemeController(ThemeMode.dark);
