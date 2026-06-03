import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kiba_app/features/field_advisor/domain/visit_provider.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class LocationTrackingState {
  const LocationTrackingState({
    this.isTracking  = false,
    this.lastLat,
    this.lastLng,
    this.lastUpdated,
  });

  final bool isTracking;
  final double? lastLat;
  final double? lastLng;
  final DateTime? lastUpdated;

  LocationTrackingState copyWith({
    bool? isTracking,
    double? lastLat,
    double? lastLng,
    DateTime? lastUpdated,
  }) =>
      LocationTrackingState(
        isTracking:  isTracking  ?? this.isTracking,
        lastLat:     lastLat     ?? this.lastLat,
        lastLng:     lastLng     ?? this.lastLng,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class LocationTrackingNotifier
    extends StateNotifier<LocationTrackingState> {
  LocationTrackingNotifier(this._db) : super(const LocationTrackingState());

  final FirebaseFirestore _db;
  Timer? _timer;
  String? _uid;
  String? _name;

  // Write to Firestore every 3 minutes while FA is on duty.
  static const _interval = Duration(minutes: 3);

  /// Call after successful check-in. GPS must already be confirmed available.
  void startTracking(String uid, String name) {
    _uid  = uid;
    _name = name;
    state = state.copyWith(isTracking: true);

    _captureAndWrite(); // immediate first write
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _captureAndWrite());
  }

  /// Call after check-out.
  Future<void> stopTracking() async {
    _timer?.cancel();
    _timer = null;
    final uid = _uid;
    _uid  = null;
    _name = null;

    // Mark FA as offline in live_locations
    if (uid != null) {
      try {
        await _db.collection('live_locations').doc(uid).update({
          'is_active':  false,
          'updated_at': Timestamp.fromDate(DateTime.now()),
        });
      } catch (_) {}
    }

    state = const LocationTrackingState(isTracking: false);
  }

  Future<void> _captureAndWrite() async {
    final uid  = _uid;
    final name = _name;
    if (uid == null || name == null) return;

    try {
      final pos = await fetchCurrentPosition();
      final now = DateTime.now();

      // ── Live location doc (admin heatmap — real-time marker) ──────────────
      await _db.collection('live_locations').doc(uid).set({
        'uid':        uid,
        'name':       name,
        'lat':        pos.latitude,
        'lng':        pos.longitude,
        'accuracy':   pos.accuracy,
        'is_active':  true,
        'updated_at': Timestamp.fromDate(now),
      });

      // ── Historical log (heatmap trail — queried by date) ──────────────────
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      await _db
          .collection('location_logs')
          .doc(uid)
          .collection('days')
          .doc(dateStr)
          .collection('points')
          .add({
        'lat':      pos.latitude,
        'lng':      pos.longitude,
        'accuracy': pos.accuracy,
        'ts':       Timestamp.fromDate(now),
      });

      state = state.copyWith(
        lastLat:     pos.latitude,
        lastLng:     pos.longitude,
        lastUpdated: now,
      );
    } catch (e) {
      // GPS temporarily unavailable — retry on next interval tick.
      // The interval guarantees recovery within _interval time.
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final locationTrackingProvider = StateNotifierProvider<
    LocationTrackingNotifier, LocationTrackingState>(
  (ref) => LocationTrackingNotifier(FirebaseFirestore.instance),
);
