import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kiba_app/core/constants/app_constants.dart';
import 'package:kiba_app/features/admin/presentation/screens/admin_attendance_screen.dart';
import 'package:kiba_app/features/admin/presentation/screens/admin_employees_screen.dart';
import 'package:kiba_app/features/admin/presentation/screens/admin_field_visits_screen.dart';
import 'package:kiba_app/features/admin/presentation/screens/admin_home_screen.dart';
import 'package:kiba_app/features/admin/presentation/screens/admin_leaves_screen.dart';
import 'package:kiba_app/features/admin/presentation/screens/admin_registrations_screen.dart';
import 'package:kiba_app/features/admin/presentation/screens/admin_alerts_screen.dart';
import 'package:kiba_app/features/admin/presentation/screens/admin_settings_screen.dart';
import 'package:kiba_app/features/admin/presentation/shell/admin_shell.dart';
import 'package:kiba_app/features/auth/data/user_model.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';
import 'package:kiba_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:kiba_app/features/auth/presentation/screens/login_screen.dart';
import 'package:kiba_app/features/auth/presentation/screens/pending_approval_screen.dart';
import 'package:kiba_app/features/auth/presentation/screens/register_screen.dart';
import 'package:kiba_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:kiba_app/features/clerk/presentation/screens/clerk_home_screen.dart';
import 'package:kiba_app/features/clerk/presentation/shell/clerk_shell.dart';
import 'package:kiba_app/features/field_advisor/presentation/screens/fa_attendance_screen.dart';
import 'package:kiba_app/features/field_advisor/presentation/screens/fa_face_verify_screen.dart';
import 'package:kiba_app/features/field_advisor/presentation/screens/fa_home_screen.dart';
import 'package:kiba_app/features/field_advisor/presentation/screens/fa_leaves_screen.dart';
import 'package:kiba_app/features/field_advisor/presentation/screens/fa_profile_screen.dart';
import 'package:kiba_app/features/field_advisor/presentation/screens/fa_visits_screen.dart';
import 'package:kiba_app/features/field_advisor/presentation/shell/fa_shell.dart';
import 'package:kiba_app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:kiba_app/shared/presentation/screens/profile_screen.dart';

// ── Route constants ────────────────────────────────────────────────────────────
class AppRoutes {
  AppRoutes._();

  // Public / auth routes
  static const String splash          = '/';
  static const String onboarding      = '/onboarding';
  static const String login           = '/login';
  static const String register        = '/register';
  static const String forgotPassword  = '/forgot-password';
  static const String pendingApproval = '/pending-approval';
  static const String rejected        = '/rejected';

  // Field Advisor routes
  static const String faHome       = '/fa/home';
  static const String faFaceVerify = '/fa/face-verify';
  static const String faAttendance = '/fa/attendance';
  static const String faLeaves     = '/fa/leaves';
  static const String faVisits     = '/fa/visits';
  static const String faProfile    = '/fa/profile';

  // Clerk routes
  static const String clerkHome    = '/clerk/home';
  static const String clerkLeaves  = '/clerk/leaves';
  static const String clerkProfile = '/clerk/profile';

  // Admin routes
  static const String adminHome          = '/admin/home';
  static const String adminUsers         = '/admin/users';
  static const String adminAttendance    = '/admin/attendance';
  static const String adminFieldVisits   = '/admin/field-visits';
  static const String adminLeaves        = '/admin/leaves';
  static const String adminAlerts        = '/admin/alerts';
  static const String adminRegistrations = '/admin/registrations';
  static const String adminAnalytics     = '/admin/analytics';
  static const String adminSettings      = '/admin/settings';
}

// ── Router provider ────────────────────────────────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = _AuthStateListenable(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: authListenable,

    redirect: (context, state) {
      final user     = ref.read(currentUserProvider);
      final location = state.uri.toString();

      // '/' is the splash path — use exact match to avoid matching every route.
      // All other auth paths are unique prefixes so startsWith is safe.
      final isPublic = location == AppRoutes.splash ||
          location.startsWith(AppRoutes.onboarding) ||
          location.startsWith(AppRoutes.login) ||
          location.startsWith(AppRoutes.register) ||
          location.startsWith(AppRoutes.forgotPassword);

      // ── Not logged in ──────────────────────────────────────────────────────
      if (user == null) {
        return isPublic ? null : AppRoutes.login;
      }

      // ── Pending approval ───────────────────────────────────────────────────
      if (user.isPending) {
        return location == AppRoutes.pendingApproval
            ? null
            : AppRoutes.pendingApproval;
      }

      // ── Rejected ───────────────────────────────────────────────────────────
      if (user.isRejected) {
        return location == AppRoutes.rejected ? null : AppRoutes.rejected;
      }

      // ── Deactivated (was approved, later disabled by admin) ────────────────
      if (!user.isActive) {
        return location == AppRoutes.rejected ? null : AppRoutes.rejected;
      }

      // ── Approved + active — redirect away from public/auth screens ─────────
      if (isPublic ||
          location == AppRoutes.pendingApproval ||
          location == AppRoutes.rejected) {
        return _homeForRole(user.role);
      }

      // ── Cross-role route protection ────────────────────────────────────────
      if (location.startsWith('/fa')    && !user.isFieldAdvisor) {
        return _homeForRole(user.role);
      }
      if (location.startsWith('/clerk') && !user.isClerk) {
        return _homeForRole(user.role);
      }
      if (location.startsWith('/admin') && !user.isAdmin) {
        return _homeForRole(user.role);
      }

      return null;
    },

    routes: [
      // ── Public / auth routes ───────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.pendingApproval,
        builder: (_, __) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: AppRoutes.rejected,
        builder: (_, __) => const RejectedScreen(),
      ),

      // ── Field Advisor Shell ────────────────────────────────────────────────
      ShellRoute(
        builder: (_, state, child) => FAShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.faHome,       builder: (_, __) => const FAHomeScreen()),
          GoRoute(
            path: AppRoutes.faFaceVerify,
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return FAFaceVerifyScreen(
                isCheckout:      extra?['isCheckout']      as bool?   ?? false,
                isEarlyCheckout: extra?['isEarlyCheckout'] as bool?   ?? false,
                checkoutReason:  extra?['checkoutReason']  as String?,
              );
            },
          ),
          GoRoute(path: AppRoutes.faAttendance, builder: (_, __) => const FaAttendanceScreen()),
          GoRoute(path: AppRoutes.faLeaves,     builder: (_, __) => const FaLeavesScreen()),
          GoRoute(path: AppRoutes.faVisits,     builder: (_, __) => const FaVisitsScreen()),
          GoRoute(path: AppRoutes.faProfile,    builder: (_, __) => const FaProfileScreen()),
        ],
      ),

      // ── Clerk Shell ────────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, state, child) => ClerkShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.clerkHome,    builder: (_, __) => const ClerkHomeScreen()),
          GoRoute(
            path: AppRoutes.clerkLeaves,
            builder: (_, __) => const _PlaceholderScreen(
              title: 'Leaves',
              icon:  Icons.event_note_rounded,
            ),
          ),
          GoRoute(path: AppRoutes.clerkProfile, builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // ── Admin Shell ────────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.adminHome,          builder: (_, __) => const AdminHomeScreen()),
          GoRoute(path: AppRoutes.adminUsers,         builder: (_, __) => const AdminEmployeesScreen()),
          GoRoute(path: AppRoutes.adminAttendance,    builder: (_, __) => const AdminAttendanceScreen()),
          GoRoute(path: AppRoutes.adminFieldVisits,   builder: (_, __) => const AdminFieldVisitsScreen()),
          GoRoute(path: AppRoutes.adminLeaves,        builder: (_, __) => const AdminLeavesScreen()),
          GoRoute(path: AppRoutes.adminRegistrations, builder: (_, __) => const AdminRegistrationsScreen()),
          GoRoute(path: AppRoutes.adminSettings,      builder: (_, __) => const AdminSettingsScreen()),
          GoRoute(path: AppRoutes.adminAlerts,        builder: (_, __) => const AdminAlertsScreen()),
          GoRoute(
            path: AppRoutes.adminAnalytics,
            builder: (_, __) => const _AdminPlaceholder(
              title: 'Analytics',
              icon:  Icons.bar_chart_rounded,
            ),
          ),
        ],
      ),
    ],
  );
});

// ── Helpers ────────────────────────────────────────────────────────────────────
String _homeForRole(String role) {
  switch (role) {
    case AppConstants.roleAdmin:
      return AppRoutes.adminHome;
    case AppConstants.roleClerk:
      return AppRoutes.clerkHome;
    case AppConstants.roleFieldAdvisor:
    default:
      return AppRoutes.faHome;
  }
}

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen<UserModel?>(currentUserProvider, (_, __) => notifyListeners());
  }
}

// ── Placeholder widgets ────────────────────────────────────────────────────────
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.icon});
  final String   title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('$title — Coming Soon',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _AdminPlaceholder extends StatelessWidget {
  const _AdminPlaceholder({required this.title, required this.icon});
  final String   title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.35)),
          const SizedBox(height: 16),
          Text('$title — Coming Soon',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Rejected / Deactivated screen ─────────────────────────────────────────────
class RejectedScreen extends ConsumerWidget {
  const RejectedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isRejected = user?.isRejected ?? true;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block_rounded,
                    size: 40, color: Color(0xFFEF4444)),
              ),
              const SizedBox(height: 24),
              Text(
                isRejected ? 'Registration Declined' : 'Account Deactivated',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (user?.rejectionReason != null) ...[
                Text(
                  'Reason: ${user!.rejectionReason}',
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF6B7280)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                isRejected
                    ? 'Your registration request was not approved. Please contact your administrator for more information.'
                    : 'Your account has been deactivated. Please contact your administrator.',
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF6B7280), height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () async {
                    await ref.read(authNotifierProvider.notifier).signOut();
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    foregroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text('Sign Out',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
