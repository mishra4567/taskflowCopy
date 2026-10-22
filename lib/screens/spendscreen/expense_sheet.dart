// screens/spendscreen/expense_sheet.dart
//
// The ONE add / edit / confirm sheet for a payment. Used by the Spending
// screen (+ button, tapping a row), by the receipt import flow (shared or
// scanned screenshots) and by the quick-add card.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:taskflow/data/app_database.dart';
import 'package:taskflow/services/spend/money.dart';
import 'package:taskflow/services/spend/payment_text_parser.dart';
import 'package:taskflow/theme/app_palette.dart';
import 'package:taskflow/theme/app_tokens.dart';
import 'package:taskflow/theme/app_typography.dart';

/// Stored in Expenses.direction.
const directionPaid = 'paid';
const directionReceived = 'received';

/// Categories offered for money that went out / came in. A category an
/// older row already has (even one that isn't listed) is still shown.
const expenseCategories = [
  'Food',
  'Groceries',
  'Transport',
  'Shopping',
  'Bills',
  'Health',
  'Entertainment',
  'Travel',
  'Other',
];

const receivedCategories = ['Salary', 'Refund', 'Gift', 'Cashback', 'Other'];

const expenseMethods = [
  'GPay',
  'PhonePe',
  'Paytm',
  'BHIM',
  'Cash',
  'Card',
  'Other',
];

const _defaultCategory = 'Other';
const _defaultMethod = 'Other';

/// Opens the add / edit / confirm sheet.
///
/// * Add by hand: call with nothing but the context. [direction] picks
///   whether it starts on Paid or Received — it can always be switched
///   inside the sheet, and Paid is the default.
/// * Edit: pass [existing] (and [onDelete] for the Delete button).
/// * Screenshot: pass [prefill] from PaymentTextParser (its direction is
///   used) and `source: 'screenshot'`; [scanText] adds a "Show scanned
///   text" button. The sheet is the confirm screen, so the person fixes
///   whatever the scan got wrong before anything is saved.
///
/// [onSaved] is optional: the Spending list is a live Drift stream and
/// refreshes by itself.
Future<void> showExpenseSheet(
  BuildContext context, {
  Expense? existing,
  ParsedPayment? prefill,
  String source = 'manual',
  String direction = directionPaid,
  String? scanText,
  VoidCallback? onSaved,
  VoidCallback? onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ExpenseSheet(
      existing: existing,
      prefill: prefill,
      source: source,
      direction: direction,
      scanText: scanText,
      onSaved: onSaved,
      onDelete: onDelete,
    ),
  );
}

class _ExpenseSheet extends StatefulWidget {
  const _ExpenseSheet({
    this.existing,
    this.prefill,
    required this.source,
    required this.direction,
    this.scanText,
    this.onSaved,
    this.onDelete,
  });

  final Expense? existing;
  final ParsedPayment? prefill;
  final String source;
  final String direction;
  final String? scanText;
  final VoidCallback? onSaved;
  final VoidCallback? onDelete;

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _payee;
  late final TextEditingController _note;
  late String _direction;
  late String _category;
  late String _method;
  late DateTime _paidAt;
  String? _upiRef;

  String? _amountError;
  String? _payeeError;
  String? _dateError;
  String? _formError;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;
  bool get _received => _direction == directionReceived;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final prefill = widget.prefill;
    if (existing != null) {
      _amount = TextEditingController(text: paiseToInput(existing.amountPaise));
      _payee = TextEditingController(text: existing.payee);
      _note = TextEditingController(text: existing.note);
      _direction = existing.direction;
      _category = existing.category;
      _method = existing.method;
      _paidAt = existing.paidAt;
      _upiRef = existing.upiRef;
    } else {
      final paise = prefill?.amountPaise;
      _amount = TextEditingController(
        text: paise == null ? '' : paiseToInput(paise),
      );
      _payee = TextEditingController(text: prefill?.payee ?? '');
      _note = TextEditingController();
      _direction = prefill != null ? prefill.direction : widget.direction;
      _category = _defaultCategory;
      _method = prefill?.method ?? _defaultMethod;
      _paidAt = prefill?.paidAt ?? DateTime.now();
      _upiRef = prefill?.upiRef;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _payee.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final now = DateTime.now();
    final first = DateTime(now.year - 5);
    final last = dateOnly(now);
    // A scanned date can be misread into the future or far past, and
    // showDatePicker asserts if initialDate falls outside first..last —
    // clamp it instead of crashing.
    var initial = dateOnly(_paidAt);
    if (initial.isAfter(last)) initial = last;
    if (initial.isBefore(first)) initial = first;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _paidAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _paidAt.hour,
        _paidAt.minute,
      );
      _dateError = null;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_paidAt),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _paidAt = DateTime(
        _paidAt.year,
        _paidAt.month,
        _paidAt.day,
        picked.hour,
        picked.minute,
      );
      _dateError = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = parseRupeesToPaise(_amount.text);
    final payee = _payee.text.trim();

    String? amountError;
    String? payeeError;
    String? dateError;
    if (amount == null || amount <= 0) {
      amountError = 'Enter an amount, like 250 or 99.50';
    }
    if (payee.isEmpty) {
      payeeError = _received ? 'Who paid you?' : 'Who did you pay?';
    }
    if (_paidAt.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      dateError = 'That time is in the future';
    }
    if (amount == null ||
        amountError != null ||
        payeeError != null ||
        dateError != null) {
      setState(() {
        _amountError = amountError;
        _payeeError = payeeError;
        _dateError = dateError;
        _formError = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
    });

    final db = AppDatabase.instance;
    final existing = widget.existing;
    final ref = _upiRef;
    final note = _note.text.trim();

    try {
      // The same UPI reference on two rows means the same payment saved
      // twice (e.g. the same screenshot scanned again): ask first.
      if (ref != null) {
        final duplicate = await db.findExpenseByUpiRef(ref);
        if (!mounted) return;
        if (duplicate != null && duplicate.id != existing?.id) {
          final saveAgain = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Already saved'),
              content: Text(
                'A payment with the same UPI reference ($ref) is already in '
                'your list. Save it again?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Save again'),
                ),
              ],
            ),
          );
          if (saveAgain != true) {
            if (mounted) setState(() => _saving = false);
            return;
          }
        }
      }

      if (existing == null) {
        await db.insertExpense(
          ExpensesCompanion.insert(
            amountPaise: amount,
            paidAt: _paidAt,
            payee: Value(payee),
            category: Value(_category),
            note: Value(note),
            method: Value(_method),
            direction: Value(_direction),
            upiRef: Value(ref),
            source: Value(widget.source),
          ),
        );
      } else {
        // upiRef and source are left alone: they describe where the
        // payment came from, not something edited here.
        await db.updateExpense(
          existing.id,
          ExpensesCompanion(
            amountPaise: Value(amount),
            payee: Value(payee),
            paidAt: Value(_paidAt),
            category: Value(_category),
            note: Value(note),
            method: Value(_method),
            direction: Value(_direction),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = "Couldn't save this payment.";
      });
      return;
    }

    widget.onSaved?.call();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text("This can't be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: dialogContext.colors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.onDelete?.call();
    Navigator.of(context).pop();
  }

  void _showScanText() {
    final text = widget.scanText ?? '';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Scanned text'),
        content: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: text)),
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(
    AppPalette colors,
    String label,
    IconData icon, {
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      errorText: errorText,
      prefixIcon: Icon(icon, color: colors.onSurfaceVariant, size: 20),
      filled: true,
      fillColor: colors.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.standard),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final prefill = widget.prefill;
    final baseCategories = _received ? receivedCategories : expenseCategories;
    final categories = {...baseCategories, _category}.toList();
    final methods = {...expenseMethods, _method}.toList();
    final title = _isEditing
        ? (_received ? 'Edit received' : 'Edit payment')
        : (_received ? 'Money received' : 'New payment');

    return Padding(
      // Keeps the sheet above the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.container),
          ),
          border: Border.all(color: colors.borderSubtle),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.borderSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              Text(
                title,
                style: AppTypography.bodyLg.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (prefill != null && !_isEditing) ...[
                const SizedBox(height: 4),
                Text(
                  'Read from your screenshot — check it before saving.',
                  style: AppTypography.bodySm.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
              if (prefill != null && prefill.looksUnsuccessful) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: colors.error,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'This receipt mentions a failed or pending '
                        'payment. Make sure it went through before saving.',
                        style: AppTypography.bodySm.copyWith(
                          color: colors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),

              // Paid / Received. Paid is the default; the choice is only
              // here when the money actually came in.
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: directionPaid,
                      label: Text('Paid'),
                      icon: Icon(Icons.north_east, size: 16),
                    ),
                    ButtonSegment(
                      value: directionReceived,
                      label: Text('Received'),
                      icon: Icon(Icons.south_west, size: 16),
                    ),
                  ],
                  selected: {_direction},
                  onSelectionChanged: (selection) => setState(() {
                    _direction = selection.first;
                    _payeeError = null;
                  }),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AppTypography.bodyMd.copyWith(color: colors.textPrimary),
                decoration: _decoration(
                  colors,
                  'Amount',
                  Icons.currency_rupee,
                  errorText: _amountError,
                ),
                onChanged: (_) {
                  if (_amountError != null) setState(() => _amountError = null);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _payee,
                textCapitalization: TextCapitalization.words,
                style: AppTypography.bodyMd.copyWith(color: colors.textPrimary),
                decoration: _decoration(
                  colors,
                  _received ? 'Received from' : 'Paid to',
                  Icons.storefront_outlined,
                  errorText: _payeeError,
                ),
                onChanged: (_) {
                  if (_payeeError != null) setState(() => _payeeError = null);
                },
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                'CATEGORY',
                style: AppTypography.labelCaps.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final c in categories)
                    _ChoiceChip(
                      label: c,
                      selected: _category == c,
                      onTap: () => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                _received ? 'RECEIVED VIA' : 'PAID WITH',
                style: AppTypography.labelCaps.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final m in methods)
                    _ChoiceChip(
                      label: m,
                      selected: _method == m,
                      onTap: () => setState(() => _method = m),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: colors.onSurface,
                      ),
                      label: Text(
                        '${_paidAt.day}/${_paidAt.month}/${_paidAt.year}',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: Icon(
                        Icons.access_time_outlined,
                        size: 16,
                        color: colors.onSurface,
                      ),
                      label: Text(
                        TimeOfDay.fromDateTime(_paidAt).format(context),
                      ),
                    ),
                  ),
                ],
              ),
              if (_dateError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _dateError!,
                    style: AppTypography.bodySm.copyWith(color: colors.error),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _note,
                style: AppTypography.bodyMd.copyWith(color: colors.textPrimary),
                decoration: _decoration(
                  colors,
                  'Note (optional)',
                  Icons.notes_outlined,
                ),
              ),

              if (_upiRef != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'UPI ref $_upiRef',
                  style: AppTypography.bodySm.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
              if ((widget.scanText ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: TextButton.icon(
                    onPressed: _showScanText,
                    icon: const Icon(Icons.text_snippet_outlined, size: 16),
                    label: const Text('Show scanned text'),
                  ),
                ),
              if (_formError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _formError!,
                  style: AppTypography.bodySm.copyWith(color: colors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),

              Row(
                children: [
                  if (_isEditing && widget.onDelete != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _delete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.error,
                          side: BorderSide(
                            color: colors.error.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppRadius.standard,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                      ),
                      child: Text(
                        _isEditing ? 'Save changes' : 'Save',
                        style: AppTypography.bodyMd.copyWith(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selected / unselected chip treatment used across the app.
class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = colors.primaryContainer;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.2)
              : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? accent : colors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 14, color: accent),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTypography.bodySm.copyWith(
                color: selected ? accent : colors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
