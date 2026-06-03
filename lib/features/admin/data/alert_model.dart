import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum AlertType { lateCheckin, earlyCheckout, visitThresholdNotMet, distanceNotMet }

extension AlertTypeX on AlertType {
  String get firestoreValue {
    switch (this) {
      case AlertType.lateCheckin:          return 'late_checkin';
      case AlertType.earlyCheckout:        return 'early_checkout';
      case AlertType.visitThresholdNotMet: return 'visit_threshold_not_met';
      case AlertType.distanceNotMet:       return 'distance_not_met';
    }
  }

  String get label {
    switch (this) {
      case AlertType.lateCheckin:          return 'Late Check-in';
      case AlertType.earlyCheckout:        return 'Early Checkout';
      case AlertType.visitThresholdNotMet: return 'Visits Not Met';
      case AlertType.distanceNotMet:       return 'Distance Not Met';
    }
  }

  IconData get icon {
    switch (this) {
      case AlertType.lateCheckin:          return Icons.access_time_rounded;
      case AlertType.earlyCheckout:        return Icons.exit_to_app_rounded;
      case AlertType.visitThresholdNotMet: return Icons.place_rounded;
      case AlertType.distanceNotMet:       return Icons.route_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AlertType.lateCheckin:          return const Color(0xFFF59E0B);
      case AlertType.earlyCheckout:        return const Color(0xFFF97316);
      case AlertType.visitThresholdNotMet: return const Color(0xFFEF4444);
      case AlertType.distanceNotMet:       return const Color(0xFFEF4444);
    }
  }

  static AlertType fromString(String? s) {
    switch (s) {
      case 'late_checkin':            return AlertType.lateCheckin;
      case 'early_checkout':          return AlertType.earlyCheckout;
      case 'visit_threshold_not_met': return AlertType.visitThresholdNotMet;
      case 'distance_not_met':        return AlertType.distanceNotMet;
      default:                        return AlertType.lateCheckin;
    }
  }
}

class AlertModel {
  const AlertModel({
    required this.id,
    required this.uid,
    this.userName,
    required this.type,
    required this.date,
    required this.message,
    required this.isRead,
    this.readBy,
    this.readAt,
    required this.createdAt,
  });

  final String     id;
  final String     uid;
  final String?    userName;
  final AlertType  type;
  final DateTime   date;
  final String     message;
  final bool       isRead;
  final String?    readBy;
  final DateTime?  readAt;
  final DateTime   createdAt;

  factory AlertModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    return AlertModel(
      id:        doc.id,
      uid:       m['uid']       as String? ?? '',
      userName:  m['user_name'] as String?,
      type:      AlertTypeX.fromString(m['type'] as String?),
      date:      (m['date']      as Timestamp?)?.toDate() ?? DateTime.now(),
      message:   m['message']   as String? ?? '',
      isRead:    m['isRead']    as bool?   ?? false,
      readBy:    m['readBy']    as String?,
      readAt:    (m['readAt']   as Timestamp?)?.toDate(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
