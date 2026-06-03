import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiba_app/core/models/attendance_threshold.dart';

/// Streams the current threshold from Firestore.
/// Both FA screens and Admin settings screens watch this.
final thresholdProvider = StreamProvider<AttendanceThreshold>((ref) {
  return AttendanceThreshold.stream();
});

/// Admin-only notifier — saves updated thresholds to Firestore.
class ThresholdNotifier extends StateNotifier<AttendanceThreshold> {
  ThresholdNotifier() : super(const AttendanceThreshold());

  void load(AttendanceThreshold t) => state = t;

  Future<void> save({
    int? minVisits,
    double? minKm,
    double? minDutyHours,
    TimeOfDay? lateCutoff,
    TimeOfDay? clerkLateCutoff,
    required String adminUid,
  }) async {
    final updated = state.copyWith(
      minVisitsForPresent:    minVisits,
      minKmForPresent:        minKm,
      minDutyHoursForPresent: minDutyHours,
      lateCheckinCutoff:      lateCutoff,
      clerkLateCheckinCutoff: clerkLateCutoff,
      updatedBy:              adminUid,
      updatedAt:              DateTime.now(),
    );
    state = updated;
    await updated.save();
  }
}

final thresholdNotifierProvider =
    StateNotifierProvider<ThresholdNotifier, AttendanceThreshold>(
  (ref) {
    final notifier = ThresholdNotifier();
    // Seed from the stream whenever it emits
    ref.listen(thresholdProvider, (_, next) {
      next.whenData(notifier.load);
    });
    return notifier;
  },
);
