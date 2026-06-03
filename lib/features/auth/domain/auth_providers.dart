import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiba_app/features/auth/data/auth_repository.dart';
import 'package:kiba_app/features/auth/data/user_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// ── Auth state sealed class ───────────────────────────────────────────────────
sealed class AuthState {
  const AuthState();
}

class AuthIdle extends AuthState {
  const AuthIdle();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthSuccess extends AuthState {
  const AuthSuccess(this.user);
  final UserModel user;
}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}

// ── Auth Notifier ─────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthIdle());

  final AuthRepository _repo;

  // Restores session from Firebase on cold start (called by SplashScreen)
  Future<void> restoreSession() async {
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) return;

    try {
      final user = await _repo.fetchCurrentUser();
      if (user != null) {
        state = AuthSuccess(user);
      }
    } catch (_) {
      // Silently fail — splash will route to login
    }
  }

  // Seeds state directly (used after restoreSession resolves user)
  void seedUser(UserModel user) => state = AuthSuccess(user);

  // Sign in
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    try {
      final user = await _repo.signInWithEmail(
        email:    email,
        password: password,
      );
      state = AuthSuccess(user);
    } catch (e) {
      state = AuthError(AuthRepository.friendlyError(e));
    }
  }

  // Register new account (creates Firebase Auth + pending Firestore doc)
  Future<void> register({
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
    state = const AuthLoading();
    try {
      final user = await _repo.register(
        email:                 email,
        password:              password,
        displayName:           displayName,
        role:                  role,
        phone:                 phone,
        gender:                gender,
        age:                   age,
        aadharNo:              aadharNo,
        panCard:               panCard,
        emergencyContactName:  emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
        address:               address,
      );
      state = AuthSuccess(user);
    } catch (e) {
      state = AuthError(AuthRepository.friendlyError(e));
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthIdle();
  }

  // Update own profile fields
  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    try {
      final updated = await _repo.updateUserProfile(uid, data);
      state = AuthSuccess(updated);
    } catch (e) {
      state = AuthError(AuthRepository.friendlyError(e));
    }
  }

  void clearError() {
    if (state is AuthError) state = const AuthIdle();
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

// ── Current user convenience provider ────────────────────────────────────────
final currentUserProvider = Provider<UserModel?>((ref) {
  final s = ref.watch(authNotifierProvider);
  if (s is AuthSuccess) return s.user;
  return null;
});

// ── Real-time stream of any user doc (for PendingApprovalScreen) ──────────────
final userStreamProvider =
    StreamProvider.family.autoDispose<UserModel?, String>((ref, uid) {
  return ref.read(authRepositoryProvider).streamUser(uid);
});

// ── Stream of all pending registrations (admin) ───────────────────────────────
final pendingRegistrationsProvider =
    StreamProvider.autoDispose<List<UserModel>>((ref) {
  return ref.read(authRepositoryProvider).streamPendingRegistrations();
});
