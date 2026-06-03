import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────
class RoamingCharacter extends StatefulWidget {
  const RoamingCharacter({
    super.key,
    required this.gender,
    required this.shirtColor,
    required this.role,
    this.height = 160,
  });

  final String gender;     // 'male' | 'female'
  final Color  shirtColor;
  final String role;       // 'field_advisor' | 'clerk' | 'admin'
  final double height;

  @override
  State<RoamingCharacter> createState() => _RoamingCharacterState();
}

// ── Animation phases ──────────────────────────────────────────────────────────
enum _Phase { walkRight, jump, wave, walkLeft, bikeRide, computerWork }

class _RoamingCharacterState extends State<RoamingCharacter>
    with TickerProviderStateMixin {

  late final AnimationController _walkCtrl;
  late final AnimationController _moveCtrl;
  late final AnimationController _jumpCtrl;
  late final AnimationController _waveCtrl;
  late final AnimationController _breathCtrl;
  late final AnimationController _bikeCtrl;
  late final AnimationController _typeCtrl;

  _Phase _phase = _Phase.walkRight;

  bool get _isClerk => widget.role == 'clerk';

  @override
  void initState() {
    super.initState();

    _walkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520))
      ..repeat();

    _breathCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);

    _moveCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..addStatusListener(_onMoveStatus)
      ..forward();

    _jumpCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

    _waveCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 320));

    _bikeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4500));

    _typeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
  }

  // ── Phase transitions ─────────────────────────────────────────────────────
  void _onMoveStatus(AnimationStatus s) {
    if (!mounted) return;
    if (s == AnimationStatus.completed) {
      _startJump(() {
        setState(() => _phase = _Phase.walkLeft);
        _moveCtrl.reverse();
      });
    } else if (s == AnimationStatus.dismissed) {
      _startWave(() {
        if (_isClerk) {
          _startComputer();
        } else {
          _startBike();
        }
      });
    }
  }

  void _startJump(VoidCallback onDone) {
    setState(() => _phase = _Phase.jump);
    _walkCtrl.stop();
    _jumpCtrl.reset();
    _jumpCtrl.forward().then((_) {
      if (!mounted) return;
      _walkCtrl.repeat();
      onDone();
    });
  }

  void _startWave(VoidCallback onDone) {
    setState(() => _phase = _Phase.wave);
    _walkCtrl.stop();
    var count = 0;
    void doWave() {
      if (!mounted) return;
      _waveCtrl.reset();
      _waveCtrl.forward().then((_) {
        if (!mounted) return;
        _waveCtrl.reverse().then((_) {
          count++;
          if (count < 3) {
            doWave();
          } else {
            _walkCtrl.repeat();
            onDone();
          }
        });
      });
    }
    doWave();
  }

  void _startBike() {
    setState(() => _phase = _Phase.bikeRide);
    _walkCtrl.repeat(); // drives wheel spin
    _bikeCtrl.reset();
    _bikeCtrl.forward().then((_) {
      if (!mounted) return;
      setState(() => _phase = _Phase.walkRight);
      _moveCtrl.forward();
    });
  }

  void _startComputer() {
    setState(() => _phase = _Phase.computerWork);
    _walkCtrl.stop();
    _typeCtrl.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      _typeCtrl.stop();
      _typeCtrl.reset();
      _walkCtrl.repeat();
      setState(() => _phase = _Phase.walkRight);
      _moveCtrl.forward();
    });
  }

  @override
  void dispose() {
    _walkCtrl.dispose();
    _moveCtrl.dispose();
    _jumpCtrl.dispose();
    _waveCtrl.dispose();
    _breathCtrl.dispose();
    _bikeCtrl.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: Listenable.merge(
          [_walkCtrl, _moveCtrl, _jumpCtrl, _waveCtrl, _breathCtrl,
           _bikeCtrl, _typeCtrl]),
      builder: (_, _) {
        // ── Bike phase ──────────────────────────────────────────────────
        if (_phase == _Phase.bikeRide) {
          const bikeW   = 110.0;
          const bikeH   = 96.0;
          const padSide = 20.0;
          final bikeX =
              padSide + (screenW - bikeW - padSide * 2) * _bikeCtrl.value;
          final wheelSpin = _walkCtrl.value * 2 * math.pi;
          final bob = math.sin(_walkCtrl.value * 4 * math.pi).abs() * 1.5;

          return SizedBox(
            width: screenW,
            height: widget.height,
            child: Stack(
              children: [
                Positioned(
                  left: bikeX,
                  bottom: 14 - bob,
                  child: CustomPaint(
                    size: const Size(bikeW, bikeH),
                    painter: _BikeRiderPainter(
                      gender:      widget.gender,
                      shirtColor:  widget.shirtColor,
                      wheelAngle:  wheelSpin,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // ── Computer phase ───────────────────────────────────────────────
        if (_phase == _Phase.computerWork) {
          return SizedBox(
            width: screenW,
            height: widget.height,
            child: Center(
              child: CustomPaint(
                size: const Size(180, 140),
                painter: _ComputerScenePainter(
                  gender:     widget.gender,
                  shirtColor: widget.shirtColor,
                  typeT:      _typeCtrl.value,
                  walkT:      _walkCtrl.value,
                ),
              ),
            ),
          );
        }

        // ── Walk / jump / wave ───────────────────────────────────────────
        const charW   = 72.0;
        const charH   = 128.0;
        const padSide = 28.0;

        final x = padSide +
            (screenW - charW - padSide * 2) * _moveCtrl.value;

        final walkT     = _walkCtrl.value * 2 * math.pi;
        final isWalking = _phase == _Phase.walkRight || _phase == _Phase.walkLeft;

        final legAngle  = isWalking ? math.sin(walkT) * 0.45 : 0.0;
        final armAngle  = isWalking ? -math.sin(walkT) * 0.35 : 0.0;
        final bob       = isWalking ? math.sin(walkT * 2).abs() * 3.0 : 0.0;
        final breath    = _breathCtrl.value * 1.2;

        final jumpLift  = _phase == _Phase.jump
            ? math.sin(_jumpCtrl.value * math.pi) * 26.0 : 0.0;
        final legTuck   = _phase == _Phase.jump
            ? math.sin(_jumpCtrl.value * math.pi) * 0.6 : 0.0;
        final squash    = _phase == _Phase.jump
            ? 1.0 - math.sin(_jumpCtrl.value * math.pi) * 0.06 : 1.0;

        final waveArm   = _phase == _Phase.wave
            ? -0.25 - _waveCtrl.value * 1.3 : armAngle;

        final facingLeft = _phase == _Phase.walkLeft;

        return SizedBox(
          width: screenW,
          height: widget.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: x,
                bottom: 10 - bob + jumpLift,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(
                      facingLeft ? -1.0 : 1.0, squash, 1.0),
                  child: CustomPaint(
                    size: const Size(charW, charH),
                    painter: _CharacterPainter(
                      gender:        widget.gender,
                      shirtColor:    widget.shirtColor,
                      legAngle:      legAngle,
                      leftArmAngle:  armAngle,
                      rightArmAngle: waveArm,
                      legTuck:       legTuck,
                      breath:        breath,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bike + Rider Painter
// ─────────────────────────────────────────────────────────────────────────────
class _BikeRiderPainter extends CustomPainter {
  const _BikeRiderPainter({
    required this.gender,
    required this.shirtColor,
    required this.wheelAngle,
  });

  final String gender;
  final Color  shirtColor;
  final double wheelAngle;

  static const _skin    = Color(0xFFF5C49A);
  static const _dark    = Color(0xFF1E2A3A);
  static const _helmet  = Color(0xFFFFD700);
  static const _chrome  = Color(0xFFB0B8C1);
  static const _rubber  = Color(0xFF1A1A2E);
  static const _exhaust = Color(0xFF6B7280);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  * 0.48;
    final wy = size.height * 0.76; // wheel axle y
    const wr = 22.0;               // wheel radius

    // ── Ground shadow ────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, wy + wr + 3), width: 90, height: 10),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    // ── Exhaust pipe ─────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 44, wy - 8, 20, 5), const Radius.circular(2.5)),
      Paint()..color = _exhaust,
    );
    canvas.drawCircle(Offset(cx - 44, wy - 5.5), 3.5,
        Paint()..color = _exhaust.withValues(alpha: 0.6));

    // ── Rear wheel ───────────────────────────────────────────────────────
    _drawWheel(canvas, Offset(cx - 26, wy), wr);
    // ── Front wheel ──────────────────────────────────────────────────────
    _drawWheel(canvas, Offset(cx + 28, wy), wr);

    // ── Chain ────────────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 8, wy), width: 18, height: 10),
      Paint()
        ..color     = _chrome.withValues(alpha: 0.5)
        ..style     = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // ── Bike frame ───────────────────────────────────────────────────────
    final framePaint = Paint()
      ..color      = shirtColor
      ..strokeWidth = 4.5
      ..style      = PaintingStyle.stroke
      ..strokeCap  = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Main diamond frame
    final frame = Path()
      ..moveTo(cx - 26, wy)        // rear axle
      ..lineTo(cx - 10, wy - 18)   // seat tube top
      ..lineTo(cx + 10, wy - 16)   // top tube front
      ..lineTo(cx + 28, wy)        // front axle
      ..moveTo(cx - 10, wy - 18)   // seat tube top
      ..lineTo(cx + 4,  wy)        // bottom bracket
      ..lineTo(cx - 26, wy)        // chain stay to rear
      ..moveTo(cx + 4,  wy)        // bottom bracket
      ..lineTo(cx + 28, wy);       // down tube to front axle
    canvas.drawPath(frame, framePaint);

    // Seat stay
    canvas.drawLine(Offset(cx - 10, wy - 18), Offset(cx - 26, wy),
        framePaint..strokeWidth = 3);

    // Fork
    canvas.drawLine(Offset(cx + 10, wy - 16), Offset(cx + 28, wy),
        framePaint..strokeWidth = 3.5);

    // ── Handlebar ────────────────────────────────────────────────────────
    canvas.drawLine(
      Offset(cx + 10, wy - 16), Offset(cx + 14, wy - 24),
      Paint()
        ..color      = _dark
        ..strokeWidth = 3
        ..strokeCap  = StrokeCap.round,
    );
    // Bar ends
    canvas.drawLine(
      Offset(cx + 10, wy - 24), Offset(cx + 18, wy - 24),
      Paint()
        ..color      = _dark
        ..strokeWidth = 3.5
        ..strokeCap  = StrokeCap.round,
    );

    // ── Saddle ───────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 11, wy - 20), width: 18, height: 5),
        const Radius.circular(2.5),
      ),
      Paint()..color = _dark,
    );

    // ── Rider body (seated, leaning forward) ─────────────────────────────
    // Torso — leaning ~30° forward
    final torsoPath = Path()
      ..moveTo(cx - 11, wy - 20)   // hip (saddle)
      ..lineTo(cx + 5,  wy - 36);  // shoulder
    canvas.drawPath(
      torsoPath,
      Paint()
        ..color      = shirtColor
        ..strokeWidth = 11
        ..strokeCap  = StrokeCap.round,
    );
    // Shirt highlight
    canvas.drawPath(
      torsoPath,
      Paint()
        ..color      = Colors.white.withValues(alpha: 0.15)
        ..strokeWidth = 5
        ..strokeCap  = StrokeCap.round,
    );

    // Arms reaching to handlebar
    canvas.drawLine(
      Offset(cx + 5,  wy - 34),
      Offset(cx + 13, wy - 24),
      Paint()
        ..color      = _skin
        ..strokeWidth = 6
        ..strokeCap  = StrokeCap.round,
    );

    // Legs (bent at pedals)
    // Left leg
    canvas.drawLine(
      Offset(cx - 10, wy - 18),
      Offset(cx - 2,  wy - 4),
      Paint()
        ..color      = _dark
        ..strokeWidth = 7
        ..strokeCap  = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(cx - 2, wy - 4),
      Offset(cx + 4, wy),
      Paint()
        ..color      = _dark
        ..strokeWidth = 6
        ..strokeCap  = StrokeCap.round,
    );

    // Right leg
    canvas.drawLine(
      Offset(cx - 8, wy - 16),
      Offset(cx - 14, wy - 4),
      Paint()
        ..color      = _dark.withValues(alpha: 0.7)
        ..strokeWidth = 7
        ..strokeCap  = StrokeCap.round,
    );

    // ── Head with helmet ─────────────────────────────────────────────────
    // Neck
    canvas.drawLine(
      Offset(cx + 5, wy - 36),
      Offset(cx + 6, wy - 40),
      Paint()..color = _skin..strokeWidth = 5..strokeCap = StrokeCap.round,
    );

    // Helmet
    final helmetCenter = Offset(cx + 5, wy - 47);
    canvas.drawCircle(helmetCenter, 10, Paint()..color = _helmet);
    // Helmet brim
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 5, wy - 38), width: 22, height: 6),
      Paint()..color = _helmet,
    );
    // Visor
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 7, wy - 43), width: 14, height: 5),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    // Helmet shine
    canvas.drawCircle(
      Offset(cx + 2, wy - 51), 3,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    // Chin strap
    canvas.drawArc(
      Rect.fromCenter(center: helmetCenter, width: 16, height: 14),
      0, math.pi,
      false,
      Paint()
        ..color      = _dark
        ..strokeWidth = 1.5
        ..style      = PaintingStyle.stroke,
    );
  }

  // ── Spinning wheel ────────────────────────────────────────────────────────
  void _drawWheel(Canvas canvas, Offset center, double r) {
    // Tyre
    canvas.drawCircle(center, r,
        Paint()..color = _rubber..strokeWidth = 5..style = PaintingStyle.stroke);
    // Inner rim
    canvas.drawCircle(center, r - 4,
        Paint()..color = _chrome.withValues(alpha: 0.6)..strokeWidth = 1.5..style = PaintingStyle.stroke);
    // Hub
    canvas.drawCircle(center, 3.5, Paint()..color = _chrome);
    // Spokes (5 spokes, rotating)
    for (var i = 0; i < 5; i++) {
      final angle = wheelAngle + i * (2 * math.pi / 5);
      final spokeEnd = Offset(
        center.dx + (r - 5) * math.cos(angle),
        center.dy + (r - 5) * math.sin(angle),
      );
      canvas.drawLine(
        center, spokeEnd,
        Paint()
          ..color      = _chrome.withValues(alpha: 0.7)
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(_BikeRiderPainter old) =>
      old.wheelAngle != wheelAngle ||
      old.gender != gender ||
      old.shirtColor != shirtColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Computer Scene Painter  (clerk only)
// ─────────────────────────────────────────────────────────────────────────────
class _ComputerScenePainter extends CustomPainter {
  const _ComputerScenePainter({
    required this.gender,
    required this.shirtColor,
    required this.typeT,
    required this.walkT,
  });

  final String gender;
  final Color  shirtColor;
  final double typeT;   // 0→1 oscillating (typing rhythm)
  final double walkT;   // 0→1 walk cycle (screen flicker / cursor)

  static const _skin      = Color(0xFFF5C49A);
  static const _hair      = Color(0xFF1A0F00);
  static const _desk      = Color(0xFF8B6343);
  static const _deskDark  = Color(0xFF6B4C32);
  static const _monitor   = Color(0xFF1E2A3A);
  static const _screen    = Color(0xFF0D1F3C);
  static const _chair     = Color(0xFF374151);
  static const _pants     = Color(0xFF1E2A3A);
  static const _keyboard  = Color(0xFFD1D5DB);

  @override
  void paint(Canvas canvas, Size size) {
    // Character sits left-center, monitor right-center
    const charX  = 52.0;   // character center x
    const monX   = 128.0;  // monitor center x
    const deskY  = 105.0;  // desk top surface y
    const chairY = 90.0;   // seat y

    // ── Desk ────────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, deskY, size.width - 28, 14),
        const Radius.circular(4),
      ),
      Paint()..color = _desk,
    );
    // Desk front face
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, deskY + 8, size.width - 28, 10),
        const Radius.circular(3),
      ),
      Paint()..color = _deskDark,
    );
    // Desk legs
    for (final legX in [30.0, size.width - 38]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(legX, deskY + 14, 7, 20),
          const Radius.circular(2),
        ),
        Paint()..color = _deskDark,
      );
    }

    // ── Keyboard on desk ─────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(charX + 28, deskY - 2), width: 46, height: 8),
        const Radius.circular(3),
      ),
      Paint()..color = _keyboard,
    );
    // Key rows
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 6; col++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              charX + 7 + col * 6.5, deskY - 6 + row * 3.5, 5, 2.5),
            const Radius.circular(0.8),
          ),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.5 + typeT * 0.3),
        );
      }
    }

    // ── Monitor ───────────────────────────────────────────────────────────
    // Stand
    canvas.drawRect(
      Rect.fromCenter(center: Offset(monX, deskY - 2), width: 6, height: 18),
      Paint()..color = _monitor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(monX, deskY + 5), width: 28, height: 6),
        const Radius.circular(3),
      ),
      Paint()..color = _monitor,
    );

    // Monitor bezel
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(monX, deskY - 36), width: 72, height: 52),
        const Radius.circular(5),
      ),
      Paint()..color = _monitor,
    );

    // Screen
    final screenRect = Rect.fromCenter(
        center: Offset(monX, deskY - 36), width: 64, height: 44);
    canvas.drawRect(screenRect, Paint()..color = _screen);

    // Screen content — colored code lines with cursor blink
    final lineColors = [
      const Color(0xFF34D399),
      const Color(0xFF60A5FA),
      const Color(0xFFFBBF24),
      const Color(0xFFE879F9),
      const Color(0xFFFF6B6B),
    ];
    for (var i = 0; i < 5; i++) {
      final lineW = (20 + (i % 3) * 12).toDouble();
      final lineY = screenRect.top + 6 + i * 7.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(screenRect.left + 4, lineY, lineW, 3.5),
          const Radius.circular(1.5),
        ),
        Paint()..color = lineColors[i].withValues(alpha: 0.85),
      );
      // Indent level
      if (i > 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(screenRect.left + 4 + 8, lineY, lineW - 8, 3.5),
            const Radius.circular(1.5),
          ),
          Paint()..color = lineColors[i].withValues(alpha: 0.4),
        );
      }
    }
    // Blinking cursor
    if ((walkT * 3).floor() % 2 == 0) {
      canvas.drawRect(
        Rect.fromLTWH(screenRect.left + 4, screenRect.top + 6 + 5 * 7.5, 2, 6),
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }

    // Screen glare
    canvas.drawOval(
      Rect.fromCenter(center: Offset(monX - 16, deskY - 46), width: 14, height: 8),
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );

    // ── Chair ─────────────────────────────────────────────────────────────
    // Seat
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(charX, chairY), width: 34, height: 9),
        const Radius.circular(4),
      ),
      Paint()..color = _chair,
    );
    // Backrest
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(charX - 4, chairY - 28, 8, 28),
        const Radius.circular(4),
      ),
      Paint()..color = _chair,
    );
    // Chair legs
    for (final lx in [-12.0, 12.0]) {
      canvas.drawLine(
        Offset(charX + lx, chairY + 4),
        Offset(charX + lx * 1.3, deskY + 14),
        Paint()..color = _chair..strokeWidth = 3..strokeCap = StrokeCap.round,
      );
    }

    // ── Character seated ──────────────────────────────────────────────────
    // Legs (at 90° — thigh horizontal, shin vertical)
    canvas.drawLine(
      Offset(charX - 7, chairY),
      Offset(charX - 7 - 10, chairY + 2),
      Paint()..color = _pants..strokeWidth = 9..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(charX - 7 - 10, chairY + 2),
      Offset(charX - 7 - 10, deskY + 4),
      Paint()..color = _pants..strokeWidth = 8..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(charX + 7, chairY),
      Offset(charX + 7 + 4, chairY + 2),
      Paint()..color = _pants..strokeWidth = 9..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(charX + 7 + 4, chairY + 2),
      Offset(charX + 7 + 4, deskY + 4),
      Paint()..color = _pants..strokeWidth = 8..strokeCap = StrokeCap.round,
    );

    // Torso (upright)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(charX, chairY - 18), width: 20, height: 26),
        const Radius.circular(5),
      ),
      Paint()..color = shirtColor,
    );
    // Shirt highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(charX - 9, chairY - 30, 6, 24),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );

    // Arms reaching forward to keyboard (typeT drives up/down)
    final armDrop = typeT * 3.0;
    // Left arm
    canvas.drawLine(
      Offset(charX - 10, chairY - 22),
      Offset(charX + 8, deskY - 5 + armDrop),
      Paint()..color = shirtColor..strokeWidth = 6..strokeCap = StrokeCap.round,
    );
    // Forearm skin
    canvas.drawLine(
      Offset(charX + 3, chairY - 10 + armDrop * 0.5),
      Offset(charX + 8, deskY - 5 + armDrop),
      Paint()..color = _skin..strokeWidth = 5..strokeCap = StrokeCap.round,
    );
    // Right arm
    canvas.drawLine(
      Offset(charX + 10, chairY - 22),
      Offset(charX + 20, deskY - 5 - armDrop),
      Paint()..color = shirtColor..strokeWidth = 6..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(charX + 16, chairY - 10 - armDrop * 0.5),
      Offset(charX + 20, deskY - 5 - armDrop),
      Paint()..color = _skin..strokeWidth = 5..strokeCap = StrokeCap.round,
    );

    // Neck
    canvas.drawRect(
      Rect.fromCenter(center: Offset(charX, chairY - 33), width: 7, height: 7),
      Paint()..color = _skin,
    );

    // Head — looking toward monitor (slight tilt right)
    _drawHead(canvas, Offset(charX + 3, chairY - 45));
  }

  void _drawHead(Canvas canvas, Offset center) {
    // Face
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 24, height: 26),
      Paint()..color = _skin,
    );
    // Eyes — looking right (toward monitor)
    for (final ex in [-4.0, 3.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx + ex, center.dy - 1), width: 5.5, height: 4),
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(center.dx + ex + 1.5, center.dy - 1), 1.6,
        Paint()..color = const Color(0xFF3D2B1F),
      );
      canvas.drawCircle(
        Offset(center.dx + ex + 2, center.dy - 1.5), 0.6,
        Paint()..color = Colors.white,
      );
    }
    // Slight smile (concentrating)
    final smile = Path()
      ..moveTo(center.dx - 3, center.dy + 6)
      ..quadraticBezierTo(center.dx + 1, center.dy + 8.5, center.dx + 5, center.dy + 6);
    canvas.drawPath(
      smile,
      Paint()
        ..color      = const Color(0xFFCC6655)
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap  = StrokeCap.round,
    );
    // Hair
    canvas.drawArc(
      Rect.fromCircle(center: Offset(center.dx, center.dy - 2), radius: 13),
      -math.pi * 1.08, math.pi * 1.16, false,
      Paint()..color = _hair..style = PaintingStyle.fill,
    );
    // Glasses (clerk detail)
    final glassesPaint = Paint()
      ..color      = const Color(0xFF374151)
      ..strokeWidth = 1.5
      ..style      = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx - 4, center.dy - 1), width: 9, height: 7),
        const Radius.circular(2),
      ),
      glassesPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx + 4, center.dy - 1), width: 9, height: 7),
        const Radius.circular(2),
      ),
      glassesPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 0.5, center.dy - 1),
      Offset(center.dx + 0.5, center.dy - 1),
      glassesPaint,
    );
    // Temple arms
    canvas.drawLine(
      Offset(center.dx - 9, center.dy - 1),
      Offset(center.dx - 13, center.dy - 1),
      glassesPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 9, center.dy - 1),
      Offset(center.dx + 13, center.dy - 1),
      glassesPaint,
    );
  }

  @override
  bool shouldRepaint(_ComputerScenePainter old) =>
      old.typeT != typeT ||
      old.walkT != walkT ||
      old.gender != gender ||
      old.shirtColor != shirtColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Walking character painter (unchanged from previous)
// ─────────────────────────────────────────────────────────────────────────────
class _CharacterPainter extends CustomPainter {
  _CharacterPainter({
    required this.gender,
    required this.shirtColor,
    required this.legAngle,
    required this.leftArmAngle,
    required this.rightArmAngle,
    required this.legTuck,
    required this.breath,
  });

  final String gender;
  final Color  shirtColor;
  final double legAngle;
  final double leftArmAngle;
  final double rightArmAngle;
  final double legTuck;
  final double breath;

  bool get isFemale => gender == 'female';

  static const _skin       = Color(0xFFF5C49A);
  static const _skinShadow = Color(0xFFE0A070);
  static const _skinBlush  = Color(0xFFFFB6C1);
  static const _hairMale   = Color(0xFF1A0F00);
  static const _hairFemale = Color(0xFF3D1A00);
  static const _hairBand   = Color(0xFFFFD700);
  static const _pants      = Color(0xFF1E2A3A);
  static const _shoeMain   = Color(0xFFF5F5F5);
  static const _shoeSole   = Color(0xFF888888);
  static const _belt       = Color(0xFF5C3D1E);
  static const _eyeWhite   = Colors.white;
  static const _eyeIris    = Color(0xFF3D2B1F);
  static const _eyePupil   = Color(0xFF0D0705);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    _drawShadow(canvas, cx, size.height - 4);
    if (isFemale) {
      _drawHairBack(canvas, cx);
    }
    _drawHead(canvas, cx);
    if (isFemale) {
      _drawHairFront(canvas, cx);
    } else {
      _drawMaleHair(canvas, cx);
    }
    _drawNeck(canvas, cx);
    _drawArm(canvas, cx, isLeft: true,  angle: leftArmAngle);
    _drawTorso(canvas, cx);
    _drawArm(canvas, cx, isLeft: false, angle: rightArmAngle);
    if (isFemale) {
      _drawFrock(canvas, cx);
    } else {
      _drawPants(canvas, cx);
    }
  }

  void _drawShadow(Canvas canvas, double cx, double y) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, y), width: 34, height: 7),
      Paint()..color = Colors.black.withValues(alpha: 0.14),
    );
  }

  void _drawHead(Canvas canvas, double cx) {
    const headCy = 20.0;
    const rx = 13.0, ry = 14.0;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, headCy), width: rx * 2, height: ry * 2),
      Paint()..color = _skin,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, headCy + 6), width: 18, height: 14),
      Paint()..color = _skinShadow.withValues(alpha: 0.18),
    );
    _drawEar(canvas, cx - rx + 1, headCy);
    _drawEar(canvas, cx + rx - 1, headCy);
    _drawEye(canvas, cx - 4.8, headCy - 2);
    _drawEye(canvas, cx + 4.8, headCy - 2);
    _drawBrow(canvas, cx - 4.8, headCy - 7.5, isLeft: true);
    _drawBrow(canvas, cx + 4.8, headCy - 7.5, isLeft: false);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, headCy + 4), width: 3, height: 2.5),
      Paint()..color = _skinShadow.withValues(alpha: 0.45),
    );
    final smilePath = Path()
      ..moveTo(cx - 4, headCy + 9)
      ..quadraticBezierTo(cx, headCy + 13.5, cx + 4, headCy + 9);
    canvas.drawPath(smilePath,
        Paint()
          ..color = const Color(0xFFCC6655)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, headCy + 10.5), width: 5, height: 2),
        const Radius.circular(1)),
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
    canvas.drawCircle(Offset(cx - 9, headCy + 5), 4,
        Paint()..color = _skinBlush.withValues(alpha: 0.35));
    canvas.drawCircle(Offset(cx + 9, headCy + 5), 4,
        Paint()..color = _skinBlush.withValues(alpha: 0.35));
  }

  void _drawEar(Canvas canvas, double x, double y) {
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 5, height: 7),
        Paint()..color = _skin);
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 2.5, height: 4),
        Paint()..color = _skinShadow.withValues(alpha: 0.3));
  }

  void _drawEye(Canvas canvas, double cx, double cy) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 6.5, height: 5),
      Paint()..color = _eyeWhite,
    );
    canvas.drawCircle(Offset(cx, cy), 2.2, Paint()..color = _eyeIris);
    canvas.drawCircle(Offset(cx, cy), 1.1, Paint()..color = _eyePupil);
    canvas.drawCircle(Offset(cx + 0.9, cy - 0.9), 0.7, Paint()..color = Colors.white);
    final lashPath = Path()
      ..moveTo(cx - 3.2, cy - 2.5)
      ..quadraticBezierTo(cx, cy - 4.5, cx + 3.2, cy - 2.5);
    canvas.drawPath(lashPath,
        Paint()
          ..color = const Color(0xFF1A0F00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round);
  }

  void _drawBrow(Canvas canvas, double cx, double cy, {required bool isLeft}) {
    final fromX = cx - 3.5;
    final toX   = cx + 3.5;
    final midY  = cy - 1.0;
    final path = Path()
      ..moveTo(fromX, cy)
      ..quadraticBezierTo((fromX + toX) / 2, midY, toX, cy);
    canvas.drawPath(path,
        Paint()
          ..color = isFemale ? _hairFemale : _hairMale
          ..style = PaintingStyle.stroke
          ..strokeWidth = isFemale ? 1.3 : 1.7
          ..strokeCap = StrokeCap.round);
  }

  void _drawMaleHair(Canvas canvas, double cx) {
    final p = Paint()..color = _hairMale;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, 20), radius: 13.5),
      -math.pi * 1.08, math.pi * 1.16, false,
      p..style = PaintingStyle.fill,
    );
    final quiff = Path()
      ..moveTo(cx - 4, 8)
      ..cubicTo(cx - 2, 3, cx + 5, 3, cx + 7, 8)
      ..cubicTo(cx + 5, 6, cx + 1, 7, cx - 1, 9);
    canvas.drawPath(quiff, p..style = PaintingStyle.fill);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 13, 22, 3.5, 7), const Radius.circular(2)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 9.5, 22, 3.5, 7), const Radius.circular(2)), p);
  }

  void _drawHairBack(Canvas canvas, double cx) {
    final p = Paint()..color = _hairFemale;
    final left = Path()
      ..moveTo(cx - 11, 9)
      ..cubicTo(cx - 20, 22, cx - 22, 44, cx - 18, 62)
      ..lineTo(cx - 13, 60)
      ..cubicTo(cx - 17, 42, cx - 16, 22, cx - 8, 11)
      ..close();
    canvas.drawPath(left, p);
    final right = Path()
      ..moveTo(cx + 11, 9)
      ..cubicTo(cx + 20, 22, cx + 22, 44, cx + 18, 62)
      ..lineTo(cx + 13, 60)
      ..cubicTo(cx + 17, 42, cx + 16, 22, cx + 8, 11)
      ..close();
    canvas.drawPath(right, p);
  }

  void _drawHairFront(Canvas canvas, double cx) {
    final p = Paint()..color = _hairFemale;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, 20), radius: 14),
        -math.pi * 1.12, math.pi * 1.24, false, p..style = PaintingStyle.fill);
    final fringe = Path()
      ..moveTo(cx - 12, 12)
      ..cubicTo(cx - 5, 5, cx + 2, 7, cx + 5, 11)
      ..cubicTo(cx + 9, 7, cx + 13, 10, cx + 13, 14);
    canvas.drawPath(fringe, p..style = PaintingStyle.fill);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, 10), width: 14, height: 3.5),
        Paint()..color = _hairBand);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, 9), width: 12, height: 1),
        Paint()..color = Colors.white.withValues(alpha: 0.4));
  }

  void _drawNeck(Canvas canvas, double cx) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 4, 33, 8, 8), const Radius.circular(3)),
      Paint()..color = _skin,
    );
    canvas.drawRect(Rect.fromLTWH(cx + 0.5, 33, 3, 8),
        Paint()..color = _skinShadow.withValues(alpha: 0.22));
  }

  void _drawTorso(Canvas canvas, double cx) {
    final torsoRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 11, 40 - breath * 0.3, 22, 24 + breath * 0.3),
      const Radius.circular(5),
    );
    canvas.drawRRect(torsoRect, Paint()..color = shirtColor);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 10, 41, 6, 22), const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: 0.13),
    );
    final collarL = Path()
      ..moveTo(cx - 5, 40)..lineTo(cx - 2, 45)..lineTo(cx, 44)..lineTo(cx - 3, 40);
    canvas.drawPath(collarL, Paint()..color = Colors.white.withValues(alpha: 0.85));
    final collarR = Path()
      ..moveTo(cx + 5, 40)..lineTo(cx + 2, 45)..lineTo(cx, 44)..lineTo(cx + 3, 40);
    canvas.drawPath(collarR, Paint()..color = Colors.white.withValues(alpha: 0.85));
  }

  void _drawArm(Canvas canvas, double cx,
      {required bool isLeft, required double angle}) {
    const shoulderY = 43.0;
    const upperLen  = 16.0;
    const lowerLen  = 14.0;
    final sx   = isLeft ? cx - 11 : cx + 11;
    final sign = isLeft ? 1.0 : -1.0;
    final baseAngle  = math.pi / 2 + sign * 0.1;
    final totalAngle = baseAngle + (isLeft ? angle : -angle);
    final elbowX = sx + upperLen * math.cos(totalAngle - math.pi / 2);
    final elbowY = shoulderY + upperLen * math.sin(totalAngle - math.pi / 2);
    final handX  = elbowX + lowerLen * math.cos(totalAngle * 0.6 - math.pi / 2);
    final handY  = elbowY + lowerLen * math.sin(totalAngle * 0.6 - math.pi / 2);
    canvas.drawLine(Offset(sx, shoulderY), Offset(elbowX, elbowY),
        Paint()..color = shirtColor..strokeWidth = 7..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(elbowX, elbowY), Offset(handX, handY),
        Paint()..color = _skin..strokeWidth = 5.5..strokeCap = StrokeCap.round);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(handX, handY), width: 7, height: 6),
        Paint()..color = _skin);
  }

  void _drawPants(Canvas canvas, double cx) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 11, 63, 22, 5), const Radius.circular(2)),
      Paint()..color = _belt,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, 65.5), width: 7, height: 4),
          const Radius.circular(1)),
      Paint()..color = const Color(0xFFD4A017),
    );
    canvas.drawRect(Rect.fromLTWH(cx - 7, 67, 14, 5), Paint()..color = _pants);
    for (final left in [true, false]) {
      _drawLeg(canvas, cx, isLeft: left);
    }
  }

  void _drawLeg(Canvas canvas, double cx, {required bool isLeft}) {
    const hipY = 67.0, thighL = 26.0, shinL = 22.0;
    final sign  = isLeft ? -1 : 1;
    final hipX  = cx + sign * 5.5;
    final angle = (isLeft ? legAngle : -legAngle) + legTuck * sign * 0.45;
    final kneeX = hipX + math.sin(angle) * thighL;
    final kneeY = hipY + math.cos(angle.abs()) * thighL;
    final shinAngle = angle * 0.5;
    final ankleX = kneeX + math.sin(shinAngle) * shinL;
    final ankleY = kneeY + math.cos(shinAngle.abs()) * shinL;
    canvas.drawLine(Offset(hipX, hipY), Offset(kneeX, kneeY),
        Paint()..color = _pants..strokeWidth = 10..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(kneeX, kneeY), 5.5, Paint()..color = _pants);
    canvas.drawLine(Offset(kneeX, kneeY), Offset(ankleX, ankleY),
        Paint()..color = _pants..strokeWidth = 8.5..strokeCap = StrokeCap.round);
    _drawSneaker(canvas, ankleX, ankleY, sign: sign.toDouble());
  }

  void _drawSneaker(Canvas canvas, double ax, double ay, {required double sign}) {
    final shoePath = Path()
      ..moveTo(ax - 4, ay)
      ..cubicTo(ax - 5, ay + 4, ax + sign * 2, ay + 8, ax + sign * 10, ay + 6)
      ..cubicTo(ax + sign * 12, ay + 5, ax + sign * 11, ay + 2, ax + sign * 8, ay)
      ..close();
    canvas.drawPath(shoePath, Paint()..color = _shoeMain);
    final solePath = Path()
      ..moveTo(ax - 5, ay + 6)
      ..cubicTo(ax - 5, ay + 10, ax + sign * 12, ay + 10, ax + sign * 12, ay + 6);
    canvas.drawPath(solePath,
        Paint()
          ..color = _shoeSole
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round);
  }

  void _drawFrock(Canvas canvas, double cx) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 11, 63, 22, 4.5), const Radius.circular(2)),
      Paint()..color = shirtColor.withValues(alpha: 0.8),
    );
    final skirt = Path()
      ..moveTo(cx - 11, 67)
      ..cubicTo(cx - 20, 78, cx - 22, 94, cx - 19, 98)
      ..lineTo(cx + 19, 98)
      ..cubicTo(cx + 22, 94, cx + 20, 78, cx + 11, 67)
      ..close();
    canvas.drawPath(skirt, Paint()..color = shirtColor);
    final fold = Path()
      ..moveTo(cx - 4, 67)
      ..cubicTo(cx - 6, 82, cx - 5, 95, cx - 3, 98)
      ..lineTo(cx + 3, 98)
      ..cubicTo(cx + 5, 95, cx + 6, 82, cx + 4, 67)
      ..close();
    canvas.drawPath(fold, Paint()..color = Colors.white.withValues(alpha: 0.14));
    for (final left in [true, false]) {
      _drawFrockLeg(canvas, cx, isLeft: left);
    }
  }

  void _drawFrockLeg(Canvas canvas, double cx, {required bool isLeft}) {
    const hemY = 97.0, shinL = 16.0;
    final sign  = isLeft ? -1 : 1;
    final footX = cx + sign * 5 +
        math.sin((isLeft ? legAngle : -legAngle) * 0.55) * shinL;
    final footY = hemY + shinL;
    canvas.drawLine(Offset(cx + sign * 5, hemY), Offset(footX, footY),
        Paint()..color = _skin..strokeWidth = 6..strokeCap = StrokeCap.round);
    final shoePath = Path()
      ..moveTo(footX - 3.5, footY)
      ..cubicTo(footX - 4, footY + 3.5, footX + sign * 2, footY + 6,
          footX + sign * 9, footY + 4)
      ..cubicTo(footX + sign * 10, footY + 3, footX + sign * 9, footY + 1,
          footX + sign * 7, footY)
      ..close();
    canvas.drawPath(shoePath, Paint()..color = _hairFemale);
  }

  @override
  bool shouldRepaint(_CharacterPainter old) =>
      old.legAngle != legAngle ||
      old.leftArmAngle != leftArmAngle ||
      old.rightArmAngle != rightArmAngle ||
      old.legTuck != legTuck ||
      old.breath != breath ||
      old.gender != gender ||
      old.shirtColor != shirtColor;
}
