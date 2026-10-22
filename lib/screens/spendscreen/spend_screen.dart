/// screens/spendscreen/spend_screen.dart
///
/// Expenses: what you've spent and received, by month and by day, backed
/// by AppDatabase's own `expenses` table. Entries get in three ways:
/// - typed by hand ("+" in the AppBar, or the quick-add card),
/// - from a screenshot picked with the scan icon, and
/// - from a receipt shared into the app from GPay / PhonePe / etc.
/// Screenshots go through receipt_import_flow.dart, which reads them and
/// either saves the payment (when sure) or opens the confirm sheet.
/// The list is a live Drift stream — saving from anywhere updates it.
///
/// "Spent" totals count only money that went out (direction 'paid');
/// money received is shown separately and never reduces what was spent.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../services/spend/money.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/quick_add/quick_add_sheet.dart'
    show QuickAddAction, QuickAddRegistry;
import 'expense_sheet.dart';
import 'receipt_import_flow.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

IconData _categoryIcon(String category) => switch (category) {
  'Food' => Icons.restaurant_outlined,
  'Groceries' => Icons.shopping_basket_outlined,
  'Transport' => Icons.directions_bus_outlined,
  'Shopping' => Icons.shopping_bag_outlined,
  'Bills' => Icons.receipt_long_outlined,
  'Health' => Icons.medical_services_outlined,
  'Entertainment' => Icons.movie_outlined,
  'Travel' => Icons.flight_outlined,
  'Salary' => Icons.account_balance_wallet_outlined,
  'Refund' => Icons.replay_outlined,
  'Gift' => Icons.card_giftcard_outlined,
  'Cashback' => Icons.savings_outlined,
  _ => Icons.payments_outlined,
};

/// Green used for money that came in.
const _receivedColor = Color(0xFF3DA66B);

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  // Created once. A StreamBuilder handed a brand-new stream on every
  // build would resubscribe (and flash a spinner) each time.
  late final Stream<List<Expense>> _expenses = AppDatabase.instance
      .watchExpenses();

  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _scanning = false;

  bool get _canGoNext {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + 1);
    return !next.isAfter(DateTime(now.year, now.month));
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  /// Pick a payment screenshot and hand it to the import flow, which reads
  /// it and either saves it (when sure) or opens the confirm sheet.
  Future<void> _scan() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    final path = file?.path;
    if (path == null || !mounted) return;

    setState(() => _scanning = true);
    try {
      // A picked file may be the person's original: never delete it.
      await importPaymentImage(context, path, deleteWhenDone: false);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _openExpense(Expense expense) {
    showExpenseSheet(
      context,
      existing: expense,
      onDelete: () => AppDatabase.instance.deleteExpense(expense.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            tooltip: 'Scan a payment screenshot',
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.document_scanner_outlined,
                    color: colors.primaryContainer,
                  ),
          ),
          IconButton(
            tooltip: 'Add expense',
            onPressed: () => showExpenseSheet(context),
            icon: Icon(
              Icons.add_circle_outline,
              color: colors.primaryContainer,
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Expense>>(
        stream: _expenses,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.containerMargin),
                child: Text(
                  "Couldn't load expenses.\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(color: colors.error),
                ),
              ),
            );
          }
          final all = snapshot.data;
          if (all == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildBody(context, all);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Expense> all) {
    final colors = context.colors;
    final now = DateTime.now();
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    bool isPaid(Expense e) => e.direction != directionReceived;

    final inMonth = all
        .where(
          (e) => e.paidAt.year == _month.year && e.paidAt.month == _month.month,
        )
        .toList();
    final monthSpent = inMonth
        .where(isPaid)
        .fold<int>(0, (sum, e) => sum + e.amountPaise);
    final monthReceived = inMonth
        .where((e) => !isPaid(e))
        .fold<int>(0, (sum, e) => sum + e.amountPaise);
    final todaySpent = all
        .where((e) => isPaid(e) && sameDay(e.paidAt, now))
        .fold<int>(0, (sum, e) => sum + e.amountPaise);

    // Category breakdown is for money that went out.
    final byCategory = <String, int>{};
    for (final e in inMonth.where(isPaid)) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amountPaise;
    }
    final topCategories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Already newest-first, so the days come out newest-first too (a
    // Dart map keeps insertion order).
    final days = <DateTime, List<Expense>>{};
    for (final e in inMonth) {
      final day = DateTime(e.paidAt.year, e.paidAt.month, e.paidAt.day);
      (days[day] ??= []).add(e);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerMargin,
        AppSpacing.md,
        AppSpacing.containerMargin,
        140,
      ),
      children: [
        _MonthSwitcher(
          label: '${_monthNames[_month.month - 1]} ${_month.year}',
          onPrevious: () => _changeMonth(-1),
          onNext: _canGoNext ? () => _changeMonth(1) : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        _SummaryCard(
          monthSpent: monthSpent,
          monthReceived: monthReceived,
          count: inMonth.length,
          todaySpent: todaySpent,
          categories: topCategories.take(5).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (inMonth.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                all.isEmpty
                    ? 'No expenses yet — tap + to add one, or scan a '
                          'GPay / PhonePe screenshot.'
                    : 'No expenses in this month.',
                style: AppTypography.bodySm.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          )
        else
          for (final entry in days.entries) ...[
            _DayHeader(
              label: _dayLabel(entry.key, now),
              spent: entry.value
                  .where(isPaid)
                  .fold<int>(0, (sum, e) => sum + e.amountPaise),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final expense in entry.value) ...[
              _ExpenseTile(
                expense: expense,
                onTap: () => _openExpense(expense),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  static String _dayLabel(DateTime day, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    return '${day.day} ${_monthNames[day.month - 1].substring(0, 3)} ${day.year}'
        .toUpperCase();
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;

  /// Null when already on the current month (no future months).
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.headlineMd.copyWith(
            color: colors.textPrimary,
            fontSize: 20,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: colors.onSurfaceVariant),
              onPressed: onPrevious,
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: onNext == null
                    ? colors.outline
                    : colors.onSurfaceVariant,
              ),
              onPressed: onNext,
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.monthSpent,
    required this.monthReceived,
    required this.count,
    required this.todaySpent,
    required this.categories,
  });

  final int monthSpent;
  final int monthReceived;
  final int count;
  final int todaySpent;
  final List<MapEntry<String, int>> categories;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SPENT THIS MONTH',
              style: AppTypography.labelCaps.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatRupees(monthSpent),
              style: AppTypography.headlineMd.copyWith(
                color: colors.textPrimary,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count ${count == 1 ? 'entry' : 'entries'}'
              ' · Today ${formatRupees(todaySpent)}',
              style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
            ),
            if (monthReceived > 0) ...[
              const SizedBox(height: 2),
              Text(
                'Received ${formatRupees(monthReceived)}',
                style: AppTypography.bodySm.copyWith(
                  color: _receivedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (categories.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              for (final entry in categories) ...[
                Row(
                  children: [
                    Icon(
                      _categoryIcon(entry.key),
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: AppTypography.bodySm.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      formatRupees(entry.value),
                      style: AppTypography.bodySm.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: monthSpent == 0 ? 0 : entry.value / monthSpent,
                    minHeight: 4,
                    backgroundColor: colors.surfaceContainerHigh,
                    color: colors.primaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.spent});

  final String label;

  /// What went out that day; nothing is shown for a day with only
  /// received money.
  final int spent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.labelCaps.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        if (spent > 0)
          Text(
            formatRupees(spent),
            style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
          ),
      ],
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.onTap});

  final Expense expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final received = expense.direction == directionReceived;
    final paidAt = expense.paidAt;
    // Time isn't shown for a date-only payment (saved as midnight).
    final time = paidAt.hour == 0 && paidAt.minute == 0
        ? null
        : TimeOfDay.fromDateTime(paidAt).format(context);
    final payee = expense.payee.trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.standard),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.standard),
                ),
                child: Icon(
                  _categoryIcon(expense.category),
                  size: 20,
                  color: received ? _receivedColor : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payee.isEmpty ? expense.category : payee,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (received) 'Received',
                        expense.category,
                        expense.method,
                        ?time,
                      ].join(' · '),
                      style: AppTypography.bodySm.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${received ? '+' : ''}${formatRupees(expense.amountPaise)}',
                style: AppTypography.bodyMd.copyWith(
                  color: received ? _receivedColor : colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Registers "Add Expense" as a quick-add card. Call once, from
/// MainShell's initState.
void registerQuickAddExpense() {
  QuickAddRegistry.register(
    QuickAddAction(
      icon: Icons.payments_outlined,
      title: 'Add Expense',
      subtitle: 'Log a payment',
      onTap: (context) {
        Navigator.of(context).pop();
        showExpenseSheet(context);
      },
    ),
  );
}
