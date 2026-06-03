import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveThreshold {
  const LeaveThreshold({
    this.faSickLeaves     = 10,
    this.faCasualLeaves   = 15,
    this.clerkSickLeaves  = 12,
    this.clerkCasualLeaves = 18,
    this.updatedBy,
    this.updatedAt,
  });

  final int faSickLeaves;
  final int faCasualLeaves;
  final int clerkSickLeaves;
  final int clerkCasualLeaves;
  final String?   updatedBy;
  final DateTime? updatedAt;

  // ── Firestore ─────────────────────────────────────────────────────────────

  static const _docPath = 'settings/leave_thresholds';

  static DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.doc(_docPath);

  static Future<LeaveThreshold> fetch() async {
    final snap = await _ref.get();
    if (!snap.exists || snap.data() == null) return const LeaveThreshold();
    return LeaveThreshold.fromMap(snap.data()!);
  }

  static Stream<LeaveThreshold> stream() {
    return _ref.snapshots().map((s) =>
        s.exists && s.data() != null
            ? LeaveThreshold.fromMap(s.data()!)
            : const LeaveThreshold());
  }

  Future<void> save() => _ref.set(toMap(), SetOptions(merge: true));

  factory LeaveThreshold.fromMap(Map<String, dynamic> m) {
    return LeaveThreshold(
      faSickLeaves:      (m['fa_sick_leaves']       as int?) ?? 10,
      faCasualLeaves:    (m['fa_casual_leaves']     as int?) ?? 15,
      clerkSickLeaves:   (m['clerk_sick_leaves']    as int?) ?? 12,
      clerkCasualLeaves: (m['clerk_casual_leaves']  as int?) ?? 18,
      updatedBy:         m['updated_by'] as String?,
      updatedAt:         (m['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'fa_sick_leaves':      faSickLeaves,
    'fa_casual_leaves':    faCasualLeaves,
    'clerk_sick_leaves':   clerkSickLeaves,
    'clerk_casual_leaves': clerkCasualLeaves,
    if (updatedBy != null) 'updated_by': updatedBy,
    if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
  };

  LeaveThreshold copyWith({
    int? faSickLeaves,
    int? faCasualLeaves,
    int? clerkSickLeaves,
    int? clerkCasualLeaves,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return LeaveThreshold(
      faSickLeaves:      faSickLeaves      ?? this.faSickLeaves,
      faCasualLeaves:    faCasualLeaves    ?? this.faCasualLeaves,
      clerkSickLeaves:   clerkSickLeaves   ?? this.clerkSickLeaves,
      clerkCasualLeaves: clerkCasualLeaves ?? this.clerkCasualLeaves,
      updatedBy:         updatedBy         ?? this.updatedBy,
      updatedAt:         updatedAt         ?? this.updatedAt,
    );
  }
}
