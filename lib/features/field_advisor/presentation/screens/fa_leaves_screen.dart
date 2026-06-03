import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kiba_app/core/theme/app_theme.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';
import 'package:kiba_app/features/field_advisor/data/leave_model.dart';
import 'package:kiba_app/features/field_advisor/domain/leave_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _green     = Color(0xFF059669);
const _greenDark = Color(0xFF047857);
const _bg        = Color(0xFFF8FAFB);
const _amber     = Color(0xFFF59E0B);
const _indigo    = Color(0xFF6366F1);

// ── Screen ────────────────────────────────────────────────────────────────────

class FaLeavesScreen extends ConsumerStatefulWidget {
  const FaLeavesScreen({super.key});

  @override
  ConsumerState<FaLeavesScreen> createState() => _FaLeavesScreenState();
}

class _FaLeavesScreenState extends ConsumerState<FaLeavesScreen> {
  LeaveType? _filter;

  @override
  Widget build(BuildContext context) {
    final leavesAsync = ref.watch(faLeavesProvider);
    final allLeaves   = leavesAsync.valueOrNull ?? [];

    final approved = allLeaves.where((l) => l.status == LeaveStatus.approved).length;
    final pending  = allLeaves.where((l) => l.status == LeaveStatus.pending).length;
    final daysUsed = allLeaves
        .where((l) => l.status == LeaveStatus.approved)
        .fold<int>(0, (sum, l) => sum + l.workingDays);

    final filteredCount = _filter == null
        ? allLeaves.length
        : allLeaves.where((l) => l.type == _filter).length;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [

          // ── App bar — title only ───────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: _greenDark,
            foregroundColor: Colors.white,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_greenDark, Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: const Text(
              'My Leaves',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),

          // ── Stats row — scrolls with content ──────────────────────────────
          SliverToBoxAdapter(
            child: _StatsRow(
              approved: approved,
              pending: pending,
              daysUsed: daysUsed,
            ),
          ),

          // ── Sticky filter row ──────────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterRowDelegate(
              filter: _filter,
              filteredCount: filteredCount,
              onFilterTap: () => _showFilterSheet(context, allLeaves),
            ),
          ),

          // ── List ──────────────────────────────────────────────────────────
          leavesAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _green)),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text(
                  '$e',
                  style: KibaTextStyles.bodyMedium.copyWith(color: KibaColors.grey500),
                ),
              ),
            ),
            data: (leaves) {
              final filtered = _filter == null
                  ? leaves
                  : leaves.where((l) => l.type == _filter).toList();

              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(onApply: () => _showApplySheet(context)),
                );
              }

              final grouped = <String, List<LeaveModel>>{};
              for (final l in filtered) {
                final key = DateFormat('MMMM yyyy').format(l.fromDate);
                (grouped[key] ??= []).add(l);
              }

              final sections = grouped.entries.toList();
              final count = sections.fold<int>(0, (s, e) => s + 1 + e.value.length);

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      int cursor = 0;
                      for (final section in sections) {
                        if (i == cursor) return _SectionHeader(label: section.key);
                        cursor++;
                        for (final leave in section.value) {
                          if (i == cursor) return _LeaveCard(leave: leave);
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

      floatingActionButton: _ApplyFab(onTap: () => _showApplySheet(context)),
    );
  }

  void _showFilterSheet(BuildContext context, List<LeaveModel> leaves) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        selected: _filter,
        leaves: leaves,
        onChanged: (t) {
          setState(() => _filter = t);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showApplySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const _ApplyLeaveSheet(),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.approved,
    required this.pending,
    required this.daysUsed,
  });
  final int approved;
  final int pending;
  final int daysUsed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          _StatCard(
            value: '$approved',
            label: 'Approved',
            icon: Icons.check_circle_outline_rounded,
            color: _green,
          ),
          const SizedBox(width: 10),
          _StatCard(
            value: '$pending',
            label: 'Pending',
            icon: Icons.schedule_rounded,
            color: _amber,
          ),
          const SizedBox(width: 10),
          _StatCard(
            value: '$daysUsed',
            label: 'Days used',
            icon: Icons.calendar_today_rounded,
            color: _indigo,
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
                    fontSize: 26,
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
                fontSize: 11,
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

// ── Sticky filter row ─────────────────────────────────────────────────────────

class _FilterRowDelegate extends SliverPersistentHeaderDelegate {
  _FilterRowDelegate({
    required this.filter,
    required this.filteredCount,
    required this.onFilterTap,
  });
  final LeaveType? filter;
  final int filteredCount;
  final VoidCallback onFilterTap;

  @override
  double get minExtent => 54;
  @override
  double get maxExtent => 54;

  @override
  bool shouldRebuild(_FilterRowDelegate old) =>
      old.filter != filter || old.filteredCount != filteredCount;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final activeColor = filter?.color ?? _green;
    final label = filter == null ? 'All Leaves' : '${filter!.label} Leaves';

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: KibaColors.grey100),
        ),
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Label + count
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$filteredCount',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: activeColor,
              ),
            ),
          ),

          const Spacer(),

          // Filter pill button
          GestureDetector(
            onTap: onFilterTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: filter != null
                    ? filter!.color.withValues(alpha: 0.1)
                    : KibaColors.grey50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: filter != null
                      ? filter!.color.withValues(alpha: 0.25)
                      : KibaColors.grey200,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 13,
                    color: filter != null ? filter!.color : KibaColors.grey500,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    filter != null ? filter!.label : 'Filter',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: filter != null ? filter!.color : KibaColors.grey600,
                    ),
                  ),
                  if (filter != null) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: filter!.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter bottom sheet ────────────────────────────────────────────────────────

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({
    required this.selected,
    required this.leaves,
    required this.onChanged,
  });
  final LeaveType? selected;
  final List<LeaveModel> leaves;
  final ValueChanged<LeaveType?> onChanged;

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

          // Title row
          Row(
            children: [
              Text(
                'Filter by Type',
                style: KibaTextStyles.headlineSmall.copyWith(color: KibaColors.grey900),
              ),
              const Spacer(),
              if (selected != null)
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: KibaColors.grey100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: KibaColors.grey600,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 4),
          Text(
            'Showing results by leave category',
            style: KibaTextStyles.bodySmall.copyWith(color: KibaColors.grey400),
          ),
          const SizedBox(height: 18),

          // All option
          _FilterOption(
            icon: Icons.apps_rounded,
            label: 'All Leaves',
            description: 'View every leave application',
            count: leaves.length,
            color: _green,
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(height: 8),

          // Per-type options
          ...LeaveType.values.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FilterOption(
                  icon: t.icon,
                  label: '${t.label} Leave',
                  description: _typeDesc[t]!,
                  count: leaves.where((l) => l.type == t).length,
                  color: t.color,
                  selected: selected == t,
                  onTap: () => onChanged(t),
                ),
              )),
        ],
      ),
    );
  }

  static const _typeDesc = {
    LeaveType.sick:      'Illness & medical',
    LeaveType.casual:    'Personal & planned time off',
    LeaveType.emergency: 'Urgent, auto-approved',
  };
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String description;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.3) : KibaColors.grey100,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? color : color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 12),

            // Label + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : KibaColors.grey800,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? color.withValues(alpha: 0.7) : KibaColors.grey400,
                    ),
                  ),
                ],
              ),
            ),

            // Count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.12) : KibaColors.grey100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : KibaColors.grey500,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Radio dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : Colors.transparent,
                border: Border.all(
                  color: selected ? color : KibaColors.grey300,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
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

// ── Leave Card — two-zone ticket design ───────────────────────────────────────

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.leave});
  final LeaveModel leave;

  @override
  Widget build(BuildContext context) {
    final t  = leave.type;
    final st = leave.status;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: t.color.withValues(alpha: 0.08),
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
            // Tinted header zone
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: t.color.withValues(alpha: 0.08),
                border: Border(
                  bottom: BorderSide(color: t.color.withValues(alpha: 0.12)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: t.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(t.icon, size: 15, color: t.color),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${t.label} Leave',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.color,
                    ),
                  ),
                  if (!leave.type.requiresApproval) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Auto',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _green,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: st.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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

            // Body zone
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leave.isSingleDay
                      ? _DateLine(
                          icon: Icons.today_rounded,
                          text: DateFormat('EEEE, d MMMM yyyy').format(leave.fromDate),
                          sub: '1 working day',
                          color: t.color,
                        )
                      : _DateRangeLine(leave: leave, color: t.color),

                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote_rounded, size: 16, color: KibaColors.grey300),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          leave.reason,
                          style: KibaTextStyles.bodySmall.copyWith(
                            color: KibaColors.grey500,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  if (leave.reviewNote != null && leave.reviewNote!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: KibaColors.grey50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.admin_panel_settings_outlined,
                              size: 13, color: KibaColors.grey400),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              leave.reviewNote!,
                              style: KibaTextStyles.bodySmall
                                  .copyWith(color: KibaColors.grey500, fontSize: 11),
                            ),
                          ),
                        ],
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

class _DateLine extends StatelessWidget {
  const _DateLine({
    required this.icon,
    required this.text,
    required this.sub,
    required this.color,
  });
  final IconData icon;
  final String text;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 11,
                  color: KibaColors.grey400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateRangeLine extends StatelessWidget {
  const _DateRangeLine({required this.leave, required this.color});
  final LeaveModel leave;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fmt  = DateFormat('EEE, d MMM');
    final days = leave.workingDays;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('From',
                  style: TextStyle(
                      fontSize: 10,
                      color: KibaColors.grey400,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(fmt.format(leave.fromDate),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  )),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_forward_rounded, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                '$days d',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('To',
                  style: TextStyle(
                      fontSize: 10,
                      color: KibaColors.grey400,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(fmt.format(leave.toDate),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onApply});
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.event_available_rounded,
                size: 48,
                color: _green,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'All clear!',
              style: KibaTextStyles.headlineMedium.copyWith(color: KibaColors.grey800),
            ),
            const SizedBox(height: 6),
            Text(
              'You have no leave applications here.\nTap below to apply for a leave.',
              textAlign: TextAlign.center,
              style: KibaTextStyles.bodyMedium
                  .copyWith(color: KibaColors.grey400, height: 1.5),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onApply,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_greenDark, _green]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _green.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Apply for Leave',
                      style: KibaTextStyles.labelLarge.copyWith(color: Colors.white),
                    ),
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

// ── Apply FAB ──────────────────────────────────────────────────────────────────

class _ApplyFab extends StatelessWidget {
  const _ApplyFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_greenDark, _green]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _green.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              'Apply Leave',
              style: KibaTextStyles.labelLarge.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Apply Leave Sheet ──────────────────────────────────────────────────────────

class _ApplyLeaveSheet extends ConsumerStatefulWidget {
  const _ApplyLeaveSheet();

  @override
  ConsumerState<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends ConsumerState<_ApplyLeaveSheet> {
  LeaveType  _type = LeaveType.casual;
  late DateTime _from;
  late DateTime _to;
  final _reasonCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  // Returns the earliest allowed start date for a given leave type.
  // Casual  → tomorrow  (must be planned in advance)
  // Sick    → yesterday (1 day retroactive allowance)
  // Emergency → today   (immediate, same-day only)
  DateTime _minFromDate(LeaveType type) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return switch (type) {
      LeaveType.casual    => today.add(const Duration(days: 1)),
      LeaveType.sick      => today.subtract(const Duration(days: 1)),
      LeaveType.emergency => today,
    };
  }

  static String _dateHint(LeaveType type) => switch (type) {
    LeaveType.casual    => 'Casual leave must start from tomorrow or later.',
    LeaveType.sick      => 'Sick leave can start from yesterday (max 1 day back).',
    LeaveType.emergency => 'Emergency leave starts from today.',
  };

  @override
  void initState() {
    super.initState();
    _from = _minFromDate(_type);
    _to   = _minFromDate(_type);
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  int get _workingDays {
    int count = 0;
    var d = _from;
    while (!d.isAfter(_to)) {
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) count++;
      d = d.add(const Duration(days: 1));
    }
    return count;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: isFrom ? _minFromDate(_type) : _from,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _type.color),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _submit() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Please enter a reason');
      return;
    }
    final minDate = _minFromDate(_type);
    if (_from.isBefore(minDate)) {
      setState(() => _error = 'Invalid start date for ${_type.label} leave');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await ref.read(leaveRepoProvider).apply(
        uid:      user.uid,
        userName: user.displayName,
        type:     _type,
        fromDate: _from,
        toDate:   _to,
        reason:   reason,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  static const _typeDescriptions = {
    LeaveType.sick:      'Illness, medical appointments\nor recovery.',
    LeaveType.casual:    'Personal errands, travel\nor planned time off.',
    LeaveType.emergency: 'Urgent situations —\nauto-approved instantly.',
  };

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final fmt = DateFormat('EEE, d MMM');

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

            // Title row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('New Leave Request',
                          style: KibaTextStyles.headlineSmall
                              .copyWith(color: KibaColors.grey900)),
                      const SizedBox(height: 2),
                      Text('Choose type and set your dates',
                          style: KibaTextStyles.bodySmall
                              .copyWith(color: KibaColors.grey400)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
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

            // Leave type cards
            Text('Leave Type',
                style: KibaTextStyles.labelSmall
                    .copyWith(color: KibaColors.grey500, letterSpacing: 0.8)),
            const SizedBox(height: 10),

            ...LeaveType.values.map((t) {
              final sel = _type == t;
              return GestureDetector(
                onTap: () => setState(() {
                  _type = t;
                  final minDate = _minFromDate(t);
                  if (_from.isBefore(minDate)) {
                    _from = minDate;
                    _to   = minDate;
                  } else if (_to.isBefore(minDate)) {
                    _to = minDate;
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sel ? t.color.withValues(alpha: 0.06) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sel ? t.color : KibaColors.grey100,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: sel ? t.color : t.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(t.icon,
                            size: 20,
                            color: sel ? Colors.white : t.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${t.label} Leave',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: sel ? t.color : KibaColors.grey800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _typeDescriptions[t]!,
                              style: TextStyle(
                                fontSize: 11,
                                color: sel
                                    ? t.color.withValues(alpha: 0.75)
                                    : KibaColors.grey400,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!t.requiresApproval)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Instant',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _green,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sel ? t.color : Colors.transparent,
                          border: Border.all(
                            color: sel ? t.color : KibaColors.grey300,
                            width: 1.5,
                          ),
                        ),
                        child: sel
                            ? const Icon(Icons.check_rounded,
                                size: 12, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // Date range
            Text('Date Range',
                style: KibaTextStyles.labelSmall
                    .copyWith(color: KibaColors.grey500, letterSpacing: 0.8)),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: KibaColors.grey50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KibaColors.grey100),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _DateTile(
                      label: 'From',
                      date: fmt.format(_from),
                      color: _type.color,
                      onTap: () => _pickDate(isFrom: true),
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _type.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: _type.color,
                    ),
                  ),
                  Expanded(
                    child: _DateTile(
                      label: 'To',
                      date: fmt.format(_to),
                      color: _type.color,
                      onTap: () => _pickDate(isFrom: false),
                    ),
                  ),
                ],
              ),
            ),

            if (_workingDays > 0) ...[
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _type.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_workingDays working ${_workingDays == 1 ? 'day' : 'days'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _type.color,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 13,
                    color: _type.color.withValues(alpha: 0.7)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    _dateHint(_type),
                    style: TextStyle(
                      fontSize: 11,
                      color: _type.color.withValues(alpha: 0.75),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Reason
            Text('Reason',
                style: KibaTextStyles.labelSmall
                    .copyWith(color: KibaColors.grey500, letterSpacing: 0.8)),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              style: KibaTextStyles.bodyMedium.copyWith(color: KibaColors.grey800),
              decoration: InputDecoration(
                hintText: 'Briefly describe your reason…',
                hintStyle:
                    KibaTextStyles.bodyMedium.copyWith(color: KibaColors.grey400),
                filled: true,
                fillColor: KibaColors.grey50,
                counterStyle:
                    TextStyle(fontSize: 11, color: KibaColors.grey400),
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
                  borderSide: BorderSide(color: _type.color, width: 1.5),
                ),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),

            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: KibaTextStyles.bodySmall
                    .copyWith(color: const Color(0xFFE11D48)),
              ),
            ],

            const SizedBox(height: 20),

            // Submit button
            GestureDetector(
              onTap: _loading ? null : _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _loading
                        ? [KibaColors.grey300, KibaColors.grey300]
                        : [
                            _type.color,
                            Color.lerp(_type.color, Colors.black, 0.15)!,
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _loading
                      ? []
                      : [
                          BoxShadow(
                            color: _type.color.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_type.icon, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Apply for $_workingDays-Day ${_type.label} Leave',
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

// ── Date tile (inside the range box) ──────────────────────────────────────────

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.color,
    required this.onTap,
  });
  final String label;
  final String date;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: KibaColors.grey100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: KibaColors.grey400,
                    letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(date,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: KibaColors.grey800)),
          ],
        ),
      ),
    );
  }
}
