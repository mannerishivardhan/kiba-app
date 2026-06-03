import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiba_app/features/admin/data/alert_model.dart';

final adminAlertsProvider = StreamProvider<List<AlertModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('alerts')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(AlertModel.fromDoc).toList());
});

final unreadAlertsCountProvider = Provider<int>((ref) {
  return ref.watch(adminAlertsProvider).valueOrNull
          ?.where((a) => !a.isRead).length ??
      0;
});

Future<void> markAlertRead(String alertId, String adminUid) =>
    FirebaseFirestore.instance.collection('alerts').doc(alertId).update({
      'isRead': true,
      'readBy': adminUid,
      'readAt': FieldValue.serverTimestamp(),
    });

Future<void> markAllAlertsRead(List<AlertModel> alerts, String adminUid) {
  final unread = alerts.where((a) => !a.isRead).toList();
  if (unread.isEmpty) return Future.value();
  final batch = FirebaseFirestore.instance.batch();
  for (final a in unread) {
    batch.update(
      FirebaseFirestore.instance.collection('alerts').doc(a.id),
      {
        'isRead': true,
        'readBy': adminUid,
        'readAt': FieldValue.serverTimestamp(),
      },
    );
  }
  return batch.commit();
}
