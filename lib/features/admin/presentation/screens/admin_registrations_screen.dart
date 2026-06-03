import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kiba_app/features/auth/data/auth_repository.dart';
import 'package:kiba_app/features/auth/data/user_model.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';

const _navy     = Color(0xFF0D1B2A);
const _green    = Color(0xFF059669);
const _red      = Color(0xFFEF4444);
const _bg       = Color(0xFFF0F4F8);
const _cardBg   = Colors.white;
const _label    = Color(0xFF1A1A2E);
const _muted    = Color(0xFF64748B);

class AdminRegistrationsScreen extends ConsumerWidget {
  const AdminRegistrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pendingRegistrationsProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: state.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _navy),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: _red)),
        ),
        data: (users) {
          if (users.isEmpty) {
            return _EmptyState();
          }
          return RefreshIndicator(
            color: _navy,
            onRefresh: () async =>
                ref.invalidate(pendingRegistrationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (_, i) => _RegistrationCard(
                user: users[i],
              ).animate(delay: (i * 60).ms).fadeIn().slideY(begin: 0.1),
            ),
          );
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFE0F2FE),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.how_to_reg_rounded,
                size: 36, color: Color(0xFF0284C7)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Pending Registrations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _label,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'All registration requests have been reviewed.',
            style: TextStyle(fontSize: 14, color: _muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Registration card ─────────────────────────────────────────────────────────
class _RegistrationCard extends ConsumerWidget {
  const _RegistrationCard({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          _CardHeader(user: user),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // ── Profile fields ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _Row(icon: Icons.mail_outline_rounded,
                    label: 'Email',    value: user.email),
                _Row(icon: Icons.phone_outlined,
                    label: 'Phone',    value: user.phone ?? '—'),
                _Row(icon: Icons.wc_rounded,
                    label: 'Gender',   value: _cap(user.gender ?? '—')),
                _Row(icon: Icons.cake_outlined,
                    label: 'Age',      value: user.age?.toString() ?? '—'),
                _Row(icon: Icons.credit_card_outlined,
                    label: 'Aadhar',   value: user.aadharNo ?? '—'),
                _Row(icon: Icons.article_outlined,
                    label: 'PAN',      value: user.panCard ?? '—'),
                _Row(icon: Icons.contact_emergency_outlined,
                    label: 'Emergency',
                    value: '${user.emergencyContactName ?? '—'} · ${user.emergencyContactPhone ?? '—'}'),
                _Row(icon: Icons.location_on_outlined,
                    label: 'Address',  value: user.address ?? '—'),
                if (user.createdAt != null)
                  _Row(icon: Icons.access_time_rounded,
                      label: 'Applied',
                      value: DateFormat('dd MMM yyyy, hh:mm a')
                          .format(user.createdAt!)),
              ],
            ),
          ),

          // ── Action buttons ───────────────────────────────────────────────
          _ActionRow(user: user),
        ],
      ),
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final roleLabel = user.role == 'field_advisor' ? 'Field Advisor' : 'Clerk';
    final roleColor = user.role == 'field_advisor'
        ? const Color(0xFF059669)
        : const Color(0xFF0284C7);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _label,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: roleColor,
                    ),
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

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String   label;
  final String   value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: _muted),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: _muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: _label,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action row ────────────────────────────────────────────────────────────────
class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          // Reject
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showRejectDialog(context, ref),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Decline'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _red,
                side: const BorderSide(color: _red, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Approve
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _approve(context, ref),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final adminUid = ref.read(currentUserProvider)?.uid ?? '';
    try {
      await ref.read(authRepositoryProvider).approveUser(user.uid, adminUid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.displayName} approved successfully.'),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AuthRepository.friendlyError(e)),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final confirmed  = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Decline ${user.displayName}?',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: _label,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Provide a reason (the applicant will see this):',
              style: TextStyle(fontSize: 13, color: _muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. Incomplete documents, not eligible...',
                hintStyle: const TextStyle(
                    fontSize: 13, color: Color(0xFFD1D5DB)),
                filled: true,
                fillColor: const Color(0xFFF7F8FA),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE4E6EC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _red, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: _muted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Decline',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final adminUid = ref.read(currentUserProvider)?.uid ?? '';
    try {
      await ref
          .read(authRepositoryProvider)
          .rejectUser(user.uid, adminUid, reasonCtrl.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.displayName} registration declined.'),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AuthRepository.friendlyError(e)),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      reasonCtrl.dispose();
    }
  }
}
