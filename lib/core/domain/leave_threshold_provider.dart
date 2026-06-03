import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiba_app/core/models/leave_threshold.dart';

final leaveThresholdProvider = StreamProvider<LeaveThreshold>((ref) {
  return LeaveThreshold.stream();
});

class LeaveThresholdNotifier extends StateNotifier<LeaveThreshold> {
  LeaveThresholdNotifier() : super(const LeaveThreshold());

  void load(LeaveThreshold t) => state = t;

  Future<void> saveFa({
    int? sickLeaves,
    int? casualLeaves,
    required String adminUid,
  }) async {
    final updated = state.copyWith(
      faSickLeaves:   sickLeaves,
      faCasualLeaves: casualLeaves,
      updatedBy:      adminUid,
      updatedAt:      DateTime.now(),
    );
    state = updated;
    await updated.save();
  }

  Future<void> saveClerk({
    int? sickLeaves,
    int? casualLeaves,
    required String adminUid,
  }) async {
    final updated = state.copyWith(
      clerkSickLeaves:   sickLeaves,
      clerkCasualLeaves: casualLeaves,
      updatedBy:         adminUid,
      updatedAt:         DateTime.now(),
    );
    state = updated;
    await updated.save();
  }
}

final leaveThresholdNotifierProvider =
    StateNotifierProvider<LeaveThresholdNotifier, LeaveThreshold>((ref) {
  final notifier = LeaveThresholdNotifier();
  ref.listen(leaveThresholdProvider, (_, next) {
    next.whenData(notifier.load);
  });
  return notifier;
});
