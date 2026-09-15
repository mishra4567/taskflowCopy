import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple app-wide developer-mode flag, persisted across app restarts.
/// Anything that needs to react to it (like Home's extension cards)
/// can listen via `DevModeService.instance.enabled`.
class DevModeService {
  DevModeService._();
  static final DevModeService instance = DevModeService._();

  static const _prefsKey = 'dev_mode_enabled';

  final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  bool _loaded = false;

  /// Call once at app startup (e.g. in main() before runApp, or in your
  /// root widget's initState) so the flag is ready before Home builds.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_prefsKey) ?? false;
    _loaded = true;
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}
