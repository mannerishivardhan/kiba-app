import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kiba_app/core/router/app_router.dart';
import 'package:kiba_app/core/theme/app_theme.dart';
import 'package:kiba_app/features/admin/domain/admin_visit_providers.dart';
import 'package:kiba_app/features/admin/domain/alert_provider.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';
import 'package:kiba_app/features/field_advisor/domain/leave_provider.dart';

// ── Colour tokens ─────────────────────────────────────────────────────────────
const _navy      = Color(0xFF0D1B2A);
const _navyLight = Color(0xFF162637);
const _accent    = Color(0xFFF59E0B);
const _muted     = Color(0xFF64748B);
const _itemText  = Color(0xFFCBD5E1);

// ── Route → title map ─────────────────────────────────────────────────────────
const _titles = <String, String>{
  '/admin/home':          'Dashboard',
  '/admin/users':         'Employees',
  '/admin/attendance':    'Attendance',
  '/admin/field-visits':  'Field Visits',
  '/admin/leaves':        'Leave Requests',
  '/admin/registrations': 'Pending Approvals',
  '/admin/alerts':        'Alerts',
  '/admin/analytics':     'Analytics',
  '/admin/settings':      'Settings',
};

String _titleFor(String location) {
  for (final e in _titles.entries) {
    if (location.startsWith(e.key)) return e.value;
  }
  return 'Admin';
}

// ── Shell ─────────────────────────────────────────────────────────────────────
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  final _key = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    return Theme(
      data: KibaTheme.admin,
      child: Scaffold(
        key: _key,
        backgroundColor: const Color(0xFFF0F4F8),
        drawer: _AdminDrawer(scaffoldKey: _key),
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.menu_rounded, size: 22),
            onPressed: () => _key.currentState?.openDrawer(),
          ),
          title: Text(
            _titleFor(location),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          actions: [
            Consumer(
              builder: (ctx, ref, _) {
                final count = ref.watch(unreadAlertsCountProvider);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, size: 22),
                      onPressed: () => context.go(AppRoutes.adminAlerts),
                    ),
                    if (count > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(color: _navy, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: widget.child,
      ),
    );
  }
}

// ── Drawer ─────────────────────────────────────────────────────────────────────
class _AdminDrawer extends ConsumerWidget {
  const _AdminDrawer({required this.scaffoldKey});
  final GlobalKey<ScaffoldState> scaffoldKey;

  static const _sections = <_NavSection>[
    _NavSection(label: null, items: [
      _NavItem(icon: Icons.dashboard_rounded,   label: 'Dashboard',      route: '/admin/home'),
    ]),
    _NavSection(label: 'MONITORING', items: [
      _NavItem(icon: Icons.people_alt_rounded,  label: 'Employees',      route: '/admin/users'),
      _NavItem(icon: Icons.schedule_rounded,    label: 'Attendance',     route: '/admin/attendance'),
      _NavItem(icon: Icons.pin_drop_rounded,    label: 'Field visits',   route: '/admin/field-visits'),
    ]),
    _NavSection(label: 'MANAGEMENT', items: [
      _NavItem(icon: Icons.approval_rounded,       label: 'Leave requests', route: '/admin/leaves'),
      _NavItem(icon: Icons.how_to_reg_rounded,     label: 'Registrations',  route: '/admin/registrations'),
      _NavItem(icon: Icons.notifications_rounded,  label: 'Alerts',         route: '/admin/alerts'),
      _NavItem(icon: Icons.settings_rounded,       label: 'Settings',       route: '/admin/settings'),
    ]),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user     = ref.watch(currentUserProvider);
    final location = GoRouterState.of(context).uri.toString();

    final badges = <String, int>{
      '/admin/alerts':        ref.watch(unreadAlertsCountProvider),
      '/admin/leaves':        ref.watch(pendingLeavesProvider).valueOrNull?.length ?? 0,
      '/admin/registrations': ref.watch(pendingRegistrationsProvider).valueOrNull?.length ?? 0,
      '/admin/field-visits':  ref.watch(todayVisitsCountProvider).valueOrNull ?? 0,
    };

    void go(String route) {
      scaffoldKey.currentState?.closeDrawer();
      context.go(route);
    }

    return Drawer(
      backgroundColor: _navy,
      width: 268,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'KIBA',
                      style: TextStyle(
                        color: Color(0xFF1A1200),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Admin panel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user?.displayName ?? 'Admin',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
            const SizedBox(height: 8),

            // ── Nav items ─────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _sections.map((s) => _SectionWidget(
                  section:  s,
                  location: location,
                  onTap:    go,
                  badges:   badges,
                )).toList(),
              ),
            ),

            // ── Sign-out ──────────────────────────────────────────────────
            Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
            InkWell(
              onTap: () async {
                scaffoldKey.currentState?.closeDrawer();
                await ref.read(authNotifierProvider.notifier).signOut();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: const [
                    Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)),
                    SizedBox(width: 12),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Section ───────────────────────────────────────────────────────────────────
class _SectionWidget extends StatelessWidget {
  const _SectionWidget({
    required this.section,
    required this.location,
    required this.onTap,
    this.badges = const {},
  });

  final _NavSection            section;
  final String                 location;
  final void Function(String)  onTap;
  final Map<String, int>       badges;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 0, 4),
            child: Text(
              section.label!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _muted,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ...section.items.map((item) {
          final active = location.startsWith(item.route);
          final badge  = badges[item.route] ?? 0;
          return _ItemTile(
            item:   item,
            active: active,
            badge:  badge,
            onTap:  () => onTap(item.route),
          );
        }),
      ],
    );
  }
}

// ── Item tile ─────────────────────────────────────────────────────────────────
class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  final _NavItem     item;
  final bool         active;
  final VoidCallback onTap;
  final int          badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.only(left: 0, right: 12, top: 11, bottom: 11),
        decoration: BoxDecoration(
          color: active ? _navyLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Accent bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 3,
              height: 20,
              margin: const EdgeInsets.only(right: 12, left: 4),
              decoration: BoxDecoration(
                color: active ? _accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(
              item.icon,
              size: 18,
              color: active ? Colors.white : _itemText,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? Colors.white : _itemText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────
class _NavSection {
  const _NavSection({required this.label, required this.items});
  final String?       label;
  final List<_NavItem> items;
}

class _NavItem {
  const _NavItem({required this.icon, required this.label, required this.route});
  final IconData icon;
  final String   label;
  final String   route;
}
