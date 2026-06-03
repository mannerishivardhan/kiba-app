
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kiba_app/core/domain/threshold_provider.dart';
import 'package:kiba_app/core/models/attendance_threshold.dart';
import 'package:kiba_app/core/theme/app_theme.dart';
import 'package:kiba_app/features/field_advisor/data/day_record.dart';
import 'package:kiba_app/features/field_advisor/domain/attendance_calendar_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _green     = Color(0xFF059669);
const _greenDark = Color(0xFF065F46);
const _teal      = Color(0xFF0D9488);
const _amber     = Color(0xFFF59E0B); // info-tile icons only
const _yellow    = Color(0xFFEAB308); // late status
const _rose      = Color(0xFFDC2626);
const _blue      = Color(0xFF2563EB);
const _orange    = Color(0xFFF97316); // threshold violations
const _bg        = Color(0xFFF0F4F3);

// ── Root Screen ───────────────────────────────────────────────────────────────

class FaAttendanceScreen extends ConsumerStatefulWidget {
  const FaAttendanceScreen({super.key});

  @override
  ConsumerState<FaAttendanceScreen> createState() => _FaAttendanceScreenState();
}

class _FaAttendanceScreenState extends ConsumerState<FaAttendanceScreen> {
  DateTime? _selected;

  void _onDayTap(DateTime date, DayRecord? record) {
    setState(() => _selected = date);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DayDetailSheet(date: date, record: record),
    ).whenComplete(() {
      if (mounted) setState(() => _selected = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state     = ref.watch(attendanceCalendarProvider);
    final notifier  = ref.read(attendanceCalendarProvider.notifier);
    final threshold = ref.watch(thresholdProvider).valueOrNull
        ?? const AttendanceThreshold();

    return ColoredBox(
      color: _bg,
      child: RefreshIndicator(
        color: _green,
        displacement: 80,
        onRefresh: notifier.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [

            // ── App bar ───────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              expandedHeight: 0,
              backgroundColor: _greenDark,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              title: const Text(
                'Attendance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                state.isRefreshing
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 22),
                        onPressed: notifier.refresh,
                      ),
              ],
            ),

            // ── Ring header ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _RingHeader(
                key: ValueKey('${state.year}-${state.month}'),
                summary: state.summary,
                year: state.year,
                month: state.month,
              ),
            ),

            // ── Calendar card ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: state.isLoading
                      ? const _CalendarLoader()
                      : _CalendarGrid(
                          state:     state,
                          selected:  _selected,
                          threshold: threshold,
                          onTap:     _onDayTap,
                        ),
                ),
              ),
            ),

            // ── Legend card ───────────────────────────────────────────────
            const SliverToBoxAdapter(child: _ColorLegend()),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

// ── Ring Header ───────────────────────────────────────────────────────────────

class _RingHeader extends StatelessWidget {
  const _RingHeader({
    super.key,
    required this.summary,
    required this.year,
    required this.month,
  });

  final MonthSummary summary;
  final int year;
  final int month;

  @override
  Widget build(BuildContext context) {
    final pct        = summary.attendancePercent;
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime(year, month));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_greenDark, Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Text(
            monthLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ring
              SizedBox(
                width: 150, height: 150,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, child) => Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(150, 150),
                        painter: _RingPainter(progress: value),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(value * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Attendance',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 24),

              // Stat pills
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatPill(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: const Color(0xFFFB923C),
                      value: '${summary.streak}d',
                      label: 'Streak',
                    ),
                    const SizedBox(height: 10),
                    _StatPill(
                      icon: Icons.check_circle_rounded,
                      iconColor: const Color(0xFF6EE7B7),
                      value: '${summary.presentCount + summary.lateCount}',
                      label: 'Present',
                    ),
                    const SizedBox(height: 10),
                    _StatPill(
                      icon: Icons.cancel_rounded,
                      iconColor: const Color(0xFFFCA5A5),
                      value: '${summary.absentCount}',
                      label: 'Absent',
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${summary.workingDays} working days this month',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Pill ─────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color    iconColor;
  final String   value;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  )),
              Text(label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Ring Painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx      = size.width / 2;
    final cy      = size.height / 2;
    const strokeW = 13.0;
    final radius  = (size.width - strokeW) / 2;
    final rect    = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    canvas.drawArc(
      rect, -math.pi / 2, 2 * math.pi, false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    canvas.drawArc(
      rect, -math.pi / 2, 2 * math.pi * progress, false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle:   -math.pi / 2 + 2 * math.pi * progress,
          colors: const [Color(0xFF6EE7B7), Colors.white, Color(0xFFA7F3D0)],
          stops: const [0.0, 0.55, 1.0],
          tileMode: TileMode.clamp,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.progress != progress;
}

// ── Calendar Loader ───────────────────────────────────────────────────────────

class _CalendarLoader extends StatelessWidget {
  const _CalendarLoader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
      child: Column(
        children: List.generate(5, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (_) {
                return Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: KibaColors.grey100,
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}

// ── Calendar Grid ─────────────────────────────────────────────────────────────

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.state,
    required this.selected,
    required this.threshold,
    required this.onTap,
  });

  final AttendanceCalendarState             state;
  final DateTime?                           selected;
  final AttendanceThreshold                 threshold;
  final void Function(DateTime, DayRecord?) onTap;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  /// Returns true when the check-in time was after the late cutoff.
  bool _wasLate(DayRecord? record) {
    final ci = record?.checkIn;
    if (ci == null) return false;
    final tod    = TimeOfDay.fromDateTime(ci);
    final cutoff = threshold.lateCheckinCutoff;
    return tod.hour > cutoff.hour ||
        (tod.hour == cutoff.hour && tod.minute > cutoff.minute);
  }

  static bool _isThresholdViolation(AttendanceStatus? s) =>
      s == AttendanceStatus.earlyCheckout ||
      s == AttendanceStatus.visitThresholdNotMet ||
      s == AttendanceStatus.distanceNotMet;

  @override
  Widget build(BuildContext context) {
    final year    = state.year;
    final month   = state.month;
    final today   = DateTime.now();
    final lastDay = DateTime(year, month + 1, 0).day;

    final leadingBlanks = (DateTime(year, month, 1).weekday - 1) % 7;
    final rows          = ((leadingBlanks + lastDay) / 7).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
      child: Column(
        children: [
          // Day-of-week headers
          Row(
            children: List.generate(7, (i) {
              return Expanded(
                child: Center(
                  child: Text(
                    _days[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: i >= 5 ? KibaColors.grey300 : KibaColors.grey500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 10),

          for (int row = 0; row < rows; row++) ...[
            Row(
              children: List.generate(7, (col) {
                final idx = row * 7 + col;
                final day = idx - leadingBlanks + 1;

                if (day < 1 || day > lastDay) {
                  return const Expanded(child: SizedBox(height: 48));
                }

                final date      = DateTime(year, month, day);
                final record    = state.records[day];
                final status    = record?.effectiveStatus;
                final isToday   = today.year == year &&
                    today.month == month && today.day == day;
                final isFuture  = date.isAfter(today);
                final isWeekend = date.weekday >= 6;
                final isSelected = selected?.year  == year &&
                    selected?.month == month && selected?.day == day;

                // Split: threshold violation AND also checked in late
                final isSplit   = _isThresholdViolation(status) &&
                    _wasLate(record);

                return Expanded(
                  child: _DayCell(
                    day:        day,
                    record:     record,
                    isToday:    isToday,
                    isFuture:   isFuture,
                    isWeekend:  isWeekend,
                    isSelected: isSelected,
                    isSplit:    isSplit,
                    onTap:      () => onTap(date, record),
                  ),
                );
              }),
            ),
            if (row < rows - 1) Divider(height: 1, color: KibaColors.grey100),
          ],
        ],
      ),
    );
  }
}

// ── Day Cell ──────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.record,
    required this.isToday,
    required this.isFuture,
    required this.isWeekend,
    required this.isSelected,
    required this.isSplit,
    required this.onTap,
  });

  final int        day;
  final DayRecord? record;
  final bool       isToday;
  final bool       isFuture;
  final bool       isWeekend;
  final bool       isSelected;
  final bool       isSplit;   // late + threshold violation on same day
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = record?.effectiveStatus;

    // ── Split circle ──────────────────────────────────────────────────────
    if (isSplit) {
      final borderColor = isSelected ? Colors.white : null;
      return GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.white, width: 2.5)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: _orange.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: CustomPaint(
                  painter: _SplitCirclePainter(
                    leftColor:   _yellow,
                    rightColor:  _orange,
                    borderColor: borderColor,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ── Single colour ─────────────────────────────────────────────────────
    Color? bgColor;
    Color  textColor;
    BoxBorder? border;
    String? label;

    if (status != null) {
      switch (status) {
        case AttendanceStatus.present:
          bgColor = _green; textColor = Colors.white;
        case AttendanceStatus.late:
          bgColor = _yellow; textColor = Colors.white;
        case AttendanceStatus.absent:
          bgColor = _rose; textColor = Colors.white;
        case AttendanceStatus.leave:
          bgColor = _blue; textColor = Colors.white;
        case AttendanceStatus.holiday:
          bgColor = const Color(0xFFE2E8F0);
          textColor = KibaColors.grey500;
          label = 'H';
        case AttendanceStatus.earlyCheckout:
        case AttendanceStatus.visitThresholdNotMet:
        case AttendanceStatus.distanceNotMet:
          bgColor = _orange; textColor = Colors.white;
      }
    } else if (isToday) {
      border    = Border.all(color: _green, width: 2);
      textColor = _green;
    } else if (isFuture || isWeekend) {
      textColor = KibaColors.grey300;
    } else {
      textColor = KibaColors.grey400;
    }

    if (isSelected && bgColor != null) {
      border = Border.all(color: Colors.white, width: 2.5);
    } else if (isSelected) {
      border = Border.all(color: _green, width: 2.5);
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              border: border,
              boxShadow: bgColor != null
                  ? [
                      BoxShadow(
                        color: bgColor.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                label ?? '$day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: (status != null || isToday || isSelected)
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Split Circle Painter ──────────────────────────────────────────────────────

class _SplitCirclePainter extends CustomPainter {
  const _SplitCirclePainter({
    required this.leftColor,
    required this.rightColor,
    this.borderColor,
  });

  final Color  leftColor;
  final Color  rightColor;
  final Color? borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final r      = size.width / 2;
    final center = Offset(r, r);
    final rect   = Rect.fromCircle(center: center, radius: r);

    // Left half (yellow — late)
    canvas.drawArc(
      rect,
      math.pi / 2,   // start at 6-o'clock
      math.pi,       // 180° clockwise → sweeps left half
      true,
      Paint()..color = leftColor,
    );

    // Right half (orange — threshold violation)
    canvas.drawArc(
      rect,
      -math.pi / 2,  // start at 12-o'clock
      math.pi,       // 180° clockwise → sweeps right half
      true,
      Paint()..color = rightColor,
    );

    // Thin white divider between halves
    canvas.drawLine(
      Offset(r, 0),
      Offset(r, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 1.5,
    );

    // Selection border ring
    if (borderColor != null) {
      canvas.drawCircle(
        center,
        r - 1.25,
        Paint()
          ..color = borderColor!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(_SplitCirclePainter o) =>
      o.leftColor != leftColor ||
      o.rightColor != rightColor ||
      o.borderColor != borderColor;
}

// ── Color Legend ──────────────────────────────────────────────────────────────

class _ColorLegend extends StatelessWidget {
  const _ColorLegend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Container(
                  width: 3, height: 14,
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Status key',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: KibaColors.grey700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Single-colour rows
            _LegendRow(items: const [
              _LegendEntry(color: _green,  label: 'Present'),
              _LegendEntry(color: _rose,   label: 'Absent'),
            ]),
            const SizedBox(height: 10),
            _LegendRow(items: const [
              _LegendEntry(color: _yellow, label: 'Late'),
              _LegendEntry(color: _blue,   label: 'Leave'),
            ]),
            const SizedBox(height: 10),
            _LegendRow(items: const [
              _LegendEntry(color: Color(0xFFE2E8F0), label: 'Holiday', outlined: true),
              _LegendEntry(color: _orange, label: 'Early / Low visits / Low km'),
            ]),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: KibaColors.grey100),
            ),

            // Split-colour row
            Row(
              children: [
                // Split dot
                SizedBox(
                  width: 14, height: 14,
                  child: CustomPaint(
                    painter: _SplitCirclePainter(
                      leftColor:  _yellow,
                      rightColor: _orange,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Late + threshold violation on the same day',
                    style: TextStyle(
                      fontSize: 12,
                      color: KibaColors.grey600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Legend helpers ────────────────────────────────────────────────────────────

class _LegendEntry {
  const _LegendEntry({
    required this.color,
    required this.label,
    this.outlined = false,
  });
  final Color  color;
  final String label;
  final bool   outlined;
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.items});
  final List<_LegendEntry> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items.map((e) {
        return Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: e.color,
                  border: e.outlined
                      ? Border.all(color: KibaColors.grey300, width: 1)
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  e.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: KibaColors.grey600,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Day Detail Bottom Sheet ───────────────────────────────────────────────────

class _DayDetailSheet extends StatelessWidget {
  const _DayDetailSheet({required this.date, required this.record});

  final DateTime   date;
  final DayRecord? record;

  @override
  Widget build(BuildContext context) {
    final status    = record?.effectiveStatus;
    final dateLabel = DateFormat('EEEE, d MMMM').format(date);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: KibaColors.grey200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dateLabel,
                            style: KibaTextStyles.titleLarge
                                .copyWith(color: KibaColors.grey800)),
                        if (status != null) ...[
                          const SizedBox(height: 6),
                          _StatusChip(
                            status:     status,
                            isOverride: record?.adminOverride == true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: KibaColors.grey400,
                    iconSize: 22,
                  ),
                ],
              ),
            ),
            if (record != null) ...[
              const Divider(height: 1),
              _SheetBody(record: record!),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_busy_outlined,
                        size: 44, color: KibaColors.grey300),
                    const SizedBox(height: 10),
                    Text('No record for this day',
                        style: KibaTextStyles.bodyMedium
                            .copyWith(color: KibaColors.grey400)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Sheet Body ────────────────────────────────────────────────────────────────

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.record});
  final DayRecord record;

  @override
  Widget build(BuildContext context) {
    final dur = record.workDuration;
    final hoursLabel = dur == Duration.zero
        ? '—'
        : '${dur.inHours}h ${dur.inMinutes.remainder(60)}m';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _InfoTile(icon: Icons.login_rounded,    iconColor: _green, label: 'Check In',
                  value: record.checkIn  != null ? DateFormat('hh:mm a').format(record.checkIn!)  : '—')),
              const SizedBox(width: 8),
              Expanded(child: _InfoTile(icon: Icons.logout_rounded,   iconColor: _rose,  label: 'Check Out',
                  value: record.checkOut != null ? DateFormat('hh:mm a').format(record.checkOut!) : '—')),
              const SizedBox(width: 8),
              Expanded(child: _InfoTile(icon: Icons.timer_outlined,   iconColor: _teal,  label: 'Hours', value: hoursLabel)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _InfoTile(icon: Icons.agriculture_rounded, iconColor: _amber, label: 'Fields',
                  value: '${record.fieldsVisited}')),
              const SizedBox(width: 8),
              Expanded(child: _InfoTile(icon: Icons.speed_rounded,       iconColor: _blue,  label: 'Km',
                  value: record.kmCovered.toStringAsFixed(1))),
              const Expanded(child: SizedBox()),
            ],
          ),
          if (record.adminOverride && record.overrideReason != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 18, color: _amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin override'
                          '${record.overrideBy != null ? ' by ${record.overrideBy}' : ''}',
                          style: KibaTextStyles.labelSmall.copyWith(color: _amber),
                        ),
                        const SizedBox(height: 2),
                        Text(record.overrideReason!,
                            style: KibaTextStyles.bodySmall
                                .copyWith(color: KibaColors.grey700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Info Tile ─────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 6),
          Text(value,
              style: KibaTextStyles.titleMedium.copyWith(
                  color: KibaColors.grey800, fontWeight: FontWeight.w700)),
          Text(label,
              style: KibaTextStyles.bodySmall
                  .copyWith(color: KibaColors.grey400, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Status Chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.isOverride = false});

  final AttendanceStatus status;
  final bool             isOverride;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      AttendanceStatus.present =>
          (_green,  const Color(0xFFD1FAE5)),
      AttendanceStatus.late =>
          (_yellow, const Color(0xFFFEF9C3)),
      AttendanceStatus.absent =>
          (_rose,   const Color(0xFFFEE2E2)),
      AttendanceStatus.leave =>
          (_blue,   const Color(0xFFDBEAFE)),
      AttendanceStatus.holiday =>
          (KibaColors.grey500, KibaColors.grey100),
      AttendanceStatus.earlyCheckout ||
      AttendanceStatus.visitThresholdNotMet ||
      AttendanceStatus.distanceNotMet =>
          (_orange, const Color(0xFFFFF7ED)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(status.label,
              style: KibaTextStyles.labelSmall.copyWith(color: color)),
          if (isOverride) ...[
            const SizedBox(width: 4),
            Icon(Icons.admin_panel_settings_outlined, size: 12, color: color),
          ],
        ],
      ),
    );
  }
}
