import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';

class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState
    extends ConsumerState<PendingApprovalScreen> {
  static const _navy  = Color(0xFF1E3A8A);
  static const _gold  = Color(0xFFE8A020);
  static const _label = Color(0xFF1A1A2E);
  static const _hint  = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();

    // Start listening once initState fires (post-frame so ref is ready)
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenForApproval());
  }

  void _listenForApproval() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // userStreamProvider streams the Firestore doc in real-time.
    // When admin approves or rejects, status changes and the router
    // redirect will automatically route to the right screen.
    ref.listen(userStreamProvider(uid), (_, next) {
      next.whenData((user) {
        if (user == null) return;
        if (user.status != 'pending') {
          // Seed AuthNotifier with the updated user so router fires
          ref.read(authNotifierProvider.notifier).seedUser(user);
          // Router's refreshListenable will handle navigation
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(),

              // ── Animated waiting indicator ───────────────────────────────
              _PulsingBadge().animate().scale(
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  ),

              const SizedBox(height: 36),

              const Text(
                'Pending Approval',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _label,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.15),

              const SizedBox(height: 12),

              Text(
                'Hi ${user?.displayName ?? 'there'}! Your registration is under review.',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _label,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 300.ms).fadeIn(),

              const SizedBox(height: 10),

              const Text(
                'Our admin team will review your profile and activate your account. '
                'This page will automatically update when your account is approved — '
                'no need to refresh.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: _hint,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 350.ms).fadeIn(),

              const SizedBox(height: 40),

              // ── Status chips ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatusChip(
                    icon: Icons.check_circle_rounded,
                    label: 'Registered',
                    color: const Color(0xFF059669),
                    active: true,
                  ),
                  _DashedLine(),
                  _StatusChip(
                    icon: Icons.hourglass_top_rounded,
                    label: 'Under Review',
                    color: _gold,
                    active: true,
                  ),
                  _DashedLine(),
                  _StatusChip(
                    icon: Icons.rocket_launch_rounded,
                    label: 'Active',
                    color: _navy,
                    active: false,
                  ),
                ],
              ).animate(delay: 400.ms).fadeIn(),

              const Spacer(),

              // ── Sign out option ──────────────────────────────────────────
              TextButton.icon(
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).signOut();
                },
                icon: const Icon(Icons.logout_rounded,
                    size: 18, color: Color(0xFF9CA3AF)),
                label: const Text(
                  'Sign out and use a different account',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ).animate(delay: 500.ms).fadeIn(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pulsing badge animation ────────────────────────────────────────────────────
class _PulsingBadge extends StatefulWidget {
  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final scale = 1.0 + _ctrl.value * 0.08;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFEF3C7),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE8A020)
                      .withValues(alpha: 0.3 + _ctrl.value * 0.2),
                  blurRadius: 20 + _ctrl.value * 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              size: 48,
              color: Color(0xFFE8A020),
            ),
          ),
        );
      },
    );
  }
}

// ── Status chip ────────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
  });
  final IconData icon;
  final String   label;
  final Color    color;
  final bool     active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color.withValues(alpha: 0.12) : const Color(0xFFF3F4F6),
            border: Border.all(
              color: active ? color : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Icon(icon, size: 20,
              color: active ? color : const Color(0xFFD1D5DB)),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? color : const Color(0xFFD1D5DB),
          ),
        ),
      ],
    );
  }
}

class _DashedLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: SizedBox(
        width: 32,
        child: Row(
          children: List.generate(
            4,
            (_) => Expanded(
              child: Container(
                height: 1.5,
                color: const Color(0xFFE5E7EB),
                margin: const EdgeInsets.symmetric(horizontal: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
