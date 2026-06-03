import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Thresholds set by admin that determine whether a day counts as
/// present, late, or absent for all field advisors.
///
/// A day is marked:
///   present  → checked in + (fields_visited ≥ minVisits  OR  km_covered ≥ minKm)
///   late     → checked in after lateCheckinCutoff
///   absent   → no check-in recorded by end of day
class AttendanceThreshold {
  const AttendanceThreshold({
    this.minVisitsForPresent    = 3,
    this.minKmForPresent        = 10.0,
    this.minDutyHoursForPresent = 6.0,
    this.lateCheckinCutoff      = const TimeOfDay(hour: 9, minute: 30),
    this.clerkLateCheckinCutoff = const TimeOfDay(hour: 9, minute: 0),
    this.updatedBy,
    this.updatedAt,
  });

  final int minVisitsForPresent;
  final double minKmForPresent;
  final double minDutyHoursForPresent;

  /// Check-ins strictly after this time are marked Late for Field Advisors.
  final TimeOfDay lateCheckinCutoff;

  /// Check-ins strictly after this time are marked Late for Clerks.
  final TimeOfDay clerkLateCheckinCutoff;

  final String?   updatedBy;
  final DateTime? updatedAt;

  // ── Firestore ─────────────────────────────────────────────────────────────

  static const _docPath = 'settings/attendance_thresholds';

  static DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.doc(_docPath);

  static Future<AttendanceThreshold> fetch() async {
    final snap = await _ref.get();
    if (!snap.exists || snap.data() == null) return const AttendanceThreshold();
    return AttendanceThreshold.fromMap(snap.data()!);
  }

  static Stream<AttendanceThreshold> stream() {
    return _ref.snapshots().map((s) =>
        s.exists && s.data() != null
            ? AttendanceThreshold.fromMap(s.data()!)
            : const AttendanceThreshold());
  }

  Future<void> save() => _ref.set(toMap(), SetOptions(merge: true));

  static TimeOfDay _parseTime(String? raw, {int defHour = 9, int defMin = 0}) {
    final parts = (raw ?? '${defHour.toString().padLeft(2, '0')}:${defMin.toString().padLeft(2, '0')}').split(':');
    return TimeOfDay(
      hour:   int.tryParse(parts[0]) ?? defHour,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? defMin,
    );
  }

  factory AttendanceThreshold.fromMap(Map<String, dynamic> m) {
    return AttendanceThreshold(
      minVisitsForPresent:    (m['min_visits_for_present']      as int?)  ?? 3,
      minKmForPresent:        (m['min_km_for_present']          as num?)?.toDouble() ?? 10.0,
      minDutyHoursForPresent: (m['min_duty_hours_for_present']  as num?)?.toDouble() ?? 6.0,
      lateCheckinCutoff:      _parseTime(m['late_checkin_cutoff']       as String?, defHour: 9, defMin: 30),
      clerkLateCheckinCutoff: _parseTime(m['clerk_late_checkin_cutoff'] as String?, defHour: 9, defMin: 0),
      updatedBy:              m['updated_by'] as String?,
      updatedAt:              (m['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  static String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
    'min_visits_for_present':    minVisitsForPresent,
    'min_km_for_present':        minKmForPresent,
    'min_duty_hours_for_present': minDutyHoursForPresent,
    'late_checkin_cutoff':       _fmtTime(lateCheckinCutoff),
    'clerk_late_checkin_cutoff': _fmtTime(clerkLateCheckinCutoff),
    if (updatedBy != null) 'updated_by': updatedBy,
    if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
  };

  AttendanceThreshold copyWith({
    int? minVisitsForPresent,
    double? minKmForPresent,
    double? minDutyHoursForPresent,
    TimeOfDay? lateCheckinCutoff,
    TimeOfDay? clerkLateCheckinCutoff,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return AttendanceThreshold(
      minVisitsForPresent:    minVisitsForPresent    ?? this.minVisitsForPresent,
      minKmForPresent:        minKmForPresent        ?? this.minKmForPresent,
      minDutyHoursForPresent: minDutyHoursForPresent ?? this.minDutyHoursForPresent,
      lateCheckinCutoff:      lateCheckinCutoff      ?? this.lateCheckinCutoff,
      clerkLateCheckinCutoff: clerkLateCheckinCutoff ?? this.clerkLateCheckinCutoff,
      updatedBy:              updatedBy              ?? this.updatedBy,
      updatedAt:              updatedAt              ?? this.updatedAt,
    );
  }
}
