import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiba_app/features/admin/data/user_repository.dart';
import 'package:kiba_app/features/auth/data/user_model.dart';
import 'package:kiba_app/features/field_advisor/data/day_record.dart';
import 'package:kiba_app/features/field_advisor/data/leave_model.dart';
import 'package:kiba_app/features/field_advisor/data/visit_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────
final userAdminRepoProvider =
    Provider<UserAdminRepository>((_) => UserAdminRepository());

// ── All employees (non-admin) stream ─────────────────────────────────────────
final allEmployeesProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(userAdminRepoProvider).streamAllEmployees();
});

// ── Per-employee stats ────────────────────────────────────────────────────────
class EmployeeStats {
  const EmployeeStats({
    required this.distanceTodayKm,
    required this.distanceMonthKm,
    required this.visitsMonth,
    required this.attendancePresent,
    required this.attendanceDays,
    required this.leavesApplied,
    required this.leavesApproved,
    required this.leavesPending,
    required this.leavesDeclined,
    this.lastVisitDate,
  });

  final double distanceTodayKm;
  final double distanceMonthKm;
  final int    visitsMonth;
  final int    attendancePresent;
  final int    attendanceDays;
  final int    leavesApplied;
  final int    leavesApproved;
  final int    leavesPending;
  final int    leavesDeclined;
  final DateTime? lastVisitDate;
}

/// Fetches all stats for one employee in parallel. autoDispose so it frees
/// memory when the expanded card goes off-screen.
final employeeStatsProvider =
    FutureProvider.family.autoDispose<EmployeeStats, String>((ref, uid) async {
  final fs         = FirebaseFirestore.instance;
  final now        = DateTime.now();
  final today      = DateTime(now.year, now.month, now.day);
  final monthStart = DateTime(now.year, now.month, 1);

  // Fire all queries in parallel — create futures first, await after
  final visitFuture = fs
      .collection('visits')
      .where('uid', isEqualTo: uid)
      .orderBy('check_in', descending: true)
      .get();

  final attFuture = MonthlyAttendanceDoc.ref(uid, now.year, now.month).get();

  final leaveFuture =
      fs.collection('leaves').where('uid', isEqualTo: uid).get();

  final visitSnap = await visitFuture;
  final attSnap   = await attFuture;
  final leaveSnap = await leaveFuture;

  // ── Visits ──────────────────────────────────────────────────────────────
  final visits      = visitSnap.docs.map(VisitModel.fromDoc).toList();
  final monthVisits = visits.where((v) => !v.checkIn.isBefore(monthStart)).toList();
  final todayVisits = visits.where((v) => !v.checkIn.isBefore(today)).toList();

  final distanceMonth = monthVisits.fold(0.0, (s, v) => s + v.distanceFromPrevKm);
  final distanceToday = todayVisits.fold(0.0, (s, v) => s + v.distanceFromPrevKm);
  final lastVisit     = monthVisits.isNotEmpty ? monthVisits.first.checkIn : null;

  // ── Attendance ──────────────────────────────────────────────────────────
  // totalDays = days elapsed so far this month
  int presentDays = 0;
  final totalDays = now.day;
  if (attSnap.exists && attSnap.data() != null) {
    final days = MonthlyAttendanceDoc.parse(attSnap.data()!, now.year, now.month);
    presentDays = days.values
        .where((d) =>
            d.effectiveStatus == AttendanceStatus.present ||
            d.effectiveStatus == AttendanceStatus.late)
        .length;
  }

  // ── Leaves ──────────────────────────────────────────────────────────────
  final statuses = leaveSnap.docs
      .map((d) => LeaveStatusX.fromString(d.data()['status'] as String?))
      .toList();

  return EmployeeStats(
    distanceTodayKm:  distanceToday,
    distanceMonthKm:  distanceMonth,
    visitsMonth:      monthVisits.length,
    attendancePresent: presentDays,
    attendanceDays:   totalDays,
    leavesApplied:    statuses.length,
    leavesApproved:   statuses.where((s) => s == LeaveStatus.approved).length,
    leavesPending:    statuses.where((s) => s == LeaveStatus.pending).length,
    leavesDeclined:   statuses.where((s) => s == LeaveStatus.declined).length,
    lastVisitDate:    lastVisit,
  );
});
