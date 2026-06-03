import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kiba_app/core/router/app_router.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';

// ─── Brand tokens ────────────────────────────────────────────────────────────
const _navy = Color(0xFF1E3A8A);
const _gold = Color(0xFFE8A020);
const _bg = Color(0xFFFFFFFF);
const _fieldBg = Color(0xFFF7F8FA);
const _border = Color(0xFFE4E6EC);
const _hint = Color(0xFF9CA3AF);
const _label = Color(0xFF1A1A2E);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authNotifierProvider.notifier).signIn(
      email: _emailCtrl.text,
      password: _passCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen and react to auth state changes
    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      if (next is AuthSuccess) {
        // Router guard handles role-based redirect automatically
        // Just go to root and let redirect() pick the correct dashboard
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 48),

                // ── KIBA Badge Logo ─────────────────────────────────────────
                CustomPaint(
                  size: const Size(110, 84),
                  painter: _KibaBadgePainter(),
                )
                    .animate()
                    .scale(duration: 600.ms, curve: Curves.elasticOut)
                    .fadeIn(),

                const SizedBox(height: 32),

                // ── Title ───────────────────────────────────────────────────
                const Text(
                  'Login',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: _label,
                    letterSpacing: -0.5,
                  ),
                ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.2),

                const SizedBox(height: 8),

                Text(
                  'Welcome back! Sign in to continue.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: _hint,
                    fontWeight: FontWeight.w400,
                  ),
                ).animate(delay: 200.ms).fadeIn(),

                const SizedBox(height: 36),

                // ── Email Field ─────────────────────────────────────────────
                _KibaField(
                  controller: _emailCtrl,
                  hint: 'Email',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your email';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.15),

                const SizedBox(height: 14),

                // ── Password Field ──────────────────────────────────────────
                _KibaField(
                  controller: _passCtrl,
                  hint: 'Password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _hint,
                      size: 20,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your password';
                    if (v.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.15),

                const SizedBox(height: 12),

                // ── Forgot Password ─────────────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => context.push(AppRoutes.forgotPassword),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _navy,
                        decoration: TextDecoration.underline,
                        decorationColor: _navy,
                      ),
                    ),
                  ),
                ).animate(delay: 350.ms).fadeIn(),

                const SizedBox(height: 28),

                // ── Login Button ────────────────────────────────────────────
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
                        borderRadius: BorderRadius.circular(32),
                      ),
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
                            'Login',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2),

                const SizedBox(height: 36),

                // ── Divider ─────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(child: Divider(color: _border, thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Kiba',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: _hint,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: _border, thickness: 1)),
                  ],
                ).animate(delay: 450.ms).fadeIn(),

                const SizedBox(height: 28),

                // ── Register link ───────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: _hint,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.register),
                      child: const Text(
                        'Register',
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
                ).animate(delay: 480.ms).fadeIn(),

                const SizedBox(height: 20),

                // ── Tagline ─────────────────────────────────────────────────
                Text(
                  'Behind the success of farmer',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: _hint,
                  ),
                ).animate(delay: 520.ms).fadeIn(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reusable field ────────────────────────────────────────────────────────────
class _KibaField extends StatelessWidget {
  const _KibaField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
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
          fontFamily: 'Inter',
          fontSize: 15,
          color: _hint,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: _fieldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(prefixIcon, size: 20, color: _hint),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix != null
            ? Padding(
                padding: const EdgeInsets.only(right: 14),
                child: suffix,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
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
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
      ),
    );
  }
}

// ── KIBA Badge (same painter as splash) ──────────────────────────────────────
class _KibaBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final outer = _path(w, h, 12);

    canvas.drawPath(outer, Paint()..color = _navy);
    canvas.drawPath(
      outer,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    const inset = 7.0;
    canvas.drawPath(
      _path(w - inset * 2, h - inset * 2, 8, dx: inset, dy: inset),
      Paint()
        ..color = _gold.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: 'KIBA',
        style: TextStyle(
          color: _gold,
          fontSize: 34,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  Path _path(double w, double h, double r, {double dx = 0, double dy = 0}) {
    final ind = w * 0.15;
    final p = Path();
    p.moveTo(dx + ind + r, dy);
    p.lineTo(dx + w - ind - r, dy);
    p.arcToPoint(Offset(dx + w - ind, dy + r), radius: Radius.circular(r));
    p.lineTo(dx + w, dy + h / 2 - r);
    p.arcToPoint(Offset(dx + w, dy + h / 2 + r), radius: Radius.circular(r));
    p.lineTo(dx + w - ind, dy + h - r);
    p.arcToPoint(Offset(dx + w - ind - r, dy + h), radius: Radius.circular(r));
    p.lineTo(dx + ind + r, dy + h);
    p.arcToPoint(Offset(dx + ind, dy + h - r), radius: Radius.circular(r));
    p.lineTo(dx, dy + h / 2 + r);
    p.arcToPoint(Offset(dx, dy + h / 2 - r), radius: Radius.circular(r));
    p.lineTo(dx + ind, dy + r);
    p.arcToPoint(Offset(dx + ind + r, dy), radius: Radius.circular(r));
    p.close();
    return p;
  }

  @override
  bool shouldRepaint(_KibaBadgePainter old) => false;
}
