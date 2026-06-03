import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';
import 'package:kiba_app/features/field_advisor/presentation/widgets/character_painter.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _green      = Color(0xFF059669);
// ignore: unused_element
const _greenDark  = Color(0xFF047857);
const _greenLight = Color(0xFFD1FAE5);
const _bg         = Color(0xFFF4F7F6);
const _card       = Colors.white;

class FaProfileScreen extends ConsumerStatefulWidget {
  const FaProfileScreen({super.key});

  @override
  ConsumerState<FaProfileScreen> createState() => _FaProfileScreenState();
}

class _FaProfileScreenState extends ConsumerState<FaProfileScreen> {
  bool _editing = false;
  bool _saving  = false;

  // Controllers
  final _nameCtrl      = TextEditingController();
  final _ageCtrl       = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _aadharCtrl    = TextEditingController();
  final _panCtrl       = TextEditingController();
  final _ecNameCtrl    = TextEditingController();  // emergency contact name
  final _ecPhoneCtrl   = TextEditingController();  // emergency contact phone
  final _addressCtrl   = TextEditingController();

  String? _gender;
  String? _error;

  @override
  void initState() {
    super.initState();
    _populateControllers();
  }

  void _populateControllers() {
    final u = ref.read(currentUserProvider);
    if (u == null) return;
    _nameCtrl.text    = u.displayName;
    _ageCtrl.text     = u.age?.toString() ?? '';
    _phoneCtrl.text   = u.phone ?? '';
    _aadharCtrl.text  = u.aadharNo ?? '';
    _panCtrl.text     = u.panCard ?? '';
    _ecNameCtrl.text  = u.emergencyContactName ?? '';
    _ecPhoneCtrl.text = u.emergencyContactPhone ?? '';
    _addressCtrl.text = u.address ?? '';
    _gender = u.gender;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _aadharCtrl.dispose();
    _panCtrl.dispose();
    _ecNameCtrl.dispose();
    _ecPhoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (_editing) {
      // cancel — restore original values
      _populateControllers();
      setState(() { _editing = false; _error = null; });
    } else {
      setState(() { _editing = true; _error = null; });
    }
  }

  Future<void> _save() async {
    final name   = _nameCtrl.text.trim();
    final ageStr = _ageCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (ageStr.isNotEmpty) {
      final age = int.tryParse(ageStr);
      if (age == null || age < 18 || age > 70) {
        setState(() => _error = 'Enter a valid age (18–70)');
        return;
      }
    }

    setState(() { _saving = true; _error = null; });
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final data = <String, dynamic>{
      'displayName': name,
      if (ageStr.isNotEmpty) 'age': int.parse(ageStr),
      if (_gender != null) 'gender': _gender,
      if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
      if (_ecNameCtrl.text.trim().isNotEmpty)
        'emergencyContactName': _ecNameCtrl.text.trim(),
      if (_ecPhoneCtrl.text.trim().isNotEmpty)
        'emergencyContactPhone': _ecPhoneCtrl.text.trim(),
      if (_addressCtrl.text.trim().isNotEmpty) 'address': _addressCtrl.text.trim(),
    };

    await ref.read(authNotifierProvider.notifier).updateProfile(user.uid, data);

    if (!mounted) return;
    final newState = ref.read(authNotifierProvider);
    if (newState is AuthError) {
      setState(() { _error = newState.message; _saving = false; });
    } else {
      setState(() { _editing = false; _saving = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }


  String _maskedAadhar(String raw) {
    if (raw.length != 12) return raw;
    return 'XXXX XXXX ${raw.substring(8)}';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _buildHeroHeader(user.role),
                const SizedBox(height: 20),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: Color(0xFFDC2626), fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),

                _ProfileSection(
                  label: 'PERSONAL',
                  children: [
                    _ProfileRow(
                      icon: Icons.person_rounded,
                      label: 'Full Name',
                      value: user.displayName,
                      editing: _editing,
                      controller: _nameCtrl,
                      inputType: TextInputType.name,
                      suffix: _RoleBadge(role: user.role),
                    ),
                    _ProfileRow(
                      icon: Icons.cake_rounded,
                      label: 'Age',
                      value: user.age != null ? '${user.age} years' : '—',
                      editing: _editing,
                      controller: _ageCtrl,
                      inputType: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                      hint: 'e.g. 28',
                    ),
                    _GenderRow(
                      gender: _gender,
                      editing: _editing,
                      onChanged: (g) => setState(() => _gender = g),
                    ),
                  ],
                ),

                _ProfileSection(
                  label: 'CONTACT',
                  children: [
                    _ProfileRow(
                      icon: Icons.mail_rounded,
                      label: 'Email',
                      value: user.email,
                      editing: false, // email is always read-only
                      controller: TextEditingController(text: user.email),
                      locked: true,
                    ),
                    _ProfileRow(
                      icon: Icons.phone_rounded,
                      label: 'Phone',
                      value: user.phone ?? '—',
                      editing: _editing,
                      controller: _phoneCtrl,
                      inputType: TextInputType.phone,
                      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
                      hint: '+91 98765 43210',
                    ),
                  ],
                ),

                _ProfileSection(
                  label: 'IDENTITY',
                  children: [
                    _ProfileRow(
                      icon: Icons.numbers_rounded,
                      label: 'Employee ID',
                      value: user.employeeId ?? 'Not assigned yet',
                      editing: false,
                      controller: TextEditingController(
                          text: user.employeeId ?? '—'),
                      locked: true,
                    ),
                    _ProfileRow(
                      icon: Icons.badge_rounded,
                      label: 'Aadhar No.',
                      value: user.aadharNo != null
                          ? _maskedAadhar(user.aadharNo!)
                          : '—',
                      editing: false,
                      controller: _aadharCtrl,
                      locked: true,
                      obscureInView: true,
                    ),
                    _ProfileRow(
                      icon: Icons.credit_card_rounded,
                      label: 'PAN Card',
                      value: user.panCard ?? '—',
                      editing: false,
                      controller: _panCtrl,
                      locked: true,
                    ),
                  ],
                ),

                _ProfileSection(
                  label: 'EMERGENCY CONTACT',
                  children: [
                    _ProfileRow(
                      icon: Icons.person_pin_rounded,
                      label: 'Contact Name',
                      value: user.emergencyContactName ?? '—',
                      editing: _editing,
                      controller: _ecNameCtrl,
                      inputType: TextInputType.name,
                      hint: 'e.g. Ravi Kumar',
                    ),
                    _ProfileRow(
                      icon: Icons.phone_in_talk_rounded,
                      label: 'Contact Phone',
                      value: user.emergencyContactPhone ?? '—',
                      editing: _editing,
                      controller: _ecPhoneCtrl,
                      inputType: TextInputType.phone,
                      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
                      hint: '+91 98765 11111',
                    ),
                  ],
                ),

                _ProfileSection(
                  label: 'ADDRESS',
                  children: [
                    _ProfileRow(
                      icon: Icons.location_on_rounded,
                      label: 'Address',
                      value: user.address ?? '—',
                      editing: _editing,
                      controller: _addressCtrl,
                      inputType: TextInputType.multiline,
                      maxLines: 3,
                      hint: 'Door no, Street, City, State — Pincode',
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Save / Edit button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: _editing
                      ? Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                label: 'Cancel',
                                color: const Color(0xFF6B7280),
                                onTap: _saving ? null : _toggleEdit,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _ActionButton(
                                label: _saving ? 'Saving…' : 'Save Changes',
                                color: _green,
                                onTap: _saving ? null : _save,
                                icon: Icons.check_rounded,
                              ),
                            ),
                          ],
                        )
                      : _ActionButton(
                          label: 'Edit Profile',
                          color: _green,
                          onTap: _toggleEdit,
                          icon: Icons.edit_rounded,
                        ),
                ),
              ],
            ),
          ),
          // Floating logout button pinned top-right
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _confirmLogout(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildHeroHeader(String role) {
    final isClerk    = role == 'clerk';
    final shirtColor = isClerk ? const Color(0xFF2563EB) : _green;
    final topColor   = isClerk ? const Color(0xFF0F172A) : const Color(0xFF022C22);
    final midColor   = isClerk ? const Color(0xFF1E3A8A) : const Color(0xFF064E3B);
    final gender     = _gender ?? 'male';

    return ClipPath(
      clipper: _WaveClipper(),
      child: Container(
        width: double.infinity,
        // Extra bottom padding to account for wave overhang
        padding: const EdgeInsets.only(bottom: 48),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [topColor, midColor, shirtColor.withValues(alpha: 0.85)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ── Decorative orbs ─────────────────────────────────────────
            Positioned(
              top: -40, right: -40,
              child: Container(
                width: 180, height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: shirtColor.withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              top: 60, left: -60,
              child: Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            Positioned(
              bottom: 40, right: 20,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            // ── Subtle grid dots ─────────────────────────────────────────
            Positioned.fill(
              child: CustomPaint(painter: _DotGridPainter()),
            ),

            // ── Content ──────────────────────────────────────────────────
            Column(
              children: [
                // Safe area top padding
                const SizedBox(height: 56),

                // Character stage — ground strip
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1), width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: RoamingCharacter(
                      gender: gender,
                      shirtColor: shirtColor,
                      role: role,
                      height: 170,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
    }
  }
}

// ── Gender row ────────────────────────────────────────────────────────────────
class _GenderRow extends StatelessWidget {
  const _GenderRow({
    required this.gender,
    required this.editing,
    required this.onChanged,
  });

  final String?              gender;
  final bool                 editing;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.wc_rounded, size: 18, color: Color(0xFF059669)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gender',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.3,
                    )),
                const SizedBox(height: 6),
                if (editing)
                  Row(
                    children: [
                      _GenderChip(
                        label: 'Male',
                        icon: Icons.male_rounded,
                        selected: gender == 'male',
                        onTap: () => onChanged('male'),
                      ),
                      const SizedBox(width: 10),
                      _GenderChip(
                        label: 'Female',
                        icon: Icons.female_rounded,
                        selected: gender == 'female',
                        onTap: () => onChanged('female'),
                      ),
                    ],
                  )
                else
                  Text(
                    gender == 'male'
                        ? 'Male'
                        : gender == 'female'
                            ? 'Female'
                            : '—',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: gender == null
                          ? Colors.grey.shade400
                          : const Color(0xFF111827),
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

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String   label;
  final IconData icon;
  final bool     selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF059669)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF059669)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: selected ? Colors.white : Colors.grey.shade500),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section wrapper ────────────────────────────────────────────────────────────
class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(
                      height: 1,
                      indent: 52,
                      color: Colors.grey.shade100,
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

// ── Profile row ────────────────────────────────────────────────────────────────
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.editing,
    required this.controller,
    this.inputType = TextInputType.text,
    this.formatters,
    this.hint,
    this.maxLines = 1,
    this.locked = false,
    this.obscureInView = false,
    this.suffix,
  });

  final IconData           icon;
  final String             label;
  final String             value;
  final bool               editing;
  final TextEditingController controller;
  final TextInputType      inputType;
  final List<TextInputFormatter>? formatters;
  final String?            hint;
  final int                maxLines;
  final bool               locked;       // always read-only (email)
  final bool               obscureInView; // mask in view mode (Aadhar)
  final Widget?            suffix;       // inline widget after label (e.g. role badge)

  @override
  Widget build(BuildContext context) {
    final isEditable = editing && !locked;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment:
            maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: locked
                  ? Colors.grey.shade100
                  : _greenLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: locked ? Colors.grey.shade400 : _green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (locked) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.lock_outline_rounded,
                          size: 11, color: Colors.grey.shade400),
                    ],
                    if (suffix != null) ...[
                      const SizedBox(width: 8),
                      suffix!,
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                if (isEditable)
                  TextFormField(
                    controller: controller,
                    keyboardType: inputType,
                    inputFormatters: formatters,
                    maxLines: maxLines,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                      hintText: hint,
                      hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                          fontWeight: FontWeight.w400),
                      border: UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: _green, width: 1.5)),
                      enabledBorder: UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.grey.shade200)),
                    ),
                  )
                else
                  Text(
                    value.isEmpty ? '—' : value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: value.isEmpty || value == '—'
                          ? Colors.grey.shade400
                          : const Color(0xFF111827),
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

// ── Action button ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
  });

  final String    label;
  final Color     color;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: onTap == null
              ? color.withValues(alpha: 0.5)
              : color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap == null
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Role badge ────────────────────────────────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final isClerk = role == 'clerk';
    final isAdmin = role == 'admin';
    final color = isClerk || isAdmin ? const Color(0xFF2563EB) : _green;
    final label = isAdmin
        ? 'Admin'
        : isClerk
            ? 'Clerk'
            : 'Field Advisor';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ── Formatters ────────────────────────────────────────────────────────────────
// ── Wave clipper ──────────────────────────────────────────────────────────────
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - 52)
      ..cubicTo(
        size.width * 0.18, size.height - 10,
        size.width * 0.38, size.height - 72,
        size.width * 0.58, size.height - 36,
      )
      ..cubicTo(
        size.width * 0.75, size.height - 8,
        size.width * 0.88, size.height - 48,
        size.width, size.height - 28,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

// ── Dot-grid background painter ───────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 0;
    const spacing = 28.0;
    const radius  = 1.5;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
