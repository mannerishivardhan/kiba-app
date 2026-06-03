import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiba_app/features/admin/data/attendance_admin_repository.dart';
import 'package:kiba_app/features/admin/domain/user_admin_providers.dart';
import 'package:kiba_app/features/field_advisor/data/day_record.dart';
import 'package:kiba_app/features/field_advisor/domain/attendance_calendar_provider.dart';

// ── Key typedefs ──────────────────────────────────────────────────────────────
typedef EmpMonthKey = ({String uid, int year, int month});
typedef PeriodKey   = ({AttendancePeriod period, int year, int month});

// ── Repository ────────────────────────────────────────────────────────────────
final adminAttRepoProvider =
    Provider<AttendanceAdminRepository>((_) => AttendanceAdminRepository());

// ── Period stats (Day / Week / Month) ─────────────────────────────────────────
// autoDispose: freed when Overview tab leaves the widget tree.
final adminPeriodStatsProvider =
    FutureProvider.family.autoDispose<PeriodStats, PeriodKey>((ref, key) async {
  final employees = await ref.watch(allEmployeesProvider.future);
  return ref
      .read(adminAttRepoProvider)
      .computePeriodStats(employees, key.period, key.year, key.month);
});

// ── Live month stream for one employee (Override tab / calendar sheet) ────────
// autoDispose: freed automatically when the calendar sheet closes.
final adminEmployeeMonthProvider =
    StreamProvider.family.autoDispose<Map<int, DayRecord>, EmpMonthKey>((ref, key) {
  return ref
      .read(adminAttRepoProvider)
      .streamEmployeeMonth(key.uid, key.year, key.month);
});

// ── Full report data for a month (Report tab) ─────────────────────────────────
final adminReportProvider =
    FutureProvider.family.autoDispose<ReportData, ({int year, int month})>(
        (ref, key) async {
  final employees = await ref.watch(allEmployeesProvider.future);
  final repo      = ref.read(adminAttRepoProvider);
  final matrix    = await repo.fetchMonthMatrix(employees, key.year, key.month);

  final reports = employees.map((user) {
    final records = matrix[user.uid] ?? {};
    return EmployeeMonthReport(
      user:    user,
      summary: MonthSummary.compute(records, key.year, key.month),
      records: records,
    );
  }).toList()
    ..sort((a, b) => a.user.displayName.compareTo(b.user.displayName));

  return ReportData(year: key.year, month: key.month, employees: reports);
});
