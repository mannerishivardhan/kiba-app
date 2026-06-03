import 'package:cloud_firestore/cloud_firestore.dart';

/// Status for a single attendance day.
enum AttendanceStatus {
  present,
  late,
  absent,
  leave,
  holiday,
  earlyCheckout,
  visitThresholdNotMet,
  distanceNotMet,
}

extension AttendanceStatusX on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.present:             return 'Present';
      case AttendanceStatus.late:                return 'Late';
      case AttendanceStatus.absent:              return 'Absent';
      case AttendanceStatus.leave:               return 'Leave';
      case AttendanceStatus.holiday:             return 'Holiday';
      case AttendanceStatus.earlyCheckout:       return 'Early Checkout';
      case AttendanceStatus.visitThresholdNotMet: return 'Visits Not Met';
      case AttendanceStatus.distanceNotMet:      return 'Distance Not Met';
    }
  }

  String get firestoreValue {
    switch (this) {
      case AttendanceStatus.present:             return 'present';
      case AttendanceStatus.late:                return 'late';
      case AttendanceStatus.absent:              return 'absent';
      case AttendanceStatus.leave:               return 'leave';
      case AttendanceStatus.holiday:             return 'holiday';
      case AttendanceStatus.earlyCheckout:       return 'early_checkout';
      case AttendanceStatus.visitThresholdNotMet: return 'visit_threshold_not_met';
      case AttendanceStatus.distanceNotMet:      return 'distance_threshold_not_met';
    }
  }

  static AttendanceStatus fromString(String? s) {
    switch (s) {
      case 'present':                  return AttendanceStatus.present;
      case 'late':                     return AttendanceStatus.late;
      case 'absent':                   return AttendanceStatus.absent;
      case 'leave':                    return AttendanceStatus.leave;
      case 'holiday':                  return AttendanceStatus.holiday;
      case 'early_checkout':           return AttendanceStatus.earlyCheckout;
      case 'visit_threshold_not_met':  return AttendanceStatus.visitThresholdNotMet;
      case 'distance_threshold_not_met': return AttendanceStatus.distanceNotMet;
      default:                         return AttendanceStatus.absent;
    }
  }
}

/// A single day's attendance data — stored as a nested map inside the
/// monthly document, NOT as its own document. One Firestore read loads
/// the entire month.
class DayRecord {
  const DayRecord({
    required this.date,
    this.checkIn,
    this.checkOut,
    this.checkInLat,
    this.checkInLng,
    this.checkOutLat,
    this.checkOutLng,
    this.kmCovered = 0,
    this.fieldsVisited = 0,
    required this.autoStatus,
    this.checkoutReason,
    this.adminOverride = false,
    this.overrideStatus,
    this.overrideReason,
    this.overrideBy,
    this.overrideAt,
  });

  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double? checkInLat;
  final double? checkInLng;
  final double? checkOutLat;
  final double? checkOutLng;
  final double kmCovered;
  final int fieldsVisited;

  /// Auto-computed from thresholds — never changed manually.
  final AttendanceStatus autoStatus;

  /// FA-supplied reason when checking out early.
  final String? checkoutReason;

  /// Admin override fields.
  final bool adminOverride;
  final AttendanceStatus? overrideStatus;
  final String? overrideReason;
  final String? overrideBy;
  final DateTime? overrideAt;

  /// What the UI shows — admin override wins when set.
  AttendanceStatus get effectiveStatus =>
      adminOverride && overrideStatus != null ? overrideStatus! : autoStatus;

  Duration get workDuration {
    if (checkIn == null || checkOut == null) return Duration.zero;
    return checkOut!.difference(checkIn!);
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  factory DayRecord.fromMap(Map<String, dynamic> m, DateTime date) {
    return DayRecord(
      date:          date,
      checkIn:       (m['check_in']  as Timestamp?)?.toDate(),
      checkOut:      (m['check_out'] as Timestamp?)?.toDate(),
      checkInLat:    (m['check_in_lat']  as num?)?.toDouble(),
      checkInLng:    (m['check_in_lng']  as num?)?.toDouble(),
      checkOutLat:   (m['check_out_lat'] as num?)?.toDouble(),
      checkOutLng:   (m['check_out_lng'] as num?)?.toDouble(),
      kmCovered:     (m['km_covered']     as num?)?.toDouble() ?? 0,
      fieldsVisited: (m['fields_visited'] as int?)  ?? 0,
      autoStatus:     AttendanceStatusX.fromString(m['auto_status'] as String?),
      checkoutReason: m['checkout_reason'] as String?,
      adminOverride:  m['admin_override'] as bool? ?? false,
      overrideStatus: m['admin_override'] == true
          ? AttendanceStatusX.fromString(m['override_status'] as String?)
          : null,
      overrideReason: m['override_reason'] as String?,
      overrideBy:     m['override_by']     as String?,
      overrideAt:     (m['override_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    if (checkIn  != null) 'check_in':  Timestamp.fromDate(checkIn!),
    if (checkOut != null) 'check_out': Timestamp.fromDate(checkOut!),
    if (checkInLat  != null) 'check_in_lat':  checkInLat,
    if (checkInLng  != null) 'check_in_lng':  checkInLng,
    if (checkOutLat != null) 'check_out_lat': checkOutLat,
    if (checkOutLng != null) 'check_out_lng': checkOutLng,
    'km_covered':     kmCovered,
    'fields_visited': fieldsVisited,
    'auto_status':    autoStatus.firestoreValue,
    if (checkoutReason != null) 'checkout_reason': checkoutReason,
    'admin_override': adminOverride,
    if (adminOverride && overrideStatus != null)
      'override_status': overrideStatus!.firestoreValue,
    if (overrideReason != null) 'override_reason': overrideReason,
    if (overrideBy     != null) 'override_by':     overrideBy,
    if (overrideAt     != null)
      'override_at': Timestamp.fromDate(overrideAt!),
  };

  DayRecord copyWith({
    DateTime? checkIn,
    DateTime? checkOut,
    double? checkInLat,
    double? checkInLng,
    double? checkOutLat,
    double? checkOutLng,
    double? kmCovered,
    int? fieldsVisited,
    AttendanceStatus? autoStatus,
    String? checkoutReason,
    bool? adminOverride,
    AttendanceStatus? overrideStatus,
    String? overrideReason,
    String? overrideBy,
    DateTime? overrideAt,
  }) {
    return DayRecord(
      date:           date,
      checkIn:        checkIn        ?? this.checkIn,
      checkOut:       checkOut       ?? this.checkOut,
      checkInLat:     checkInLat     ?? this.checkInLat,
      checkInLng:     checkInLng     ?? this.checkInLng,
      checkOutLat:    checkOutLat    ?? this.checkOutLat,
      checkOutLng:    checkOutLng    ?? this.checkOutLng,
      kmCovered:      kmCovered      ?? this.kmCovered,
      fieldsVisited:  fieldsVisited  ?? this.fieldsVisited,
      autoStatus:     autoStatus     ?? this.autoStatus,
      checkoutReason: checkoutReason ?? this.checkoutReason,
      adminOverride:  adminOverride  ?? this.adminOverride,
      overrideStatus: overrideStatus ?? this.overrideStatus,
      overrideReason: overrideReason ?? this.overrideReason,
      overrideBy:     overrideBy     ?? this.overrideBy,
      overrideAt:     overrideAt     ?? this.overrideAt,
    );
  }
}

// ── Monthly document helper ───────────────────────────────────────────────────

/// Firestore path: attendance/{uid}/months/{YYYY-MM}
/// One document = one month. All days stored in a `days` map keyed by
/// day-of-month string ("1".."31"). One read loads the full month.
class MonthlyAttendanceDoc {
  static String docId(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  static DocumentReference<Map<String, dynamic>> ref(
          String uid, int year, int month) =>
      FirebaseFirestore.instance
          .collection('attendance')
          .doc(uid)
          .collection('months')
          .doc(docId(year, month));

  /// Parse a full month document into a day-keyed map.
  static Map<int, DayRecord> parse(
      Map<String, dynamic> data, int year, int month) {
    final raw = data['days'] as Map<String, dynamic>? ?? {};
    final result = <int, DayRecord>{};
    for (final entry in raw.entries) {
      final day = int.tryParse(entry.key);
      if (day == null) continue;
      final dayData = entry.value as Map<String, dynamic>?;
      if (dayData == null) continue;
      result[day] = DayRecord.fromMap(dayData, DateTime(year, month, day));
    }
    return result;
  }
}
