import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiba_app/features/field_advisor/domain/attendance_calendar_provider.dart';

/// Today's check-in / check-out state derived from the monthly Firestore record.
/// Updating requires calling attendanceCalendarProvider.notifier.upsertToday().
class AttendanceState {
  const AttendanceState({
    this.checkInTime,
    this.checkOutTime,
  });

  final DateTime? checkInTime;
  final DateTime? checkOutTime;

  bool get isCheckedIn  => checkInTime  != null;
  bool get isCheckedOut => checkOutTime != null;
}

final attendanceProvider = Provider<AttendanceState>((ref) {
  final records = ref.watch(attendanceCalendarProvider).records;
  final today   = DateTime.now();
  final record  = records[today.day];
  if (record == null) return const AttendanceState();
  return AttendanceState(
    checkInTime:  record.checkIn,
    checkOutTime: record.checkOut,
  );
});
