import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:kiba_app/core/router/app_router.dart';
import 'package:kiba_app/core/theme/app_theme.dart';

const _green     = Color(0xFF059669);
const _greenDark = Color(0xFF047857);
const _inactive  = Color(0xFFB0BEC5);

/// Field Advisor Shell — 5-item nav with center FAB as the home screen.
/// Gates entry behind location permission; re-checks on every app resume.
/// 0=Attendance · 1=Leaves · [FAB/Home] · 3=Visits · 4=Profile
class FAShell extends ConsumerStatefulWidget {
  const FAShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<FAShell> createState() => _FAShellState();
}

class _FAShellState extends ConsumerState<FAShell>
    with WidgetsBindingObserver {
  LocationPermission? _perm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    final perm = await Geolocator.checkPermission();
    if (mounted) setState(() => _perm = perm);
  }

  Future<void> _requestPermission() async {
    final perm = await Geolocator.requestPermission();
    if (mounted) setState(() => _perm = perm);
  }

  bool get _granted =>
      _perm == LocationPermission.whileInUse ||
      _perm == LocationPermission.always;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: KibaTheme.fieldAdvisor,
      child: switch (_perm) {
        null => const Scaffold(
            backgroundColor: Color(0xFFF4FBF7),
            body: Center(child: CircularProgressIndicator()),
          ),
        _ when _granted => _FAScaffold(child: widget.child),
        _ => _LocationGate(
            isPermanent: _perm == LocationPermission.deniedForever,
            onAllow: _requestPermission,
          ),
      },
    );
  }
}

class _FAScaffold extends StatelessWidget {
  const _FAScaffold({required this.child});
  final Widget child;

  static const _navItems = [
    (route: AppRoutes.faAttendance, activeIcon: Icons.calendar_today_rounded, icon: Icons.calendar_today_outlined, label: 'Attendance'),
    (route: AppRoutes.faLeaves,     activeIcon: Icons.event_note_rounded,     icon: Icons.event_note_outlined,     label: 'Leaves'),
    (route: '',                     activeIcon: Icons.add,                    icon: Icons.add,                     label: ''),
    (route: AppRoutes.faVisits,     activeIcon: Icons.map_rounded,            icon: Icons.map_outlined,            label: 'Visits'),
    (route: AppRoutes.faProfile,    activeIcon: Icons.person_rounded,         icon: Icons.person_outlined,         label: 'Profile'),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/fa/home'))       return -1;
    if (loc.startsWith('/fa/attendance')) return 0;
    if (loc.startsWith('/fa/leaves'))     return 1;
    if (loc.startsWith('/fa/visits'))     return 3;
    if (loc.startsWith('/fa/profile'))    return 4;
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final idx      = _currentIndex(context);
    final isFabActive = idx == -1;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF7),
      body: child,

      // ── Gradient FAB with white ring ──────────────────────────────────────
      floatingActionButton: _GradientFab(
        isActive: isFabActive,
        onPressed: () => context.go(AppRoutes.faHome),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── Bottom nav bar ────────────────────────────────────────────────────
      bottomNavigationBar: _BottomNav(
        items: _navItems,
        activeIndex: idx,
        bottomPad: bottomPad,
        onTap: (route) => context.go(route),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient FAB
// ─────────────────────────────────────────────────────────────────────────────
class _GradientFab extends StatelessWidget {
  const _GradientFab({required this.isActive, required this.onPressed});
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [_greenDark, _green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white,
            width: isActive ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _green.withValues(alpha: isActive ? 0.55 : 0.30),
              blurRadius: isActive ? 20 : 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Icon(
          Icons.fingerprint_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom nav bar
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.items,
    required this.activeIndex,
    required this.bottomPad,
    required this.onTap,
  });

  final List<({String route, IconData activeIcon, IconData icon, String label})> items;
  final int activeIndex;
  final double bottomPad;
  final void Function(String route) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x2A059669),
            blurRadius: 28,
            spreadRadius: 0,
            offset: Offset(0, -8),
          ),
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            spreadRadius: 0,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        notchMargin: 10,
        shape: const CircularNotchedRectangle(),
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 64 + bottomPad,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPad),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: Attendance, Leaves — Expanded so width adapts to screen
                ...[0, 1].map((i) => Expanded(
                      child: _NavItem(
                        icon: items[i].icon,
                        activeIcon: items[i].activeIcon,
                        label: items[i].label,
                        isActive: activeIndex == i,
                        onTap: () => onTap(items[i].route),
                      ),
                    )),
                // Center gap for FAB notch — fixed width
                const SizedBox(width: 64),
                // Right: Visits, Profile — Expanded so width adapts to screen
                ...[3, 4].map((i) => Expanded(
                      child: _NavItem(
                        icon: items[i].icon,
                        activeIcon: items[i].activeIcon,
                        label: items[i].label,
                        isActive: activeIndex == i,
                        onTap: () => onTap(items[i].route),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav item — pill indicator on active
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon inside animated pill
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 48,
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? _green.withValues(alpha: 0.13)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                size: 22,
                color: isActive ? _green : _inactive,
              ),
            ),

            const SizedBox(height: 4),

            // Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? _green : _inactive,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location permission gate
// ─────────────────────────────────────────────────────────────────────────────
class _LocationGate extends StatelessWidget {
  const _LocationGate({required this.isPermanent, required this.onAllow});
  final bool         isPermanent;
  final VoidCallback onAllow;

  static const _reasons = [
    (Icons.map_rounded,                  'Tag GPS coordinates on every farm visit'),
    (Icons.directions_rounded,           'Calculate distance covered during duty'),
    (Icons.admin_panel_settings_rounded, 'Give admins verified field activity reports'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(),

              // ── Icon ──────────────────────────────────────────────────────
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 48,
                  color: _green,
                ),
              ),
              const SizedBox(height: 28),

              // ── Heading ───────────────────────────────────────────────────
              const Text(
                'Location Access Required',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1B2A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Kiba needs your location to record farm visit coordinates and track distance covered on duty. Location is only used while the app is in use.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.65,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // ── Reason bullets ────────────────────────────────────────────
              for (final r in _reasons) ...[
                Row(
                  children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(r.$1, size: 17, color: _green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        r.$2,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF374151),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              const Spacer(),

              // ── Primary button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: isPermanent
                      ? () => Geolocator.openAppSettings()
                      : onAllow,
                  icon: Icon(
                    isPermanent
                        ? Icons.settings_rounded
                        : Icons.location_on_rounded,
                    size: 20,
                  ),
                  label: Text(
                    isPermanent ? 'Open Settings' : 'Allow Location',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                ),
              ),

              if (isPermanent) ...[
                const SizedBox(height: 14),
                const Text(
                  'You permanently denied location. Go to\nSettings → Kiba → Location → "While Using the App".',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    height: 1.55,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
