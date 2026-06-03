import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiba_app/features/admin/data/visit_admin_repository.dart';
import 'package:kiba_app/features/field_advisor/data/visit_model.dart';

typedef VisitRangeKey = ({DateTime from, DateTime to});

final adminVisitRepoProvider =
    Provider<VisitAdminRepository>((_) => VisitAdminRepository());

final adminAllVisitsProvider =
    StreamProvider.autoDispose<List<VisitModel>>((ref) =>
        ref.read(adminVisitRepoProvider).streamAll());

final adminVisitRangeProvider =
    StreamProvider.family
        .autoDispose<List<VisitModel>, VisitRangeKey>((ref, key) =>
            ref.read(adminVisitRepoProvider).streamRange(key.from, key.to));

// Today's visit count — non-autoDispose so the shell badge stays live
final todayVisitsCountProvider = StreamProvider<int>((ref) {
  final now   = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return ref
      .read(adminVisitRepoProvider)
      .streamRange(today, today.add(const Duration(days: 1)))
      .map((v) => v.length);
});
