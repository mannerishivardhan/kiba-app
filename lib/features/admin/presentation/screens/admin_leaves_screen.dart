import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kiba_app/features/admin/domain/user_admin_providers.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';
import 'package:kiba_app/features/field_advisor/data/leave_model.dart';
import 'package:kiba_app/features/field_advisor/domain/leave_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _navy    = Color(0xFF0D1B2A);
const _navyMid = Color(0xFF16293E);
const _amber   = Color(0xFFF59E0B);
const _faGreen = Color(0xFF059669);
const _rose    = Color(0xFFDC2626);
const _bg      = Color(0xFFF0F4F8);
const _ink900  = Color(0xFF111827);
const _ink600  = Color(0xFF4B5563);
const _ink400  = Color(0xFF9CA3AF);
const _border  = Color(0xFFE5E7EB);
const _surface = Color(0xFFFBFCFD);

// ─────────────────────────────────────────────────────────────────────────────
class AdminLeavesScreen extends ConsumerStatefulWidget {
  const AdminLeavesScreen({super.key});

  @override
  ConsumerState<AdminLeavesScreen> createState() =>
      _AdminLeavesScreenState();
}

class _AdminLeavesScreenState extends ConsumerState<AdminLeavesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        // ── Stats header ─────────────────────────────────────────────────
        const _StatsHeader(),

        // ── Tab bar (matches attendance design) ──────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_navy, _navyMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              color: _amber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: const Border(
                  bottom: BorderSide(color: _amber, width: 2.5)),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.42),
            labelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(
                iconMargin: EdgeInsets.only(bottom: 2),
                icon: Icon(Icons.pending_actions_rounded, size: 17),
                text: 'Pending',
              ),
              Tab(
                iconMargin: EdgeInsets.only(bottom: 2),
                icon: Icon(Icons.history_rounded, size: 17),
                text: 'History',
              ),
            ],
          ),
        ),

        // ── Content ──────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              _PendingTab(),
              _HistoryTab(),
            ],
          ),
        ),
      ]);
}

// ── Stats Header ──────────────────────────────────────────────────────────────
class _StatsHeader extends ConsumerWidget {
  const _StatsHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allLeavesProvider).valueOrNull ?? [];
    final now            = DateTime.now();
    final monthStart     = DateTime(now.year, now.month, 1);
    final pending        = all.where((l) => l.status == LeaveStatus.pending).length;
    final approvedMonth  = all
        .where((l) =>
            l.status == LeaveStatus.approved &&
            !l.appliedAt.isBefore(monthStart))
        .length;
    final declinedMonth  = all
        .where((l) =>
            l.status == LeaveStatus.declined &&
            !l.appliedAt.isBefore(monthStart))
        .length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        Expanded(
          child: _StatTile(
            count:   pending,
            label:   'Pending',
            icon:    Icons.schedule_rounded,
            color:   _amber,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            count:   approvedMonth,
            label:   'Approved',
            icon:    Icons.check_circle_outline_rounded,
            color:   _faGreen,
            note:    'this month',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            count:   declinedMonth,
            label:   'Declined',
            icon:    Icons.cancel_outlined,
            color:   _rose,
            note:    'this month',
          ),
        ),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.count,
    required this.label,
    required this.icon,
    required this.color,
    this.note,
  });
  final int      count;
  final String   label;
  final IconData icon;
  final Color    color;
  final String?  note;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: color),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
            if (note != null)
              Text(
                note!,
                style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7)),
              ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pending Tab
// ─────────────────────────────────────────────────────────────────────────────
class _PendingTab extends ConsumerWidget {
  const _PendingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingLeavesProvider);

    return ColoredBox(
      color: _bg,
      child: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: _navy),
        ),
        error: (e, _) => Center(
            child: Text('$e',
                style: const TextStyle(fontSize: 13, color: _rose))),
        data: (leaves) {
          if (leaves.isEmpty) {
            return const _EmptyState(
              icon:      Icons.check_circle_outline_rounded,
              iconColor: _faGreen,
              title:     'All caught up!',
              subtitle:  'No pending leave requests right now',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: leaves.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) =>
                _AdminLeaveCard(leave: leaves[i], showActions: true),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  History Tab
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab();

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String       _query        = '';
  LeaveStatus? _statusFilter;
  LeaveType?   _typeFilter;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async      = ref.watch(allLeavesProvider);
    final empList    = ref.watch(allEmployeesProvider).valueOrNull ?? [];
    final uidToEmpId = {for (final u in empList) u.uid: u.employeeId ?? ''};

    return ColoredBox(
      color: _bg,
      child: Column(children: [
        // ── Filter panel ──────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Search field
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              style: const TextStyle(fontSize: 14, color: _ink900),
              decoration: InputDecoration(
                hintText: 'Search by name or ID…',
                hintStyle: const TextStyle(color: _ink400, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: _ink400),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            size: 16, color: _ink400),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled:    true,
                fillColor: _surface,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: _navy, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Status filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FilterChip(
                  label:  'All',
                  active: _statusFilter == null && _typeFilter == null,
                  color:  _navy,
                  onTap:  () => setState(() {
                    _statusFilter = null;
                    _typeFilter   = null;
                  }),
                ),
                const SizedBox(width: 6),
                ...LeaveStatus.values.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _FilterChip(
                        label:  s.label,
                        active: _statusFilter == s,
                        color:  s.color,
                        onTap:  () => setState(() =>
                            _statusFilter = _statusFilter == s ? null : s),
                      ),
                    )),
                Container(
                  width: 1, height: 22, color: _border,
                  margin: const EdgeInsets.only(right: 6),
                ),
                ...LeaveType.values.map((t) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _FilterChip(
                        label:  t.label,
                        active: _typeFilter == t,
                        color:  t.color,
                        icon:   t.icon,
                        onTap:  () => setState(() =>
                            _typeFilter = _typeFilter == t ? null : t),
                      ),
                    )),
              ]),
            ),
            const SizedBox(height: 10),
          ]),
        ),
        Container(height: 1, color: _border),

        // ── List ──────────────────────────────────────────────────────
        Expanded(
          child: async.when(
            loading: () => const Center(
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: _navy),
            ),
            error: (e, _) => Center(
                child: Text('$e',
                    style: const TextStyle(fontSize: 13, color: _rose))),
            data: (leaves) {
              final filtered = _filter(leaves, uidToEmpId);
              if (filtered.isEmpty) {
                return _EmptyState(
                  icon:     Icons.search_off_rounded,
                  title:    'No leaves found',
                  subtitle: _query.isNotEmpty ||
                          _statusFilter != null ||
                          _typeFilter != null
                      ? 'Try adjusting your filters'
                      : 'No leave requests yet',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _AdminLeaveCard(
                  leave:       filtered[i],
                  showActions: false,
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  List<LeaveModel> _filter(
      List<LeaveModel> leaves, Map<String, String> uidToEmpId) {
    var list = leaves;
    if (_statusFilter != null) {
      list = list.where((l) => l.status == _statusFilter).toList();
    }
    if (_typeFilter != null) {
      list = list.where((l) => l.type == _typeFilter).toList();
    }
    if (_query.isNotEmpty) {
      final q  = _query.toLowerCase();
      final qN = q.replaceAll('-', '').replaceAll(' ', '');
      list = list.where((l) {
        if (l.userName.toLowerCase().contains(q)) return true;
        final empId = (uidToEmpId[l.uid] ?? '').toLowerCase().replaceAll('-', '');
        return qN.isNotEmpty && empId.contains(qN);
      }).toList();
    }
    return list;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Leave Card
// ─────────────────────────────────────────────────────────────────────────────
class _AdminLeaveCard extends StatelessWidget {
  const _AdminLeaveCard({
    required this.leave,
    required this.showActions,
  });
  final LeaveModel leave;
  final bool       showActions;

  @override
  Widget build(BuildContext context) {
    final fmt    = DateFormat('d MMM yyyy');
    final typeX  = leave.type;
    final statX  = leave.status;
    final color  = typeX.color;
    final days   = leave.workingDays;
    final dateLabel = leave.isSingleDay
        ? fmt.format(leave.fromDate)
        : '${fmt.format(leave.fromDate)} – ${fmt.format(leave.toDate)}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(width: 4, color: color),

              // Content
              Expanded(
                child: ColoredBox(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header ────────────────────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _LeaveAvatar(
                              name:  leave.userName,
                              color: color,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    leave.userName.isEmpty
                                        ? 'Unknown'
                                        : leave.userName,
                                    style: const TextStyle(
                                      fontSize:   14,
                                      fontWeight: FontWeight.w800,
                                      color:      _ink900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Applied ${DateFormat('d MMM · h:mm a').format(leave.appliedAt)}',
                                    style: const TextStyle(
                                        fontSize: 11, color: _ink400),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:        statX.surface,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                statX.label,
                                style: TextStyle(
                                  fontSize:   11,
                                  fontWeight: FontWeight.w700,
                                  color:      statX.color,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                        const Divider(color: _border, height: 1),
                        const SizedBox(height: 10),

                        // ── Type + days + date ─────────────────────────
                        Row(
                          children: [
                            _LeaveBadge(
                              icon:  typeX.icon,
                              label: typeX.label,
                              color: color,
                              bg:    typeX.surface,
                            ),
                            const SizedBox(width: 8),
                            _LeaveBadge(
                              icon:  Icons.calendar_today_rounded,
                              label: '$days ${days == 1 ? 'day' : 'days'}',
                              color: _ink600,
                              bg:    _bg,
                            ),
                            const Spacer(),
                            Row(children: [
                              const Icon(Icons.event_outlined,
                                  size: 12, color: _ink400),
                              const SizedBox(width: 4),
                              Text(
                                dateLabel,
                                style: const TextStyle(
                                  fontSize:   11,
                                  fontWeight: FontWeight.w500,
                                  color:      _ink600,
                                ),
                              ),
                            ]),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // ── Reason ─────────────────────────────────────
                        Text(
                          leave.reason,
                          style: const TextStyle(
                            fontSize:   12,
                            color:      _ink400,
                            fontStyle:  FontStyle.italic,
                          ),
                          maxLines:  2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // ── Action buttons (pending tab only) ──────────
                        if (showActions &&
                            leave.status == LeaveStatus.pending) ...[
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _openReview(context, approve: false),
                                icon: const Icon(Icons.close_rounded,
                                    size: 15),
                                label: const Text('Decline'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _rose,
                                  side:
                                      const BorderSide(color: _rose),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 9),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  textStyle: const TextStyle(
                                      fontSize:   13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _openReview(context, approve: true),
                                icon: const Icon(Icons.check_rounded,
                                    size: 15),
                                label: const Text('Approve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _faGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 9),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  textStyle: const TextStyle(
                                      fontSize:   13,
                                      fontWeight: FontWeight.w600),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ]),
                        ],

                        // ── Review note ────────────────────────────────
                        if (leave.reviewNote != null &&
                            leave.reviewNote!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.format_quote_rounded,
                                    size: 14, color: color),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        leave.reviewNote!,
                                        style: const TextStyle(
                                            fontSize: 12, color: _ink600),
                                      ),
                                      if (leave.reviewedBy != null) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          '— ${leave.reviewedBy}${leave.reviewedAt != null ? ' · ${DateFormat('d MMM').format(leave.reviewedAt!)}' : ''}',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color:    _ink400),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openReview(BuildContext context, {required bool approve}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(leave: leave, approve: approve),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Review Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.leave, required this.approve});
  final LeaveModel leave;
  final bool       approve;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  final _noteCtrl = TextEditingController();
  bool _loading   = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    final adminUid = ref.read(currentUserProvider)?.uid ?? 'admin';
    final repo     = ref.read(leaveRepoProvider);
    try {
      if (widget.approve) {
        await repo.approve(widget.leave.id,
            approvedBy: adminUid, note: _noteCtrl.text.trim());
      } else {
        await repo.decline(widget.leave.id,
            declinedBy: adminUid, note: _noteCtrl.text.trim());
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: _rose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom      = MediaQuery.of(context).viewInsets.bottom;
    final isApprove   = widget.approve;
    final actionColor = isApprove ? _faGreen : _rose;
    final typeX       = widget.leave.type;
    final days        = widget.leave.workingDays;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(0, 0, 0, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ───────────────────────────────────────────────────
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Gradient header ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [actionColor, actionColor.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isApprove ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 24, color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isApprove ? 'Approve Leave Request' : 'Decline Leave Request',
                      style: const TextStyle(
                        fontSize:   16,
                        fontWeight: FontWeight.w800,
                        color:      Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.leave.userName} · ${typeX.label} · $days ${days == 1 ? 'day' : 'days'}',
                      style: TextStyle(
                        fontSize: 12,
                        color:    Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),

          // ── Leave summary strip ──────────────────────────────────────
          Container(
            color: actionColor.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(children: [
              _LeaveBadge(
                icon:  typeX.icon,
                label: typeX.label,
                color: typeX.color,
                bg:    typeX.surface,
              ),
              const SizedBox(width: 8),
              const Icon(Icons.event_outlined, size: 13, color: _ink400),
              const SizedBox(width: 4),
              Text(
                '${DateFormat('d MMM').format(widget.leave.fromDate)}'
                '${widget.leave.isSingleDay ? '' : ' – ${DateFormat('d MMM').format(widget.leave.toDate)}'}',
                style: const TextStyle(
                    fontSize: 12, color: _ink600, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  '"${widget.leave.reason}"',
                  style: const TextStyle(
                      fontSize: 11, color: _ink400, fontStyle: FontStyle.italic),
                  maxLines:  1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),

          // ── Note field ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Note (optional)',
                  style: TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w700,
                      color:      _ink600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteCtrl,
                  maxLines:   3,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 14, color: _ink900),
                  decoration: InputDecoration(
                    hintText: isApprove
                        ? 'e.g. Approved — get well soon…'
                        : 'e.g. Insufficient leave balance…',
                    hintStyle:
                        const TextStyle(color: _ink400, fontSize: 13),
                    filled:    true,
                    fillColor: _surface,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: actionColor, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          actionColor.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                      textStyle: const TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w700),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(isApprove
                            ? 'Confirm Approval'
                            : 'Confirm Decline'),
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
//  Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _LeaveAvatar extends StatelessWidget {
  const _LeaveAvatar({required this.name, required this.color});
  final String name;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return Container(
      width:  38, height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color:      color.withValues(alpha: 0.3),
            blurRadius: 6,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w700,
              color:      Colors.white),
        ),
      ),
    );
  }
}

class _LeaveBadge extends StatelessWidget {
  const _LeaveBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
  });
  final IconData icon;
  final String   label;
  final Color    color, bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ]),
      );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.color,
    this.icon,
    required this.onTap,
  });
  final String       label;
  final bool         active;
  final Color        color;
  final IconData?    icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color:        active ? color : _surface,
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(color: active ? color : _border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 12,
                  color: active ? Colors.white : _ink600),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w600,
                color:      active ? Colors.white : _ink600,
              ),
            ),
          ]),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = _ink400,
  });
  final IconData icon;
  final String   title, subtitle;
  final Color    iconColor;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: iconColor),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize:   17,
                    fontWeight: FontWeight.w700,
                    color:      _ink600)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 13, color: _ink400)),
          ],
        ),
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _initials(String name) {
  if (name.trim().isEmpty) return '?';
  final parts = name.trim().split(' ');
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
