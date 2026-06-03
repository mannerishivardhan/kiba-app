import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kiba_app/core/domain/threshold_provider.dart';
import 'package:kiba_app/core/domain/leave_threshold_provider.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';

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
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen>
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
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Tab bar ────────────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_navy, _navyMid],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
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
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(
                iconMargin: EdgeInsets.only(bottom: 2),
                icon: Icon(Icons.person_pin_rounded, size: 17),
                text: 'Field Advisor',
              ),
              Tab(
                iconMargin: EdgeInsets.only(bottom: 2),
                icon: Icon(Icons.badge_rounded, size: 17),
                text: 'Clerk',
              ),
            ],
          ),
        ),

        // ── Tab views ──────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              _FaSettingsTab(),
              _ClerkSettingsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Field Advisor tab
// ─────────────────────────────────────────────────────────────────────────────
class _FaSettingsTab extends ConsumerStatefulWidget {
  const _FaSettingsTab();

  @override
  ConsumerState<_FaSettingsTab> createState() => _FaSettingsTabState();
}

class _FaSettingsTabState extends ConsumerState<_FaSettingsTab>
    with AutomaticKeepAliveClientMixin {
  final _visitsCtrl    = TextEditingController();
  final _kmCtrl        = TextEditingController();
  final _dutyHrsCtrl   = TextEditingController();
  final _faSickCtrl    = TextEditingController();
  final _faCasualCtrl  = TextEditingController();
  TimeOfDay _cutoff    = const TimeOfDay(hour: 9, minute: 30);
  bool _isSaving       = false;
  bool _attLoaded      = false;
  bool _leaveLoaded    = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _visitsCtrl.dispose();
    _kmCtrl.dispose();
    _dutyHrsCtrl.dispose();
    _faSickCtrl.dispose();
    _faCasualCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final att   = ref.watch(thresholdProvider).valueOrNull;
    final leave = ref.watch(leaveThresholdProvider).valueOrNull;

    if (att != null && !_attLoaded) {
      _visitsCtrl.text   = '${att.minVisitsForPresent}';
      _kmCtrl.text       = att.minKmForPresent.toStringAsFixed(1);
      _dutyHrsCtrl.text  = att.minDutyHoursForPresent.toStringAsFixed(1);
      _cutoff            = att.lateCheckinCutoff;
      _attLoaded         = true;
    }
    if (leave != null && !_leaveLoaded) {
      _faSickCtrl.text   = '${leave.faSickLeaves}';
      _faCasualCtrl.text = '${leave.faCasualLeaves}';
      _leaveLoaded       = true;
    }

    return ColoredBox(
      color: _bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── Attendance Rules ─────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.rule_rounded,
            title: 'Attendance Rules',
            subtitle: 'Applies to all Field Advisors',
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: _SettingsField(
                      ctrl:         _visitsCtrl,
                      label:        'Min Visits',
                      hint:         'e.g. 3',
                      icon:         Icons.place_rounded,
                      iconColor:    _faGreen,
                      keyboardType: TextInputType.number,
                      helper:       'Minimum farm visits to count as Present',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SettingsField(
                      ctrl:         _kmCtrl,
                      label:        'Min Distance (km)',
                      hint:         'e.g. 10.0',
                      icon:         Icons.route_rounded,
                      iconColor:    _navy,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      helper:       'Minimum km covered (alternative)',
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                _SettingsField(
                  ctrl:         _dutyHrsCtrl,
                  label:        'Min Duty Hours',
                  hint:         'e.g. 6.0',
                  icon:         Icons.timer_rounded,
                  iconColor:    _amber,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  helper:       'Hours below this triggers Early Checkout alert',
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: _border),
                const SizedBox(height: 16),
                _SettingsRow(
                  icon:      Icons.access_time_rounded,
                  iconColor: _amber,
                  title:     'Late Check-in After',
                  subtitle:  'Check-ins after this time are marked Late',
                  trailing:  _TimeChip(
                    time:    _cutoff,
                    onTap:   () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _cutoff,
                        builder: (ctx, child) => MediaQuery(
                          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
                          child: child!,
                        ),
                      );
                      if (picked != null) setState(() => _cutoff = picked);
                    },
                  ),
                ),
              ],
            ),
          ),

          if (att?.updatedBy != null || att?.updatedAt != null)
            _LastUpdated(updatedBy: att!.updatedBy, updatedAt: att.updatedAt),

          const SizedBox(height: 24),

          // ── Leave Entitlements ───────────────────────────────────────────
          _SectionHeader(
            icon: Icons.event_note_rounded,
            title: 'Leave Entitlements',
            subtitle: 'Annual leave days per Field Advisor',
          ),
          const SizedBox(height: 12),
          _Card(
            child: Row(children: [
              Expanded(
                child: _SettingsField(
                  ctrl:         _faSickCtrl,
                  label:        'Sick Leave Days',
                  hint:         'e.g. 10',
                  icon:         Icons.local_hospital_rounded,
                  iconColor:    _rose,
                  keyboardType: TextInputType.number,
                  helper:       'Max sick days per year',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SettingsField(
                  ctrl:         _faCasualCtrl,
                  label:        'Casual Leave Days',
                  hint:         'e.g. 15',
                  icon:         Icons.beach_access_rounded,
                  iconColor:    _faGreen,
                  keyboardType: TextInputType.number,
                  helper:       'Max casual days per year',
                ),
              ),
            ]),
          ),

          if (leave?.updatedBy != null || leave?.updatedAt != null)
            _LastUpdated(
                updatedBy: leave!.updatedBy, updatedAt: leave.updatedAt),

          const SizedBox(height: 28),

          // ── Save ─────────────────────────────────────────────────────────
          _SaveButton(isSaving: _isSaving, onPressed: _save),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final visits   = int.tryParse(_visitsCtrl.text.trim());
    final km       = double.tryParse(_kmCtrl.text.trim());
    final dutyHrs  = double.tryParse(_dutyHrsCtrl.text.trim());
    final sick     = int.tryParse(_faSickCtrl.text.trim());
    final casual   = int.tryParse(_faCasualCtrl.text.trim());

    if (visits == null || visits <= 0) {
      _showSnack('Enter a valid minimum visits count', isError: true); return;
    }
    if (km == null || km <= 0) {
      _showSnack('Enter a valid minimum distance', isError: true); return;
    }
    if (dutyHrs == null || dutyHrs <= 0) {
      _showSnack('Enter a valid minimum duty hours', isError: true); return;
    }
    if (sick == null || sick <= 0) {
      _showSnack('Enter a valid sick leave count', isError: true); return;
    }
    if (casual == null || casual <= 0) {
      _showSnack('Enter a valid casual leave count', isError: true); return;
    }

    setState(() => _isSaving = true);
    try {
      final adminUid = ref.read(currentUserProvider)?.uid ?? '';
      await Future.wait([
        ref.read(thresholdNotifierProvider.notifier).save(
          minVisits:    visits,
          minKm:        km,
          minDutyHours: dutyHrs,
          lateCutoff:   _cutoff,
          adminUid:     adminUid,
        ),
        ref.read(leaveThresholdNotifierProvider.notifier).saveFa(
          sickLeaves:   sick,
          casualLeaves: casual,
          adminUid:     adminUid,
        ),
      ]);
      if (mounted) _showSnack('Field Advisor settings saved');
    } catch (e) {
      if (mounted) _showSnack('Save failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _rose : _faGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Clerk tab
// ─────────────────────────────────────────────────────────────────────────────
class _ClerkSettingsTab extends ConsumerStatefulWidget {
  const _ClerkSettingsTab();

  @override
  ConsumerState<_ClerkSettingsTab> createState() => _ClerkSettingsTabState();
}

class _ClerkSettingsTabState extends ConsumerState<_ClerkSettingsTab>
    with AutomaticKeepAliveClientMixin {
  final _clerkSickCtrl   = TextEditingController();
  final _clerkCasualCtrl = TextEditingController();
  TimeOfDay _cutoff      = const TimeOfDay(hour: 9, minute: 0);
  bool _isSaving         = false;
  bool _attLoaded        = false;
  bool _leaveLoaded      = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _clerkSickCtrl.dispose();
    _clerkCasualCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final att   = ref.watch(thresholdProvider).valueOrNull;
    final leave = ref.watch(leaveThresholdProvider).valueOrNull;

    if (att != null && !_attLoaded) {
      _cutoff    = att.clerkLateCheckinCutoff;
      _attLoaded = true;
    }
    if (leave != null && !_leaveLoaded) {
      _clerkSickCtrl.text   = '${leave.clerkSickLeaves}';
      _clerkCasualCtrl.text = '${leave.clerkCasualLeaves}';
      _leaveLoaded          = true;
    }

    return ColoredBox(
      color: _bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── Attendance Rules ─────────────────────────────────────────────
          _SectionHeader(
            icon: Icons.rule_rounded,
            title: 'Attendance Rules',
            subtitle: 'Applies to all Clerks',
          ),
          const SizedBox(height: 12),
          _Card(
            child: _SettingsRow(
              icon:      Icons.access_time_rounded,
              iconColor: _amber,
              title:     'Late Check-in After',
              subtitle:  'Check-ins after this time are marked Late',
              trailing:  _TimeChip(
                time:  _cutoff,
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _cutoff,
                    builder: (ctx, child) => MediaQuery(
                      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _cutoff = picked);
                },
              ),
            ),
          ),

          if (att?.updatedBy != null || att?.updatedAt != null)
            _LastUpdated(updatedBy: att!.updatedBy, updatedAt: att.updatedAt),

          const SizedBox(height: 24),

          // ── Leave Entitlements ───────────────────────────────────────────
          _SectionHeader(
            icon: Icons.event_note_rounded,
            title: 'Leave Entitlements',
            subtitle: 'Annual leave days per Clerk',
          ),
          const SizedBox(height: 12),
          _Card(
            child: Row(children: [
              Expanded(
                child: _SettingsField(
                  ctrl:         _clerkSickCtrl,
                  label:        'Sick Leave Days',
                  hint:         'e.g. 12',
                  icon:         Icons.local_hospital_rounded,
                  iconColor:    _rose,
                  keyboardType: TextInputType.number,
                  helper:       'Max sick days per year',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SettingsField(
                  ctrl:         _clerkCasualCtrl,
                  label:        'Casual Leave Days',
                  hint:         'e.g. 18',
                  icon:         Icons.beach_access_rounded,
                  iconColor:    _faGreen,
                  keyboardType: TextInputType.number,
                  helper:       'Max casual days per year',
                ),
              ),
            ]),
          ),

          if (leave?.updatedBy != null || leave?.updatedAt != null)
            _LastUpdated(
                updatedBy: leave!.updatedBy, updatedAt: leave.updatedAt),

          const SizedBox(height: 28),

          // ── Save ─────────────────────────────────────────────────────────
          _SaveButton(isSaving: _isSaving, onPressed: _save),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final sick   = int.tryParse(_clerkSickCtrl.text.trim());
    final casual = int.tryParse(_clerkCasualCtrl.text.trim());

    if (sick == null || sick <= 0) {
      _showSnack('Enter a valid sick leave count', isError: true); return;
    }
    if (casual == null || casual <= 0) {
      _showSnack('Enter a valid casual leave count', isError: true); return;
    }

    setState(() => _isSaving = true);
    try {
      final adminUid = ref.read(currentUserProvider)?.uid ?? '';
      await Future.wait([
        ref.read(thresholdNotifierProvider.notifier).save(
          clerkLateCutoff: _cutoff,
          adminUid:        adminUid,
        ),
        ref.read(leaveThresholdNotifierProvider.notifier).saveClerk(
          sickLeaves:   sick,
          casualLeaves: casual,
          adminUid:     adminUid,
        ),
      ]);
      if (mounted) _showSnack('Clerk settings saved');
    } catch (e) {
      if (mounted) _showSnack('Save failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _rose : _faGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String   title, subtitle;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_navy, _navyMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: _navy.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: _ink900),
                overflow: TextOverflow.ellipsis),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: _ink400),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]);
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}

class _SettingsField extends StatelessWidget {
  const _SettingsField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.keyboardType,
    required this.helper,
  });
  final TextEditingController ctrl;
  final String        label, hint, helper;
  final IconData      icon;
  final Color         iconColor;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 13, color: iconColor),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _ink600)),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: _ink900),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _ink400, fontSize: 14),
              filled: true,
              fillColor: _surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                borderSide: BorderSide(color: iconColor, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(helper, style: const TextStyle(fontSize: 10, color: _ink400)),
        ],
      );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });
  final IconData icon;
  final Color    iconColor;
  final String   title, subtitle;
  final Widget   trailing;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink900)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11, color: _ink400)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      );
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.time, required this.onTap});
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_navy, _navyMid]),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(
              time.format(context),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
          ]),
        ),
      );
}

class _LastUpdated extends StatelessWidget {
  const _LastUpdated({required this.updatedBy, required this.updatedAt});
  final String?   updatedBy;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (updatedBy != null) parts.add('by $updatedBy');
    if (updatedAt != null) {
      parts.add('on ${DateFormat('d MMM yyyy, hh:mm a').format(updatedAt!)}');
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Row(children: [
        const Icon(Icons.history_rounded, size: 12, color: _ink400),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            'Last updated ${parts.join(' ')}',
            style: const TextStyle(fontSize: 11, color: _ink400),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.isSaving, required this.onPressed});
  final bool isSaving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isSaving ? null : onPressed,
          icon: isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_rounded, size: 17),
          label: const Text('Save Settings'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _border,
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      );
}
