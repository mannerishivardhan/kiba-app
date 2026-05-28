import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kiba_app/core/router/app_router.dart';

// ── Brand colours (self-contained so splash has zero external deps) ──────────
const _navy = Color(0xFF1E3A8A);   // badge fill
const _gold = Color(0xFFE8A020);   // text + border
const _white = Colors.white;

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _rippleCtrl;
  late final AnimationController _logoCtrl;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: _white,
      ),
    );

    // Ripple loops forever
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Logo entry: scale + fade once
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) context.go(AppRoutes.onboarding);
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    _logoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Logo + Ripple stack ──────────────────────────────────────────
            SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Three staggered ripple rings
                  _RippleRing(
                    controller: _rippleCtrl,
                    delay: 0.0,
                    maxRadius: 130,
                    color: _navy,
                  ),
                  _RippleRing(
                    controller: _rippleCtrl,
                    delay: 0.33,
                    maxRadius: 130,
                    color: _gold,
                  ),
                  _RippleRing(
                    controller: _rippleCtrl,
                    delay: 0.66,
                    maxRadius: 130,
                    color: _navy,
                  ),

                  // KIBA badge logo
                  AnimatedBuilder(
                    animation: _logoCtrl,
                    builder: (context, child) {
                      final scale = CurvedAnimation(
                        parent: _logoCtrl,
                        curve: Curves.elasticOut,
                      ).value;
                      final opacity = CurvedAnimation(
                        parent: _logoCtrl,
                        curve: const Interval(0, 0.4),
                      ).value;
                      return Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: scale.clamp(0.0, 1.2),
                          child: child,
                        ),
                      );
                    },
                    child: CustomPaint(
                      size: const Size(170, 130),
                      painter: _KibaBadgePainter(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tagline
            const Text(
              'Behind the success of farmer',
              style: TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: Color(0xFF555555),
                letterSpacing: 0.2,
              ),
            )
                .animate(delay: 600.ms)
                .fadeIn(duration: 700.ms)
                .slideY(begin: 0.2, curve: Curves.easeOut),
          ],
        ),
      ),
    );
  }
}

// ── Ripple Ring Widget ────────────────────────────────────────────────────────
class _RippleRing extends StatelessWidget {
  const _RippleRing({
    required this.controller,
    required this.delay,
    required this.maxRadius,
    required this.color,
  });

  final AnimationController controller;
  final double delay;   // 0.0 – 1.0 fraction of one cycle
  final double maxRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Shift the phase by delay so rings are staggered
        double t = (controller.value + delay) % 1.0;
        // Use easeOut curve for natural expansion
        final curved = Curves.easeOut.transform(t);
        final radius = curved * maxRadius;
        final opacity = (1.0 - curved).clamp(0.0, 1.0) * 0.35;

        return CustomPaint(
          size: Size(maxRadius * 2, maxRadius * 2),
          painter: _RingPainter(
            radius: radius,
            color: color.withValues(alpha: opacity),
            strokeWidth: 2.5,
          ),
        );
      },
    );
  }
}

// ── Ring Painter ──────────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.radius,
    required this.color,
    required this.strokeWidth,
  });

  final double radius;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      radius,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.radius != radius || old.color != color;
}

// ── KIBA Badge Painter ────────────────────────────────────────────────────────
/// Draws the hexagonal/rounded-rect badge exactly matching the brand logo:
/// deep navy fill, golden rounded-hex outline, bold golden "KIBA" text.
class _KibaBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Outer path — hexagonal shield shape (wide top/bottom, angled sides)
    final outerPath = _buildBadgePath(w, h, cornerR: 18);

    // Navy fill
    canvas.drawPath(
      outerPath,
      Paint()..color = _navy,
    );

    // Golden border (thick)
    canvas.drawPath(
      outerPath,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5,
    );

    // Inner golden border (thinner, inset by ~10)
    final inset = 10.0;
    final innerPath = _buildBadgePath(
      w - inset * 2,
      h - inset * 2,
      cornerR: 12,
      offsetX: inset,
      offsetY: inset,
    );
    canvas.drawPath(
      innerPath,
      Paint()
        ..color = _gold.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // "KIBA" text
    final tp = TextPainter(
      text: const TextSpan(
        text: 'KIBA',
        style: TextStyle(
          color: _gold,
          fontSize: 54,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(cx - tp.width / 2, cy - tp.height / 2),
    );
  }

  /// Builds a hexagonal-rounded badge path.
  /// The shape has flat top/bottom with angled left/right sides.
  Path _buildBadgePath(
    double w,
    double h, {
    required double cornerR,
    double offsetX = 0,
    double offsetY = 0,
  }) {
    final x = offsetX;
    final y = offsetY;
    final indent = w * 0.15; // left/right diagonal indent

    final path = Path();
    // Top-left corner (after diagonal)
    path.moveTo(x + indent + cornerR, y);
    // Top edge
    path.lineTo(x + w - indent - cornerR, y);
    // Top-right arc
    path.arcToPoint(Offset(x + w - indent, y + cornerR),
        radius: Radius.circular(cornerR));
    // Right side diagonal (going down-right)
    path.lineTo(x + w, y + h / 2 - cornerR);
    // Middle-right arc
    path.arcToPoint(Offset(x + w, y + h / 2 + cornerR),
        radius: Radius.circular(cornerR));
    // Right side diagonal (going down-left)
    path.lineTo(x + w - indent, y + h - cornerR);
    // Bottom-right arc
    path.arcToPoint(Offset(x + w - indent - cornerR, y + h),
        radius: Radius.circular(cornerR));
    // Bottom edge
    path.lineTo(x + indent + cornerR, y + h);
    // Bottom-left arc
    path.arcToPoint(Offset(x + indent, y + h - cornerR),
        radius: Radius.circular(cornerR));
    // Left side diagonal (going up-right)
    path.lineTo(x, y + h / 2 + cornerR);
    // Middle-left arc
    path.arcToPoint(Offset(x, y + h / 2 - cornerR),
        radius: Radius.circular(cornerR));
    // Left side diagonal (going up-right)
    path.lineTo(x + indent, y + cornerR);
    // Top-left arc
    path.arcToPoint(Offset(x + indent + cornerR, y),
        radius: Radius.circular(cornerR));
    path.close();

    return path;
  }

  @override
  bool shouldRepaint(_KibaBadgePainter old) => false;
}
