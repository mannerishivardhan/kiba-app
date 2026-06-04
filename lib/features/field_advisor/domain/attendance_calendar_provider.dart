import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiba_app/core/domain/threshold_provider.dart';
import 'package:kiba_app/core/models/attendance_threshold.dart';
import 'package:kiba_app/features/auth/data/user_model.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';
import 'package:kiba_app/features/field_advisor/data/day_record.dart';

// ignore_for_file: avoid_catches_without_on_clauses

// ── Monthly summary (computed locally from records) ───────────────────────────
class MonthSummary {
  const MonthSummary({
    this.presentCount = 0,
    this.lateCount    = 0,
    this.absentCount  = 0,
    this.leaveCount   = 0,
    this.streak       = 0,
    this.workingDays  = 0,
  });

  final int presentCount;
  final int lateCount;
  final int absentCount;
  final int leaveCount;
  final int streak;
  final int workingDays;

  double get attendancePercent {
    if (workingDays == 0) return 0;
    return ((presentCount + lateCount) / workingDays).clamp(0.0, 1.0);
  }

  static MonthSummary compute(
      Map<int, DayRecord> records, int year, int month) {
    final now        = DateTime.now();
    final isCurrent  = now.year == year && now.month == month;
    final lastDay    = isCurrent ? now.day : DateTime(year, month + 1, 0).day;

    int present = 0, late = 0, absent = 0, leave = 0, working = 0;

    for (int d = 1; d <= lastDay; d++) {
      final weekday = DateTime(year, month, d).weekday;
      if (weekday == DateTime.saturday || weekday == DateTime.sunday) continue;
      working++;
      switch (records[d]?.effectiveStatus ?? AttendanceStatus.absent) {
        case AttendanceStatus.present:              present++; break;
        case AttendanceStatus.late:                 late++;    break;
        case AttendanceStatus.absent:
        case AttendanceStatus.earlyCheckout:
        case AttendanceStatus.visitThresholdNotMet:
        case AttendanceStatus.distanceNotMet:
          absent++;
          break;
        case AttendanceStatus.leave:   leave++;   break;
        case AttendanceStatus.holiday: break;
      }
    }

    // Streak — consecutive present/late working days ending today
    int streak  = 0;
    DateTime cursor = now;
    while (cursor.month == month && cursor.year == year) {
      if (cursor.weekday == DateTime.saturday ||
          cursor.weekday == DateTime.sunday) {
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      final s = records[cursor.day]?.effectiveStatus;
      if (s == AttendanceStatus.present || s == AttendanceStatus.late) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return MonthSummary(
      presentCount: present,
      lateCount:    late,
      absentCount:  absent,
      leaveCount:   leave,
      streak:       streak,
      workingDays:  working,
    );
  }
}

// ── State ─────────────────────────────────────────────────────────────────────
class AttendanceCalendarState {
  const AttendanceCalendarState({
    required this.year,
    required this.month,
    this.records      = const {},
    this.summary      = const MonthSummary(),
    this.selectedDate,
    this.isLoading    = true,
    this.isRefreshing = false,
  });

  final int  year;
  final int  month;
  final Map<int, DayRecord> records;
  final MonthSummary summary;
  final DateTime? selectedDate;
  final bool isLoading;     // true only on very first load (no cache)
  final bool isRefreshing;  // true while background server fetch is in progress

  DayRecord? get selectedRecord =>
      selectedDate != null ? records[selectedDate!.day] : null;

  AttendanceCalendarState copyWith({
    int? year,
    int? month,
    Map<int, DayRecord>? records,
    MonthSummary? summary,
    DateTime? selectedDate,
    bool clearSelection = false,
    bool? isLoading,
    bool? isRefreshing,
  }) {
    return AttendanceCalendarState(
      year:         year        ?? this.year,
      month:        month       ?? this.month,
      records:      records     ?? this.records,
      summary:      summary     ?? this.summary,
      selectedDate: clearSelection ? null : (selectedDate ?? this.selectedDate),
      isLoading:    isLoading   ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class AttendanceCalendarNotifier
    extends StateNotifier<AttendanceCalendarState> {

  AttendanceCalendarNotifier(this._ref)
      : super(AttendanceCalendarState(
          year:  DateTime.now().year,
          month: DateTime.now().month,
        )) {
    // Try immediately in case the user is already available (session restore).
    // Also listen so the first login after a cold start triggers the load.
    _ref.listen<UserModel?>(currentUserProvider, (prev, next) {
      if (next != null && prev?.uid != next.uid) {
        loadMonth(DateTime.now().year, DateTime.now().month);
      }
    });
    loadMonth(DateTime.now().year, DateTime.now().month);
  }

  final Ref _ref;

  String? get _uid   => _ref.read(currentUserProvider)?.uid;
  String? get _empId => _ref.read(currentUserProvider)?.employeeId;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// SWR: serve cache instantly → fetch server in background → update if different.
  Future<void> loadMonth(int year, int month) async {
    final empId = _empId;
    if (empId == null) return;

    state = state.copyWith(
      year: year, month: month,
      records: {}, summary: const MonthSummary(),
      isLoading: true, isRefreshing: false,
    );

    final docRef = MonthlyAttendanceDoc.ref(empId, year, month);

    // ── Step 1: Serve from disk cache instantly ────────────────────────────
    // UI renders immediately — no loading spinner for returning users.
    try {
      final cached = await docRef.get(const GetOptions(source: Source.cache));
      if (cached.exists && cached.data() != null && mounted) {
        final records = MonthlyAttendanceDoc.parse(cached.data()!, year, month);
        state = state.copyWith(
          records:      records,
          summary:      MonthSummary.compute(records, year, month),
          isLoading:    false,   // cache is ready — hide spinner
          isRefreshing: true,    // server check in progress
        );
      }
    } catch (_) {
      // No disk cache yet — first ever open. Server fetch below will handle it.
    }

    // ── Step 2: Fetch from server silently in background ───────────────────
    // UI already showing cached data. Server fetch updates only if changed.
    try {
      final fresh = await docRef.get(const GetOptions(source: Source.server));
      if (!mounted) return;

      final records = fresh.exists && fresh.data() != null
          ? MonthlyAttendanceDoc.parse(fresh.data()!, year, month)
          : <int, DayRecord>{};

      state = state.copyWith(
        records:      records,
        summary:      MonthSummary.compute(records, year, month),
        isLoading:    false,
        isRefreshing: false,
      );
    } catch (_) {
      // Server unreachable — cached data stays, just stop the refresh indicator.
      if (mounted) state = state.copyWith(isLoading: false, isRefreshing: false);
    }
  }

  /// Pull-to-refresh — forces a fresh server fetch regardless of cache.
  Future<void> refresh() => loadMonth(state.year, state.month);

  void goToPreviousMonth() {
    final d = DateTime(state.year, state.month - 1);
    loadMonth(d.year, d.month);
  }

  void goToNextMonth() {
    final now = DateTime.now();
    final d   = DateTime(state.year, state.month + 1);
    if (d.year > now.year || (d.year == now.year && d.month > now.month)) return;
    loadMonth(d.year, d.month);
  }

  void selectDay(DateTime date) => state = state.copyWith(selectedDate: date);
  void clearSelection()         => state = state.copyWith(clearSelection: true);

  /// Writes today's record. UI updates immediately from local state while
  /// Firestore write completes in the background.
  Future<void> upsertToday({
    DateTime? checkIn,
    DateTime? checkOut,
    double? checkInLat,
    double? checkInLng,
    double? checkOutLat,
    double? checkOutLng,
    double? kmCovered,
    int? fieldsVisited,
    bool isEarlyCheckout = false,
    String? checkoutReason,
  }) async {
    final uid   = _uid;
    final empId = _empId;
    if (uid == null || empId == null) return;

    final today = DateTime.now();
    final t     = _ref.read(thresholdProvider).valueOrNull
        ?? const AttendanceThreshold();

    final existing = state.records[today.day];
    final ci       = checkIn       ?? existing?.checkIn;
    final co       = checkOut      ?? existing?.checkOut;
    final ciLat    = checkInLat    ?? existing?.checkInLat;
    final ciLng    = checkInLng    ?? existing?.checkInLng;
    final coLat    = checkOutLat   ?? existing?.checkOutLat;
    final coLng    = checkOutLng   ?? existing?.checkOutLng;
    final km       = kmCovered     ?? existing?.kmCovered     ?? 0;
    final visits   = fieldsVisited ?? existing?.fieldsVisited ?? 0;
    final reason   = checkoutReason ?? existing?.checkoutReason;

    // Determine isEarlyCheckout from duty-hours if not explicitly set
    final effectiveEarly = isEarlyCheckout ||
        (co != null && ci != null &&
            co.difference(ci).inMinutes < (t.minDutyHoursForPresent * 60).round());

    final record = DayRecord(
      date:           today,
      checkIn:        ci,
      checkOut:       co,
      checkInLat:     ciLat,
      checkInLng:     ciLng,
      checkOutLat:    coLat,
      checkOutLng:    coLng,
      kmCovered:      km,
      fieldsVisited:  visits,
      autoStatus:     _computeStatus(
        checkIn:        ci,
        checkOut:       co,
        km:             km,
        visits:         visits,
        isEarlyCheckout: effectiveEarly,
        t:              t,
      ),
      checkoutReason: reason,
      adminOverride:  existing?.adminOverride  ?? false,
      overrideStatus: existing?.overrideStatus,
      overrideReason: existing?.overrideReason,
      overrideBy:     existing?.overrideBy,
      overrideAt:     existing?.overrideAt,
    );

    // Update local state instantly — FA sees result before Firestore confirms.
    final updated = Map<int, DayRecord>.from(state.records)..[today.day] = record;
    state = state.copyWith(
      records: updated,
      summary: MonthSummary.compute(updated, today.year, today.month),
    );

    // Write to Firestore — 1 write, merged into the monthly document.
    await MonthlyAttendanceDoc.ref(empId, today.year, today.month).set(
      {'days': {today.day.toString(): record.toMap()}},
      SetOptions(merge: true),
    );

    // Write an alert when checkout completes and status warrants admin attention.
    if (checkOut != null) {
      _writeCheckoutAlert(uid, record.autoStatus, today).catchError((_) {});
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  AttendanceStatus _computeStatus({
    required DateTime? checkIn,
    required DateTime? checkOut,
    required double km,
    required int visits,
    required bool isEarlyCheckout,
    required AttendanceThreshold t,
  }) {
    if (checkIn == null) return AttendanceStatus.absent;

    final cutoff = t.lateCheckinCutoff;
    final tod    = TimeOfDay.fromDateTime(checkIn);
    final isLate = tod.hour > cutoff.hour ||
        (tod.hour == cutoff.hour && tod.minute > cutoff.minute);

    // Day in progress (no checkout) — preliminary status only.
    if (checkOut == null) {
      return isLate ? AttendanceStatus.late : AttendanceStatus.present;
    }

    // Day complete — apply all rules in priority order.
    if (isEarlyCheckout)              return AttendanceStatus.earlyCheckout;
    if (visits < t.minVisitsForPresent) return AttendanceStatus.visitThresholdNotMet;
    if (km < t.minKmForPresent)         return AttendanceStatus.distanceNotMet;
    return isLate ? AttendanceStatus.late : AttendanceStatus.present;
  }

  Future<void> _writeCheckoutAlert(
      String uid, AttendanceStatus status, DateTime date) async {
    String? type;
    String? message;
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    switch (status) {
      case AttendanceStatus.late:
        type    = 'late_checkin';
        message = 'Checked in late on $dateStr.';
        break;
      case AttendanceStatus.earlyCheckout:
        type    = 'early_checkout';
        message = 'Early checkout recorded on $dateStr.';
        break;
      case AttendanceStatus.visitThresholdNotMet:
        type    = 'visit_threshold_not_met';
        message = 'Visit threshold not met on $dateStr.';
        break;
      case AttendanceStatus.distanceNotMet:
        type    = 'distance_not_met';
        message = 'Distance threshold not met on $dateStr.';
        break;
      default:
        return;
    }
    final userName = _ref.read(currentUserProvider)?.displayName;
    await FirebaseFirestore.instance.collection('alerts').add({
      'uid':       uid,
      'user_name': userName,
      'type':      type,
      'date':      Timestamp.fromDate(date),
      'message':   message,
      'isRead':    false,
      'readBy':    null,
      'readAt':    null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final attendanceCalendarProvider = StateNotifierProvider<
    AttendanceCalendarNotifier, AttendanceCalendarState>(
  (ref) => AttendanceCalendarNotifier(ref),
);
