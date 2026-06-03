import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum LeaveType { sick, casual, emergency }

extension LeaveTypeX on LeaveType {
  String get value {
    switch (this) {
      case LeaveType.sick:      return 'sick';
      case LeaveType.casual:    return 'casual';
      case LeaveType.emergency: return 'emergency';
    }
  }

  String get label {
    switch (this) {
      case LeaveType.sick:      return 'Sick';
      case LeaveType.casual:    return 'Casual';
      case LeaveType.emergency: return 'Emergency';
    }
  }

  IconData get icon {
    switch (this) {
      case LeaveType.sick:      return Icons.medical_services_outlined;
      case LeaveType.casual:    return Icons.beach_access_outlined;
      case LeaveType.emergency: return Icons.warning_amber_rounded;
    }
  }

  Color get color {
    switch (this) {
      case LeaveType.sick:      return const Color(0xFFE11D48);
      case LeaveType.casual:    return const Color(0xFF2563EB);
      case LeaveType.emergency: return const Color(0xFFE8A020);
    }
  }

  Color get surface {
    switch (this) {
      case LeaveType.sick:      return const Color(0xFFFFF1F2);
      case LeaveType.casual:    return const Color(0xFFEFF6FF);
      case LeaveType.emergency: return const Color(0xFFFEF9EC);
    }
  }

  // Emergency leaves skip admin approval — auto-approved on apply.
  bool get requiresApproval => this != LeaveType.emergency;

  static LeaveType fromString(String? s) {
    switch (s) {
      case 'sick':      return LeaveType.sick;
      case 'casual':    return LeaveType.casual;
      case 'emergency': return LeaveType.emergency;
      default:          return LeaveType.casual;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

enum LeaveStatus { pending, approved, declined }

extension LeaveStatusX on LeaveStatus {
  String get value {
    switch (this) {
      case LeaveStatus.pending:  return 'pending';
      case LeaveStatus.approved: return 'approved';
      case LeaveStatus.declined: return 'declined';
    }
  }

  String get label {
    switch (this) {
      case LeaveStatus.pending:  return 'Awaiting';
      case LeaveStatus.approved: return 'Approved';
      case LeaveStatus.declined: return 'Declined';
    }
  }

  Color get color {
    switch (this) {
      case LeaveStatus.pending:  return const Color(0xFFE8A020);
      case LeaveStatus.approved: return const Color(0xFF059669);
      case LeaveStatus.declined: return const Color(0xFFE11D48);
    }
  }

  Color get surface {
    switch (this) {
      case LeaveStatus.pending:  return const Color(0xFFFEF3C7);
      case LeaveStatus.approved: return const Color(0xFFD1FAE5);
      case LeaveStatus.declined: return const Color(0xFFFEE2E2);
    }
  }

  static LeaveStatus fromString(String? s) {
    switch (s) {
      case 'approved': return LeaveStatus.approved;
      case 'declined': return LeaveStatus.declined;
      default:         return LeaveStatus.pending;
    }
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────

class LeaveModel {
  const LeaveModel({
    required this.id,
    required this.uid,
    required this.userName,
    required this.type,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.status,
    required this.appliedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote,
  });

  final String id;
  final String uid;
  final String userName;
  final LeaveType type;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final LeaveStatus status;
  final DateTime appliedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNote;

  bool get isSingleDay =>
      fromDate.year == toDate.year &&
      fromDate.month == toDate.month &&
      fromDate.day == toDate.day;

  /// Working days (Mon–Fri) in the leave range.
  int get workingDays {
    int count = 0;
    var d = fromDate;
    while (!d.isAfter(toDate)) {
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
        count++;
      }
      d = d.add(const Duration(days: 1));
    }
    return count;
  }

  // ── Firestore ─────────────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('leaves');

  static DocumentReference<Map<String, dynamic>> newRef() => _col.doc();

  static DocumentReference<Map<String, dynamic>> ref(String id) => _col.doc(id);

  static Query<Map<String, dynamic>> queryForUser(String uid) => _col
      .where('uid', isEqualTo: uid)
      .orderBy('applied_at', descending: true);

  static Query<Map<String, dynamic>> queryPending() => _col
      .where('status', isEqualTo: 'pending')
      .orderBy('applied_at', descending: true);

  static Query<Map<String, dynamic>> queryAll() =>
      _col.orderBy('applied_at', descending: true);

  factory LeaveModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    return LeaveModel(
      id:         doc.id,
      uid:        m['uid']       as String,
      userName:   m['user_name'] as String? ?? '',
      type:       LeaveTypeX.fromString(m['type']   as String?),
      status:     LeaveStatusX.fromString(m['status'] as String?),
      fromDate:   (m['from_date'] as Timestamp).toDate(),
      toDate:     (m['to_date']   as Timestamp).toDate(),
      reason:     m['reason']    as String? ?? '',
      appliedAt:  (m['applied_at'] as Timestamp).toDate(),
      reviewedBy: m['reviewed_by'] as String?,
      reviewedAt: (m['reviewed_at'] as Timestamp?)?.toDate(),
      reviewNote: m['review_note'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':        uid,
    'user_name':  userName,
    'type':       type.value,
    'from_date':  Timestamp.fromDate(fromDate),
    'to_date':    Timestamp.fromDate(toDate),
    'reason':     reason,
    'status':     status.value,
    'applied_at': Timestamp.fromDate(appliedAt),
    if (reviewedBy != null) 'reviewed_by':  reviewedBy,
    if (reviewedAt != null) 'reviewed_at':  Timestamp.fromDate(reviewedAt!),
    if (reviewNote != null) 'review_note':  reviewNote,
  };

  LeaveModel copyWith({LeaveStatus? status, String? reviewedBy,
      DateTime? reviewedAt, String? reviewNote}) {
    return LeaveModel(
      id: id, uid: uid, userName: userName, type: type,
      fromDate: fromDate, toDate: toDate, reason: reason,
      appliedAt: appliedAt,
      status:     status     ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNote: reviewNote ?? this.reviewNote,
    );
  }
}
