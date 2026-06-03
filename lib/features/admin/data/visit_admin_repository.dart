import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kiba_app/features/auth/data/user_model.dart';
import 'package:kiba_app/features/field_advisor/data/visit_model.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class FaVisitStat {
  const FaVisitStat({
    required this.user,
    required this.visitCount,
    required this.totalKm,
    required this.totalAcres,
  });

  final UserModel user;
  final int       visitCount;
  final double    totalKm;
  final double    totalAcres;
}

class VisitStats {
  const VisitStats({
    required this.totalVisits,
    required this.totalKm,
    required this.totalAcres,
    required this.purposeBreakdown,
    required this.statusBreakdown,
    required this.perFa,
  });

  final int                  totalVisits;
  final double               totalKm;
  final double               totalAcres;
  final Map<VisitPurpose, int> purposeBreakdown;
  final Map<VisitStatus, int>  statusBreakdown;
  final List<FaVisitStat>    perFa;

  static VisitStats empty() => VisitStats(
        totalVisits:      0,
        totalKm:          0,
        totalAcres:       0,
        purposeBreakdown: {for (final p in VisitPurpose.values) p: 0},
        statusBreakdown:  {for (final s in VisitStatus.values)  s: 0},
        perFa:            [],
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

class VisitAdminRepository {
  static final _col =
      FirebaseFirestore.instance.collection('visits');

  Stream<List<VisitModel>> streamAll() => _col
      .orderBy('check_in', descending: true)
      .snapshots()
      .map((s) => s.docs.map(VisitModel.fromDoc).toList());

  Stream<List<VisitModel>> streamRange(DateTime from, DateTime to) => _col
      .where('check_in',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .where('check_in',
          isLessThanOrEqualTo: Timestamp.fromDate(to))
      .orderBy('check_in', descending: true)
      .snapshots()
      .map((s) => s.docs.map(VisitModel.fromDoc).toList());

  VisitStats computeStats(
      List<VisitModel> visits, List<UserModel> employees) {
    final totalKm    = visits.fold(0.0, (s, v) => s + v.distanceFromPrevKm);
    final totalAcres = visits.fold(0.0, (s, v) => s + v.pondArea);

    final purposeBreakdown = <VisitPurpose, int>{
      for (final p in VisitPurpose.values) p: 0,
    };
    final statusBreakdown = <VisitStatus, int>{
      for (final s in VisitStatus.values) s: 0,
    };

    for (final v in visits) {
      purposeBreakdown[v.purpose] = (purposeBreakdown[v.purpose] ?? 0) + 1;
      statusBreakdown[v.status]   = (statusBreakdown[v.status]   ?? 0) + 1;
    }

    final faCounts = <String, int>{};
    final faKm     = <String, double>{};
    final faAcres  = <String, double>{};
    for (final v in visits) {
      faCounts[v.uid]  = (faCounts[v.uid]  ?? 0) + 1;
      faKm[v.uid]      = (faKm[v.uid]      ?? 0) + v.distanceFromPrevKm;
      faAcres[v.uid]   = (faAcres[v.uid]   ?? 0) + v.pondArea;
    }

    final perFa = employees
        .map((e) => FaVisitStat(
              user:       e,
              visitCount: faCounts[e.uid] ?? 0,
              totalKm:    faKm[e.uid]     ?? 0,
              totalAcres: faAcres[e.uid]  ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.visitCount.compareTo(a.visitCount));

    return VisitStats(
      totalVisits:      visits.length,
      totalKm:          totalKm,
      totalAcres:       totalAcres,
      purposeBreakdown: purposeBreakdown,
      statusBreakdown:  statusBreakdown,
      perFa:            perFa,
    );
  }
}
