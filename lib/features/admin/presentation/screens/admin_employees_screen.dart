import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kiba_app/features/admin/domain/user_admin_providers.dart';
import 'package:kiba_app/features/auth/data/user_model.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _navy    = Color(0xFF0D1B2A);
const _faGreen = Color(0xFF059669);
const _clBlue  = Color(0xFF2563EB);
const _bg      = Color(0xFFF0F4F8);
const _ink900  = Color(0xFF111827);
const _ink600  = Color(0xFF4B5563);
const _ink400  = Color(0xFF9CA3AF);
const _border  = Color(0xFFE5E7EB);

// ── Filter ────────────────────────────────────────────────────────────────────
enum _EmpFilter { all, fa, clerk, active, inactive }

extension _EmpFilterX on _EmpFilter {
  String get label {
    switch (this) {
      case _EmpFilter.all:      return 'All';
      case _EmpFilter.fa:       return 'Field Advisor';
      case _EmpFilter.clerk:    return 'Clerk';
      case _EmpFilter.active:   return 'Active';
      case _EmpFilter.inactive: return 'Inactive';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AdminEmployeesScreen extends ConsumerStatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  ConsumerState<AdminEmployeesScreen> createState() =>
      _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends ConsumerState<AdminEmployeesScreen> {
  final _searchCtrl = TextEditingController();
  _EmpFilter _filter      = _EmpFilter.all;
  String?    _expandedUid;
  String     _query       = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<UserModel> _filtered(List<UserModel> all) => all.where((u) {
        switch (_filter) {
          case _EmpFilter.fa:       if (!u.isFieldAdvisor) return false;
          case _EmpFilter.clerk:    if (!u.isClerk)        return false;
          case _EmpFilter.active:   if (!u.isActive)       return false;
          case _EmpFilter.inactive: if (u.isActive)        return false;
          case _EmpFilter.all:      break;
        }
        if (_query.isEmpty) return true;
        final q  = _query.toLowerCase();
        final qN = q.replaceAll('-', '').replaceAll(' ', '');
        final empId = (u.employeeId ?? '').toLowerCase().replaceAll('-', '');
        return u.displayName.toLowerCase().contains(q) ||
            (qN.isNotEmpty && empId.contains(qN));
      }).toList();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allEmployeesProvider);
    return ColoredBox(
      color: _bg,
      child: Column(
        children: [
          _Header(
            controller: _searchCtrl,
            filter: _filter,
            onSearch: (v) => setState(() => _query = v),
            onFilter: (f) => setState(() {
              _filter = f;
              _expandedUid = null;
            }),
          ),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: _faGreen)),
              error:   (e, _) => Center(child: Text('$e')),
              data:    (all) {
                final list = _filtered(all);
                if (list.isEmpty) return _EmptyState(isSearch: _query.isNotEmpty);
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  itemCount: list.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _EmployeeCard(
                      key: ValueKey(list[i].uid),
                      user: list[i],
                      isExpanded: _expandedUid == list[i].uid,
                      onToggle: () => setState(() =>
                          _expandedUid =
                              _expandedUid == list[i].uid ? null : list[i].uid),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HEADER — search + filter chips, fused with shell navy AppBar
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.filter,
    required this.onSearch,
    required this.onFilter,
  });

  final TextEditingController   controller;
  final _EmpFilter               filter;
  final ValueChanged<String>     onSearch;
  final ValueChanged<_EmpFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _navy,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        children: [
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: TextField(
              controller: controller,
              onChanged: onSearch,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name or employee ID…',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.38), fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.45), size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _EmpFilter.values.map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Chip(
                  label: f.label,
                  selected: filter == f,
                  onTap: () => onFilter(f),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool   selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF59E0B)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFFF59E0B)
                : Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF1A1200) : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPLOYEE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _EmployeeCard extends StatefulWidget {
  const _EmployeeCard({
    super.key,
    required this.user,
    required this.isExpanded,
    required this.onToggle,
  });

  final UserModel    user;
  final bool         isExpanded;
  final VoidCallback onToggle;

  @override
  State<_EmployeeCard> createState() => _EmployeeCardState();
}

class _EmployeeCardState extends State<_EmployeeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _size;
  late final Animation<double>   _chevron;
  late final Animation<double>   _fade;
  bool _hasOpened = false;
  int  _activeTab = 0; // 0=Activity  1=Info

  Color get _roleColor =>
      widget.user.isFieldAdvisor ? _faGreen : _clBlue;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 340));
    _size    = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    _chevron = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    _fade    = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn));
  }

  @override
  void didUpdateWidget(_EmployeeCard old) {
    super.didUpdateWidget(old);
    if (widget.isExpanded && !old.isExpanded) {
      setState(() => _hasOpened = true);
      _ctrl.forward();
    } else if (!widget.isExpanded && old.isExpanded) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final u     = widget.user;
    final color = _roleColor;

    return Opacity(
      opacity: u.isActive ? 1.0 : 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            // ── Header row ─────────────────────────────────────────────────
            InkWell(
              onTap: widget.onToggle,
              splashColor: color.withValues(alpha: 0.05),
              highlightColor: color.withValues(alpha: 0.03),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  children: [
                    _Avatar(user: u, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  u.displayName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _ink900,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _RolePill(user: u, color: color),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.phone_rounded, size: 12,
                                color: u.phone != null
                                    ? _ink400
                                    : const Color(0xFFD1D5DB)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                u.phone ?? 'No phone added',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: u.phone != null
                                      ? _ink600
                                      : const Color(0xFFD1D5DB)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                          if (u.employeeId != null) ...[
                            const SizedBox(height: 3),
                            Row(children: [
                              Icon(Icons.numbers_rounded,
                                  size: 11,
                                  color: color.withValues(alpha: 0.75)),
                              const SizedBox(width: 3),
                              Text(
                                u.employeeId!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ]),
                          ],
                          if (u.createdAt != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Member since ${DateFormat('MMM yyyy').format(u.createdAt!)}',
                              style: const TextStyle(
                                  fontSize: 11, color: _ink400),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _ActiveDot(isActive: u.isActive),
                        const SizedBox(height: 10),
                        RotationTransition(
                          turns: Tween(begin: 0.0, end: 0.5).animate(_chevron),
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: _bg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.keyboard_arrow_down_rounded,
                                color: _ink400, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Expanding body ──────────────────────────────────────────────
            SizeTransition(
              sizeFactor: _size,
              axisAlignment: -1.0,
              child: _hasOpened
                  ? FadeTransition(
                      opacity: _fade,
                      child: _ExpandedBody(
                        user: u,
                        roleColor: color,
                        activeTab: _activeTab,
                        onTabChange: (t) => setState(() => _activeTab = t),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EXPANDED BODY — tab switcher + content
// ─────────────────────────────────────────────────────────────────────────────
class _ExpandedBody extends StatelessWidget {
  const _ExpandedBody({
    required this.user,
    required this.roleColor,
    required this.activeTab,
    required this.onTabChange,
  });

  final UserModel         user;
  final Color             roleColor;
  final int               activeTab;
  final ValueChanged<int> onTabChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: _border),

        // Tab switcher
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _TabBtn(
                  label: 'Activity',
                  icon: Icons.bar_chart_rounded,
                  active: activeTab == 0,
                  color: roleColor,
                  onTap: () => onTabChange(0),
                ),
                _TabBtn(
                  label: 'Info',
                  icon: Icons.person_outline_rounded,
                  active: activeTab == 1,
                  color: roleColor,
                  onTap: () => onTabChange(1),
                ),
              ],
            ),
          ),
        ),

        // Tab content
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: activeTab == 0
              ? _ActivityTab(key: const ValueKey(0), uid: user.uid, roleColor: roleColor)
              : _InfoTab(key: const ValueKey(1), user: user, roleColor: roleColor),
        ),
      ],
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });
  final String   label;
  final IconData icon;
  final bool     active;
  final Color    color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6, offset: const Offset(0, 1))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14,
                  color: active ? color : _ink400),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? _ink900 : _ink400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  INFO TAB — profile fields from UserModel (no async)
// ─────────────────────────────────────────────────────────────────────────────
class _InfoTab extends StatelessWidget {
  const _InfoTab({super.key, required this.user, required this.roleColor});
  final UserModel user;
  final Color     roleColor;

  String? _maskedAadhar(String? raw) {
    if (raw == null || raw.length != 12) return raw;
    return 'XXXX XXXX ${raw.substring(8)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoSection(label: 'Personal', icon: Icons.person_rounded, color: roleColor, rows: [
          _InfoRow(icon: Icons.cake_rounded,   label: 'Age',
              value: user.age != null ? '${user.age} yrs' : null,
              color: roleColor),
          _InfoRow(icon: Icons.wc_rounded,     label: 'Gender',
              value: user.gender != null
                  ? (user.gender == 'male' ? 'Male' : 'Female')
                  : null,
              color: roleColor),
        ]),

        _InfoSection(label: 'Contact', icon: Icons.contact_phone_rounded, color: roleColor, rows: [
          _InfoRow(icon: Icons.mail_rounded,  label: 'Email',
              value: user.email.isNotEmpty ? user.email : null,
              color: roleColor, locked: true),
          _InfoRow(icon: Icons.phone_rounded, label: 'Phone',
              value: user.phone, color: roleColor),
        ]),

        _InfoSection(label: 'Identity', icon: Icons.badge_rounded, color: roleColor, rows: [
          _InfoRow(icon: Icons.numbers_rounded,      label: 'Employee ID',
              value: user.employeeId, color: roleColor),
          _InfoRow(icon: Icons.badge_rounded,        label: 'Aadhar No.',
              value: _maskedAadhar(user.aadharNo),
              color: roleColor),
          _InfoRow(icon: Icons.credit_card_rounded,  label: 'PAN Card',
              value: user.panCard, color: roleColor),
        ]),

        _InfoSection(label: 'Emergency Contact', icon: Icons.emergency_rounded, color: roleColor, rows: [
          _InfoRow(icon: Icons.person_pin_rounded,    label: 'Name',
              value: user.emergencyContactName, color: roleColor),
          _InfoRow(icon: Icons.phone_in_talk_rounded, label: 'Phone',
              value: user.emergencyContactPhone, color: roleColor),
        ]),

        _InfoSection(label: 'Address', icon: Icons.location_on_rounded, color: roleColor, isLast: true, rows: [
          _InfoRow(icon: Icons.location_on_rounded, label: 'Address',
              value: user.address, color: roleColor, multiLine: true),
        ]),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.label,
    required this.icon,
    required this.color,
    required this.rows,
    this.isLast = false,
  });
  final String       label;
  final IconData     icon;
  final Color        color;
  final List<Widget> rows;
  final bool         isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
          child: Row(
            children: [
              Container(
                width: 3, height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _ink600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i < rows.length - 1)
                  Divider(height: 1, indent: 44, color: _border),
              ],
            ],
          ),
        ),
        if (!isLast) const SizedBox(height: 4),
        if (isLast) const SizedBox(height: 16),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.locked    = false,
    this.multiLine = false,
  });
  final IconData icon;
  final String   label;
  final String?  value;
  final Color    color;
  final bool     locked;
  final bool     multiLine;

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment:
            multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: has
                  ? color.withValues(alpha: 0.09)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15,
                color: has ? color : const Color(0xFFD1D5DB)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _ink400,
                      letterSpacing: 0.1,
                    ),
                  ),
                  if (locked) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.lock_outline_rounded,
                        size: 10, color: _ink400),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  has ? value! : '—',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: has ? _ink900 : const Color(0xFFD1D5DB),
                    height: multiLine ? 1.5 : 1.2,
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
//  ACTIVITY TAB — fetches stats lazily
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityTab extends ConsumerWidget {
  const _ActivityTab({super.key, required this.uid, required this.roleColor});
  final String uid;
  final Color  roleColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(employeeStatsProvider(uid));
    return async.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: roleColor)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text('Could not load: $e',
            style: const TextStyle(fontSize: 12, color: Colors.red)),
      ),
      data: (s) => _ActivityContent(stats: s, roleColor: roleColor),
    );
  }
}

class _ActivityContent extends StatelessWidget {
  const _ActivityContent({required this.stats, required this.roleColor});
  final EmployeeStats stats;
  final Color         roleColor;

  String _fmt(double km) => km < 1
      ? '${(km * 1000).toStringAsFixed(0)} m'
      : '${km.toStringAsFixed(1)} km';

  String _relative(DateTime dt) {
    final today = DateTime.now();
    final d = DateTime(today.year, today.month, today.day)
        .difference(DateTime(dt.year, dt.month, dt.day))
        .inDays;
    if (d == 0) return 'Today';
    if (d == 1) return 'Yesterday';
    if (d < 7)  return '$d days ago';
    return DateFormat('d MMM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final distMonth = _fmt(stats.distanceMonthKm);
    final distToday = _fmt(stats.distanceTodayKm);
    final attendStr = stats.attendanceDays == 0
        ? '—'
        : '${stats.attendancePresent}/${stats.attendanceDays}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 3-stat summary strip ────────────────────────────────────────
          Row(children: [
            Expanded(child: _StatChip(
              icon: Icons.route_rounded, value: distMonth,
              label: 'Distance', color: roleColor)),
            const SizedBox(width: 8),
            Expanded(child: _StatChip(
              icon: Icons.pin_drop_rounded, value: '${stats.visitsMonth}',
              label: 'Visits', color: roleColor)),
            const SizedBox(width: 8),
            Expanded(child: _StatChip(
              icon: Icons.calendar_today_rounded, value: attendStr,
              label: 'Days', color: roleColor)),
          ]),

          const SizedBox(height: 18),

          // ── Distance ─────────────────────────────────────────────────────
          _ActSection(label: 'Distance', icon: Icons.route_rounded, color: roleColor),
          const SizedBox(height: 8),
          _DataCard(children: [
            _DataRow(label: 'Today', value: distToday),
            _DataRow(label: 'This month', value: distMonth,
                valueColor: roleColor),
          ]),

          const SizedBox(height: 18),

          // ── Leaves ───────────────────────────────────────────────────────
          _ActSection(label: 'Leave Summary', icon: Icons.beach_access_rounded, color: roleColor),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _LeaveBox(count: stats.leavesApplied,
                label: 'Applied',
                color: _ink600,
                bg: const Color(0xFFF3F4F6))),
            const SizedBox(width: 8),
            Expanded(child: _LeaveBox(count: stats.leavesApproved,
                label: 'Approved',
                color: const Color(0xFF059669),
                bg: const Color(0xFFECFDF5))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _LeaveBox(count: stats.leavesPending,
                label: 'Pending',
                color: const Color(0xFFD97706),
                bg: const Color(0xFFFFFBEB))),
            const SizedBox(width: 8),
            Expanded(child: _LeaveBox(count: stats.leavesDeclined,
                label: 'Declined',
                color: const Color(0xFFDC2626),
                bg: const Color(0xFFFEF2F2))),
          ]),

          const SizedBox(height: 18),

          // ── Activity ──────────────────────────────────────────────────────
          _ActSection(label: 'Activity', icon: Icons.bar_chart_rounded, color: roleColor),
          const SizedBox(height: 8),
          _DataCard(children: [
            _DataRow(
              label: 'Last visit',
              value: stats.lastVisitDate != null
                  ? _relative(stats.lastVisitDate!)
                  : 'No visits yet',
              valueColor: stats.lastVisitDate != null ? _ink900 : _ink400,
            ),
            _DataRow(
              label: 'Visits this month',
              value: '${stats.visitsMonth}',
              valueColor: roleColor,
            ),
            if (stats.attendanceDays > 0)
              _DataRow(
                label: 'Attendance',
                value: '${stats.attendancePresent} of ${stats.attendanceDays} days',
              ),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.color});
  final UserModel user;
  final Color     color;

  @override
  Widget build(BuildContext context) => Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Center(
          child: Text(
            user.displayName.isNotEmpty
                ? user.displayName[0].toUpperCase()
                : '?',
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: color),
          ),
        ),
      );
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.user, required this.color});
  final UserModel user;
  final Color     color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
        ),
        child: Text(
          user.isFieldAdvisor ? 'FA' : 'Clerk',
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color),
        ),
      );
}

class _ActiveDot extends StatelessWidget {
  const _ActiveDot({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final c = isActive ? const Color(0xFF10B981) : const Color(0xFFD1D5DB);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: c,
          boxShadow: isActive
              ? [BoxShadow(color: c.withValues(alpha: 0.55), blurRadius: 5)]
              : null,
        ),
      ),
      const SizedBox(width: 4),
      Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: isActive ? c : _ink400),
      ),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String   value;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.1)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _ink400)),
        ]),
      );
}

class _ActSection extends StatelessWidget {
  const _ActSection({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String   label;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 3, height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _ink600,
              letterSpacing: 0.2,
            )),
      ]);
}

class _DataCard extends StatelessWidget {
  const _DataCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                const Divider(height: 1, color: _border),
            ],
          ],
        ),
      );
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String  label;
  final String  value;
  final Color?  valueColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: _ink400,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? _ink900)),
            ),
          ],
        ),
      );
}

class _LeaveBox extends StatelessWidget {
  const _LeaveBox({
    required this.count,
    required this.label,
    required this.color,
    required this.bg,
  });
  final int    count;
  final String label;
  final Color  color;
  final Color  bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.15))),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle),
              child: Center(
                child: Text(
                  '$count',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isSearch});
  final bool isSearch;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearch
                    ? Icons.search_off_rounded
                    : Icons.people_outline_rounded,
                size: 32, color: _ink400),
            ),
            const SizedBox(height: 16),
            Text(
              isSearch ? 'No employees found' : 'No employees yet',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _ink900)),
            const SizedBox(height: 6),
            Text(
              isSearch
                  ? 'Try a different name or phone'
                  : 'Employees appear here once they sign up',
              style: const TextStyle(fontSize: 13, color: _ink400),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
