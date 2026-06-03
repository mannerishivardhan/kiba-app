import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── Visit Purpose ─────────────────────────────────────────────────────────────

enum VisitPurpose { routine, followUp, emergency, firstVisit, other }

extension VisitPurposeX on VisitPurpose {
  String get value {
    switch (this) {
      case VisitPurpose.routine:    return 'routine';
      case VisitPurpose.followUp:   return 'follow_up';
      case VisitPurpose.emergency:  return 'emergency';
      case VisitPurpose.firstVisit: return 'first_visit';
      case VisitPurpose.other:      return 'other';
    }
  }

  String get label {
    switch (this) {
      case VisitPurpose.routine:    return 'Routine';
      case VisitPurpose.followUp:   return 'Follow-up';
      case VisitPurpose.emergency:  return 'Emergency';
      case VisitPurpose.firstVisit: return 'First Visit';
      case VisitPurpose.other:      return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case VisitPurpose.routine:    return Icons.repeat_rounded;
      case VisitPurpose.followUp:   return Icons.replay_rounded;
      case VisitPurpose.emergency:  return Icons.warning_amber_rounded;
      case VisitPurpose.firstVisit: return Icons.flag_rounded;
      case VisitPurpose.other:      return Icons.more_horiz_rounded;
    }
  }

  Color get color {
    switch (this) {
      case VisitPurpose.routine:    return const Color(0xFF059669);
      case VisitPurpose.followUp:   return const Color(0xFF6366F1);
      case VisitPurpose.emergency:  return const Color(0xFFEF4444);
      case VisitPurpose.firstVisit: return const Color(0xFFF59E0B);
      case VisitPurpose.other:      return const Color(0xFF6B7280);
    }
  }

  static VisitPurpose fromString(String? s) {
    switch (s) {
      case 'routine':     return VisitPurpose.routine;
      case 'follow_up':   return VisitPurpose.followUp;
      case 'emergency':   return VisitPurpose.emergency;
      case 'first_visit': return VisitPurpose.firstVisit;
      default:            return VisitPurpose.other;
    }
  }
}

// ── Visit Status ──────────────────────────────────────────────────────────────

enum VisitStatus { active, completed, missed }

extension VisitStatusX on VisitStatus {
  String get value {
    switch (this) {
      case VisitStatus.active:    return 'active';
      case VisitStatus.completed: return 'completed';
      case VisitStatus.missed:    return 'missed';
    }
  }

  String get label {
    switch (this) {
      case VisitStatus.active:    return 'Active';
      case VisitStatus.completed: return 'Completed';
      case VisitStatus.missed:    return 'Missed';
    }
  }

  Color get color {
    switch (this) {
      case VisitStatus.active:    return const Color(0xFF059669);
      case VisitStatus.completed: return const Color(0xFF6366F1);
      case VisitStatus.missed:    return const Color(0xFFEF4444);
    }
  }

  Color get surface {
    switch (this) {
      case VisitStatus.active:    return const Color(0xFFD1FAE5);
      case VisitStatus.completed: return const Color(0xFFEDE9FE);
      case VisitStatus.missed:    return const Color(0xFFFEE2E2);
    }
  }

  static VisitStatus fromString(String? s) {
    switch (s) {
      case 'active':    return VisitStatus.active;
      case 'completed': return VisitStatus.completed;
      case 'missed':    return VisitStatus.missed;
      default:          return VisitStatus.active;
    }
  }
}

// ── Visit Model ───────────────────────────────────────────────────────────────

class VisitModel {
  const VisitModel({
    required this.id,
    required this.uid,
    required this.farmerName,
    required this.pondArea,
    required this.address,
    this.latitude,
    this.longitude,
    required this.purpose,
    this.issuesReported = '',
    this.resolutionGiven = '',
    this.notes = '',
    required this.checkIn,
    this.checkOut,
    this.distanceFromPrevKm = 0.0,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String uid;
  final String farmerName;
  final double pondArea;           // acres
  final String address;
  final double? latitude;
  final double? longitude;
  final VisitPurpose purpose;
  final String issuesReported;
  final String resolutionGiven;
  final String notes;
  final DateTime checkIn;
  final DateTime? checkOut;
  final double distanceFromPrevKm; // haversine leg in km
  final VisitStatus status;
  final DateTime createdAt;

  bool get isActive => status == VisitStatus.active;

  Duration get duration {
    final end = checkOut ?? DateTime.now();
    return end.difference(checkIn);
  }

  String get durationLabel {
    final d = duration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  // ── Firestore ─────────────────────────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('visits');

  static Query<Map<String, dynamic>> queryForUser(String uid) =>
      _col.where('uid', isEqualTo: uid).orderBy('check_in', descending: true);

  static Query<Map<String, dynamic>> queryTodayForUser(String uid) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _col
        .where('uid', isEqualTo: uid)
        .where('check_in',
            isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .orderBy('check_in');
  }

  factory VisitModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    return VisitModel(
      id:                 doc.id,
      uid:                m['uid'] as String,
      farmerName:         m['farmer_name']      as String? ?? '',
      pondArea:           (m['pond_area']        as num?)?.toDouble() ?? 0,
      address:            m['address']           as String? ?? '',
      latitude:           (m['latitude']         as num?)?.toDouble(),
      longitude:          (m['longitude']        as num?)?.toDouble(),
      purpose:            VisitPurposeX.fromString(m['purpose'] as String?),
      issuesReported:     m['issues_reported']   as String? ?? '',
      resolutionGiven:    m['resolution_given']  as String? ?? '',
      notes:              m['notes']             as String? ?? '',
      checkIn:            (m['check_in']         as Timestamp).toDate(),
      checkOut:           (m['check_out']        as Timestamp?)?.toDate(),
      distanceFromPrevKm: (m['distance_from_prev_km'] as num?)?.toDouble() ?? 0,
      status:             VisitStatusX.fromString(m['status'] as String?),
      createdAt:          (m['created_at']       as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':                    uid,
    'farmer_name':            farmerName,
    'pond_area':              pondArea,
    'address':                address,
    if (latitude  != null) 'latitude':  latitude,
    if (longitude != null) 'longitude': longitude,
    'purpose':                purpose.value,
    'issues_reported':        issuesReported,
    'resolution_given':       resolutionGiven,
    'notes':                  notes,
    'check_in':               Timestamp.fromDate(checkIn),
    if (checkOut != null) 'check_out': Timestamp.fromDate(checkOut!),
    'distance_from_prev_km':  distanceFromPrevKm,
    'status':                 status.value,
    'created_at':             Timestamp.fromDate(createdAt),
  };
}
