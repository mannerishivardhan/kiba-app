import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kiba_app/core/constants/app_constants.dart';
import 'package:kiba_app/features/auth/data/user_model.dart';

class UserAdminRepository {
  UserAdminRepository({FirebaseFirestore? fs})
      : _fs = fs ?? FirebaseFirestore.instance;

  final FirebaseFirestore _fs;

  Stream<List<UserModel>> streamAllEmployees() {
    return _fs.collection(AppConstants.usersCollection).snapshots().map((snap) {
      final users = snap.docs
          .map((d) => UserModel.fromMap(d.id, d.data()))
          .where((u) => !u.isAdmin)
          .toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      return users;
    });
  }

  Future<void> setActiveStatus(String uid, {required bool isActive}) async {
    await _fs
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({'isActive': isActive});
  }
}
