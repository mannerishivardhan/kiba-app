import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kiba_app/core/domain/threshold_provider.dart';
import 'package:kiba_app/core/models/attendance_threshold.dart';
import 'package:kiba_app/core/router/app_router.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';
import 'package:kiba_app/features/field_advisor/data/day_record.dart';
import 'package:kiba_app/features/field_advisor/data/leave_model.dart';
import 'package:kiba_app/features/field_advisor/domain/attendance_calendar_provider.dart';
import 'package:kiba_app/features/field_advisor/domain/attendance_provider.dart';
import 'package:kiba_app/features/field_advisor/domain/leave_provider.dart';
import 'package:kiba_app/features/field_advisor/presentation/widgets/fa_journey_timeline.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _green        = Color(0xFF059669);
const _greenDark    = Color(0xFF047857);
const _blue         = Color(0xFF059669);
const _yellow       = Color(0xFFE8A020);
const _grey         = Color(0xFF6B7280);
const _textPrimary  = Color(0xFF111827);
const _cardBg       = Color(0xFFFFFFFF);
const _bg           = Color(0xFFF4FBF7);

// ── Screen ────────────────────────────────────────────────────────────────────
class FAHomeScreen extends ConsumerWidget {
  const FAHomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    if (h < 21) return 'Good Evening';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user       = ref.watch(currentUserProvider);
    final attendance = ref.watch(attendanceProvider);
    final now        = DateTime.now();
    final name       = user?.displayName ?? 'Field Advisor';

    final calState    = ref.watch(attendanceCalendarProvider);
    final todayStatus = calState.records[now.day]?.effectiveStatus;
    final isHoliday   = todayStatus == AttendanceStatus.holiday;

    // On leave if attendance record already reflects it OR there is an
    // active (pending/approved) leave covering today — catches pending
    // sick/casual leaves that haven't been mapped to attendance yet.
    final leaves    = ref.watch(faLeavesProvider).valueOrNull ?? [];
    final todayOnly = DateTime(now.year, now.month, now.day);
    final isOnLeave = todayStatus == AttendanceStatus.leave ||
        leaves.any((l) {
          if (l.status != LeaveStatus.approved) return false;
          final from = DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day);
          final to   = DateTime(l.toDate.year,   l.toDate.month,   l.toDate.day);
          return !todayOnly.isBefore(from) && !todayOnly.isAfter(to);
        });
    final isRestDay   = isOnLeave || isHoliday;
    final summary     = calState.summary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: CustomScrollView(
          slivers: [
            // ── Gradient header (extends behind status bar) ────────────────
            SliverToBoxAdapter(
              child: _Header(
                name:        name,
                greeting:    _greeting(),
                today:       now,
                attendance:  attendance,
                isOnLeave:   isOnLeave,
                isHoliday:   isHoliday,
              ),
            ),

            // ── Leave / Holiday banner (replaces duty UI) ──────────────────
            if (isRestDay)
              SliverToBoxAdapter(
                child: _LeaveOrHolidayBanner(isLeave: isOnLeave),
              ),

            // ── Normal duty UI ─────────────────────────────────────────────
            if (!isRestDay) ...[
              // Attendance stat cards
              SliverToBoxAdapter(
                child: _AttendanceSection(attendance: attendance, summary: summary),
              ),

              // Slide to Check In (only before first check-in)
              if (!attendance.isCheckedIn)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: _SwipeCheckInButton(attendance: attendance, ref: ref),
                  ),
                ),

              // Journey timeline (after check-in)
              if (attendance.isCheckedIn)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: FAJourneyTimeline(),
                  ),
                ),

              // Slide to Check Out / Done (below journey)
              if (attendance.isCheckedIn)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _SwipeCheckInButton(attendance: attendance, ref: ref),
                  ),
                ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — gradient + greeting + week strip
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.greeting,
    required this.today,
    required this.attendance,
    required this.isOnLeave,
    required this.isHoliday,
  });

  final String          name;
  final String          greeting;
  final DateTime        today;
  final AttendanceState attendance;
  final bool            isOnLeave;
  final bool            isHoliday;

  // Returns (label, dot color) based on actual duty state.
  ({String label, Color dot}) get _badge {
    if (isHoliday)              return (label: 'Holiday',        dot: const Color(0xFF7DD3FC));
    if (isOnLeave)              return (label: 'On Leave',       dot: const Color(0xFF60A5FA));
    if (attendance.isCheckedOut) return (label: 'Done for Today', dot: const Color(0xFFC4B5FD));
    if (attendance.isCheckedIn)  return (label: 'On Duty',        dot: const Color(0xFF6EE7B7));
    return                              (label: 'Not Checked In', dot: Colors.white54);
  }

  String _initials(String n) {
    final parts = n.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return n.isNotEmpty ? n[0].toUpperCase() : 'K';
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_greenDark, _green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: topPad + 16),

          // ── Top row: avatar + greeting + bell ───────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Avatar with white ring
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Greeting + name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name.split(' ').first,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Notification bell
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    // Unread badge
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _yellow,
                          shape: BoxShape.circle,
                          border: Border.all(color: _greenDark, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Date + status row ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    DateFormat('EEEE, dd MMMM yyyy').format(today),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Builder(builder: (_) {
                  final b = _badge;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: b.dot,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          b.label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Week strip ───────────────────────────────────────────────────
          _WeekStrip(today: today),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Week Strip — inside header
// ─────────────────────────────────────────────────────────────────────────────
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.today});
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => today.subtract(Duration(days: 3 - i)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: days.map((d) {
          final isToday = d.day == today.day &&
              d.month == today.month &&
              d.year == today.year;
          return Expanded(child: _DayChip(date: d, isToday: isToday));
        }).toList(),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.date, required this.isToday});
  final DateTime date;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isToday ? Colors.white : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: isToday
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          Text(
            DateFormat('EEE').format(date),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isToday ? _green : Colors.white.withValues(alpha: 0.7),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${date.day}'.padLeft(2, '0'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isToday ? _green : Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          // Dot indicator
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday
                  ? _green
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance stat cards — 2 × 2 grid
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceSection extends StatelessWidget {
  const _AttendanceSection({required this.attendance, required this.summary});
  final AttendanceState attendance;
  final MonthSummary    summary;

  @override
  Widget build(BuildContext context) {
    final checkIn  = attendance.checkInTime;
    final checkOut = attendance.checkOutTime;
    final fmt      = DateFormat('hh:mm a');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: "Today's Attendance"),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.login_rounded,
                  label: 'Check In',
                  value: checkIn != null ? fmt.format(checkIn) : '--:-- --',
                  sub: checkIn != null ? 'On Time' : 'Not yet',
                  accentColor: const Color(0xFF1E3A8A),
                  iconBg: const Color(0xFFEFF6FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.logout_rounded,
                  label: 'Check Out',
                  value: checkOut != null ? fmt.format(checkOut) : '--:-- --',
                  sub: checkOut != null ? 'Done' : 'Not yet',
                  accentColor: const Color(0xFFE8A020),
                  iconBg: const Color(0xFFFEF3C7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.coffee_rounded,
                  label: 'Break Time',
                  value: attendance.isCheckedIn ? '30 min' : '0 min',
                  sub: 'Avg 30 min',
                  accentColor: const Color(0xFFE8A020),
                  iconBg: const Color(0xFFEFF6FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_month_rounded,
                  label: 'Working Days',
                  value: '${summary.presentCount + summary.lateCount}/${summary.workingDays}',
                  sub: 'Present this month',
                  accentColor: const Color(0xFF1E3A8A),
                  iconBg: const Color(0xFFFEF3C7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.accentColor,
    required this.iconBg,
  });

  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color accentColor;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(color: accentColor, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
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
          // Icon + label row
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontSize: 11,
              color: accentColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Swipe to Check In / Check Out
// ─────────────────────────────────────────────────────────────────────────────
class _SwipeCheckInButton extends StatefulWidget {
  const _SwipeCheckInButton({required this.attendance, required this.ref});
  final AttendanceState attendance;
  final WidgetRef ref;

  @override
  State<_SwipeCheckInButton> createState() => _SwipeCheckInButtonState();
}

class _SwipeCheckInButtonState extends State<_SwipeCheckInButton> {
  double _dragX = 0;
  static const double _thumbSize = 56;
  static const double _height    = 68;
  static const double _padding   = 5;

  bool get _isCheckOut => widget.attendance.isCheckedIn && !widget.attendance.isCheckedOut;
  bool get _isDone     => widget.attendance.isCheckedOut;

  Color get _trackColor => _isDone
      ? _green
      : _isCheckOut
          ? _yellow
          : _blue;

  String get _label => _isDone
      ? 'Attendance Complete'
      : _isCheckOut
          ? 'Slide to Check Out'
          : 'Slide to Check In';

  IconData get _thumbIcon => _isDone
      ? Icons.check_circle_rounded
      : _isCheckOut
          ? Icons.logout_rounded
          : Icons.login_rounded;

  void _onDragEnd(double maxWidth) async {
    final dragThreshold = maxWidth - _thumbSize - _padding * 2;
    if (_dragX >= dragThreshold * 0.72) {
      if (_isCheckOut) {
        final t = widget.ref.read(thresholdProvider).valueOrNull
            ?? const AttendanceThreshold();
        final now         = DateTime.now();
        final checkInTime = widget.attendance.checkInTime!;

        // Read live km/visits from today's Firestore-backed record.
        final todayRecord = widget.ref
            .read(attendanceCalendarProvider)
            .records[now.day];
        final km     = todayRecord?.kmCovered     ?? 0.0;
        final visits = todayRecord?.fieldsVisited ?? 0;

        final isEarly         = now.difference(checkInTime).inMinutes <
            (t.minDutyHoursForPresent * 60).round();
        final visitsMissing   = visits < t.minVisitsForPresent;
        final distanceMissing = km     < t.minKmForPresent;

        // Collect every unmet threshold into a single list.
        final violations = <_Violation>[];
        if (isEarly) {
          violations.add(_Violation(
            icon: Icons.access_time_rounded,
            text:
                'Duty time: ${_fmtDur(now.difference(checkInTime))} / '
                '${t.minDutyHoursForPresent.toStringAsFixed(1)} h required',
          ));
        }
        if (visitsMissing) {
          violations.add(_Violation(
            icon: Icons.place_rounded,
            text: 'Fields visited: $visits / ${t.minVisitsForPresent} required',
          ));
        }
        if (distanceMissing) {
          violations.add(_Violation(
            icon: Icons.route_rounded,
            text:
                'Distance: ${km.toStringAsFixed(1)} km / '
                '${t.minKmForPresent.toStringAsFixed(1)} km required',
          ));
        }

        String? reason;

        if (violations.isNotEmpty) {
          // Buzz immediately so the FA feels the alert before reading it.
          HapticFeedback.vibrate();

          if (!mounted) {
            setState(() => _dragX = 0);
            return;
          }

          final result = await _showViolationDialog(
            context,
            violations,
            needsReason: isEarly,
          );
          if (!result.proceed) {
            if (mounted) setState(() => _dragX = 0);
            return;
          }
          reason = result.reason;
        }

        if (mounted) {
          context.go(AppRoutes.faFaceVerify, extra: {
            'isCheckout':      true,
            'isEarlyCheckout': isEarly,
            'checkoutReason':  reason?.isNotEmpty == true ? reason : null,
          });
        }
      } else if (!widget.attendance.isCheckedIn) {
        context.go(AppRoutes.faFaceVerify);
      }
    }
    if (mounted) setState(() => _dragX = 0);
  }

  static String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  Future<({bool proceed, String? reason})> _showViolationDialog(
    BuildContext ctx,
    List<_Violation> violations, {
    required bool needsReason,
  }) async {
    final ctrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding:   const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B), size: 22),
            SizedBox(width: 8),
            Text('Targets Not Met',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "You haven't reached today's targets:",
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 10),
            ...violations.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(v.icon,
                            size: 14, color: const Color(0xFFEF4444)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          v.text,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            if (needsReason) ...[
              const Divider(height: 20),
              const Text(
                'Reason for early checkout (optional):',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  hintText: 'Enter reason…',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Your attendance will be marked accordingly.',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 4),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Check Out Anyway'),
          ),
        ],
      ),
    );

    final text = ctrl.text.trim();
    return (proceed: ok ?? false, reason: text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final maxW   = constraints.maxWidth;
      final trackW = maxW - _thumbSize - _padding * 2;
      final progress = _dragX / trackW;

      return GestureDetector(
        onHorizontalDragUpdate: _isDone
            ? null
            : (d) {
                setState(() {
                  _dragX = (_dragX + d.delta.dx).clamp(0.0, trackW);
                });
              },
        onHorizontalDragEnd: _isDone ? null : (_) => _onDragEnd(maxW),
        child: Container(
          height: _height,
          decoration: BoxDecoration(
            color: _trackColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _trackColor.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Arrow hints in the track
              if (!_isDone)
                Padding(
                  padding: EdgeInsets.only(
                    left: _thumbSize + _padding * 2 + 8,
                    right: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: List.generate(3, (i) {
                      final opacity = ((1 - progress) * (0.3 + i * 0.2)).clamp(0.0, 0.6);
                      return Opacity(
                        opacity: opacity,
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      );
                    }),
                  ),
                ),

              // Label
              AnimatedOpacity(
                duration: const Duration(milliseconds: 100),
                opacity: (1 - progress * 1.5).clamp(0.0, 1.0),
                child: Text(
                  _label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

              // Thumb
              if (!_isDone)
                Positioned(
                  left: _padding + _dragX,
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(_thumbIcon, color: _trackColor, size: 26),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leave / Holiday banner — replaces the duty UI on non-working days
// ─────────────────────────────────────────────────────────────────────────────
class _LeaveOrHolidayBanner extends StatelessWidget {
  const _LeaveOrHolidayBanner({required this.isLeave});
  final bool isLeave;

  @override
  Widget build(BuildContext context) {
    final color = isLeave ? const Color(0xFF7C3AED) : const Color(0xFF0369A1);
    final bg    = isLeave ? const Color(0xFFF5F3FF) : const Color(0xFFE0F2FE);
    final icon  = isLeave ? Icons.event_busy_rounded : Icons.beach_access_rounded;
    final title = isLeave ? "You're on approved leave today" : "Today is a holiday";
    final sub   = isLeave
        ? 'Your leave has been approved. Enjoy your day off!'
        : 'No check-in required. See you tomorrow!';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      height: 1.4,
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared section title
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Violation data holder used by the checkout warning dialog
// ─────────────────────────────────────────────────────────────────────────────
class _Violation {
  const _Violation({required this.icon, required this.text});
  final IconData icon;
  final String   text;
}

// ─────────────────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }
}
