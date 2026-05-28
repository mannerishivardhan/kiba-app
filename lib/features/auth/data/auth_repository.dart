import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kiba_app/core/constants/app_constants.dart';
import 'package:kiba_app/features/auth/data/user_model.dart';

/// All Firebase Auth + Firestore operations for authentication.
class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // ── Current user stream ───────────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  // ── Sign in with email + password ─────────────────────────────────────────
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) throw Exception('Authentication failed — no user returned.');

    return _fetchOrCreateUserDoc(user);
  }

  // ── Fetch Firestore profile (create if first login) ───────────────────────
  Future<UserModel> _fetchOrCreateUserDoc(User firebaseUser) async {
    final ref = _firestore
        .collection(AppConstants.usersCollection)
        .doc(firebaseUser.uid);

    final snap = await ref.get();

    if (snap.exists && snap.data() != null) {
      return UserModel.fromMap(firebaseUser.uid, snap.data()!);
    }

    // First-time login — create a default profile
    final newUser = UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? 'Kiba User',
      role: AppConstants.roleFieldAdvisor,
      photoUrl: firebaseUser.photoURL,
      createdAt: DateTime.now(),
    );

    await ref.set(newUser.toMap());
    return newUser;
  }


  // ── Fetch current user's Firestore doc ────────────────────────────────────
  Future<UserModel?> fetchCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snap = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .get();

    if (!snap.exists || snap.data() == null) return null;
    return UserModel.fromMap(user.uid, snap.data()!);
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Send password reset email ─────────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Map Firebase errors to readable messages ──────────────────────────────
  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'No internet connection.';
        case 'invalid-credential':
          return 'Invalid email or password.';
        default:
          return e.message ?? 'An error occurred. Please try again.';
      }
    }
    return 'Error: $e';
  }
}
