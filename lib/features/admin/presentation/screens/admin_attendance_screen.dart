import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kiba_app/core/domain/threshold_provider.dart';
import 'package:kiba_app/core/models/attendance_threshold.dart';
import 'package:kiba_app/features/admin/data/attendance_admin_repository.dart';
import 'package:kiba_app/features/admin/domain/admin_attendance_providers.dart';
import 'package:kiba_app/features/admin/domain/user_admin_providers.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';
import 'package:kiba_app/features/field_advisor/data/day_record.dart';
import 'package:kiba_app/features/auth/data/user_model.dart';
import 'package:kiba_app/features/field_advisor/domain/attendance_calendar_provider.dart'
    show MonthSummary;

// ── Palette ───────────────────────────────────────────────────────────────────
const _navy    = Color(0xFF0D1B2A);
const _navyMid = Color(0xFF16293E);
const _amber   = Color(0xFFF59E0B);
const _yellow  = Color(0xFFEAB308);  // late check-in
const _orange  = Color(0xFFF97316);  // threshold violations
const _faGreen = Color(0xFF059669);
const _clBlue  = Color(0xFF2563EB);
const _rose    = Color(0xFFDC2626);
const _violet  = Color(0xFF7C3AED);
const _bg      = Color(0xFFF0F4F8);
const _ink900  = Color(0xFF111827);
const _ink600  = Color(0xFF4B5563);
const _ink400  = Color(0xFF9CA3AF);
const _border  = Color(0xFFE5E7EB);
const _surface = Color(0xFFFBFCFD);

// ── Status helpers ────────────────────────────────────────────────────────────
Color _statusColor(AttendanceStatus s) => switch (s) {
      AttendanceStatus.present              => _faGreen,
      AttendanceStatus.late                 => _yellow,
      AttendanceStatus.absent               => _rose,
      AttendanceStatus.leave                => _clBlue,
      AttendanceStatus.holiday              => _ink400,
      AttendanceStatus.earlyCheckout ||
      AttendanceStatus.visitThresholdNotMet ||
      AttendanceStatus.distanceNotMet       => _orange,
    };

Color _statusBg(AttendanceStatus s) => switch (s) {
      AttendanceStatus.present              => const Color(0xFFECFDF5),
      AttendanceStatus.late                 => const Color(0xFFFEF9C3),
      AttendanceStatus.absent               => const Color(0xFFFEF2F2),
      AttendanceStatus.leave                => const Color(0xFFEFF6FF),
      AttendanceStatus.holiday              => const Color(0xFFF3F4F6),
      AttendanceStatus.earlyCheckout ||
      AttendanceStatus.visitThresholdNotMet ||
      AttendanceStatus.distanceNotMet       => const Color(0xFFFFF7ED),
    };

// Solid fill color for calendar circles (full-saturation)
Color _statusFill(AttendanceStatus s) => switch (s) {
      AttendanceStatus.present              => _faGreen,
      AttendanceStatus.late                 => _yellow,
      AttendanceStatus.absent               => _rose,
      AttendanceStatus.leave                => _clBlue,
      AttendanceStatus.holiday              => _ink400,
      AttendanceStatus.earlyCheckout ||
      AttendanceStatus.visitThresholdNotMet ||
      AttendanceStatus.distanceNotMet       => _orange,
    };

// ── Split-circle helper functions ─────────────────────────────────────────────
bool _wasLate(DateTime? checkIn, TimeOfDay cutoff) {
  if (checkIn == null) return false;
  final tod = TimeOfDay.fromDateTime(checkIn);
  return tod.hour > cutoff.hour ||
      (tod.hour == cutoff.hour && tod.minute > cutoff.minute);
}

bool _isThresholdViolation(AttendanceStatus? s) =>
    s == AttendanceStatus.earlyCheckout ||
    s == AttendanceStatus.visitThresholdNotMet ||
    s == AttendanceStatus.distanceNotMet;

String _statusLabel(AttendanceStatus s) => switch (s) {
      AttendanceStatus.present              => 'Present',
      AttendanceStatus.late                 => 'Late',
      AttendanceStatus.absent               => 'Absent',
      AttendanceStatus.leave                => 'Leave',
      AttendanceStatus.holiday              => 'Holiday',
      AttendanceStatus.earlyCheckout        => 'Early Out',
      AttendanceStatus.visitThresholdNotMet => 'Visits Low',
      AttendanceStatus.distanceNotMet       => 'Dist Low',
    };

// ── Split-circle painter ──────────────────────────────────────────────────────
class _SplitCirclePainter extends CustomPainter {
  const _SplitCirclePainter({
    required this.leftColor,
    required this.rightColor,
  });
  final Color leftColor, rightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final r      = size.width / 2;
    final center = Offset(r, r);
    final rect   = Rect.fromCircle(center: center, radius: r);
    canvas.drawArc(rect, math.pi / 2, math.pi, true,
        Paint()..color = leftColor);
    canvas.drawArc(rect, -math.pi / 2, math.pi, true,
        Paint()..color = rightColor);
    canvas.drawLine(
      Offset(r, 0), Offset(r, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SplitCirclePainter old) =>
      old.leftColor != leftColor || old.rightColor != rightColor;
}

enum _ReportRole { all, fa, clerk }

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});
  @override
  ConsumerState<AdminAttendanceScreen> createState() =>
      _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_navy, _navyMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: TabBar(
            controller: _tabs,
            indicator: BoxDecoration(
              color: _amber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border(bottom: BorderSide(color: _amber, width: 2.5)),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.42),
            labelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(
                iconMargin: EdgeInsets.only(bottom: 2),
                icon: Icon(Icons.bar_chart_rounded, size: 17),
                text: 'Overview',
              ),
              Tab(
                iconMargin: EdgeInsets.only(bottom: 2),
                icon: Icon(Icons.edit_calendar_rounded, size: 17),
                text: 'Override',
              ),
              Tab(
                iconMargin: EdgeInsets.only(bottom: 2),
                icon: Icon(Icons.summarize_rounded, size: 17),
                text: 'Report',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _OverviewTab(),
              _OverrideTab(),
              _ReportTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAB 1 — OVERVIEW
// ─────────────────────────────────────────────────────────────────────────────
class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab();
  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab>
    with AutomaticKeepAliveClientMixin {
  AttendancePeriod _period = AttendancePeriod.month;
  int _year  = DateTime.now().year;
  int _month = DateTime.now().month;

  @override
  bool get wantKeepAlive => true;

  PeriodKey get _key => (period: _period, year: _year, month: _month);

  String get _periodLabel {
    final now = DateTime.now();
    switch (_period) {
      case AttendancePeriod.day:
        return DateFormat('EEEE, d MMM').format(now);
      case AttendancePeriod.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return '${DateFormat('d MMM').format(monday)} – ${DateFormat('d MMM').format(now)}';
      case AttendancePeriod.month:
        return DateFormat('MMMM yyyy').format(DateTime(_year, _month));
    }
  }

  void _prevMonth() {
    final d = DateTime(_year, _month - 1);
    setState(() { _year = d.year; _month = d.month; });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final d   = DateTime(_year, _month + 1);
    if (d.year > now.year || (d.year == now.year && d.month > now.month)) return;
    setState(() { _year = d.year; _month = d.month; });
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return _year < now.year || (_year == now.year && _month < now.month);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(adminPeriodStatsProvider(_key));

    return ColoredBox(
      color: _bg,
      child: Column(
        children: [
          // ── Controls header ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _PeriodStrip(
              selected: _period,
              onChanged: (p) => setState(() {
                _period = p;
                if (p == AttendancePeriod.month) {
                  _year  = DateTime.now().year;
                  _month = DateTime.now().month;
                }
              }),
            ),
          ),

          // ── Period label / month nav ───────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: _period == AttendancePeriod.month
                ? Row(children: [
                    _NavArrow(icon: Icons.chevron_left_rounded, onTap: _prevMonth),
                    Expanded(
                      child: Text(
                        _periodLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _ink900,
                        ),
                      ),
                    ),
                    _NavArrow(
                      icon: Icons.chevron_right_rounded,
                      enabled: _canGoNext,
                      onTap: _canGoNext ? _nextMonth : () {},
                    ),
                  ])
                : Center(
                    child: Text(
                      _periodLabel,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500, color: _ink400),
                    ),
                  ),
          ),

          Container(height: 1, color: _border),

          // ── Stats ──────────────────────────────────────────────────────────
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: _faGreen, strokeWidth: 2.5)),
              error: (e, _) =>
                  Center(child: Text('$e', style: const TextStyle(color: _rose))),
              data: (stats) => _OverviewContent(stats: stats, period: _period),
            ),
          ),
        ],
      ),
    );
  }

}

// ── Overview content ──────────────────────────────────────────────────────────
class _OverviewContent extends StatelessWidget {
  const _OverviewContent({required this.stats, required this.period});
  final PeriodStats stats;
  final AttendancePeriod period;

  @override
  Widget build(BuildContext context) {
    final fa    = stats.fa;
    final clerk = stats.clerk;
    final all   = stats.rows;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Role cards ─────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (fa.isNotEmpty)
                Expanded(
                  child: _RoleStatCard(
                    roleLabel: 'Field Advisors',
                    group: fa,
                    stats: stats,
                    color: _faGreen,
                    icon: Icons.nature_people_rounded,
                    period: period,
                  ),
                ),
              if (fa.isNotEmpty && clerk.isNotEmpty) const SizedBox(width: 12),
              if (clerk.isNotEmpty)
                Expanded(
                  child: _RoleStatCard(
                    roleLabel: 'Clerks',
                    group: clerk,
                    stats: stats,
                    color: _clBlue,
                    icon: Icons.badge_rounded,
                    period: period,
                  ),
                ),
            ],
          ),

          // ── Combined bar ───────────────────────────────────────────────────
          if (all.isNotEmpty) ...[
            const SizedBox(height: 14),
            _CombinedBar(stats: stats),
          ],

          // ── Day: employee list ─────────────────────────────────────────────
          if (period == AttendancePeriod.day && all.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionLabel(label: "TODAY'S STATUS"),
            const SizedBox(height: 10),
            ..._sortedForDay(all).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _EmployeeStatusRow(stat: e),
                )),
          ],
        ],
      ),
    );
  }

  List<EmployeeAttStat> _sortedForDay(List<EmployeeAttStat> rows) {
    int order(EmployeeAttStat e) {
      if (e.workingDays == 0) return 4;
      if (e.absentDays > 0) return 0;
      if (e.lateDays > 0) return 1;
      if (e.presentDays > 0) return 2;
      return 3;
    }
    return [...rows]..sort((a, b) => order(a).compareTo(order(b)));
  }
}

// ── Period strip ──────────────────────────────────────────────────────────────
class _PeriodStrip extends StatelessWidget {
  const _PeriodStrip({required this.selected, required this.onChanged});
  final AttendancePeriod selected;
  final ValueChanged<AttendancePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: AttendancePeriod.values.map((p) {
          final active = p == selected;
          final label  = switch (p) {
            AttendancePeriod.day   => 'Day',
            AttendancePeriod.week  => 'Week',
            AttendancePeriod.month => 'Month',
          };
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: active
                      ? const LinearGradient(
                          colors: [_navy, _navyMid],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: _navy.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : _ink400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Role stat card ────────────────────────────────────────────────────────────
class _RoleStatCard extends StatelessWidget {
  const _RoleStatCard({
    required this.roleLabel,
    required this.group,
    required this.stats,
    required this.color,
    required this.icon,
    required this.period,
  });
  final String              roleLabel;
  final List<EmployeeAttStat> group;
  final PeriodStats         stats;
  final Color               color;
  final IconData            icon;
  final AttendancePeriod    period;

  @override
  Widget build(BuildContext context) {
    final rate    = stats.rateOf(group);
    final present = stats.presentIn(group);
    final late    = stats.lateIn(group);
    final absent  = stats.absentIn(group);
    final leave   = stats.leaveIn(group);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gradient header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.72)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  roleLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${group.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ]),
          ),

          // Ring + count chips
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: Column(children: [
              // Animated ring
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: rate),
                      duration: const Duration(milliseconds: 1100),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => CustomPaint(
                        size: const Size(100, 100),
                        painter: _RingPainter(progress: v, color: color),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: rate),
                      duration: const Duration(milliseconds: 1100),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(v * 100).round()}%',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: color,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            period == AttendancePeriod.day ? 'today' : 'rate',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: _ink400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Count chips
              Row(children: [
                _CountChip(count: present, label: 'P',  color: _faGreen),
                const SizedBox(width: 4),
                _CountChip(count: late,    label: 'L',  color: _amber),
                const SizedBox(width: 4),
                _CountChip(count: absent,  label: 'A',  color: _rose),
                const SizedBox(width: 4),
                _CountChip(count: leave,   label: 'Lv', color: _clBlue),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Combined stacked bar ──────────────────────────────────────────────────────
class _CombinedBar extends StatelessWidget {
  const _CombinedBar({required this.stats});
  final PeriodStats stats;

  @override
  Widget build(BuildContext context) {
    final all     = stats.rows;
    final total   = stats.workingIn(all);
    final present = stats.presentIn(all);
    final late    = stats.lateIn(all);
    final absent  = stats.absentIn(all);
    final leave   = stats.leaveIn(all);
    final overall = total == 0
        ? 0.0
        : ((present + late) / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: _SectionLabel(label: 'COMBINED ATTENDANCE'),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_navy, _navyMid],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${(overall * 100).round()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Stacked bar
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    if (present > 0)
                      Flexible(flex: present, child: Container(color: _faGreen)),
                    if (late > 0)
                      Flexible(flex: late, child: Container(color: _amber)),
                    if (leave > 0)
                      Flexible(flex: leave, child: Container(color: _clBlue)),
                    if (absent > 0)
                      Flexible(flex: absent, child: Container(color: _rose)),
                    if (total - present - late - absent - leave > 0)
                      Flexible(
                        flex: total - present - late - absent - leave,
                        child: Container(color: const Color(0xFFE9EEF3)),
                      ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
            ),

          const SizedBox(height: 12),

          // Legend chips
          Row(
            children: [
              _LegendChip(color: _faGreen, label: 'Present', count: present),
              const SizedBox(width: 6),
              _LegendChip(color: _amber,   label: 'Late',    count: late),
              const SizedBox(width: 6),
              _LegendChip(color: _rose,    label: 'Absent',  count: absent),
              const SizedBox(width: 6),
              _LegendChip(color: _clBlue,  label: 'Leave',   count: leave),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Per-employee status row (Day period) ──────────────────────────────────────
class _EmployeeStatusRow extends StatelessWidget {
  const _EmployeeStatusRow({required this.stat});
  final EmployeeAttStat stat;

  @override
  Widget build(BuildContext context) {
    final u = stat.user;
    final color = u.isFieldAdvisor ? _faGreen : _clBlue;

    AttendanceStatus? todayStatus;
    if (stat.workingDays > 0) {
      if (stat.presentDays > 0)     todayStatus = AttendanceStatus.present;
      else if (stat.lateDays > 0)   todayStatus = AttendanceStatus.late;
      else if (stat.leaveDays > 0)  todayStatus = AttendanceStatus.leave;
      else                          todayStatus = AttendanceStatus.absent;
    }

    final statusC = todayStatus != null ? _statusColor(todayStatus) : _ink400;
    final statusBg = todayStatus != null
        ? _statusBg(todayStatus)
        : const Color(0xFFF9FAFB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: statusC.withValues(alpha: 0.5), width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _AttAvatar(name: u.displayName, color: color, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.displayName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _ink900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      u.isFieldAdvisor ? 'FA' : 'Clerk',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          if (todayStatus != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: statusC.withValues(alpha: 0.3)),
              ),
              child: Text(
                _statusLabel(todayStatus),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: statusC,
                ),
              ),
            )
          else
            Text('—', style: const TextStyle(fontSize: 14, color: _ink400)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAB 2 — OVERRIDE
// ─────────────────────────────────────────────────────────────────────────────
class _OverrideTab extends ConsumerStatefulWidget {
  const _OverrideTab();
  @override
  ConsumerState<_OverrideTab> createState() => _OverrideTabState();
}

class _OverrideTabState extends ConsumerState<_OverrideTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(allEmployeesProvider);

    return ColoredBox(
      color: _bg,
      child: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: _ink900, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search name, phone or ID…',
                  hintStyle:
                      const TextStyle(color: _ink400, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _ink400, size: 18),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded,
                              size: 17, color: _ink400),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
          Container(height: 1, color: _border),

          // Employee list
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: _faGreen, strokeWidth: 2.5)),
              error: (e, _) => Center(child: Text('$e')),
              data: (all) {
                final filtered = _query.isEmpty
                    ? all
                    : all.where((u) {
                        final q  = _query.toLowerCase();
                        final qN = q.replaceAll('-', '').replaceAll(' ', '');
                        final empId =
                            (u.employeeId ?? '').toLowerCase().replaceAll('-', '');
                        return u.displayName.toLowerCase().contains(q) ||
                            (qN.isNotEmpty && empId.contains(qN));
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _border,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.search_off_rounded,
                              size: 30, color: _ink400),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _query.isEmpty
                              ? 'No employees found'
                              : 'No match for "$_query"',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _ink600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _OverrideEmployeeRow(
                    user: filtered[i],
                    onTap: () => _openCalendarSheet(ctx, filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openCalendarSheet(BuildContext ctx, UserModel user) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(ctx),
        child: _EmployeeCalendarSheet(user: user),
      ),
    );
  }
}

// ── Override employee row — styled like the employee card ─────────────────────
class _OverrideEmployeeRow extends StatelessWidget {
  const _OverrideEmployeeRow({required this.user, required this.onTap});
  final UserModel    user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = user.isFieldAdvisor ? _faGreen : _clBlue;
    return Opacity(
      opacity: user.isActive ? 1.0 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border(left: BorderSide(color: color, width: 4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar — same style as employee screen _Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: color.withValues(alpha: 0.2), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + role pill
                      Row(children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _ink900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: color.withValues(alpha: 0.3),
                                width: 0.8),
                          ),
                          child: Text(
                            user.isFieldAdvisor ? 'FA' : 'Clerk',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color),
                          ),
                        ),
                      ]),
                      // Employee ID
                      if (user.employeeId != null) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.numbers_rounded,
                              size: 11,
                              color: color.withValues(alpha: 0.75)),
                          const SizedBox(width: 3),
                          Text(
                            user.employeeId!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: color,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ]),
                      ],
                      // Phone
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(Icons.phone_rounded,
                            size: 11,
                            color: user.phone != null
                                ? _ink400
                                : const Color(0xFFD1D5DB)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            user.phone ?? 'No phone',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: user.phone != null
                                  ? _ink600
                                  : const Color(0xFFD1D5DB),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_calendar_rounded,
                      size: 15, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Employee calendar sheet ───────────────────────────────────────────────────
class _EmployeeCalendarSheet extends ConsumerStatefulWidget {
  const _EmployeeCalendarSheet({required this.user});
  final UserModel user;
  @override
  ConsumerState<_EmployeeCalendarSheet> createState() =>
      _EmployeeCalendarSheetState();
}

class _EmployeeCalendarSheetState
    extends ConsumerState<_EmployeeCalendarSheet> {
  int _year  = DateTime.now().year;
  int _month = DateTime.now().month;

  bool get _canGoNext {
    final now = DateTime.now();
    return _year < now.year || (_year == now.year && _month < now.month);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.user.isFieldAdvisor ? _faGreen : _clBlue;
    final key   = (uid: widget.user.employeeId ?? widget.user.uid, year: _year, month: _month);
    final async = ref.watch(adminEmployeeMonthProvider(key));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header with gradient
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.06),
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                _AttAvatar(
                    name: widget.user.displayName, color: color, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _ink900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.user.isFieldAdvisor
                                  ? 'Field Advisor'
                                  : 'Clerk',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color),
                            ),
                          ),
                          if (widget.user.employeeId != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _navy.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.user.employeeId!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _navy,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: _ink400,
                ),
              ],
            ),
          ),

          Container(height: 1, color: _border),

          // Month nav
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _NavArrow(
                  icon: Icons.chevron_left_rounded,
                  onTap: () {
                    final d = DateTime(_year, _month - 1);
                    setState(() { _year = d.year; _month = d.month; });
                  },
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(DateTime(_year, _month)),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _ink900,
                    ),
                  ),
                ),
                _NavArrow(
                  icon: Icons.chevron_right_rounded,
                  enabled: _canGoNext,
                  onTap: _canGoNext
                      ? () {
                          final d = DateTime(_year, _month + 1);
                          setState(() { _year = d.year; _month = d.month; });
                        }
                      : () {},
                ),
              ],
            ),
          ),

          // Calendar
          Builder(
            builder: (ctx) {
              final threshold = ref.watch(thresholdProvider).valueOrNull;
              return async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('$e', style: const TextStyle(color: _rose)),
                ),
                data: (records) => Column(
                  children: [
                    _AdminCalendarGrid(
                      records:   records,
                      year:      _year,
                      month:     _month,
                      threshold: threshold,
                      onDayTap:  (date, record) =>
                          _openDaySheet(context, date, record),
                    ),
                    _SummaryStrip(
                        records: records, year: _year, month: _month),
                    const _AdminColorLegend(),
                  ],
                ),
              );
            },
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.touch_app_rounded,
                    size: 12, color: _ink400),
                const SizedBox(width: 4),
                const Text(
                  'Tap any past date to view or override',
                  style: TextStyle(fontSize: 11, color: _ink400),
                ),
              ],
            ),
          ),

          SizedBox(
              height: MediaQuery.of(context).viewInsets.bottom + 12),
        ],
      ),
    );
  }

  void _openDaySheet(BuildContext ctx, DateTime date, DayRecord? record) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(ctx),
        child: _DayOverrideSheet(
          user:   widget.user,
          date:   date,
          record: record,
          year:   _year,
          month:  _month,
        ),
      ),
    );
  }
}

// ── Admin calendar grid ───────────────────────────────────────────────────────
class _AdminCalendarGrid extends StatelessWidget {
  const _AdminCalendarGrid({
    required this.records,
    required this.year,
    required this.month,
    required this.onDayTap,
    this.threshold,
  });
  final Map<int, DayRecord> records;
  final int year, month;
  final void Function(DateTime date, DayRecord? record) onDayTap;
  final AttendanceThreshold? threshold;

  static const _headers = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final now     = DateTime.now();
    final lastDay = DateTime(year, month + 1, 0).day;
    final leading = (DateTime(year, month, 1).weekday - 1) % 7;
    final total   = leading + lastDay;
    final rows    = (total / 7).ceil();
    final cutoff  = threshold?.lateCheckinCutoff ??
        const AttendanceThreshold().lateCheckinCutoff;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        children: [
          // Day-of-week headers
          Row(
            children: _headers
                .map((h) => Expanded(
                      child: Center(
                        child: Text(
                          h,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: h == 'S' ? _ink400.withValues(alpha: 0.55) : _ink400,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          for (int row = 0; row < rows; row++) ...[
            Row(
              children: List.generate(7, (col) {
                final idx = row * 7 + col;
                final day = idx - leading + 1;
                if (day < 1 || day > lastDay) {
                  return const Expanded(child: SizedBox(height: 48));
                }
                final date     = DateTime(year, month, day);
                final record   = records[day];
                final isToday  = now.year == year &&
                    now.month == month &&
                    now.day == day;
                final isFuture = date.isAfter(now);
                final isWkend  = date.weekday >= DateTime.saturday;

                // Split: late check-in AND threshold violation on same day
                final isSplit  = record != null &&
                    _isThresholdViolation(record.effectiveStatus) &&
                    _wasLate(record.checkIn, cutoff);

                return Expanded(
                  child: GestureDetector(
                    onTap: isFuture ? null : () => onDayTap(date, record),
                    child: SizedBox(
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _AdminDayCell(
                            day: day,
                            record: record,
                            isToday: isToday,
                            isFuture: isFuture,
                            isWeekend: isWkend,
                            isSplit: isSplit,
                          ),
                          if (record?.adminOverride == true)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _amber,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 1),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (row < rows - 1) const SizedBox(height: 1),
          ],
        ],
      ),
    );
  }
}

class _AdminDayCell extends StatelessWidget {
  const _AdminDayCell({
    required this.day,
    required this.record,
    required this.isToday,
    required this.isFuture,
    required this.isWeekend,
    this.isSplit = false,
  });
  final int        day;
  final DayRecord? record;
  final bool       isToday, isFuture, isWeekend, isSplit;

  @override
  Widget build(BuildContext context) {
    // Split circle: late + threshold violation
    if (isSplit) {
      return Center(
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
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
                leftColor:  _yellow,
                rightColor: _orange,
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
      );
    }

    final status = record?.effectiveStatus;
    Color? fillColor;
    Color  textColor;
    List<BoxShadow>? shadows;

    if (status != null) {
      fillColor = _statusFill(status);
      textColor = Colors.white;
      shadows   = [
        BoxShadow(
          color: fillColor.withValues(alpha: 0.32),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (isToday) {
      fillColor = _navy;
      textColor = Colors.white;
    } else {
      fillColor = null;
      textColor = (isFuture || isWeekend)
          ? const Color(0xFFD1D5DB)
          : _ink400;
    }

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fillColor,
          boxShadow: shadows,
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 13,
              fontWeight: (fillColor != null) ? FontWeight.w700 : FontWeight.w400,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Summary strip ─────────────────────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip(
      {required this.records, required this.year, required this.month});
  final Map<int, DayRecord> records;
  final int year, month;

  @override
  Widget build(BuildContext context) {
    final s = MonthSummary.compute(records, year, month);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Row(children: [
        _MiniCount(count: s.presentCount, label: 'Present', color: _faGreen),
        _MiniCount(count: s.lateCount,    label: 'Late',    color: _yellow),
        _MiniCount(count: s.absentCount,  label: 'Absent',  color: _rose),
        _MiniCount(count: s.leaveCount,   label: 'Leave',   color: _clBlue),
      ]),
    );
  }
}

class _MiniCount extends StatelessWidget {
  const _MiniCount(
      {required this.count, required this.label, required this.color});
  final int    count;
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(children: [
            Text(
              '$count',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: color),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 9.5, color: _ink400),
            ),
          ]),
        ),
      );
}

// ── Calendar color legend ─────────────────────────────────────────────────────
class _AdminColorLegend extends StatelessWidget {
  const _AdminColorLegend();

  static const _entries = <({Color color, String label, bool isSplit})>[
    (color: _faGreen,                  label: 'Present',           isSplit: false),
    (color: _yellow,                   label: 'Late check-in',     isSplit: false),
    (color: _rose,                     label: 'Absent',            isSplit: false),
    (color: _clBlue,                   label: 'On Leave',          isSplit: false),
    (color: _orange,                   label: 'Threshold violation (early / visits / km)', isSplit: false),
    (color: _ink400,                   label: 'Holiday',           isSplit: false),
    (color: Colors.transparent,        label: 'Late + threshold violation', isSplit: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 14, decoration: BoxDecoration(
                color: _navy, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text(
                'Status colours',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: _ink900, letterSpacing: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: _entries.map((e) {
              final dot = e.isSplit
                  ? ClipOval(
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CustomPaint(
                          painter: _SplitCirclePainter(
                            leftColor: _yellow,
                            rightColor: _orange,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: e.color,
                        shape: BoxShape.circle,
                      ),
                    );
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  dot,
                  const SizedBox(width: 5),
                  Text(
                    e.label,
                    style: const TextStyle(
                        fontSize: 10.5, color: _ink600),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _amber,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Amber dot = admin override applied',
                style: TextStyle(fontSize: 10.5, color: _ink600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Activity timeline ─────────────────────────────────────────────────────────
class _ActivityTimeline extends StatefulWidget {
  const _ActivityTimeline({required this.record, required this.hasOverride});
  final DayRecord record;
  final bool      hasOverride;

  @override
  State<_ActivityTimeline> createState() => _ActivityTimelineState();
}

class _ActivityTimelineState extends State<_ActivityTimeline> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;

    final nodes = <_TLData>[];

    if (r.checkIn != null) {
      nodes.add(_TLData(
        dotColor: _faGreen,
        icon:     Icons.login_rounded,
        title:    'Checked In',
        time:     DateFormat('hh:mm a').format(r.checkIn!),
        rows: [
          if (r.checkInLat != null)
            _TLRow.location(
              label: 'GPS',
              lat:   r.checkInLat!,
              lng:   r.checkInLng!,
              color: _faGreen,
            ),
        ],
      ));
    }

    if (r.checkOut != null) {
      nodes.add(_TLData(
        dotColor: _rose,
        icon:     Icons.logout_rounded,
        title:    'Checked Out',
        time:     DateFormat('hh:mm a').format(r.checkOut!),
        rows: [
          _TLRow.info(
            icon:  Icons.timelapse_rounded,
            label: 'Duration',
            value: _fmtDuration(r.workDuration),
            color: _violet,
          ),
          if (r.checkOutLat != null)
            _TLRow.location(
              label: 'GPS',
              lat:   r.checkOutLat!,
              lng:   r.checkOutLng!,
              color: _rose,
            ),
          if (r.checkoutReason != null && r.checkoutReason!.isNotEmpty)
            _TLRow.info(
              icon:  Icons.info_outline_rounded,
              label: 'Reason',
              value: r.checkoutReason!,
              color: _amber,
            ),
        ],
      ));
    }

    if (r.checkIn != null) {
      nodes.add(_TLData(
        dotColor: _violet,
        icon:     Icons.assessment_rounded,
        title:    'System Assessment',
        time:     null,
        rows: [
          _TLRow.info(
            icon:  Icons.route_rounded,
            label: 'Distance',
            value: '${r.kmCovered.toStringAsFixed(1)} km',
            color: _violet,
          ),
          _TLRow.info(
            icon:  Icons.place_rounded,
            label: 'Fields visited',
            value: '${r.fieldsVisited}',
            color: _faGreen,
          ),
          _TLRow.status(label: 'Auto status', status: r.autoStatus),
        ],
      ));
    }

    if (widget.hasOverride) {
      nodes.add(_TLData(
        dotColor: _amber,
        icon:     Icons.admin_panel_settings_rounded,
        title:    'Admin Override',
        time:     r.overrideAt != null
            ? DateFormat('d MMM, hh:mm a').format(r.overrideAt!)
            : null,
        rows: [
          if (r.overrideStatus != null)
            _TLRow.status(label: 'Changed to', status: r.overrideStatus!),
          if (r.overrideBy != null)
            _TLRow.info(
              icon:  Icons.person_rounded,
              label: 'By',
              value: r.overrideBy!,
              color: _amber,
            ),
          if (r.overrideReason != null && r.overrideReason!.isNotEmpty)
            _TLRow.info(
              icon:  Icons.comment_rounded,
              label: 'Reason',
              value: r.overrideReason!,
              color: _ink600,
            ),
        ],
      ));
    }

    if (nodes.isEmpty) return const SizedBox.shrink();

    final timeHint = r.checkIn != null
        ? (r.checkOut != null
            ? '${DateFormat('h:mm a').format(r.checkIn!)} → ${DateFormat('h:mm a').format(r.checkOut!)}'
            : DateFormat('h:mm a').format(r.checkIn!))
        : null;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsed header — always visible
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.timeline_rounded,
                        size: 14, color: _navy),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Activity Log',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _ink900,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  if (timeHint != null && !_expanded) ...[
                    Text(timeHint,
                        style: const TextStyle(
                            fontSize: 10, color: _ink400)),
                    const SizedBox(width: 6),
                  ],
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 240),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: _ink400),
                  ),
                ],
              ),
            ),
          ),

          // Expandable timeline body
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: _expanded
                ? Container(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: _border)),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    child: Column(
                      children: [
                        for (int i = 0; i < nodes.length; i++)
                          _TimelineNode(
                            data:   nodes[i],
                            isLast: i == nodes.length - 1,
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Timeline data + row types ─────────────────────────────────────────────────
class _TLData {
  const _TLData({
    required this.dotColor,
    required this.icon,
    required this.title,
    required this.time,
    required this.rows,
  });
  final Color        dotColor;
  final IconData     icon;
  final String       title;
  final String?      time;
  final List<Widget> rows;
}

class _TLRow extends StatelessWidget {
  const _TLRow._({required this.child});
  final Widget child;

  factory _TLRow.info({
    required IconData icon,
    required String   label,
    required String   value,
    required Color    color,
  }) => _TLRow._(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text('$label  ',
            style: const TextStyle(fontSize: 10.5, color: _ink400)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: _ink600)),
        ),
      ],
    ),
  );

  factory _TLRow.location({
    required String label,
    required double lat,
    required double lng,
    required Color  color,
  }) => _TLRow._(
    child: _LocationTile(label: label, lat: lat, lng: lng, color: color),
  );

  factory _TLRow.status({
    required String           label,
    required AttendanceStatus status,
  }) => _TLRow._(
    child: Row(
      children: [
        Text('$label  ',
            style: const TextStyle(fontSize: 10.5, color: _ink400)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _statusColor(status),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _statusLabel(status),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => child;
}

// ── Timeline node widget ──────────────────────────────────────────────────────
class _TimelineNode extends StatelessWidget {
  const _TimelineNode({required this.data, required this.isLast});
  final _TLData data;
  final bool    isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left column: icon dot + connector line
          Column(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: data.dotColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: data.dotColor.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(data.icon, size: 13, color: data.dotColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          data.dotColor.withValues(alpha: 0.3),
                          _border,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 12),

          // Right column: content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row + time badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          data.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _ink900,
                          ),
                        ),
                      ),
                      if (data.time != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: data.dotColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            data.time!,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: data.dotColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (data.rows.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...data.rows.map((row) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: row,
                        )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Day override sheet ────────────────────────────────────────────────────────
class _DayOverrideSheet extends ConsumerStatefulWidget {
  const _DayOverrideSheet({
    required this.user,
    required this.date,
    required this.record,
    required this.year,
    required this.month,
  });
  final UserModel  user;
  final DateTime   date;
  final DayRecord? record;
  final int year, month;

  @override
  ConsumerState<_DayOverrideSheet> createState() =>
      _DayOverrideSheetState();
}

class _DayOverrideSheetState extends ConsumerState<_DayOverrideSheet> {
  AttendanceStatus? _pickedStatus;
  final _reasonCtrl = TextEditingController();
  bool _isSaving    = false;
  bool _isClearing  = false;

  bool get _canSave =>
      _pickedStatus != null &&
      _reasonCtrl.text.trim().length >= 10 &&
      !_isSaving;

  @override
  void initState() {
    super.initState();
    if (widget.record?.adminOverride == true) {
      _pickedStatus    = widget.record!.overrideStatus;
      _reasonCtrl.text = widget.record!.overrideReason ?? '';
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record     = widget.record;
    final auto       = record?.autoStatus;
    final eff        = record?.effectiveStatus;
    final hasOverride = record?.adminOverride == true;
    final userColor  = widget.user.isFieldAdvisor ? _faGreen : _clBlue;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      userColor.withValues(alpha: 0.06),
                      Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: userColor.withValues(alpha: 0.15)),
                ),
                child: Row(children: [
                  _AttAvatar(
                      name: widget.user.displayName,
                      color: userColor,
                      size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.user.displayName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _ink900,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.user.employeeId != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: userColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.user.employeeId!,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: userColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('EEEE, d MMMM yyyy')
                              .format(widget.date),
                          style: const TextStyle(
                              fontSize: 12, color: _ink600),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 16),

              // Current record card
              if (record != null) ...[
                const _SectionLabel(label: 'CURRENT RECORD'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Time row ─────────────────────────────────────────
                      if (record.checkIn != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _InfoTileSmall(
                              icon: Icons.login_rounded,
                              iconColor: _faGreen,
                              label: 'Check In',
                              value: DateFormat('hh:mm a').format(record.checkIn!),
                            ),
                            if (record.checkOut != null)
                              _InfoTileSmall(
                                icon: Icons.logout_rounded,
                                iconColor: _rose,
                                label: 'Check Out',
                                value: DateFormat('hh:mm a').format(record.checkOut!),
                              ),
                            if (record.checkOut != null)
                              _InfoTileSmall(
                                icon: Icons.timelapse_rounded,
                                iconColor: _violet,
                                label: 'Duty',
                                value: _fmtDuration(record.workDuration),
                              ),
                          ],
                        ),
                      // ── Stats row ─────────────────────────────────────────
                      if (record.checkIn != null) ...[
                        const SizedBox(height: 10),
                        Container(height: 1, color: _border),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _InfoTileSmall(
                              icon: Icons.route_rounded,
                              iconColor: _violet,
                              label: 'Distance',
                              value: '${record.kmCovered.toStringAsFixed(1)} km',
                            ),
                            _InfoTileSmall(
                              icon: Icons.place_rounded,
                              iconColor: _faGreen,
                              label: 'Fields',
                              value: '${record.fieldsVisited}',
                            ),
                          ],
                        ),
                      ],
                      // ── Location row ──────────────────────────────────────
                      if (record.checkInLat != null || record.checkOutLat != null) ...[
                        const SizedBox(height: 10),
                        Container(height: 1, color: _border),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (record.checkInLat != null)
                              Expanded(
                                child: _LocationTile(
                                  label:    'Check-In Location',
                                  lat:      record.checkInLat!,
                                  lng:      record.checkInLng!,
                                  color:    _faGreen,
                                ),
                              ),
                            if (record.checkInLat != null && record.checkOutLat != null)
                              const SizedBox(width: 8),
                            if (record.checkOutLat != null)
                              Expanded(
                                child: _LocationTile(
                                  label:    'Check-Out Location',
                                  lat:      record.checkOutLat!,
                                  lng:      record.checkOutLng!,
                                  color:    _rose,
                                ),
                              ),
                          ],
                        ),
                      ],
                      // ── Checkout reason ───────────────────────────────────
                      if (record.checkoutReason != null &&
                          record.checkoutReason!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(height: 1, color: _border),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: _amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.info_outline_rounded,
                                  size: 13, color: _amber),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Early Checkout Reason',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: _amber)),
                                  const SizedBox(height: 2),
                                  Text(record.checkoutReason!,
                                      style: const TextStyle(
                                          fontSize: 12, color: _ink600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      // ── Status pills ──────────────────────────────────────
                      if (record.checkIn != null) ...[
                        const SizedBox(height: 10),
                        Container(height: 1, color: _border),
                        const SizedBox(height: 10),
                      ],
                      Row(children: [
                        if (auto != null) ...[
                          const Text('Auto ',
                              style: TextStyle(fontSize: 11, color: _ink400)),
                          _StatusPill(status: auto),
                          const SizedBox(width: 10),
                        ],
                        if (hasOverride && eff != null) ...[
                          const Icon(Icons.arrow_right_alt_rounded,
                              size: 14, color: _ink400),
                          const SizedBox(width: 4),
                          _StatusPill(status: eff, isOverride: true),
                        ],
                      ]),
                    ],
                  ),
                ),

                // Override banner
                if (hasOverride && record.overrideReason != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _amber.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: _amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              size: 14,
                              color: _amber),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'By ${record.overrideBy ?? "Admin"}'
                                '${record.overrideAt != null ? '  ·  ${DateFormat("d MMM").format(record.overrideAt!)}' : ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _amber,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                record.overrideReason!,
                                style: const TextStyle(
                                    fontSize: 12.5, color: _ink600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _ActivityTimeline(record: record, hasOverride: hasOverride),
                const SizedBox(height: 18),
              ],

              // Status picker
              const _SectionLabel(label: 'SET OVERRIDE STATUS'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AttendanceStatus.values.map((s) {
                  final active = _pickedStatus == s;
                  final col    = _statusColor(s);
                  return GestureDetector(
                    onTap: () => setState(() => _pickedStatus = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: active ? col : _statusBg(s),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: active ? col : col.withValues(alpha: 0.3),
                          width: active ? 1.5 : 1,
                        ),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: col.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7, height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active ? Colors.white : col,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _statusLabel(s),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : col,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Reason field
              if (_pickedStatus != null) ...[
                const SizedBox(height: 16),
                const _SectionLabel(label: 'REASON (REQUIRED)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _reasonCtrl,
                  onChanged: (_) => setState(() {}),
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13.5, color: _ink900),
                  decoration: InputDecoration(
                    hintText: 'Minimum 10 characters…',
                    hintStyle:
                        const TextStyle(fontSize: 13, color: _ink400),
                    filled: true,
                    fillColor: _surface,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _pickedStatus != null
                            ? _statusColor(_pickedStatus!)
                            : _faGreen,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // Action buttons
              Row(children: [
                if (hasOverride) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isClearing ? null : _clearOverride,
                      icon: _isClearing
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _rose))
                          : const Icon(Icons.undo_rounded, size: 15),
                      label: const Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _rose),
                        foregroundColor: _rose,
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _canSave ? _save : null,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Save Override'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pickedStatus != null
                          ? _statusColor(_pickedStatus!)
                          : _faGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final adminName =
          ref.read(currentUserProvider)?.displayName ?? 'Admin';
      await ref.read(adminAttRepoProvider).overrideDay(
        uid:       widget.user.employeeId ?? widget.user.uid,
        year:      widget.year,
        month:     widget.month,
        day:       widget.date.day,
        status:    _pickedStatus!,
        reason:    _reasonCtrl.text.trim(),
        adminName: adminName,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Override saved'),
          backgroundColor: _faGreen,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: _rose,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _clearOverride() async {
    setState(() => _isClearing = true);
    try {
      await ref.read(adminAttRepoProvider).clearOverride(
        uid:   widget.user.employeeId ?? widget.user.uid,
        year:  widget.year,
        month: widget.month,
        day:   widget.date.day,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Override cleared'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: _rose,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAB 3 — REPORT
// ─────────────────────────────────────────────────────────────────────────────
class _ReportTab extends ConsumerStatefulWidget {
  const _ReportTab();
  @override
  ConsumerState<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends ConsumerState<_ReportTab>
    with AutomaticKeepAliveClientMixin {
  int _year  = DateTime.now().year;
  int _month = DateTime.now().month;
  _ReportRole _role = _ReportRole.all;

  @override
  bool get wantKeepAlive => true;

  bool get _canGoNext {
    final now = DateTime.now();
    return _year < now.year || (_year == now.year && _month < now.month);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(adminReportProvider((year: _year, month: _month)));

    return ColoredBox(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Month picker ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month navigation
                  Row(children: [
                    _NavArrow(
                      icon: Icons.chevron_left_rounded,
                      onTap: () {
                        final d = DateTime(_year, _month - 1);
                        setState(
                            () { _year = d.year; _month = d.month; });
                      },
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            DateFormat('MMMM yyyy')
                                .format(DateTime(_year, _month)),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _ink900,
                            ),
                          ),
                          const Text(
                            'Attendance Report',
                            style: TextStyle(
                                fontSize: 11, color: _ink400),
                          ),
                        ],
                      ),
                    ),
                    _NavArrow(
                      icon: Icons.chevron_right_rounded,
                      enabled: _canGoNext,
                      onTap: _canGoNext
                          ? () {
                              final d = DateTime(_year, _month + 1);
                              setState(() {
                                _year = d.year;
                                _month = d.month;
                              });
                            }
                          : () {},
                    ),
                  ]),

                  const SizedBox(height: 14),
                  Container(height: 1, color: _border),
                  const SizedBox(height: 12),

                  // Role filter
                  SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: _ReportRole.values.map((r) {
                    final active = r == _role;
                    final label  = switch (r) {
                      _ReportRole.all   => 'All',
                      _ReportRole.fa    => 'Field Advisors',
                      _ReportRole.clerk => 'Clerks',
                    };
                    final color = switch (r) {
                      _ReportRole.all   => _navy,
                      _ReportRole.fa    => _faGreen,
                      _ReportRole.clerk => _clBlue,
                    };
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _role = r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: active
                                ? LinearGradient(
                                    colors: [
                                      color,
                                      color.withValues(alpha: 0.75)
                                    ],
                                  )
                                : null,
                            color: active ? null : _bg,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: active ? color : _border,
                            ),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : _ink400,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList()),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Report content ────────────────────────────────────────────────
            async.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: CircularProgressIndicator(
                      color: _faGreen, strokeWidth: 2.5),
                ),
              ),
              error: (e, _) => Center(
                child: Text('$e',
                    style: const TextStyle(color: _rose)),
              ),
              data: (report) {
                final employees = _filter(report.employees);
                final totalP = employees.fold(
                    0, (s, e) => s + e.summary.presentCount);
                final totalL = employees.fold(
                    0, (s, e) => s + e.summary.lateCount);
                final totalA = employees.fold(
                    0, (s, e) => s + e.summary.absentCount);
                final totalLv = employees.fold(
                    0, (s, e) => s + e.summary.leaveCount);
                final totalWd = employees.fold(
                    0, (s, e) => s + e.summary.workingDays);
                final rate = totalWd == 0
                    ? 0.0
                    : ((totalP + totalL) / totalWd * 100)
                        .clamp(0.0, 100.0);
                final rateColor = rate >= 80
                    ? _faGreen
                    : rate >= 60
                        ? _amber
                        : _rose;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary dashboard card
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_navy, _navyMid],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _navy.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Top: overall rate + overrides
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(18, 18, 18, 14),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${rate.round()}%',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        color: rateColor == _rose
                                            ? const Color(0xFFFF8080)
                                            : rateColor == _amber
                                                ? const Color(0xFFFCD34D)
                                                : const Color(0xFF6EE7B7),
                                        height: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Overall attendance rate',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (report.totalOverrides > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _amber.withValues(alpha: 0.18),
                                    borderRadius:
                                        BorderRadius.circular(22),
                                    border: Border.all(
                                        color: _amber.withValues(
                                            alpha: 0.4)),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                            Icons.edit_note_rounded,
                                            size: 13,
                                            color: _amber),
                                        const SizedBox(width: 5),
                                        Text(
                                          '${report.totalOverrides} override${report.totalOverrides > 1 ? 's' : ''}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: _amber,
                                          ),
                                        ),
                                      ]),
                                ),
                            ]),
                          ),

                          // Stat tiles row
                          Container(
                            margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                _DashStat(
                                    count: employees.length,
                                    label: 'Employees',
                                    color: Colors.white),
                                _DashStatDivider(),
                                _DashStat(
                                    count: totalP,
                                    label: 'Present',
                                    color: const Color(0xFF6EE7B7)),
                                _DashStatDivider(),
                                _DashStat(
                                    count: totalL,
                                    label: 'Late',
                                    color: const Color(0xFFFCD34D)),
                                _DashStatDivider(),
                                _DashStat(
                                    count: totalA,
                                    label: 'Absent',
                                    color: const Color(0xFFFF8080)),
                                _DashStatDivider(),
                                _DashStat(
                                    count: totalLv,
                                    label: 'Leave',
                                    color: const Color(0xFF93C5FD)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const _SectionLabel(label: 'EMPLOYEE BREAKDOWN'),
                    const SizedBox(height: 10),

                    // Employee rows
                    ...employees.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ReportEmployeeRow(
                            report: e,
                            totalWorkingDays:
                                DateTime(_year, _month + 1, 0).day,
                          ),
                        )),

                    const SizedBox(height: 18),

                    // Export button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _exportCsv(context, report, employees),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Export CSV Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<EmployeeMonthReport> _filter(List<EmployeeMonthReport> all) =>
      switch (_role) {
        _ReportRole.all   => all,
        _ReportRole.fa    => all.where((e) => e.user.isFieldAdvisor).toList(),
        _ReportRole.clerk => all.where((e) => e.user.isClerk).toList(),
      };

  Future<void> _exportCsv(
      BuildContext context,
      ReportData report,
      List<EmployeeMonthReport> employees) async {
    final lastDay    = DateTime(_year, _month + 1, 0).day;
    final monthLabel =
        DateFormat('MMMM yyyy').format(DateTime(_year, _month));

    final sb = StringBuffer();
    sb.writeln('Kiba App — Attendance Report: $monthLabel');
    sb.writeln(
        'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}');
    sb.writeln();

    final dayNums =
        List.generate(lastDay, (i) => '${i + 1}').join(',');
    sb.writeln('Name,Role,$dayNums,Present,Late,Absent,Leave,Rate%');

    for (final e in employees) {
      final cells = List.generate(lastDay, (i) {
        final d       = i + 1;
        final weekday = DateTime(_year, _month, d).weekday;
        if (weekday >= DateTime.saturday) return 'WE';
        final s = e.records[d]?.effectiveStatus;
        return switch (s) {
          null                                  => '-',
          AttendanceStatus.present              => 'P',
          AttendanceStatus.late                 => 'L',
          AttendanceStatus.absent               => 'A',
          AttendanceStatus.leave                => 'Lv',
          AttendanceStatus.holiday              => 'H',
          AttendanceStatus.earlyCheckout        => 'EC',
          AttendanceStatus.visitThresholdNotMet => 'VN',
          AttendanceStatus.distanceNotMet       => 'DN',
        };
      }).join(',');

      final wd   = e.summary.workingDays;
      final rate = wd == 0
          ? '0.0'
          : ((e.summary.presentCount + e.summary.lateCount) / wd * 100)
              .toStringAsFixed(1);

      final role = e.user.isFieldAdvisor ? 'FA' : 'Clerk';
      sb.writeln(
          '${e.user.displayName},$role,$cells,${e.summary.presentCount},${e.summary.lateCount},${e.summary.absentCount},${e.summary.leaveCount},$rate%');
    }

    final csv      = sb.toString();
    final filename =
        'Attendance_${_year}_${_month.toString().padLeft(2, '0')}.csv';

    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: filename,
        text: 'Kiba Attendance Report — $monthLabel',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: _rose,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

class _ReportEmployeeRow extends StatelessWidget {
  const _ReportEmployeeRow(
      {required this.report, required this.totalWorkingDays});
  final EmployeeMonthReport report;
  final int totalWorkingDays;

  @override
  Widget build(BuildContext context) {
    final u     = report.user;
    final s     = report.summary;
    final color = u.isFieldAdvisor ? _faGreen : _clBlue;
    final wd    = s.workingDays;
    final rate  = wd == 0 ? 0.0 : ((s.presentCount + s.lateCount) / wd);
    final rateColor = rate >= 0.8
        ? _faGreen
        : rate >= 0.6
            ? _amber
            : _rose;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _AttAvatar(name: u.displayName, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      u.displayName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _ink900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      u.isFieldAdvisor ? 'FA' : 'Cl',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                // Mini count chips
                Row(children: [
                  _MiniDot(count: s.presentCount, color: _faGreen),
                  const SizedBox(width: 6),
                  _MiniDot(count: s.lateCount, color: _amber),
                  const SizedBox(width: 6),
                  _MiniDot(count: s.absentCount, color: _rose),
                  const SizedBox(width: 6),
                  _MiniDot(count: s.leaveCount, color: _clBlue),
                ]),
                const SizedBox(height: 6),
                // Rate bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate,
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(rate * 100).round()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: rateColor,
                ),
              ),
              Text(
                '${s.presentCount + s.lateCount}/$wd d',
                style: const TextStyle(fontSize: 10, color: _ink400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});
  final double progress;
  final Color  color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width / 2;
    final cy     = size.height / 2;
    const sw     = 9.0;
    final radius = (size.width - sw) / 2;
    final rect   = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    canvas.drawArc(
      rect, -math.pi / 2, 2 * math.pi, false,
      Paint()
        ..color = color.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    canvas.drawArc(
      rect, -math.pi / 2, 2 * math.pi * progress, false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _AttAvatar extends StatelessWidget {
  const _AttAvatar({
    required this.name,
    required this.color,
    this.size = 40,
  });
  final String name;
  final Color  color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.65)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      );
}

class _CountChip extends StatelessWidget {
  const _CountChip(
      {required this.count, required this.label, required this.color});
  final int    count;
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: _ink400),
            ),
          ]),
        ),
      );
}

class _LegendChip extends StatelessWidget {
  const _LegendChip(
      {required this.color, required this.label, required this.count});
  final Color  color;
  final String label;
  final int    count;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 3),
              Text(
                '$count',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color),
              ),
            ]),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: _ink400),
            ),
          ]),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, this.isOverride = false});
  final AttendanceStatus status;
  final bool isOverride;

  @override
  Widget build(BuildContext context) {
    final col = _statusColor(status);
    final bg  = _statusBg(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: col.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 5, height: 5,
          decoration: BoxDecoration(shape: BoxShape.circle, color: col),
        ),
        const SizedBox(width: 5),
        Text(
          _statusLabel(status),
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: col),
        ),
        if (isOverride) ...[
          const SizedBox(width: 4),
          Icon(Icons.admin_panel_settings_rounded, size: 10, color: col),
        ],
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 3, height: 13,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_amber, Color(0xFFFBBF24)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _ink600,
            letterSpacing: 0.6,
          ),
        ),
      ]);
}

class _InfoTileSmall extends StatelessWidget {
  const _InfoTileSmall({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color    iconColor;
  final String   label, value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: _ink900),
          ),
          Text(label,
              style: const TextStyle(fontSize: 9, color: _ink400)),
        ],
      );
}

class _NavArrow extends StatelessWidget {
  const _NavArrow(
      {required this.icon, required this.onTap, this.enabled = true});
  final IconData     icon;
  final VoidCallback onTap;
  final bool         enabled;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: enabled ? _bg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: enabled ? _border : Colors.transparent),
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? _ink600 : const Color(0xFFD1D5DB),
          ),
        ),
      );
}


class _MiniDot extends StatelessWidget {
  const _MiniDot({required this.count, required this.color});
  final int   count;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      );
}

class _DashStat extends StatelessWidget {
  const _DashStat(
      {required this.count, required this.label, required this.color});
  final int    count;
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(
            '$count',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: color),
          ),
          Text(
            label,
            style: TextStyle(
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
          ),
        ]),
      );
}

class _DashStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 28,
        color: Colors.white.withValues(alpha: 0.1),
      );
}

// ── Location tile with Google Maps link ───────────────────────────────────────
class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.label,
    required this.lat,
    required this.lng,
    required this.color,
  });
  final String label;
  final double lat, lng;
  final Color  color;

  Future<void> _openMaps() async {
    final uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openMaps,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_rounded, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  Text(
                    '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 9.5, color: _ink400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 11, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

// ── Duration formatter ─────────────────────────────────────────────────────────
String _fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}m';
  return '${h}h ${m}m';
}
