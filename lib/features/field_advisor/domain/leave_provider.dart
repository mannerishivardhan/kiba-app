import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';
import 'package:kiba_app/features/field_advisor/data/day_record.dart';
import 'package:kiba_app/features/field_advisor/data/leave_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

class LeaveRepository {
  // ── FA: apply for leave ────────────────────────────────────────────────────

  Future<void> apply({
    required String uid,
    required String userName,
    required LeaveType type,
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
  }) async {
    final docRef = LeaveModel.newRef();
    final now = DateTime.now();

    // Emergency → auto-approved; others → pending
    final status = type.requiresApproval
        ? LeaveStatus.pending
        : LeaveStatus.approved;

    final leave = LeaveModel(
      id:        docRef.id,
      uid:       uid,
      userName:  userName,
      type:      type,
      fromDate:  _dateOnly(fromDate),
      toDate:    _dateOnly(toDate),
      reason:    reason,
      status:    status,
      appliedAt: now,
      reviewedBy:  type.requiresApproval ? null : 'system',
      reviewedAt:  type.requiresApproval ? null : now,
    );

    await docRef.set(leave.toMap());

    // Emergency: immediately map to attendance
    if (!type.requiresApproval) {
      await _mapToAttendance(leave, approvedBy: 'system');
    }
  }

  // ── Admin: approve ─────────────────────────────────────────────────────────

  Future<void> approve(
    String leaveId, {
    required String approvedBy,
    String? note,
  }) async {
    final snap = await LeaveModel.ref(leaveId).get();
    if (!snap.exists || snap.data() == null) return;
    final leave = LeaveModel.fromDoc(snap);

    final now = DateTime.now();
    await LeaveModel.ref(leaveId).update({
      'status':      'approved',
      'reviewed_by': approvedBy,
      'reviewed_at': Timestamp.fromDate(now),
      if (note != null && note.isNotEmpty) 'review_note': note,
    });

    await _mapToAttendance(
      leave.copyWith(status: LeaveStatus.approved,
          reviewedBy: approvedBy, reviewedAt: now),
      approvedBy: approvedBy,
    );
  }

  // ── Admin: decline ─────────────────────────────────────────────────────────

  Future<void> decline(
    String leaveId, {
    required String declinedBy,
    String? note,
  }) async {
    await LeaveModel.ref(leaveId).update({
      'status':      'declined',
      'reviewed_by': declinedBy,
      'reviewed_at': Timestamp.fromDate(DateTime.now()),
      if (note != null && note.isNotEmpty) 'review_note': note,
    });
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  Stream<List<LeaveModel>> streamForUser(String uid) {
    return LeaveModel.queryForUser(uid)
        .snapshots()
        .map((s) => s.docs.map(LeaveModel.fromDoc).toList());
  }

  Stream<List<LeaveModel>> streamPending() {
    return LeaveModel.queryPending()
        .snapshots()
        .map((s) => s.docs.map(LeaveModel.fromDoc).toList());
  }

  Stream<List<LeaveModel>> streamAll() {
    return LeaveModel.queryAll()
        .snapshots()
        .map((s) => s.docs.map(LeaveModel.fromDoc).toList());
  }

  // ── Attendance mapping ─────────────────────────────────────────────────────

  /// For each working day in the leave range, writes leave status into the
  /// monthly attendance doc using SetOptions(mergeFields) so other days
  /// in the same month are untouched.
  Future<void> _mapToAttendance(
    LeaveModel leave, {
    required String approvedBy,
  }) async {
    // Group days by (year, month) to minimise writes — one per month doc.
    final Map<String, Map<String, dynamic>> byMonth = {};

    var d = leave.fromDate;
    while (!d.isAfter(leave.toDate)) {
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
        final key = '${d.year}-${d.month}';
        (byMonth[key] ??= {})[d.day.toString()] = {
          'admin_override':   true,
          'override_status':  AttendanceStatus.leave.firestoreValue,
          'override_reason':  '${leave.type.label} leave — ${leave.reason}',
          'override_by':      approvedBy,
          'override_at':      Timestamp.fromDate(DateTime.now()),
          'auto_status':      AttendanceStatus.leave.firestoreValue,
        };
      }
      d = d.add(const Duration(days: 1));
    }

    // One merge write per month, all days bundled in a single set call.
    await Future.wait(byMonth.entries.map((entry) {
      final parts = entry.key.split('-');
      final year  = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final ref   = MonthlyAttendanceDoc.ref(leave.uid, year, month);
      // mergeFields: update only the specific day paths, leave everything else.
      final mergeFields = entry.value.keys
          .map((d) => FieldPath(['days', d]))
          .toList();
      return ref.set({'days': entry.value}, SetOptions(mergeFields: mergeFields));
    }));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

// ── Providers ─────────────────────────────────────────────────────────────────

final leaveRepoProvider = Provider<LeaveRepository>((_) => LeaveRepository());

/// FA: stream of this user's leaves.
final faLeavesProvider = StreamProvider<List<LeaveModel>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(leaveRepoProvider).streamForUser(uid);
});

/// Admin: pending leave requests.
final pendingLeavesProvider = StreamProvider<List<LeaveModel>>((ref) {
  return ref.read(leaveRepoProvider).streamPending();
});

/// Admin: all leave history.
final allLeavesProvider = StreamProvider<List<LeaveModel>>((ref) {
  return ref.read(leaveRepoProvider).streamAll();
});
