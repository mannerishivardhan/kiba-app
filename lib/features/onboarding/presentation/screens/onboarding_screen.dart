import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:kiba_app/core/constants/app_constants.dart';
import 'package:kiba_app/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Brand tokens ──────────────────────────────────────────────────────────────
const _navy  = Color(0xFF1E3A8A);
const _gold  = Color(0xFFE8A020);
const _white = Colors.white;

// ── Page data ─────────────────────────────────────────────────────────────────
class _PageData {
  const _PageData({
    required this.bg,
    required this.fg,
    required this.title,
    required this.subtitle,
    required this.illustrationBuilder,
  });
  final Color bg;
  final Color fg;
  final String title;
  final String subtitle;
  final WidgetBuilder illustrationBuilder;
}

final _pages = <_PageData>[
  _PageData(
    bg: _navy,
    fg: _white,
    title: 'Mark Attendance\nFrom the Field',
    subtitle: 'GPS-powered check-in wherever your work takes you — fast, accurate, effortless.',
    illustrationBuilder: (_) => const _AttendanceIllustration(),
  ),
  _PageData(
    bg: _gold,
    fg: _navy,
    title: 'Manage Daily\nTasks Easily',
    subtitle: 'Receive assignments, update progress, and report from anywhere in real-time.',
    illustrationBuilder: (_) => const _TaskIllustration(),
  ),
  _PageData(
    bg: _white,
    fg: _navy,
    title: 'Your Team,\nAlways In Sync',
    subtitle: 'Real-time visibility for managers and field advisors — one app, every role.',
    illustrationBuilder: (_) => const _TeamIllustration(),
  ),
];

// ── Main Screen ───────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _current = 0;

  void _next() {
    if (_current < _pages.length - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyOnboardingDone, true);
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_current];

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          page.bg == _white ? Brightness.dark : Brightness.light,
    ));

    return Scaffold(
      backgroundColor: page.bg,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        color: page.bg,
        child: SafeArea(
          child: Column(
            children: [
              // ── Illustration area (55%) ────────────────────────────────────
              Expanded(
                flex: 55,
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (context, i) => Stack(
                    alignment: Alignment.center,
                    children: [
                      // Decorative background circle
                      Positioned(
                        top: 40,
                        child: Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _pages[i].fg.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      // Floating decorative icons
                      ..._FloatingIcons.forPage(i, _pages[i].fg),
                      // Main illustration
                      _pages[i].illustrationBuilder(context),
                    ],
                  ),
                ),
              ),

              // ── Text + Nav (45%) ──────────────────────────────────────────
              Expanded(
                flex: 45,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        page.title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: page.fg,
                          height: 1.15,
                          letterSpacing: -0.5,
                        ),
                      ).animate(key: ValueKey(_current)).fadeIn(duration: 350.ms).slideY(begin: 0.15),

                      const SizedBox(height: 14),

                      // Subtitle
                      Text(
                        page.subtitle,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: page.fg.withValues(alpha: 0.65),
                          height: 1.6,
                        ),
                      ).animate(key: ValueKey('sub$_current')).fadeIn(delay: 100.ms, duration: 350.ms),

                      const Spacer(),

                      // Bottom nav row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Skip
                          TextButton(
                            onPressed: _finish,
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: page.fg.withValues(alpha: 0.5),
                              ),
                            ),
                          ),

                          // Dots
                          Row(
                            children: List.generate(_pages.length, (i) {
                              final active = i == _current;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: active ? 22 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: active
                                      ? page.fg
                                      : page.fg.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),

                          // Next / Get Started
                          GestureDetector(
                            onTap: _next,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: _current == _pages.length - 1 ? 140 : 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: page.fg,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: _current == _pages.length - 1
                                  ? Center(
                                      child: Text(
                                        'Get Started',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: page.bg,
                                        ),
                                      ),
                                    )
                                  : Icon(Icons.arrow_forward_rounded,
                                      color: page.bg, size: 24),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Floating Icons helper ─────────────────────────────────────────────────────
class _FloatingIcons {
  static List<Widget> forPage(int page, Color color) {
    final sets = [
      // Page 0 – attendance
      [
        _fi(Icons.location_on_rounded, 42, 60, color),
        _fi(Icons.access_time_rounded, 280, 80, color),
        _fi(Icons.calendar_today_rounded, 30, 200, color),
        _fi(Icons.eco_rounded, 290, 220, color),
      ],
      // Page 1 – tasks
      [
        _fi(Icons.star_rounded, 40, 60, color),
        _fi(Icons.check_circle_rounded, 285, 75, color),
        _fi(Icons.flag_rounded, 30, 210, color),
        _fi(Icons.emoji_events_rounded, 290, 200, color),
      ],
      // Page 2 – team
      [
        _fi(Icons.people_rounded, 38, 65, color),
        _fi(Icons.notifications_rounded, 282, 72, color),
        _fi(Icons.handshake_rounded, 28, 205, color),
        _fi(Icons.wifi_rounded, 288, 215, color),
      ],
    ];
    return sets[page];
  }

  static Widget _fi(IconData icon, double left, double top, Color color) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 22, color: color.withValues(alpha: 0.55)),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(
            begin: 0,
            end: -8,
            duration: Duration(milliseconds: 2000 + left.toInt() * 3),
            curve: Curves.easeInOut,
          ),
    );
  }
}

// ── Illustration 1 – Attendance ───────────────────────────────────────────────
class _AttendanceIllustration extends StatelessWidget {
  const _AttendanceIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ripple rings
          _ring(180, _gold, 0.15),
          _ring(140, _gold, 0.25),
          _ring(100, _gold, 0.4),
          // Phone card
          Container(
            width: 90,
            height: 115,
            decoration: BoxDecoration(
              color: _gold,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: _gold.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fingerprint, size: 36, color: _navy),
                const SizedBox(height: 6),
                Container(
                  width: 50, height: 6,
                  decoration: BoxDecoration(color: _navy.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 36, height: 6,
                  decoration: BoxDecoration(color: _navy.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3)),
                ),
              ],
            ),
          ),
          // Location pin on top
          Positioned(
            top: 8,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _navy,
                shape: BoxShape.circle,
                border: Border.all(color: _gold, width: 2.5),
              ),
              child: const Icon(Icons.location_on_rounded, size: 18, color: _gold),
            ),
          ),
        ],
      ),
    ).animate().scale(duration: 600.ms, curve: Curves.elasticOut);
  }

  Widget _ring(double size, Color c, double opacity) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.withValues(alpha: opacity), width: 1.5),
        ),
      );
}

// ── Illustration 2 – Tasks ────────────────────────────────────────────────────
class _TaskIllustration extends StatelessWidget {
  const _TaskIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 220,
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: _navy.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 12))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(width: 10, height: 10, decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('Today\'s Tasks', style: TextStyle(color: _gold, fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
          const SizedBox(height: 16),
          // Task items
          ...[
            ('Visit Farm A', true),
            ('Submit Report', true),
            ('Team Meeting', false),
            ('Soil Analysis', false),
          ].map((t) => _taskRow(t.$1, t.$2)),
        ],
      ),
    ).animate().scale(duration: 600.ms, curve: Curves.elasticOut);
  }

  Widget _taskRow(String label, bool done) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? _gold : Colors.transparent,
              border: Border.all(color: done ? _gold : _white.withValues(alpha: 0.3), width: 2),
            ),
            child: done ? const Icon(Icons.check_rounded, size: 12, color: _navy) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: done ? _white.withValues(alpha: 0.5) : _white,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: _white.withValues(alpha: 0.4),
              ),
            ),
          ),
        ]),
      );
}

// ── Illustration 3 – Team ─────────────────────────────────────────────────────
class _TeamIllustration extends StatelessWidget {
  const _TeamIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Connection lines
          CustomPaint(size: const Size(240, 220), painter: _LinePainter()),
          // Manager (center top)
          Positioned(top: 10, child: _avatar('Manager', _gold, _navy, 52, Icons.manage_accounts_rounded)),
          // FAs (bottom row)
          Positioned(bottom: 10, left: 10, child: _avatar('FA 1', _navy, _white, 46, Icons.person_rounded)),
          Positioned(bottom: 10, child: _avatar('FA 2', _navy, _white, 46, Icons.person_rounded)),
          Positioned(bottom: 10, right: 10, child: _avatar('FA 3', _navy, _white, 46, Icons.person_rounded)),
        ],
      ),
    ).animate().scale(duration: 600.ms, curve: Curves.elasticOut);
  }

  Widget _avatar(String label, Color bg, Color fg, double size, IconData icon) {
    return Column(
      children: [
        Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: _gold, width: 2.5),
            boxShadow: [BoxShadow(color: bg.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Icon(icon, color: fg, size: size * 0.45),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600, color: _navy)),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _navy.withValues(alpha: 0.15)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final cx = size.width / 2;
    // Manager to each FA
    canvas.drawLine(Offset(cx, 72), Offset(33, size.height - 66), paint);
    canvas.drawLine(Offset(cx, 72), Offset(cx, size.height - 66), paint);
    canvas.drawLine(Offset(cx, 72), Offset(size.width - 33, size.height - 66), paint);
  }
  @override
  bool shouldRepaint(_LinePainter old) => false;
}
