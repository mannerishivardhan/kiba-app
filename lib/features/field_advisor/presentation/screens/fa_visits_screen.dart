import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:kiba_app/core/theme/app_theme.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';
import 'package:kiba_app/features/field_advisor/data/visit_model.dart';
import 'package:kiba_app/features/field_advisor/domain/attendance_provider.dart';
import 'package:kiba_app/features/field_advisor/domain/visit_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _blue     = Color(0xFF059669);
const _blueDark = Color(0xFF047857);
const _bg       = Color(0xFFF8FAFB);

// ── Date filter ───────────────────────────────────────────────────────────────
enum _DateFilter { today, week, month, all }

extension _DateFilterX on _DateFilter {
  String get label {
    switch (this) {
      case _DateFilter.today: return 'Today';
      case _DateFilter.week:  return 'This Week';
      case _DateFilter.month: return 'This Month';
      case _DateFilter.all:   return 'All Time';
    }
  }

  bool matches(DateTime dt) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case _DateFilter.today:
        return dt.isAfter(today.subtract(const Duration(seconds: 1)));
      case _DateFilter.week:
        return dt.isAfter(today.subtract(Duration(days: today.weekday - 1)));
      case _DateFilter.month:
        return dt.isAfter(DateTime(now.year, now.month, 1)
            .subtract(const Duration(seconds: 1)));
      case _DateFilter.all:
        return true;
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────
class FaVisitsScreen extends ConsumerStatefulWidget {
  const FaVisitsScreen({super.key});

  @override
  ConsumerState<FaVisitsScreen> createState() => _FaVisitsScreenState();
}

class _FaVisitsScreenState extends ConsumerState<FaVisitsScreen> {
  _DateFilter _filter = _DateFilter.today;

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(faVisitsProvider);
    final attendance  = ref.watch(attendanceProvider);
    final canLog      = attendance.isCheckedIn && !attendance.isCheckedOut;
    final all         = visitsAsync.valueOrNull ?? [];

    // Stats — always from today regardless of filter
    final todayVisits = all.where((v) => _DateFilter.today.matches(v.checkIn)).toList();
    final todayKm     = todayVisits.fold(0.0, (s, v) => s + v.distanceFromPrevKm);
    final todayPonds  = todayVisits.fold(0.0, (s, v) => s + v.pondArea);

    // Filter + group
    final filtered = all.where((v) => _filter.matches(v.checkIn)).toList();
    final grouped  = <String, List<VisitModel>>{};
    for (final v in filtered) {
      final key = _sectionKey(v.checkIn);
      (grouped[key] ??= []).add(v);
    }
    final sections = grouped.entries.toList();
    final count    = sections.fold<int>(0, (s, e) => s + 1 + e.value.length);

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [

          // ── App bar ────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: _blueDark,
            foregroundColor: Colors.white,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_blueDark, _blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: const Text(
              'My Visits',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),

          // ── Stats row (scrolls away) ───────────────────────────────────────
          SliverToBoxAdapter(
            child: _StatsRow(
              visits:    todayVisits.length,
              km:        todayKm,
              pondAcres: todayPonds,
            ),
          ),

          // ── Today's route strip ────────────────────────────────────────────
          if (todayVisits.isNotEmpty)
            SliverToBoxAdapter(
              child: _JourneyStrip(visits: todayVisits, totalKm: todayKm),
            ),

          // ── Filter row (sticky) ────────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterRowDelegate(
              filter: _filter,
              count:  filtered.length,
              onFilterTap: () => _showFilterSheet(context),
            ),
          ),

          // ── List ──────────────────────────────────────────────────────────
          visitsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _blue)),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text('$e',
                    style: KibaTextStyles.bodyMedium
                        .copyWith(color: KibaColors.grey500)),
              ),
            ),
            data: (_) {
              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(
                    canLog:      canLog,
                    isCheckedOut: attendance.isCheckedOut,
                    onLog:       () => _showLogSheet(context),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      int cursor = 0;
                      for (final section in sections) {
                        if (i == cursor) {
                          return _SectionHeader(label: section.key);
                        }
                        cursor++;
                        for (final visit in section.value) {
                          if (i == cursor) {
                            return _VisitCard(
                              visit: visit,
                              onEnd: () => _showEndSheet(context, visit),
                            );
                          }
                          cursor++;
                        }
                      }
                      return null;
                    },
                    childCount: count,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: canLog ? _LogFab(onTap: () => _showLogSheet(context)) : null,
    );
  }

  String _sectionKey(DateTime dt) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(dt.year, dt.month, dt.day);
    final diff  = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEEE, d MMMM').format(dt);
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        selected: _filter,
        onChanged: (f) {
          setState(() => _filter = f);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showLogSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const _LogVisitSheet(),
    );
  }

  void _showEndSheet(BuildContext context, VisitModel visit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EndVisitSheet(visit: visit),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.visits,
    required this.km,
    required this.pondAcres,
  });
  final int visits;
  final double km;
  final double pondAcres;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          _StatCard(
            value: '$visits',
            label: 'Visits Today',
            icon: Icons.location_on_rounded,
            color: _blue,
          ),
          const SizedBox(width: 10),
          _StatCard(
            value: km.toStringAsFixed(1),
            label: 'km Covered',
            icon: Icons.route_rounded,
            color: const Color(0xFF059669),
          ),
          const SizedBox(width: 10),
          _StatCard(
            value: pondAcres.toStringAsFixed(1),
            label: 'Acres Covered',
            icon: Icons.water_rounded,
            color: const Color(0xFF6366F1),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: KibaColors.grey900,
                    height: 1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 13, color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: KibaColors.grey500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Today's journey strip ─────────────────────────────────────────────────────

class _JourneyStrip extends StatelessWidget {
  const _JourneyStrip({required this.visits, required this.totalKm});
  final List<VisitModel> visits;
  final double totalKm;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Text(
                  "TODAY'S ROUTE",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: KibaColors.grey400,
                    letterSpacing: 1.1,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${totalKm.toStringAsFixed(1)} km total',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Base node
                _StopNode(label: 'Base', isDone: true, isBase: true),
                // Visit stops
                for (final v in visits) ...[
                  _LegLine(
                    km: v.distanceFromPrevKm,
                    isDone: v.status == VisitStatus.completed,
                  ),
                  _StopNode(
                    label: v.farmerName.length > 10
                        ? '${v.farmerName.substring(0, 10)}…'
                        : v.farmerName,
                    isDone: v.status == VisitStatus.completed,
                    isActive: v.isActive,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StopNode extends StatefulWidget {
  const _StopNode({
    required this.label,
    required this.isDone,
    this.isBase   = false,
    this.isActive = false,
  });
  final String label;
  final bool   isDone;
  final bool   isBase;
  final bool   isActive;

  @override
  State<_StopNode> createState() => _StopNodeState();
}

class _StopNodeState extends State<_StopNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.isActive) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isBase
        ? KibaColors.grey400
        : widget.isActive
            ? const Color(0xFF059669)
            : widget.isDone
                ? _blue
                : KibaColors.grey300;

    return SizedBox(
      width: 64,
      child: Column(
        children: [
          if (widget.isActive)
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) => Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: _pulse.value * 0.55),
                      blurRadius: 10,
                      spreadRadius: _pulse.value * 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.person_pin_circle_rounded,
                    size: 16, color: Colors.white),
              ),
            )
          else
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isDone || widget.isBase
                    ? color
                    : color.withValues(alpha: 0.2),
                border: widget.isDone || widget.isBase
                    ? null
                    : Border.all(color: color, width: 1.5),
              ),
              child: Icon(
                widget.isBase
                    ? Icons.home_rounded
                    : widget.isDone
                        ? Icons.check_rounded
                        : Icons.location_on_rounded,
                size: 14,
                color: widget.isDone || widget.isBase
                    ? Colors.white
                    : color,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: widget.isActive ? color : KibaColors.grey500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegLine extends StatelessWidget {
  const _LegLine({required this.km, required this.isDone});
  final double km;
  final bool   isDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 36,
              height: 2,
              color: isDone
                  ? _blue.withValues(alpha: 0.4)
                  : KibaColors.grey200,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (km > 0)
          Text(
            '${km.toStringAsFixed(1)}km',
            style: TextStyle(
              fontSize: 8,
              color: KibaColors.grey400,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}

// ── Sticky filter row ─────────────────────────────────────────────────────────

class _FilterRowDelegate extends SliverPersistentHeaderDelegate {
  _FilterRowDelegate({
    required this.filter,
    required this.count,
    required this.onFilterTap,
  });
  final _DateFilter filter;
  final int count;
  final VoidCallback onFilterTap;

  @override
  double get minExtent => 54;
  @override
  double get maxExtent => 54;

  @override
  bool shouldRebuild(_FilterRowDelegate old) =>
      old.filter != filter || old.count != count;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: KibaColors.grey100)),
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            filter.label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _blue,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _blue.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, size: 13, color: _blue),
                  const SizedBox(width: 5),
                  Text(
                    'Period',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter sheet ──────────────────────────────────────────────────────────────

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.selected, required this.onChanged});
  final _DateFilter selected;
  final ValueChanged<_DateFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: KibaColors.grey200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Filter by Period',
              style: KibaTextStyles.headlineSmall
                  .copyWith(color: KibaColors.grey900)),
          const SizedBox(height: 16),
          ...(_DateFilter.values.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => onChanged(f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected == f
                          ? _blue.withValues(alpha: 0.06)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected == f
                            ? _blue.withValues(alpha: 0.3)
                            : KibaColors.grey100,
                        width: selected == f ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: selected == f ? _blue : KibaColors.grey400,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          f.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: selected == f
                                ? _blue
                                : KibaColors.grey800,
                          ),
                        ),
                        const Spacer(),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected == f ? _blue : Colors.transparent,
                            border: Border.all(
                              color: selected == f
                                  ? _blue
                                  : KibaColors.grey300,
                              width: 1.5,
                            ),
                          ),
                          child: selected == f
                              ? const Icon(Icons.check_rounded,
                                  size: 12, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ))),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: KibaColors.grey400,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: KibaColors.grey100)),
        ],
      ),
    );
  }
}

// ── Visit card ────────────────────────────────────────────────────────────────

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.visit, required this.onEnd});
  final VisitModel visit;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final p  = visit.purpose;
    final st = visit.status;
    final timeFmt = DateFormat('h:mm a');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: p.color.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Tinted header zone ──────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: p.color.withValues(alpha: 0.08),
                border: Border(
                  bottom:
                      BorderSide(color: p.color.withValues(alpha: 0.12)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: p.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(p.icon, size: 14, color: p.color),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    p.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: p.color,
                    ),
                  ),
                  const Spacer(),
                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: st.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (visit.isActive)
                          _PulsingDot(color: st.color)
                        else
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: st.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 5),
                        Text(
                          st.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: st.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Body zone ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Farmer + pond area
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_rounded,
                                    size: 13,
                                    color: KibaColors.grey400),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    visit.farmerName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.water_rounded,
                                    size: 13,
                                    color: KibaColors.grey400),
                                const SizedBox(width: 5),
                                Text(
                                  '${visit.pondArea.toStringAsFixed(1)} acres',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: KibaColors.grey500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Km leg badge
                      if (visit.distanceFromPrevKm > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Text(
                                visit.distanceFromPrevKm.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF059669),
                                  height: 1,
                                ),
                              ),
                              Text(
                                'km',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: KibaColors.grey400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Location + time
                  if (visit.address.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 13, color: KibaColors.grey400),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              visit.address,
                              style: TextStyle(
                                fontSize: 11,
                                color: KibaColors.grey500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 13, color: KibaColors.grey400),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          visit.checkOut != null
                              ? '${timeFmt.format(visit.checkIn)} → ${timeFmt.format(visit.checkOut!)} · ${visit.durationLabel}'
                              : '${timeFmt.format(visit.checkIn)} → now · ${visit.durationLabel}',
                          style: TextStyle(
                            fontSize: 11,
                            color: KibaColors.grey500,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Issues & resolution
                  if (visit.issuesReported.isNotEmpty ||
                      visit.resolutionGiven.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                  ],

                  if (visit.issuesReported.isNotEmpty)
                    _FieldRow(
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFF59E0B),
                      label: 'Issues',
                      text: visit.issuesReported,
                    ),

                  if (visit.resolutionGiven.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _FieldRow(
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF059669),
                      label: 'Resolution',
                      text: visit.resolutionGiven,
                    ),
                  ],

                  // End visit button for active
                  if (visit.isActive) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: onEnd,
                      child: Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF047857)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF059669)
                                  .withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.stop_circle_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 7),
                            Text(
                              'End Visit',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: text,
                  style: TextStyle(
                    fontSize: 12,
                    color: KibaColors.grey600,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Pulsing dot for active visit ──────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _anim.value),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.canLog,
    required this.isCheckedOut,
    required this.onLog,
  });
  final bool canLog;
  final bool isCheckedOut;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    // ── Not checked in yet ────────────────────────────────────────────────
    if (!canLog && !isCheckedOut) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: KibaColors.grey100,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(Icons.lock_outline_rounded,
                    size: 44, color: KibaColors.grey400),
              ),
              const SizedBox(height: 20),
              Text('Not Checked In',
                  style: KibaTextStyles.headlineMedium
                      .copyWith(color: KibaColors.grey800)),
              const SizedBox(height: 6),
              Text(
                'Check in on the home screen first\nto start logging farm visits.',
                textAlign: TextAlign.center,
                style: KibaTextStyles.bodyMedium
                    .copyWith(color: KibaColors.grey400, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    // ── Checked out — duty complete ───────────────────────────────────────
    if (isCheckedOut) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.check_circle_rounded,
                    size: 48, color: Color(0xFF059669)),
              ),
              const SizedBox(height: 20),
              Text('Duty Complete',
                  style: KibaTextStyles.headlineMedium
                      .copyWith(color: KibaColors.grey800)),
              const SizedBox(height: 6),
              Text(
                "You've checked out for today.\nNew visits can be logged after tomorrow's check-in.",
                textAlign: TextAlign.center,
                style: KibaTextStyles.bodyMedium
                    .copyWith(color: KibaColors.grey400, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    // ── Checked in, no visits yet ─────────────────────────────────────────
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.map_rounded, size: 48, color: _blue),
            ),
            const SizedBox(height: 20),
            Text('No Visits Yet',
                style: KibaTextStyles.headlineMedium
                    .copyWith(color: KibaColors.grey800)),
            const SizedBox(height: 6),
            Text(
              'Start logging your field visits.\nYour route will appear here.',
              textAlign: TextAlign.center,
              style: KibaTextStyles.bodyMedium
                  .copyWith(color: KibaColors.grey400, height: 1.5),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onLog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_blueDark, _blue]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _blue.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_location_alt_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text('Log First Visit',
                        style: KibaTextStyles.labelLarge
                            .copyWith(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Log Visit FAB ─────────────────────────────────────────────────────────────

class _LogFab extends StatelessWidget {
  const _LogFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_blueDark, _blue]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _blue.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_location_alt_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Log Visit',
                style: KibaTextStyles.labelLarge
                    .copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ── Log Visit Sheet ───────────────────────────────────────────────────────────

class _LogVisitSheet extends ConsumerStatefulWidget {
  const _LogVisitSheet();

  @override
  ConsumerState<_LogVisitSheet> createState() => _LogVisitSheetState();
}

class _LogVisitSheetState extends ConsumerState<_LogVisitSheet> {
  final _farmerCtrl    = TextEditingController();
  final _issuesCtrl    = TextEditingController();
  final _resolutionCtrl = TextEditingController();
  final _notesCtrl     = TextEditingController();

  VisitPurpose _purpose  = VisitPurpose.routine;
  double       _pondArea = 1.0;

  // GPS state
  Position? _position;
  String    _address      = '';
  double    _estimatedKm  = 0;
  bool      _gpsLoading   = true;
  String?   _gpsError;

  bool   _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchGps();
  }

  Future<void> _fetchGps() async {
    setState(() { _gpsLoading = true; _gpsError = null; });
    try {
      final pos = await fetchCurrentPosition();
      final addr = await reverseGeocode(pos.latitude, pos.longitude);
      final user = ref.read(currentUserProvider);
      double km  = 0;
      if (user != null) {
        km = await ref
            .read(visitRepoProvider)
            .estimateLegDistance(user.uid, pos.latitude, pos.longitude);
      }
      if (!mounted) return;
      setState(() {
        _position    = pos;
        _address     = addr;
        _estimatedKm = km;
        _gpsLoading  = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gpsError   = e.toString().replaceFirst('Exception: ', '');
        _gpsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _farmerCtrl.dispose();
    _issuesCtrl.dispose();
    _resolutionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_farmerCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Farmer name is required');
      return;
    }
    if (_pondArea <= 0) {
      setState(() => _error = 'Pond area must be greater than 0');
      return;
    }
    if (_issuesCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Issues reported is required');
      return;
    }
    if (_resolutionCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Resolution given is required');
      return;
    }
    if (_gpsError != null || _position == null) {
      setState(() => _error = 'Location is required. Please retry GPS.');
      return;
    }

    // Face verification gate before creating the visit
    final verified = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const _VisitFaceVerifySheet(),
    );
    if (verified != true) return;
    if (!mounted) return;

    setState(() { _loading = true; _error = null; });

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await ref.read(visitRepoProvider).startVisit(
        uid:             user.uid,
        farmerName:      _farmerCtrl.text.trim(),
        pondArea:        _pondArea,
        purpose:         _purpose,
        issuesReported:  _issuesCtrl.text.trim(),
        resolutionGiven: _resolutionCtrl.text.trim(),
        notes:           _notesCtrl.text.trim(),
        position:        _position,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: KibaColors.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Log Field Visit',
                          style: KibaTextStyles.headlineSmall
                              .copyWith(color: KibaColors.grey900)),
                      const SizedBox(height: 2),
                      Text('Fill in details and start your visit',
                          style: KibaTextStyles.bodySmall
                              .copyWith(color: KibaColors.grey400)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: KibaColors.grey100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: KibaColors.grey500),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── FARMER DETAILS ──────────────────────────────────────────────
            _SectionLabel('FARMER DETAILS'),
            const SizedBox(height: 10),

            _Field(
              label: 'Farmer Name',
              hint: 'e.g. Ramesh Kumar',
              controller: _farmerCtrl,
              required: true,
            ),
            const SizedBox(height: 12),

            // Pond area stepper
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pond Area (acres)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: KibaColors.grey600,
                          )),
                      const SizedBox(height: 2),
                      Text('Required',
                          style: TextStyle(
                              fontSize: 10, color: const Color(0xFFEF4444))),
                    ],
                  ),
                ),
                _PondStepper(
                  value: _pondArea,
                  onChanged: (v) => setState(() => _pondArea = v),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ── PURPOSE ─────────────────────────────────────────────────────
            _SectionLabel('PURPOSE'),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: VisitPurpose.values.map((p) {
                final sel = _purpose == p;
                return GestureDetector(
                  onTap: () => setState(() => _purpose = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? p.color : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? p.color : KibaColors.grey200,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(p.icon,
                            size: 12,
                            color: sel ? Colors.white : p.color),
                        const SizedBox(width: 5),
                        Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                sel ? Colors.white : KibaColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 18),

            // ── FIELD OBSERVATIONS ──────────────────────────────────────────
            _SectionLabel('FIELD OBSERVATIONS'),
            const SizedBox(height: 10),

            _Field(
              label: 'Issues Reported *',
              hint: 'e.g. White spot disease on pond 3…',
              controller: _issuesCtrl,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            _Field(
              label: 'Resolution Given *',
              hint: 'e.g. Applied treatment X, advised follow-up…',
              controller: _resolutionCtrl,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            _Field(
              label: 'Additional Notes',
              hint: 'Any other observations…',
              controller: _notesCtrl,
              maxLines: 2,
            ),

            const SizedBox(height: 18),

            // ── LOCATION ────────────────────────────────────────────────────
            _SectionLabel('LOCATION'),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _gpsError != null
                    ? const Color(0xFFFEE2E2)
                    : _gpsLoading
                        ? KibaColors.grey50
                        : const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _gpsError != null
                      ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                      : _gpsLoading
                          ? KibaColors.grey200
                          : const Color(0xFF059669).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  if (_gpsLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF059669)),
                    )
                  else if (_gpsError != null)
                    const Icon(Icons.location_off_rounded,
                        color: Color(0xFFEF4444), size: 18)
                  else
                    const Icon(Icons.my_location_rounded,
                        color: Color(0xFF059669), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _gpsLoading
                              ? 'Acquiring GPS…'
                              : _gpsError != null
                                  ? 'Location unavailable'
                                  : _address.isNotEmpty
                                      ? _address
                                      : 'Location acquired',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _gpsError != null
                                ? const Color(0xFFEF4444)
                                : _gpsLoading
                                    ? KibaColors.grey500
                                    : const Color(0xFF059669),
                          ),
                        ),
                        if (!_gpsLoading &&
                            _gpsError == null &&
                            _estimatedKm > 0)
                          Text(
                            '~${_estimatedKm.toStringAsFixed(1)} km from last point',
                            style: TextStyle(
                                fontSize: 11, color: KibaColors.grey400),
                          ),
                        if (_gpsError != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _gpsError!,
                            style: TextStyle(
                                fontSize: 10,
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.8)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_gpsError != null || _gpsLoading == false)
                    GestureDetector(
                      onTap: _gpsLoading ? null : _fetchGps,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _gpsError != null
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF059669),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: KibaTextStyles.bodySmall
                      .copyWith(color: const Color(0xFFEF4444))),
            ],

            const SizedBox(height: 20),

            // ── Submit ──────────────────────────────────────────────────────
            GestureDetector(
              onTap: _loading ? null : _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: (_loading || _gpsLoading)
                        ? [KibaColors.grey300, KibaColors.grey300]
                        : [_blueDark, _blue],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: (_loading || _gpsLoading)
                      ? []
                      : [
                          BoxShadow(
                            color: _blue.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _estimatedKm > 0
                                  ? 'Start Visit · ${_estimatedKm.toStringAsFixed(1)} km'
                                  : 'Start Visit',
                              style: KibaTextStyles.labelLarge
                                  .copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── End Visit Sheet ────────────────────────────────────────────────────────────

class _EndVisitSheet extends ConsumerStatefulWidget {
  const _EndVisitSheet({required this.visit});
  final VisitModel visit;

  @override
  ConsumerState<_EndVisitSheet> createState() => _EndVisitSheetState();
}

class _EndVisitSheetState extends ConsumerState<_EndVisitSheet> {
  final _notesCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom   = MediaQuery.of(context).viewInsets.bottom;
    final duration = DateTime.now().difference(widget.visit.checkIn);
    final h        = duration.inHours;
    final m        = duration.inMinutes.remainder(60);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: KibaColors.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text('End Visit',
                style: KibaTextStyles.headlineSmall
                    .copyWith(color: KibaColors.grey900)),
            const SizedBox(height: 4),
            Text(widget.visit.farmerName,
                style: KibaTextStyles.bodyMedium
                    .copyWith(color: KibaColors.grey500)),

            const SizedBox(height: 16),

            // Summary row
            Row(
              children: [
                _SummaryChip(
                  icon: Icons.timer_rounded,
                  label: h > 0 ? '${h}h ${m}m' : '${m}m',
                  color: const Color(0xFF6366F1),
                ),
                const SizedBox(width: 10),
                _SummaryChip(
                  icon: Icons.route_rounded,
                  label: '${widget.visit.distanceFromPrevKm.toStringAsFixed(1)} km leg',
                  color: const Color(0xFF059669),
                ),
                const SizedBox(width: 10),
                _SummaryChip(
                  icon: Icons.water_rounded,
                  label: '${widget.visit.pondArea.toStringAsFixed(1)} ac',
                  color: _blue,
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text('Final Notes (optional)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: KibaColors.grey600,
                )),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style:
                  KibaTextStyles.bodyMedium.copyWith(color: KibaColors.grey800),
              decoration: InputDecoration(
                hintText: 'Any closing remarks…',
                hintStyle:
                    KibaTextStyles.bodyMedium.copyWith(color: KibaColors.grey400),
                filled: true,
                fillColor: KibaColors.grey50,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: KibaColors.grey100),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: KibaColors.grey100),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _blue, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 20),

            GestureDetector(
              onTap: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      final nav = Navigator.of(context);
                      await ref.read(visitRepoProvider).endVisit(
                            visitId:    widget.visit.id,
                            finalNotes: _notesCtrl.text.trim(),
                          );
                      if (mounted) nav.pop();
                    },
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF047857)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Complete Visit',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                )),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Visit Face Verify Sheet ───────────────────────────────────────────────────
// Pops with `true` when face is verified, null/false if cancelled.
class _VisitFaceVerifySheet extends StatefulWidget {
  const _VisitFaceVerifySheet();

  @override
  State<_VisitFaceVerifySheet> createState() => _VisitFaceVerifySheetState();
}

enum _FaceState { aligning, scanning, verified }

class _VisitFaceVerifySheetState extends State<_VisitFaceVerifySheet>
    with TickerProviderStateMixin {

  late final AnimationController _orbitCtrl;
  late final AnimationController _scanCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _successCtrl;

  late final Animation<double> _scanAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _successScale;

  _FaceState _state = _FaceState.aligning;

  @override
  void initState() {
    super.initState();

    _orbitCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 10))..repeat();

    _scanCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _scanAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut));

    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _successCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
    _successScale = CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);

    Future.delayed(const Duration(seconds: 2), _startScanning);
  }

  void _startScanning() {
    if (!mounted) return;
    setState(() => _state = _FaceState.scanning);
    Future.delayed(const Duration(seconds: 2), _onVerified);
  }

  void _onVerified() {
    if (!mounted) return;
    setState(() => _state = _FaceState.verified);
    _successCtrl.forward();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF04091A), Color(0xFF0D1B3E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _state == _FaceState.verified
                ? 'Identity Verified'
                : _state == _FaceState.scanning
                    ? 'Scanning Face…'
                    : 'Align Your Face',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _state == _FaceState.verified
                ? 'Starting your visit'
                : 'Keep your face centred in the frame',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Orbiting dots
                    AnimatedBuilder(
                      animation: _orbitCtrl,
                      builder: (_, _) {
                        return CustomPaint(
                          size: const Size(240, 240),
                          painter: _OrbitPainter(
                            progress: _orbitCtrl.value,
                            color: _state == _FaceState.verified
                                ? const Color(0xFF34D399)
                                : const Color(0xFF059669),
                          ),
                        );
                      },
                    ),
                    // Pulsing ring
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, _) => Container(
                        width: 190 + _pulseAnim.value * 6,
                        height: 190 + _pulseAnim.value * 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (_state == _FaceState.verified
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFF059669))
                                .withValues(alpha: _pulseAnim.value * 0.5),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Face oval frame
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _state == _FaceState.verified
                              ? const Color(0xFF34D399)
                              : const Color(0xFF059669),
                          width: 2.5,
                        ),
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                      child: _state == _FaceState.verified
                          ? ScaleTransition(
                              scale: _successScale,
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF34D399),
                                size: 72,
                              ),
                            )
                          : const Icon(
                              Icons.face_rounded,
                              color: Colors.white24,
                              size: 72,
                            ),
                    ),
                    // Scan line
                    if (_state == _FaceState.scanning)
                      AnimatedBuilder(
                        animation: _scanAnim,
                        builder: (_, _) => Positioned(
                          top: 30 + _scanAnim.value * 140,
                          child: Container(
                            width: 180,
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFF059669).withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 112.0;
    const dotCount = 8;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < dotCount; i++) {
      final angle = (2 * math.pi * i / dotCount) + (2 * math.pi * progress);
      final opacity = (math.sin(angle) * 0.5 + 0.5) * 0.6 + 0.1;
      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(center.dx + radius * math.cos(angle),
               center.dy + radius * math.sin(angle)),
        3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: KibaColors.grey400,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines  = 1,
    this.required  = false,
  });
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: KibaColors.grey600,
                )),
            if (required) ...[
              const SizedBox(width: 4),
              Text('*',
                  style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w700)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          style:
              KibaTextStyles.bodyMedium.copyWith(color: KibaColors.grey800),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                KibaTextStyles.bodyMedium.copyWith(color: KibaColors.grey400),
            filled: true,
            fillColor: KibaColors.grey50,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: KibaColors.grey100),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: KibaColors.grey100),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _blue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _PondStepper extends StatelessWidget {
  const _PondStepper({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: KibaColors.grey200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            icon: Icons.remove_rounded,
            onTap: value > 0.5 ? () => onChanged((value - 0.5)) : null,
          ),
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: KibaColors.grey50,
            child: Text(
              value.toStringAsFixed(1),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: KibaColors.grey800,
              ),
            ),
          ),
          _StepBtn(
            icon: Icons.add_rounded,
            onTap: () => onChanged(value + 0.5),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        color: Colors.transparent,
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? KibaColors.grey300 : KibaColors.grey700,
        ),
      ),
    );
  }
}
