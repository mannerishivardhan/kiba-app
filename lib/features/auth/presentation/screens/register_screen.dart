import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kiba_app/core/constants/app_constants.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';

// ── Brand tokens ──────────────────────────────────────────────────────────────
const _navy    = Color(0xFF1E3A8A);
const _gold    = Color(0xFFE8A020);
const _bg      = Color(0xFFFFFFFF);
const _fieldBg = Color(0xFFF7F8FA);
const _border  = Color(0xFFE4E6EC);
const _hint    = Color(0xFF9CA3AF);
const _label   = Color(0xFF1A1A2E);
const _section = Color(0xFF6B7280);

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────────────────────────────
  final _nameCtrl              = TextEditingController();
  final _emailCtrl             = TextEditingController();
  final _passwordCtrl          = TextEditingController();
  final _confirmPassCtrl       = TextEditingController();
  final _phoneCtrl             = TextEditingController();
  final _ageCtrl               = TextEditingController();
  final _aadharCtrl            = TextEditingController();
  final _panCtrl               = TextEditingController();
  final _emergencyNameCtrl     = TextEditingController();
  final _emergencyPhoneCtrl    = TextEditingController();
  final _addressCtrl           = TextEditingController();

  // ── Form state ────────────────────────────────────────────────────────────
  String  _role          = AppConstants.roleFieldAdvisor;
  String  _gender        = 'male';
  bool    _obscurePass   = true;
  bool    _obscureConf   = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _aadharCtrl.dispose();
    _panCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    await ref.read(authNotifierProvider.notifier).register(
          email:                 _emailCtrl.text,
          password:              _passwordCtrl.text,
          displayName:           _nameCtrl.text,
          role:                  _role,
          phone:                 _phoneCtrl.text,
          gender:                _gender,
          age:                   int.parse(_ageCtrl.text.trim()),
          aadharNo:              _aadharCtrl.text,
          panCard:               _panCtrl.text,
          emergencyContactName:  _emergencyNameCtrl.text,
          emergencyContactPhone: _emergencyPhoneCtrl.text,
          address:               _addressCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (_, next) {
      if (next is AuthSuccess) {
        // Router redirect takes over from here — routes to pending approval
        context.go('/');
      } else if (next is AuthError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(next.message),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
      }
    });

    final isLoading = ref.watch(authNotifierProvider) is AuthLoading;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _label,
        title: const Text(
          'Create Account',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: _label,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            children: [
              // ── Header ──────────────────────────────────────────────────
              const Text(
                'Register to join Kiba.\nYour account will be activated after admin approval.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: _hint,
                  height: 1.5,
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 28),

              // ════════════════════════════════════════════════════════════
              // Section 1 — Account
              // ════════════════════════════════════════════════════════════
              _SectionHeader(label: 'Account Details', delay: 50.ms),

              _KibaField(
                controller: _nameCtrl,
                hint: 'Full name',
                icon: Icons.person_outline_rounded,
                delay: 100.ms,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
              ),

              const SizedBox(height: 12),

              _KibaField(
                controller: _emailCtrl,
                hint: 'Email address',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                delay: 130.ms,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter your email';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              _KibaField(
                controller: _passwordCtrl,
                hint: 'Password',
                icon: Icons.lock_outline_rounded,
                obscure: _obscurePass,
                delay: 160.ms,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscurePass = !_obscurePass),
                  child: Icon(
                    _obscurePass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _hint,
                    size: 20,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a password';
                  if (v.length < 8) return 'Minimum 8 characters';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              _KibaField(
                controller: _confirmPassCtrl,
                hint: 'Confirm password',
                icon: Icons.lock_outline_rounded,
                obscure: _obscureConf,
                delay: 190.ms,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscureConf = !_obscureConf),
                  child: Icon(
                    _obscureConf
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _hint,
                    size: 20,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirm your password';
                  if (v != _passwordCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Role dropdown
              _DropdownField<String>(
                value: _role,
                hint: 'Select your role',
                icon: Icons.badge_outlined,
                delay: 210.ms,
                items: const [
                  DropdownMenuItem(
                    value: AppConstants.roleFieldAdvisor,
                    child: Text('Field Advisor'),
                  ),
                  DropdownMenuItem(
                    value: AppConstants.roleClerk,
                    child: Text('Clerk'),
                  ),
                ],
                onChanged: (v) => setState(() => _role = v!),
                validator: (v) => v == null ? 'Select your role' : null,
              ),

              const SizedBox(height: 28),

              // ════════════════════════════════════════════════════════════
              // Section 2 — Personal Info
              // ════════════════════════════════════════════════════════════
              _SectionHeader(label: 'Personal Information', delay: 230.ms),

              _KibaField(
                controller: _phoneCtrl,
                hint: 'Phone number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                delay: 260.ms,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter your phone number';
                  if (v.trim().length != 10) return 'Phone must be 10 digits';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Gender dropdown
              _DropdownField<String>(
                value: _gender,
                hint: 'Select gender',
                icon: Icons.wc_rounded,
                delay: 280.ms,
                items: const [
                  DropdownMenuItem(value: 'male',   child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other',  child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _gender = v!),
                validator: (v) => v == null ? 'Select your gender' : null,
              ),

              const SizedBox(height: 12),

              _KibaField(
                controller: _ageCtrl,
                hint: 'Age',
                icon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                delay: 300.ms,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter your age';
                  final age = int.tryParse(v.trim());
                  if (age == null || age < 18 || age > 65) {
                    return 'Age must be between 18 and 65';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 28),

              // ════════════════════════════════════════════════════════════
              // Section 3 — Identity Documents
              // ════════════════════════════════════════════════════════════
              _SectionHeader(label: 'Identity Documents', delay: 320.ms),

              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _gold.withValues(alpha: 0.4), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 16, color: _gold.withValues(alpha: 0.8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Document numbers are masked and stored securely. '
                        'Only the last 4 digits are visible.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: _gold.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 340.ms).fadeIn(),

              _KibaField(
                controller: _aadharCtrl,
                hint: 'Aadhar number (12 digits)',
                icon: Icons.credit_card_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                delay: 360.ms,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter your Aadhar number';
                  if (v.trim().length != 12) return 'Aadhar must be 12 digits';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              _KibaField(
                controller: _panCtrl,
                hint: 'PAN card (e.g. ABCDE1234F)',
                icon: Icons.article_outlined,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                  UpperCaseTextFormatter(),
                ],
                delay: 380.ms,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter your PAN card number';
                  if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$')
                      .hasMatch(v.trim().toUpperCase())) {
                    return 'Invalid PAN format (e.g. ABCDE1234F)';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 28),

              // ════════════════════════════════════════════════════════════
              // Section 4 — Emergency Contact
              // ════════════════════════════════════════════════════════════
              _SectionHeader(label: 'Emergency Contact', delay: 400.ms),

              _KibaField(
                controller: _emergencyNameCtrl,
                hint: 'Contact person name',
                icon: Icons.contact_emergency_outlined,
                delay: 420.ms,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter emergency contact name'
                    : null,
              ),

              const SizedBox(height: 12),

              _KibaField(
                controller: _emergencyPhoneCtrl,
                hint: 'Contact phone number',
                icon: Icons.phone_in_talk_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                delay: 440.ms,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter emergency contact phone';
                  }
                  if (v.trim().length != 10) return 'Phone must be 10 digits';
                  return null;
                },
              ),

              const SizedBox(height: 28),

              // ════════════════════════════════════════════════════════════
              // Section 5 — Address
              // ════════════════════════════════════════════════════════════
              _SectionHeader(label: 'Address', delay: 460.ms),

              TextFormField(
                controller: _addressCtrl,
                maxLines: 3,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: _label,
                ),
                decoration: InputDecoration(
                  hintText: 'Full address',
                  hintStyle: const TextStyle(
                      fontFamily: 'Inter', fontSize: 15, color: _hint),
                  filled: true,
                  fillColor: _fieldBg,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _border, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _navy, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFFEF4444), width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFFEF4444), width: 2),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your address'
                    : null,
              ).animate(delay: 480.ms).fadeIn().slideY(begin: 0.1),

              const SizedBox(height: 36),

              // ── Submit ───────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _navy.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Submit Registration',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.15),

              const SizedBox(height: 16),

              // ── Login link ───────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already registered? ',
                    style: TextStyle(
                        fontFamily: 'Inter', fontSize: 14, color: _hint),
                  ),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                        decoration: TextDecoration.underline,
                        decorationColor: _navy,
                      ),
                    ),
                  ),
                ],
              ).animate(delay: 520.ms).fadeIn(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.delay});
  final String   label;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _section,
          letterSpacing: 1.2,
        ),
      ).animate(delay: delay).fadeIn(),
    );
  }
}

// ── Reusable text field ───────────────────────────────────────────────────────
class _KibaField extends StatelessWidget {
  const _KibaField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.delay,
    this.obscure          = false,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  final TextEditingController          controller;
  final String                         hint;
  final IconData                       icon;
  final Duration                       delay;
  final bool                           obscure;
  final Widget?                        suffix;
  final TextInputType?                 keyboardType;
  final List<TextInputFormatter>?      inputFormatters;
  final TextCapitalization             textCapitalization;
  final String? Function(String?)?     validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:            controller,
      obscureText:           obscure,
      keyboardType:          keyboardType,
      inputFormatters:       inputFormatters,
      textCapitalization:    textCapitalization,
      validator:             validator,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        color: _label,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 15, color: _hint),
        filled: true,
        fillColor: _fieldBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, size: 20, color: _hint),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix != null
            ? Padding(
                padding: const EdgeInsets.only(right: 14),
                child: suffix,
              )
            : null,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _navy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
      ),
    ).animate(delay: delay).fadeIn().slideY(begin: 0.1);
  }
}

// ── Reusable dropdown field ───────────────────────────────────────────────────
class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
    required this.delay,
    this.validator,
  });

  final T?                              value;
  final String                          hint;
  final IconData                        icon;
  final List<DropdownMenuItem<T>>       items;
  final void Function(T?)               onChanged;
  final Duration                        delay;
  final String? Function(T?)?           validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        color: _label,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontFamily: 'Inter', fontSize: 15, color: _hint),
        filled: true,
        fillColor: _fieldBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, size: 20, color: _hint),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _navy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
      ),
    ).animate(delay: delay).fadeIn().slideY(begin: 0.1);
  }
}

// ── Formatter: force uppercase ────────────────────────────────────────────────
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    return next.copyWith(text: next.text.toUpperCase());
  }
}
