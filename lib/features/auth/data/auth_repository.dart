import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kiba_app/core/constants/app_constants.dart';
import 'package:kiba_app/features/auth/data/user_model.dart';

class AuthRepository {
  AuthRepository({
    FirebaseAuth?     auth,
    FirebaseFirestore? firestore,
  })  : _auth      = auth      ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth      _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppConstants.usersCollection);

  // ── Auth state stream ──────────────────────────────────────────────────────
  Stream<User?> get authStateChanges       => _auth.authStateChanges();
  User?         get currentFirebaseUser    => _auth.currentUser;

  // ── Sign in ────────────────────────────────────────────────────────────────
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email:    email.trim(),
      password: password,
    );

    final fbUser = credential.user;
    if (fbUser == null) throw Exception('Authentication failed.');

    final snap = await _users.doc(fbUser.uid).get();
    if (!snap.exists || snap.data() == null) {
      await _auth.signOut();
      throw Exception(
        'No account profile found. Please register or contact your administrator.',
      );
    }

    // Best-effort last-login timestamp (approved users only; ignore if denied)
    _users.doc(fbUser.uid).update({'lastLoginAt': FieldValue.serverTimestamp()})
        .catchError((_) {});

    return UserModel.fromMap(fbUser.uid, snap.data()!);
  }

  // ── Register (creates Firebase Auth + pending Firestore doc) ──────────────
  Future<UserModel> register({
    required String email,
    required String password,
    required String displayName,
    required String role,
    required String phone,
    required String gender,
    required int    age,
    required String aadharNo,
    required String panCard,
    required String emergencyContactName,
    required String emergencyContactPhone,
    required String address,
  }) async {
    // Create Firebase Auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email:    email.trim(),
      password: password,
    );

    final fbUser = credential.user!;
    await fbUser.updateDisplayName(displayName.trim());

    // Build Firestore user doc
    final doc = {
      'uid':          fbUser.uid,
      'email':        email.trim(),
      'displayName':  displayName.trim(),
      'role':         role,
      'status':       AppConstants.accountPending,
      'isActive':     false,
      'phone':        phone.trim(),
      'gender':       gender,
      'age':          age,
      'aadharNo':     _maskAadhar(aadharNo),
      'panCard':      _maskPan(panCard),
      'emergencyContactName':  emergencyContactName.trim(),
      'emergencyContactPhone': emergencyContactPhone.trim(),
      'address':               address.trim(),
      'teamId':          null,
      'photoUrl':        null,
      'approvedAt':      null,
      'approvedBy':      null,
      'rejectionReason': null,
      'createdAt':       FieldValue.serverTimestamp(),
      'lastLoginAt':     null,
    };

    await _users.doc(fbUser.uid).set(doc);

    // Return model (createdAt will be null here since server sets it,
    // but that's fine — PendingApprovalScreen streams the live doc)
    return UserModel(
      uid:                    fbUser.uid,
      email:                  email.trim(),
      displayName:            displayName.trim(),
      role:                   role,
      status:                 AppConstants.accountPending,
      isActive:               false,
      phone:                  phone.trim(),
      gender:                 gender,
      age:                    age,
      aadharNo:               _maskAadhar(aadharNo),
      panCard:                _maskPan(panCard),
      emergencyContactName:   emergencyContactName.trim(),
      emergencyContactPhone:  emergencyContactPhone.trim(),
      address:                address.trim(),
    );
  }

  // ── Fetch current user's Firestore doc ─────────────────────────────────────
  Future<UserModel?> fetchCurrentUser() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return null;

    final snap = await _users.doc(fbUser.uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return UserModel.fromMap(fbUser.uid, snap.data()!);
  }

  // ── Stream a user's doc in real-time (for PendingApprovalScreen) ──────────
  Stream<UserModel?> streamUser(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return UserModel.fromMap(uid, snap.data()!);
    });
  }

  // ── Stream all pending registrations (admin) ───────────────────────────────
  Stream<List<UserModel>> streamPendingRegistrations() {
    return _users
        .where('status', isEqualTo: AppConstants.accountPending)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => UserModel.fromMap(d.id, d.data()))
            .toList());
  }

  // ── Admin: approve a pending user ──────────────────────────────────────────
  // Assigns a human-readable employeeId (FA-001, CL-001, AD-001) atomically
  // with the approval using a Firestore transaction + counter document.
  Future<void> approveUser(String uid, String adminUid) async {
    // Read role once outside the transaction (cheap idempotent read).
    final userSnap = await _users.doc(uid).get();
    final role     = userSnap.data()?['role'] as String? ?? 'field_advisor';

    // Already has an ID? Skip generation (handles re-approval edge case).
    if (userSnap.data()?['employeeId'] != null) {
      await _users.doc(uid).update({
        'status':          AppConstants.accountApproved,
        'isActive':        true,
        'approvedAt':      FieldValue.serverTimestamp(),
        'approvedBy':      adminUid,
        'rejectionReason': null,
      });
      return;
    }

    final String counterKey;
    final String prefix;
    if (role == 'clerk') {
      counterKey = 'cl_count'; prefix = 'CL';
    } else if (role == 'admin') {
      counterKey = 'ad_count'; prefix = 'AD';
    } else {
      counterKey = 'fa_count'; prefix = 'FA';
    }

    final counterRef =
        _firestore.collection('counters').doc('employee_sequences');

    await _firestore.runTransaction((txn) async {
      final counterSnap = await txn.get(counterRef);
      final current    = (counterSnap.data()?[counterKey] as int?) ?? 0;
      final next       = current + 1;
      final employeeId = '$prefix-${next.toString().padLeft(3, '0')}';

      // Write new counter value (merge so other role counters are preserved).
      txn.set(counterRef, {counterKey: next}, SetOptions(merge: true));

      // Approve the user and stamp the new ID in one atomic write.
      txn.update(_users.doc(uid), {
        'employeeId':      employeeId,
        'status':          AppConstants.accountApproved,
        'isActive':        true,
        'approvedAt':      FieldValue.serverTimestamp(),
        'approvedBy':      adminUid,
        'rejectionReason': null,
      });
    });
  }

  // ── Admin: reject a pending user ───────────────────────────────────────────
  Future<void> rejectUser(
    String uid,
    String adminUid,
    String reason,
  ) async {
    await _users.doc(uid).update({
      'status':          AppConstants.accountRejected,
      'isActive':        false,
      'approvedAt':      FieldValue.serverTimestamp(),
      'approvedBy':      adminUid,
      'rejectionReason': reason.trim(),
    });
  }

  // ── Update user profile ────────────────────────────────────────────────────
  Future<UserModel> updateUserProfile(
      String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).update(data);
    final snap = await _users.doc(uid).get();
    return UserModel.fromMap(uid, snap.data()!);
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> signOut() => _auth.signOut();

  // ── Password reset ─────────────────────────────────────────────────────────
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  // ── PII masking ───────────────────────────────────────────────────────────
  static String _maskAadhar(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return 'XXXX-XXXX-XXXX';
    return 'XXXX-XXXX-${digits.substring(digits.length - 4)}';
  }

  static String _maskPan(String raw) {
    final clean = raw.trim().toUpperCase();
    if (clean.length < 10) return clean;
    // ABCDE1234F → ABCXX1234F
    return '${clean.substring(0, 3)}XX${clean.substring(5)}';
  }

  // ── Friendly Firebase error messages ──────────────────────────────────────
  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Invalid email or password.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'email-already-in-use':
          return 'An account with this email already exists.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'No internet connection.';
        default:
          return e.message ?? 'An error occurred. Please try again.';
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}
