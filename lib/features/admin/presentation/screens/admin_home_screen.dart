import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kiba_app/core/router/app_router.dart';
import 'package:kiba_app/features/admin/domain/alert_provider.dart';
import 'package:kiba_app/features/admin/domain/user_admin_providers.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';
import 'package:kiba_app/features/field_advisor/domain/leave_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _navy   = Color(0xFF0D1B2A);
const _navyMd = Color(0xFF1A2F45);
const _amber  = Color(0xFFF59E0B);
const _green  = Color(0xFF059669);
const _rose   = Color(0xFFEF4444);
const _violet = Color(0xFF7C3AED);
const _blue   = Color(0xFF3B82F6);
const _muted  = Color(0xFF64748B);
const _ink    = Color(0xFF0F172A);

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user       = ref.watch(currentUserProvider);
    final employees  = ref.watch(allEmployeesProvider);
    final regs       = ref.watch(pendingRegistrationsProvider);
    final leaves     = ref.watch(pendingLeavesProvider);
    final alertCount = ref.watch(unreadAlertsCountProvider);
    final now        = DateTime.now();

    final totalStaff    = employees.valueOrNull?.length ?? 0;
    final pendingRegs   = regs.valueOrNull?.length      ?? 0;
    final pendingLeaves = leaves.valueOrNull?.length    ?? 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Welcome banner ────────────────────────────────────────────────
          _WelcomeBanner(
            name: user?.displayName ?? 'Admin',
            greeting: _greeting(),
            today: now,
          ),

          const SizedBox(height: 24),

          // ── Overview stats ────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _SectionLabel('Overview'),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: _StatTile(
                      icon:  Icons.people_alt_rounded,
                      label: 'Total Staff',
                      value: employees.isLoading ? '—' : '$totalStaff',
                      color: _navy,
                      onTap: () => context.go(AppRoutes.adminUsers),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon:  Icons.how_to_reg_rounded,
                      label: 'Pending Approvals',
                      value: regs.isLoading ? '—' : '$pendingRegs',
                      color: pendingRegs > 0 ? _violet : _muted,
                      badge: pendingRegs,
                      onTap: () => context.go(AppRoutes.adminRegistrations),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _StatTile(
                      icon:  Icons.event_note_rounded,
                      label: 'Pending Leaves',
                      value: leaves.isLoading ? '—' : '$pendingLeaves',
                      color: pendingLeaves > 0 ? _amber : _muted,
                      badge: pendingLeaves,
                      onTap: () => context.go(AppRoutes.adminLeaves),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon:  Icons.notifications_rounded,
                      label: 'Unread Alerts',
                      value: '$alertCount',
                      color: alertCount > 0 ? _rose : _muted,
                      badge: alertCount,
                      onTap: () => context.go(AppRoutes.adminAlerts),
                    ),
                  ),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Quick access grid ─────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _SectionLabel('Quick Access'),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.05,
              children: [
                _QuickTile(
                  icon:  Icons.people_alt_rounded,
                  label: 'Employees',
                  color: _navy,
                  onTap: () => context.go(AppRoutes.adminUsers),
                ),
                _QuickTile(
                  icon:  Icons.schedule_rounded,
                  label: 'Attendance',
                  color: _green,
                  onTap: () => context.go(AppRoutes.adminAttendance),
                ),
                _QuickTile(
                  icon:  Icons.pin_drop_rounded,
                  label: 'Field Visits',
                  color: _blue,
                  onTap: () => context.go(AppRoutes.adminFieldVisits),
                ),
                _QuickTile(
                  icon:  Icons.approval_rounded,
                  label: 'Leaves',
                  color: _amber,
                  onTap: () => context.go(AppRoutes.adminLeaves),
                ),
                _QuickTile(
                  icon:  Icons.how_to_reg_rounded,
                  label: 'Approvals',
                  color: _violet,
                  onTap: () => context.go(AppRoutes.adminRegistrations),
                ),
                _QuickTile(
                  icon:  Icons.settings_rounded,
                  label: 'Settings',
                  color: _muted,
                  onTap: () => context.go(AppRoutes.adminSettings),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Welcome banner — navy gradient strip with avatar + greeting + date
// ─────────────────────────────────────────────────────────────────────────────
class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({
    required this.name,
    required this.greeting,
    required this.today,
  });

  final String name;
  final String greeting;
  final DateTime today;

  String _initials(String n) {
    final p = n.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return n.isNotEmpty ? n[0].toUpperCase() : 'A';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, _navyMd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _amber.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _amber,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name.split(' ').first,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(today),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label with amber left-bar
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: _amber,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _ink,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat tile — white card with colored left border + number + badge
// ─────────────────────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  final IconData     icon;
  final String       label;
  final String       value;
  final Color        color;
  final int          badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick access tile — square white card with icon + label
// ─────────────────────────────────────────────────────────────────────────────
class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
