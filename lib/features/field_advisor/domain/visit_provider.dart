import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:kiba_app/features/auth/domain/auth_providers.dart';
import 'package:kiba_app/features/field_advisor/data/visit_model.dart';

// ── Haversine ─────────────────────────────────────────────────────────────────

/// Great-circle distance between two GPS coordinates (km).
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r     = 6371.0;
  final dLat  = _rad(lat2 - lat1);
  final dLng  = _rad(lng2 - lng1);
  final a     = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _rad(double deg) => deg * pi / 180;

// ── GPS helpers ───────────────────────────────────────────────────────────────

Future<Position> fetchCurrentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception('Location services are disabled.');
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.deniedForever) {
    throw Exception('Location permission permanently denied.');
  }
  return Geolocator.getCurrentPosition(
    locationSettings:
        const LocationSettings(accuracy: LocationAccuracy.high),
  );
}

Future<String> reverseGeocode(double lat, double lng) async {
  try {
    final marks = await placemarkFromCoordinates(lat, lng);
    if (marks.isEmpty) return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    final p     = marks.first;
    final parts = [p.name, p.subLocality, p.locality]
        .where((s) => s != null && s.isNotEmpty)
        .toList();
    return parts.take(3).join(', ');
  } catch (_) {
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }
}

// ── Repository ────────────────────────────────────────────────────────────────

class VisitRepository {
  VisitRepository(this._db);
  final FirebaseFirestore _db;

  Stream<List<VisitModel>> streamForUser(String uid) =>
      VisitModel.queryForUser(uid)
          .snapshots()
          .map((s) => s.docs.map(VisitModel.fromDoc).toList());

  /// Haversine leg distance from the last known GPS point today.
  /// Falls back to the check-in location stored in the attendance doc,
  /// then to 0 if neither is available.
  Future<double> estimateLegDistance(
      String uid, double lat, double lng) async {
    // Try last visit with GPS coords today
    final snap = await VisitModel.queryTodayForUser(uid).get();
    final today = snap.docs.map(VisitModel.fromDoc).toList();

    for (final v in today.reversed) {
      if (v.latitude != null && v.longitude != null) {
        return haversineKm(v.latitude!, v.longitude!, lat, lng);
      }
    }

    // Fall back to check-in coords stored in the monthly attendance doc
    final now      = DateTime.now();
    final monthStr = DateFormat('yyyy-MM').format(now);
    final dayStr   = now.day.toString();
    try {
      final doc = await _db
          .collection('attendance')
          .doc(uid)
          .collection('months')
          .doc(monthStr)
          .get();
      final dayData = doc.data()?['days']?[dayStr];
      final ciLat   = (dayData?['check_in_lat'] as num?)?.toDouble();
      final ciLng   = (dayData?['check_in_lng'] as num?)?.toDouble();
      if (ciLat != null && ciLng != null) {
        return haversineKm(ciLat, ciLng, lat, lng);
      }
    } catch (_) {}

    return 0.0;
  }

  Future<void> startVisit({
    required String uid,
    required String farmerName,
    required double pondArea,
    required VisitPurpose purpose,
    required String issuesReported,
    required String resolutionGiven,
    String notes        = '',
    Position? position, // pre-fetched — avoids second GPS call
  }) async {
    Position? pos = position;
    try {
      pos ??= await fetchCurrentPosition();
    } catch (_) {
      pos = null;
    }

    final address     = pos != null
        ? await reverseGeocode(pos.latitude, pos.longitude)
        : '';
    final distanceKm  = pos != null
        ? await estimateLegDistance(uid, pos.latitude, pos.longitude)
        : 0.0;

    final now = DateTime.now();
    final id  = const Uuid().v4();

    final visit = VisitModel(
      id:                 id,
      uid:                uid,
      farmerName:         farmerName,
      pondArea:           pondArea,
      address:            address,
      latitude:           pos?.latitude,
      longitude:          pos?.longitude,
      purpose:            purpose,
      issuesReported:     issuesReported,
      resolutionGiven:    resolutionGiven,
      notes:              notes,
      checkIn:            now,
      distanceFromPrevKm: distanceKm,
      status:             VisitStatus.active,
      createdAt:          now,
    );

    await _db.collection('visits').doc(id).set(visit.toMap());

    // Atomically accumulate km on today's attendance record
    await _addKmToAttendance(uid, distanceKm);
  }

  Future<void> endVisit({
    required String visitId,
    String finalNotes = '',
  }) async {
    await _db.collection('visits').doc(visitId).update({
      'check_out': Timestamp.fromDate(DateTime.now()),
      'status':    VisitStatus.completed.value,
      if (finalNotes.isNotEmpty) 'notes': finalNotes,
    });
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _addKmToAttendance(String uid, double km) async {
    if (km <= 0) return;
    final now      = DateTime.now();
    final monthStr = DateFormat('yyyy-MM').format(now);
    final dayStr   = now.day.toString();
    try {
      await _db
          .collection('attendance')
          .doc(uid)
          .collection('months')
          .doc(monthStr)
          .update({'days.$dayStr.km_covered': FieldValue.increment(km)});
    } catch (_) {
      // Attendance doc doesn't exist yet — create it with this km entry.
      await _db
          .collection('attendance')
          .doc(uid)
          .collection('months')
          .doc(monthStr)
          .set(
            {'days': {dayStr: {'km_covered': km}}},
            SetOptions(mergeFields: [FieldPath(['days', dayStr, 'km_covered'])]),
          );
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final visitRepoProvider = Provider<VisitRepository>(
  (ref) => VisitRepository(FirebaseFirestore.instance),
);

final faVisitsProvider = StreamProvider<List<VisitModel>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(visitRepoProvider).streamForUser(uid);
});
