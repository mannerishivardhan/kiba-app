import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kiba_app/core/theme/app_theme.dart';

/// Shell wrapper for Clerk — Blue theme, 3-tab bottom nav.
class ClerkShell extends ConsumerWidget {
  const ClerkShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Theme(
      data: KibaTheme.clerk,
      child: _ClerkScaffold(child: child),
    );
  }
}

class _ClerkScaffold extends StatelessWidget {
  const _ClerkScaffold({required this.child});
  final Widget child;

  static const _tabs = [
    ('/clerk/home',    Icons.home_rounded,       Icons.home_outlined,       'Home'),
    ('/clerk/leaves',  Icons.event_note_rounded,  Icons.event_note_outlined, 'Leaves'),
    ('/clerk/profile', Icons.person_rounded,      Icons.person_outlined,     'Profile'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].$1)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(_tabs[i].$1),
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        destinations: _tabs.map((t) => NavigationDestination(
          icon: Icon(t.$3),
          selectedIcon: Icon(t.$2, color: theme.colorScheme.primary),
          label: t.$4,
        )).toList(),
      ),
    );
  }
}
