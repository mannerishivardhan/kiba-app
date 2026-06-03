import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kiba_app/features/admin/data/visit_admin_repository.dart';
import 'package:kiba_app/features/admin/domain/admin_visit_providers.dart';
import 'package:kiba_app/features/admin/domain/user_admin_providers.dart';
import 'package:kiba_app/features/auth/data/user_model.dart';
import 'package:kiba_app/features/field_advisor/data/visit_model.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _navy    = Color(0xFF0D1B2A);
const _navyMid = Color(0xFF16293E);
const _amber   = Color(0xFFF59E0B);
const _faGreen = Color(0xFF059669);
const _clBlue  = Color(0xFF2563EB);
const _violet  = Color(0xFF7C3AED);
const _rose    = Color(0xFFDC2626);
const _bg      = Color(0xFFF0F4F8);
const _ink900  = Color(0xFF111827);
const _ink600  = Color(0xFF4B5563);
const _ink400  = Color(0xFF9CA3AF);
const _border  = Color(0xFFE5E7EB);
const _surface = Color(0xFFFBFCFD);

// ── Period ────────────────────────────────────────────────────────────────────
enum _VisitPeriod { today, week, month }

extension _VisitPeriodX on _VisitPeriod {
  String get label {
    switch (this) {
      case _VisitPeriod.today: return 'Today';
      case _VisitPeriod.week:  return 'This Week';
      case _VisitPeriod.month: return 'This Month';
    }
  }

  VisitRangeKey buildRangeKey() {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case _VisitPeriod.today:
        return (from: today, to: now);
      case _VisitPeriod.week:
        return (
          from: today.subtract(Duration(days: today.weekday - 1)),
          to: now,
        );
      case _VisitPeriod.month:
        return (from: DateTime(now.year, now.month, 1), to: now);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class AdminFieldVisitsScreen extends ConsumerStatefulWidget {
  const AdminFieldVisitsScreen({super.key});

  @override
  ConsumerState<AdminFieldVisitsScreen> createState() =>
      _AdminFieldVisitsScreenState();
}

class _AdminFieldVisitsScreenState
    extends ConsumerState<AdminFieldVisitsScreen>
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
                icon: Icon(Icons.bar_chart_rounded, size: 17),
                text: 'Overview',
              ),
              Tab(
                iconMargin: EdgeInsets.only(bottom: 2),
                icon: Icon(Icons.view_list_rounded, size: 17),
                text: 'Feed',
              ),
            ],
          ),
        ),

        // ── Content ──────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              _OverviewTab(),
              _FeedTab(),
            ],
          ),
        ),
      ]);
}

// ── Period Strip (matches attendance screen design exactly) ───────────────────
class _PeriodStrip extends StatelessWidget {
  const _PeriodStrip({required this.selected, required this.onSelected});
  final _VisitPeriod                selected;
  final ValueChanged<_VisitPeriod>  onSelected;

  @override
  Widget build(BuildContext context) => Container(
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: _VisitPeriod.values.map((p) {
            final active = p == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelected(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(
                            colors: [_navy, _navyMid],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: _navy.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    p.label,
                    style: TextStyle(
                      fontSize:   12.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color:      active ? Colors.white : _ink400,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Overview Tab — owns period state + period strip (matches attendance layout)
// ─────────────────────────────────────────────────────────────────────────────
class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab();

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab>
    with AutomaticKeepAliveClientMixin {
  _VisitPeriod _period = _VisitPeriod.today;
  late VisitRangeKey _rangeKey;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _rangeKey = _period.buildRangeKey();
  }

  String get _periodLabel {
    final now = DateTime.now();
    switch (_period) {
      case _VisitPeriod.today:
        return DateFormat('EEEE, d MMM').format(now);
      case _VisitPeriod.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return '${DateFormat('d MMM').format(monday)} – ${DateFormat('d MMM').format(now)}';
      case _VisitPeriod.month:
        return DateFormat('MMMM yyyy').format(now);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final visitsAsync    = ref.watch(adminVisitRangeProvider(_rangeKey));
    final employeesAsync = ref.watch(allEmployeesProvider);
    final repo           = ref.read(adminVisitRepoProvider);

    return ColoredBox(
      color: _bg,
      child: Column(children: [
        // ── Period strip ──────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _PeriodStrip(
            selected:   _period,
            onSelected: (p) => setState(() {
              _period   = p;
              _rangeKey = p.buildRangeKey();
            }),
          ),
        ),
        // ── Period label ──────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
          child: Center(
            child: Text(
              _periodLabel,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: _ink400),
            ),
          ),
        ),
        Container(height: 1, color: _border),

        // ── Stats ─────────────────────────────────────────────────────
        Expanded(
          child: visitsAsync.when(
            loading: () => const _LoadingBody(),
            error:   (e, _) => _ErrorBody(error: e),
            data: (visits) => employeesAsync.when(
              loading: () => const _LoadingBody(),
              error:   (e, _) => _ErrorBody(error: e),
              data: (employees) {
                final stats = repo.computeStats(visits, employees);
                return _OverviewBody(stats: stats);
              },
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.stats});
  final VisitStats stats;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        children: [
          // ── Quick stat cards ──────────────────────────────────────────
          Row(children: [
            Expanded(
              child: _QuickStatCard(
                value: '${stats.totalVisits}',
                title: 'Total Visits',
                icon:  Icons.place_rounded,
                color: _amber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickStatCard(
                value: '${stats.totalKm.toStringAsFixed(1)} km',
                title: 'Distance',
                icon:  Icons.route_rounded,
                color: _faGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickStatCard(
                value: stats.totalAcres.toStringAsFixed(1),
                title: 'Acres',
                icon:  Icons.water_rounded,
                color: _violet,
              ),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Status chips ──────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: _StatusChip(
                label: 'Active',
                count: stats.statusBreakdown[VisitStatus.active] ?? 0,
                color: _faGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatusChip(
                label: 'Completed',
                count: stats.statusBreakdown[VisitStatus.completed] ?? 0,
                color: _clBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatusChip(
                label: 'Missed',
                count: stats.statusBreakdown[VisitStatus.missed] ?? 0,
                color: _rose,
              ),
            ),
          ]),

          if (stats.totalVisits == 0) ...[
            const SizedBox(height: 40),
            const _EmptyState(
              icon:     Icons.pin_drop_outlined,
              title:    'No field visits',
              subtitle: 'No visits recorded for this period',
            ),
          ] else ...[
            // ── Purpose breakdown ───────────────────────────────────────
            const SizedBox(height: 16),
            const _SectionLabel(
                icon: Icons.donut_small_rounded, title: 'Visit Purposes'),
            const SizedBox(height: 10),
            _Card(child: _PurposeBreakdown(stats: stats)),

            // ── FA Leaderboard ──────────────────────────────────────────
            const SizedBox(height: 16),
            const _SectionLabel(
                icon: Icons.leaderboard_rounded, title: 'FA Performance'),
            const SizedBox(height: 10),
            _Card(child: _FaLeaderboard(perFa: stats.perFa)),
          ],
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Feed Tab
// ─────────────────────────────────────────────────────────────────────────────
class _FeedTab extends ConsumerStatefulWidget {
  const _FeedTab();

  @override
  ConsumerState<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<_FeedTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String        _query         = '';
  VisitPurpose? _purposeFilter;

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

    final visitsAsync    = ref.watch(adminAllVisitsProvider);
    final employeesAsync = ref.watch(allEmployeesProvider);

    final userMap = employeesAsync.valueOrNull != null
        ? {for (final u in employeesAsync.valueOrNull!) u.uid: u}
        : <String, UserModel>{};

    return Column(children: [
      // ── Search + filter ──────────────────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.trim()),
            style: const TextStyle(fontSize: 14, color: _ink900),
            decoration: InputDecoration(
              hintText: 'Search farmer, FA name, ID or address…',
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
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
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
                borderSide: const BorderSide(color: _navy, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Purpose filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _PurposeChip(
                label:  'All',
                active: _purposeFilter == null,
                color:  _navy,
                onTap:  () => setState(() => _purposeFilter = null),
              ),
              ...VisitPurpose.values.map((p) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _PurposeChip(
                      label:  p.label,
                      active: _purposeFilter == p,
                      color:  p.color,
                      icon:   p.icon,
                      onTap:  () => setState(() => _purposeFilter = p),
                    ),
                  )),
            ]),
          ),
          const SizedBox(height: 10),
        ]),
      ),
      Container(height: 1, color: _border),

      // ── List ─────────────────────────────────────────────────────────
      Expanded(
        child: visitsAsync.when(
          loading: () => const _LoadingBody(),
          error:   (e, _) => _ErrorBody(error: e),
          data: (visits) {
            final filtered = _filter(visits, userMap);
            if (filtered.isEmpty) {
              return _EmptyState(
                icon:  Icons.search_off_rounded,
                title: 'No visits found',
                subtitle: _query.isNotEmpty || _purposeFilter != null
                    ? 'Try adjusting your search or filter'
                    : 'No visits recorded for this period',
              );
            }
            final items = _buildItems(filtered);
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 48),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                if (item is String) return _DateHeader(label: item);
                return _AdminVisitCard(
                  visit: item as VisitModel,
                  fa:    userMap[(item).uid],
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  List<VisitModel> _filter(
      List<VisitModel> visits, Map<String, UserModel> userMap) {
    var list = visits;
    if (_purposeFilter != null) {
      list = list.where((v) => v.purpose == _purposeFilter).toList();
    }
    if (_query.isNotEmpty) {
      final q  = _query.toLowerCase();
      final qN = q.replaceAll('-', '').replaceAll(' ', '');
      list = list.where((v) {
        final faName  = userMap[v.uid]?.displayName.toLowerCase() ?? '';
        final empId   = (userMap[v.uid]?.employeeId ?? '').toLowerCase().replaceAll('-', '');
        return v.farmerName.toLowerCase().contains(q) ||
            faName.contains(q) ||
            v.address.toLowerCase().contains(q) ||
            (qN.isNotEmpty && empId.contains(qN));
      }).toList();
    }
    return list;
  }

  List<dynamic> _buildItems(List<VisitModel> visits) {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final items     = <dynamic>[];
    String? lastHdr;
    for (final v in visits) {
      final d = DateTime(v.checkIn.year, v.checkIn.month, v.checkIn.day);
      final hdr = d == today
          ? 'Today'
          : d == yesterday
              ? 'Yesterday'
              : DateFormat('EEEE, d MMMM').format(d);
      if (hdr != lastHdr) {
        items.add(hdr);
        lastHdr = hdr;
      }
      items.add(v);
    }
    return items;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Visit Card
// ─────────────────────────────────────────────────────────────────────────────
class _AdminVisitCard extends StatefulWidget {
  const _AdminVisitCard({required this.visit, this.fa});
  final VisitModel visit;
  final UserModel? fa;

  @override
  State<_AdminVisitCard> createState() => _AdminVisitCardState();
}

class _AdminVisitCardState extends State<_AdminVisitCard> {
  bool _expanded = false;
  Future<String>? _placeFuture;

  @override
  void initState() {
    super.initState();
    final v = widget.visit;
    if (v.latitude != null && v.longitude != null) {
      _placeFuture = _resolvePlaceName(v.latitude!, v.longitude!);
    }
  }

  static Future<String> _resolvePlaceName(double lat, double lon) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lon);
      if (marks.isEmpty) return _coordFallback(lat, lon);
      final p = marks.first;
      final parts = [p.subLocality, p.locality, p.administrativeArea]
          .where((s) => s != null && s.isNotEmpty)
          .map((s) => s!)
          .toList();
      if (parts.isEmpty) return _coordFallback(lat, lon);
      return parts.take(2).join(', ');
    } catch (_) {
      return _coordFallback(lat, lon);
    }
  }

  static String _coordFallback(double lat, double lon) =>
      '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';

  static Future<void> _openMaps(double lat, double lon) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final v          = widget.visit;
    final fa         = widget.fa;
    final color      = v.purpose.color;
    final hasDetails = v.issuesReported.isNotEmpty ||
        v.resolutionGiven.isNotEmpty ||
        v.notes.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
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
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(12, 14, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row 1: purpose icon + farmer + status
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width:  34, height: 34,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(9),
                                    ),
                                    child: Icon(v.purpose.icon,
                                        size: 16, color: color),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          v.farmerName.isEmpty
                                              ? 'Unknown Farmer'
                                              : v.farmerName,
                                          style: const TextStyle(
                                            fontSize:   14,
                                            fontWeight: FontWeight.w800,
                                            color:      _ink900,
                                          ),
                                          maxLines:  1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (v.address.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Row(children: [
                                            const Icon(
                                                Icons.location_on_rounded,
                                                size:  11,
                                                color: _ink400),
                                            const SizedBox(width: 3),
                                            Expanded(
                                              child: Text(
                                                v.address,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color:    _ink400),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ]),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: v.status.surface,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      v.status.label,
                                      style: TextStyle(
                                        fontSize:   10,
                                        fontWeight: FontWeight.w700,
                                        color:      v.status.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Row 2: FA info + metrics
                              Row(children: [
                                _FaMini(fa: fa),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    fa?.displayName ?? 'Unknown FA',
                                    style: const TextStyle(
                                        fontSize:   11,
                                        fontWeight: FontWeight.w600,
                                        color:      _ink600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (v.distanceFromPrevKm > 0) ...[
                                  _MidDot(),
                                  Text(
                                    '${v.distanceFromPrevKm.toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                      fontSize:   11,
                                      fontWeight: FontWeight.w600,
                                      color:      _faGreen,
                                    ),
                                  ),
                                ],
                                if (v.pondArea > 0) ...[
                                  _MidDot(),
                                  Text(
                                    '${v.pondArea.toStringAsFixed(1)} ac',
                                    style: const TextStyle(
                                        fontSize: 11, color: _ink400),
                                  ),
                                ],
                              ]),

                              const SizedBox(height: 7),

                              // Row 3: in / out times + GPS
                              Row(children: [
                                const Icon(Icons.login_rounded,
                                    size: 11, color: _faGreen),
                                const SizedBox(width: 3),
                                Text(
                                  DateFormat('h:mm a').format(v.checkIn),
                                  style: const TextStyle(
                                    fontSize:   11,
                                    fontWeight: FontWeight.w600,
                                    color:      _faGreen,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    size:  10,
                                    color: _ink400,
                                  ),
                                ),
                                Icon(
                                  v.checkOut != null
                                      ? Icons.logout_rounded
                                      : Icons.radio_button_checked_rounded,
                                  size:  11,
                                  color: v.checkOut != null
                                      ? _violet
                                      : _faGreen,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  v.checkOut != null
                                      ? DateFormat('h:mm a')
                                          .format(v.checkOut!)
                                      : 'Active',
                                  style: TextStyle(
                                    fontSize:   11,
                                    fontWeight: FontWeight.w600,
                                    color: v.checkOut != null
                                        ? _violet
                                        : _faGreen,
                                  ),
                                ),
                                if (_placeFuture != null) ...[
                                  _MidDot(),
                                  const Icon(Icons.gps_fixed_rounded,
                                      size: 11, color: _clBlue),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: FutureBuilder<String>(
                                      future: _placeFuture,
                                      builder: (_, snap) {
                                        final label = snap.hasData
                                            ? snap.data!
                                            : snap.hasError
                                                ? _coordFallback(
                                                    v.latitude!, v.longitude!)
                                                : '…';
                                        return GestureDetector(
                                          onTap: snap.hasData
                                              ? () => _openMaps(
                                                  v.latitude!, v.longitude!)
                                              : null,
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              fontSize:      11,
                                              color:         _clBlue,
                                              fontWeight:    snap.hasData
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              decoration: snap.hasData
                                                  ? TextDecoration.underline
                                                  : null,
                                              decorationColor: _clBlue,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ]),
                            ],
                          ),
                        ),

                        // ── Expand toggle ─────────────────────────────
                        if (hasDetails) ...[
                          GestureDetector(
                            onTap: () =>
                                setState(() => _expanded = !_expanded),
                            child: Container(
                              width: double.infinity,
                              color: _bg,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              child: Row(children: [
                                Icon(
                                  _expanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size:  14,
                                  color: color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _expanded
                                      ? 'Hide details'
                                      : 'Show details',
                                  style: TextStyle(
                                    fontSize:   11,
                                    fontWeight: FontWeight.w600,
                                    color:      color,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    v.purpose.label,
                                    style: TextStyle(
                                      fontSize:   10,
                                      fontWeight: FontWeight.w600,
                                      color:      color,
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            child: _expanded
                                ? _DetailSection(visit: v)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
          );
        }
}

class _FaMini extends StatelessWidget {
  const _FaMini({this.fa});
  final UserModel? fa;

  @override
  Widget build(BuildContext context) => Container(
        width:  22, height: 22,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            _avatarColor(fa?.displayName ?? ''),
            _avatarColor(fa?.displayName ?? '').withValues(alpha: 0.75),
          ]),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            _initials(fa?.displayName),
            style: const TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      );
}

class _MidDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: Text('·', style: TextStyle(color: _ink400, fontSize: 11)),
      );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.visit});
  final VisitModel visit;

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 0, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: _border, height: 16),
            if (visit.issuesReported.isNotEmpty)
              _DetailRow(
                icon:      Icons.warning_amber_rounded,
                iconColor: _rose,
                label:     'Issues Reported',
                text:      visit.issuesReported,
              ),
            if (visit.resolutionGiven.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DetailRow(
                icon:      Icons.check_circle_outline_rounded,
                iconColor: _faGreen,
                label:     'Resolution Given',
                text:      visit.resolutionGiven,
              ),
            ],
            if (visit.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DetailRow(
                icon:      Icons.notes_rounded,
                iconColor: _clBlue,
                label:     'Notes',
                text:      visit.notes,
              ),
            ],
            if (visit.checkOut != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: _violet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.timer_rounded,
                      size: 12, color: _violet),
                ),
                const SizedBox(width: 8),
                Text(
                  'Duration: ${visit.durationLabel}',
                  style: const TextStyle(
                      fontSize: 12,
                      color:    _ink600,
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ],
          ],
        ),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.text,
  });
  final IconData icon;
  final Color    iconColor;
  final String   label, text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 12, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize:   10,
                        fontWeight: FontWeight.w700,
                        color:      _ink600)),
                const SizedBox(height: 2),
                Text(text,
                    style: const TextStyle(fontSize: 12, color: _ink900)),
              ],
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Overview sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.value,
    required this.title,
    required this.icon,
    required this.color,
  });
  final String   value, title;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.w900,
                  color:      _ink900),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                  fontSize:   10,
                  color:      _ink400,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int    count;
  final Color  color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:  color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Text(
            '$count',
            style: TextStyle(
                fontSize:   20,
                fontWeight: FontWeight.w900,
                color:      color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
                fontSize:   10,
                color:      color,
                fontWeight: FontWeight.w600),
          ),
        ]),
      );
}

class _PurposeBreakdown extends StatelessWidget {
  const _PurposeBreakdown({required this.stats});
  final VisitStats stats;

  @override
  Widget build(BuildContext context) {
    final breakdown = stats.purposeBreakdown;
    final total     = stats.totalVisits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stacked bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 20,
            child: Row(
              children: VisitPurpose.values.map((p) {
                final count = breakdown[p] ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return Expanded(
                  flex: count,
                  child: ColoredBox(color: p.color),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Legend
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: VisitPurpose.values
              .where((p) => (breakdown[p] ?? 0) > 0)
              .map((p) {
            final count = breakdown[p] ?? 0;
            final pct   = (count / total * 100).round();
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: p.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: p.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  '${p.label}  $count  ($pct%)',
                  style: TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                    color:      p.color,
                  ),
                ),
              ]),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FaLeaderboard extends StatelessWidget {
  const _FaLeaderboard({required this.perFa});
  final List<FaVisitStat> perFa;

  @override
  Widget build(BuildContext context) {
    final active = perFa.where((f) => f.visitCount > 0).take(6).toList();
    if (active.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No visits recorded yet',
            style: TextStyle(fontSize: 13, color: _ink400),
          ),
        ),
      );
    }
    final maxVisits = active.first.visitCount;
    return Column(
      children: active
          .asMap()
          .entries
          .map((e) => _LeaderRow(
                rank:      e.key + 1,
                fa:        e.value,
                maxVisits: maxVisits,
                isLast:    e.key == active.length - 1,
              ))
          .toList(),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.rank,
    required this.fa,
    required this.maxVisits,
    this.isLast = false,
  });
  final int          rank;
  final FaVisitStat  fa;
  final int          maxVisits;
  final bool         isLast;

  @override
  Widget build(BuildContext context) {
    final pct   = fa.visitCount / maxVisits;
    final color = _avatarColor(fa.user.displayName);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Rank badge
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color:  rank == 1 ? _amber : _bg,
            shape:  BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w800,
                color:
                    rank == 1 ? const Color(0xFF1A1200) : _ink400,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Avatar
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.75)],
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
              _initials(fa.user.displayName),
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    fa.user.displayName,
                    style: const TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        color:      _ink900),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${fa.visitCount} visits',
                  style: const TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w700,
                      color:      _ink600),
                ),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:           pct,
                  minHeight:       5,
                  backgroundColor: _bg,
                  valueColor:      AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${fa.totalKm.toStringAsFixed(1)} km · ${fa.totalAcres.toStringAsFixed(1)} ac',
                style: const TextStyle(fontSize: 10, color: _ink400),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title});
  final IconData icon;
  final String   title;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 3, height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_amber, Color(0xFFF97316)],
              begin:  Alignment.topCenter,
              end:    Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 14, color: _ink600),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w800,
              color:      _ink900),
        ),
      ]);
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      );
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Row(children: [
          Container(
            width: 3, height: 14,
            decoration: BoxDecoration(
              color: _amber,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
                fontSize:      10,
                fontWeight:    FontWeight.w800,
                color:         _ink600,
                letterSpacing: 0.8),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: _border)),
        ]),
      );
}

class _PurposeChip extends StatelessWidget {
  const _PurposeChip({
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: _navy),
      );
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: _rose),
              const SizedBox(height: 12),
              const Text(
                'Failed to load visits',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _ink900),
              ),
              const SizedBox(height: 4),
              Text(
                error.toString(),
                style: const TextStyle(fontSize: 12, color: _ink400),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String   title, subtitle;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: _ink400),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _ink600)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 13, color: _ink400)),
          ],
        ),
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _initials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final parts = name.trim().split(' ');
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

Color _avatarColor(String name) {
  const colors = [
    Color(0xFF0D1B2A),
    Color(0xFF059669),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFD97706),
    Color(0xFF0891B2),
    Color(0xFFDB2777),
  ];
  if (name.isEmpty) return colors[0];
  return colors[name.codeUnitAt(0) % colors.length];
}
