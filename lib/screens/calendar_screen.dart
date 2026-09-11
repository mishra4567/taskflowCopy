// calender_screen
import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

class _AgendaItem {
  const _AgendaItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color Function(AppPalette) color;
}

/// Sample due dates keyed by day-of-month, relative to the current month.
/// Swap for real task/roadmap due-date queries once the data layer exists.
Map<int, List<_AgendaItem>> _sampleEvents(DateTime month, DateTime today) {
  if (month.year != today.year || month.month != today.month) return {};
  return {
    today.day: [
      _AgendaItem(
        title: 'Finalize Q3 Strategy Deck',
        subtitle: 'Task due today',
        icon: Icons.check_circle_outline,
        color: (c) => c.primary,
      ),
    ],
    today.day + 2: [
      _AgendaItem(
        title: 'Product V2 milestone',
        subtitle: 'Roadmap · 45% complete',
        icon: Icons.map_outlined,
        color: (c) => c.tertiary,
      ),
    ],
    today.day - 3: [
      _AgendaItem(
        title: 'Review Design System tokens',
        subtitle: 'Completed',
        icon: Icons.check_circle,
        color: (c) => c.tertiary,
      ),
    ],
  };
}

/// Calendar tab — monthly grid with due-date markers, plus an agenda list
/// for whichever day is selected.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  final DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(_today.year, _today.month);
    _selectedDate = DateTime(_today.year, _today.month, _today.day);
  }

  void _changeMonth(int delta) {
    setState(
      () => _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
      ),
    );
  }

  static const _monthNames = [
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
  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final events = _sampleEvents(_visibleMonth, _today);
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadingBlanks = (firstOfMonth.weekday - DateTime.monday) % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    final selectedEvents =
        _visibleMonth.year == _selectedDate.year &&
            _visibleMonth.month == _selectedDate.month
        ? (events[_selectedDate.day] ?? const <_AgendaItem>[])
        : const <_AgendaItem>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerMargin,
        AppSpacing.md,
        AppSpacing.containerMargin,
        140,
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
              style: AppTypography.headlineMd.copyWith(
                color: colors.textPrimary,
                fontSize: 20,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left,
                    color: colors.onSurfaceVariant,
                  ),
                  onPressed: () => _changeMonth(-1),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: colors.onSurfaceVariant,
                  ),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: AppTypography.labelCaps.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var row = 0; row < rowCount; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++) ...[
                  Expanded(
                    child: _buildCell(
                      context,
                      row * 7 + col,
                      leadingBlanks,
                      daysInMonth,
                      events,
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          _selectedDate.year == _today.year &&
                  _selectedDate.month == _today.month &&
                  _selectedDate.day == _today.day
              ? 'TODAY'
              : '${_monthNames[_selectedDate.month - 1].toUpperCase()} ${_selectedDate.day}',
          style: AppTypography.labelCaps.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (selectedEvents.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Nothing scheduled',
                style: AppTypography.bodySm.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          )
        else
          for (final event in selectedEvents) ...[
            _AgendaCard(item: event),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  Widget _buildCell(
    BuildContext context,
    int cellIndex,
    int leadingBlanks,
    int daysInMonth,
    Map<int, List<_AgendaItem>> events,
  ) {
    final colors = context.colors;
    final dayNumber = cellIndex - leadingBlanks + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 44);
    }

    final date = DateTime(_visibleMonth.year, _visibleMonth.month, dayNumber);
    final isToday =
        date.year == _today.year &&
        date.month == _today.month &&
        date.day == _today.day;
    final isSelected =
        date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day;
    final hasEvent = events.containsKey(dayNumber);

    return GestureDetector(
      onTap: () => setState(() => _selectedDate = date),
      child: SizedBox(
        height: 44,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? colors.primaryContainer
                  : isToday
                  ? colors.surfaceContainerHigh
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: AppTypography.bodySm.copyWith(
                    color: isSelected ? colors.onPrimary : colors.textPrimary,
                    fontWeight: isToday || isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                if (hasEvent && !isSelected)
                  Positioned(
                    bottom: 3,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.tertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.item});
  final _AgendaItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
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
              child: Icon(item.icon, size: 20, color: item.color(colors)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.bodyMd.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: AppTypography.bodySm.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
