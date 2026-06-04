import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kiba_app/features/auth/data/user_model.dart';
import 'package:kiba_app/features/field_advisor/data/day_record.dart';
import 'package:kiba_app/features/field_advisor/domain/attendance_calendar_provider.dart';

// ── Period enum ───────────────────────────────────────────────────────────────
enum AttendancePeriod { day, week, month }

// ── Per-employee stat row for a given period ──────────────────────────────────
class EmployeeAttStat {
  const EmployeeAttStat({
    required this.user,
    required this.presentDays,
    required this.lateDays,
    required this.absentDays,
    required this.leaveDays,
    required this.workingDays,
  });

  final UserModel user;
  final int presentDays;
  final int lateDays;
  final int absentDays;
  final int leaveDays;
  final int workingDays; // excludes holidays & weekends

  double get rate => workingDays == 0
      ? 0.0
      : ((presentDays + lateDays) / workingDays).clamp(0.0, 1.0);
}

// ── Aggregated stats (all + FA + Clerk) ───────────────────────────────────────
class PeriodStats {
  const PeriodStats(this.rows);
  final List<EmployeeAttStat> rows;

  List<EmployeeAttStat> get fa    => rows.where((e) => e.user.isFieldAdvisor).toList();
  List<EmployeeAttStat> get clerk => rows.where((e) => e.user.isClerk).toList();

  int _sum(List<EmployeeAttStat> g, int Function(EmployeeAttStat) f) =>
      g.fold(0, (s, e) => s + f(e));

  int presentIn(List<EmployeeAttStat> g) => _sum(g, (e) => e.presentDays);
  int lateIn(List<EmployeeAttStat> g)    => _sum(g, (e) => e.lateDays);
  int absentIn(List<EmployeeAttStat> g)  => _sum(g, (e) => e.absentDays);
  int leaveIn(List<EmployeeAttStat> g)   => _sum(g, (e) => e.leaveDays);
  int workingIn(List<EmployeeAttStat> g) => _sum(g, (e) => e.workingDays);

  double rateOf(List<EmployeeAttStat> g) {
    final w = workingIn(g);
    return w == 0 ? 0.0 : ((presentIn(g) + lateIn(g)) / w).clamp(0.0, 1.0);
  }
}

// ── Report models ─────────────────────────────────────────────────────────────
class EmployeeMonthReport {
  const EmployeeMonthReport({
    required this.user,
    required this.summary,
    required this.records,
  });
  final UserModel user;
  final MonthSummary summary;
  final Map<int, DayRecord> records;
}

class ReportData {
  const ReportData({
    required this.year,
    required this.month,
    required this.employees,
  });
  final int year;
  final int month;
  final List<EmployeeMonthReport> employees;

  int get totalOverrides => employees
      .expand((e) => e.records.values)
      .where((d) => d.adminOverride)
      .length;
}

// ── Repository ────────────────────────────────────────────────────────────────
class AttendanceAdminRepository {
  // ── Batch reads ─────────────────────────────────────────────────────────────

  Future<Map<String, Map<int, DayRecord>>> fetchMonthMatrix(
      List<UserModel> employees, int year, int month) async {
    final results = <String, Map<int, DayRecord>>{};
    await Future.wait(employees.map((u) async {
      final snap = await MonthlyAttendanceDoc.ref(u.employeeId ?? u.uid, year, month).get();
      results[u.uid] = snap.exists && snap.data() != null
          ? MonthlyAttendanceDoc.parse(snap.data()!, year, month)
          : {};
    }));
    return results;
  }

  // ── Period stats computation ─────────────────────────────────────────────────
  // Handles week spanning previous month by fetching two month matrices.

  Future<PeriodStats> computePeriodStats(
    List<UserModel> employees,
    AttendancePeriod period,
    int year,
    int month,
  ) async {
    final now    = DateTime.now();
    final matrix = await fetchMonthMatrix(employees, year, month);
    var   prev   = <String, Map<int, DayRecord>>{};

    if (period == AttendancePeriod.week) {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      if (monday.month != now.month || monday.year != now.year) {
        prev = await fetchMonthMatrix(employees, monday.year, monday.month);
      }
    }

    final rows = employees.map((user) {
      final recs = matrix[user.uid] ?? {};
      switch (period) {
        // ── Today only ──────────────────────────────────────────────────────
        case AttendancePeriod.day:
          final isWorkday = now.weekday < DateTime.saturday;
          if (!isWorkday) {
            return EmployeeAttStat(user: user, presentDays: 0, lateDays: 0,
                absentDays: 0, leaveDays: 0, workingDays: 0);
          }
          final s = recs[now.day]?.effectiveStatus;
          return EmployeeAttStat(
            user:        user,
            presentDays: s == AttendanceStatus.present ? 1 : 0,
            lateDays:    s == AttendanceStatus.late    ? 1 : 0,
            absentDays:  (s == null || s == AttendanceStatus.absent) ? 1 : 0,
            leaveDays:   s == AttendanceStatus.leave   ? 1 : 0,
            workingDays: 1,
          );

        // ── Mon–today ───────────────────────────────────────────────────────
        case AttendancePeriod.week:
          final monday = now.subtract(Duration(days: now.weekday - 1));
          int p = 0, l = 0, a = 0, lv = 0, w = 0;
          var cursor = monday;
          while (!cursor.isAfter(now)) {
            if (cursor.weekday < DateTime.saturday) {
              final dayRecs =
                  (cursor.month == now.month && cursor.year == now.year)
                      ? recs
                      : (prev[user.uid] ?? {});
              final s = dayRecs[cursor.day]?.effectiveStatus;
              if (s != AttendanceStatus.holiday) {
                w++;
                switch (s ?? AttendanceStatus.absent) {
                  case AttendanceStatus.present: p++;  break;
                  case AttendanceStatus.late:    l++;  break;
                  case AttendanceStatus.absent:  a++;  break;
                  case AttendanceStatus.leave:   lv++; break;
                  default: break;
                }
              }
            }
            cursor = cursor.add(const Duration(days: 1));
          }
          return EmployeeAttStat(
            user: user,
            presentDays: p, lateDays: l,
            absentDays: a, leaveDays: lv,
            workingDays: w,
          );

        // ── Full month ──────────────────────────────────────────────────────
        case AttendancePeriod.month:
          final s = MonthSummary.compute(recs, year, month);
          return EmployeeAttStat(
            user:        user,
            presentDays: s.presentCount,
            lateDays:    s.lateCount,
            absentDays:  s.absentCount,
            leaveDays:   s.leaveCount,
            workingDays: s.workingDays,
          );
      }
    }).toList();

    return PeriodStats(rows);
  }

  // ── Single-employee month stream ─────────────────────────────────────────────
  Stream<Map<int, DayRecord>> streamEmployeeMonth(String uid, int year, int month) {
    return MonthlyAttendanceDoc.ref(uid, year, month).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return {};
      return MonthlyAttendanceDoc.parse(snap.data()!, year, month);
    });
  }

  // ── Override write ───────────────────────────────────────────────────────────
  // Uses update() with dot-notation keys to touch only the override fields,
  // leaving check-in/checkout/km data intact. Falls back to set() when the
  // monthly document doesn't exist yet (employee never checked in this month).
  Future<void> overrideDay({
    required String uid,
    required int year,
    required int month,
    required int day,
    required AttendanceStatus status,
    required String reason,
    required String adminName,
  }) async {
    final ref  = MonthlyAttendanceDoc.ref(uid, year, month);
    final data = {
      'days.$day.admin_override':  true,
      'days.$day.override_status': status.firestoreValue,
      'days.$day.override_reason': reason,
      'days.$day.override_by':     adminName,
      'days.$day.override_at':     Timestamp.fromDate(DateTime.now()),
    };
    try {
      await ref.update(data);
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        await ref.set({
          'days': {
            '$day': {
              'auto_status':     AttendanceStatus.absent.firestoreValue,
              'admin_override':  true,
              'override_status': status.firestoreValue,
              'override_reason': reason,
              'override_by':     adminName,
              'override_at':     Timestamp.fromDate(DateTime.now()),
            }
          }
        });
      } else {
        rethrow;
      }
    }
  }

  // ── Override clear ───────────────────────────────────────────────────────────
  Future<void> clearOverride({
    required String uid,
    required int year,
    required int month,
    required int day,
  }) async {
    await MonthlyAttendanceDoc.ref(uid, year, month).update({
      'days.$day.admin_override':  false,
      'days.$day.override_status': FieldValue.delete(),
      'days.$day.override_reason': FieldValue.delete(),
      'days.$day.override_by':     FieldValue.delete(),
      'days.$day.override_at':     FieldValue.delete(),
    });
  }
}
