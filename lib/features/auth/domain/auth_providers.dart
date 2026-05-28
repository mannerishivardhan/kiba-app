import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiba_app/features/auth/data/auth_repository.dart';
import 'package:kiba_app/features/auth/data/user_model.dart';

// ── Repository provider ───────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// ── Auth state ────────────────────────────────────────────────────────────────
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

  /// Sign in and emit [AuthSuccess] or [AuthError].
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    try {
      final user = await _repo.signInWithEmail(
        email: email,
        password: password,
      );
      state = AuthSuccess(user);
    } catch (e, stack) {
      print('Auth Error: $e');
      print('Stack trace: $stack');
      state = AuthError(AuthRepository.friendlyError(e));
    }
  }

  /// Sign out and reset state.
  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthIdle();
  }

  /// Clear error back to idle (e.g., when user edits a field).
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
  final state = ref.watch(authNotifierProvider);
  if (state is AuthSuccess) return state.user;
  return null;
});
