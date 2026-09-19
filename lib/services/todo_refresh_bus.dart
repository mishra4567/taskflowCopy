// services/todo_refresh_bus
import 'package:flutter/foundation.dart';

/// Tiny signal for "a todo changed somewhere else, please reload."
///
/// TodoScreen keeps its own in-memory `_tasks` list for snappy scrolling,
/// so a write that doesn't go through TodoScreen itself — e.g. the quick
/// add sheet, which persists directly to AppDatabase — has no way to tell
/// an already-open TodoScreen to refresh. Bumping [notify] here is that
/// signal; TodoScreen listens for it in initState and reloads from the
/// database when it fires.
class TodoRefreshBus {
  TodoRefreshBus._();

  /// The value itself is meaningless — only the fact that it changed
  /// matters, so listeners just re-fetch rather than reading this.
  static final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  static ValueNotifier<int> get tick => _tick;

  static void notify() => _tick.value++;
}
