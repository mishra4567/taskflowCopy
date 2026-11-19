// services/expense_refresh_bus
import 'package:flutter/foundation.dart';

// Fires whenever an expense is saved, edited or deleted from somewhere
// that isn't the Spending screen (a shared screenshot, say), so an open
// Spending screen reloads. Same idea as TodoRefreshBus.
class ExpenseRefreshBus {
  ExpenseRefreshBus._();
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);
  static void notify() => tick.value++;
}
