import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:kiba_app/core/router/app_router.dart';
import 'package:kiba_app/features/auth/domain/auth_providers.dart';
import 'package:kiba_app/features/field_advisor/domain/attendance_calendar_provider.dart';
import 'package:kiba_app/features/field_advisor/domain/location_tracking_provider.dart';
import 'package:kiba_app/features/field_advisor/domain/visit_provider.dart';

// ── Colors ────────────────────────────────────────────────────────────────────
const _bgTop    = Color(0xFF04091A);
const _bgBottom = Color(0xFF0D1B3E);
const _navy     = Color(0xFF1E3A8A);
const _gold     = Color(0xFFE8A020);
const _success  = Color(0xFF34D399);

// Kiba logo orbit colors
const _orbitColors = [
  Color(0xFFE8A020), // gold
  Color(0xFF34D399), // mint
  Color(0xFF7C3AED), // purple
  Color(0xFFEF4444), // red
  Color(0xFF06B6D4), // cyan
  Color(0xFFF97316), // orange
  Color(0xFFEC4899), // pink
  Color(0xFF1E3A8A), // navy
];

enum _VerifyState { locating, locationError, aligning, scanning, verified }

// ── Screen ────────────────────────────────────────────────────────────────────
class FAFaceVerifyScreen extends ConsumerStatefulWidget {
  const FAFaceVerifyScreen({
    super.key,
    this.isCheckout      = false,
    this.isEarlyCheckout = false,
    this.checkoutReason,
  });

  final bool    isCheckout;
  final bool    isEarlyCheckout;
  final String? checkoutReason;

  @override
  ConsumerState<FAFaceVerifyScreen> createState() => _FAFaceVerifyScreenState();
}

class _FAFaceVerifyScreenState extends ConsumerState<FAFaceVerifyScreen>
    with TickerProviderStateMixin {

  late final AnimationController _orbitCtrl;
  late final AnimationController _scanCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _successCtrl;

  late final Animation<double> _scanAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _successScale;

  _VerifyState _state    = _VerifyState.locating;
  Position?    _position; // GPS captured before face scan starts
  String?      _locationError;

  @override
  void initState() {
    super.initState();

    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scanAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _successScale =
        CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);

    // Gate: GPS must be confirmed before face scan starts.
    _requestLocation();
  }

  Future<void> _requestLocation() async {
    try {
      final pos = await fetchCurrentPosition();
      if (!mounted) return;
      _position = pos;
      setState(() => _state = _VerifyState.aligning);
      Future.delayed(const Duration(seconds: 3), _startScanning);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state         = _VerifyState.locationError;
        _locationError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _startScanning() {
    if (!mounted) return;
    setState(() => _state = _VerifyState.scanning);
    Future.delayed(const Duration(seconds: 2), _onVerified);
  }

  void _onVerified() {
    if (!mounted) return;
    setState(() => _state = _VerifyState.verified);
    _successCtrl.forward();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      final now  = DateTime.now();
      final pos  = _position!;
      final user = ref.read(currentUserProvider);

      if (widget.isCheckout) {
        ref.read(attendanceCalendarProvider.notifier).upsertToday(
          checkOut:        now,
          checkOutLat:     pos.latitude,
          checkOutLng:     pos.longitude,
          isEarlyCheckout: widget.isEarlyCheckout,
          checkoutReason:  widget.checkoutReason,
        );
        ref.read(locationTrackingProvider.notifier).stopTracking();
      } else {
        ref.read(attendanceCalendarProvider.notifier).upsertToday(
          checkIn:    now,
          checkInLat: pos.latitude,
          checkInLng: pos.longitude,
        );
        if (user != null) {
          ref.read(locationTrackingProvider.notifier)
              .startTracking(user.uid, user.displayName);
        }
      }

      context.go(AppRoutes.faHome);
    });
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTop,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                onBack: () => context.go(AppRoutes.faHome),
                title:  widget.isCheckout ? 'Check-Out Verify' : 'Face Verification',
              ),
              const SizedBox(height: 12),
              _InstructionText(state: _state),
              const SizedBox(height: 28),

              // Location gate — replaces face frame until GPS confirmed
              if (_state == _VerifyState.locating ||
                  _state == _VerifyState.locationError)
                Expanded(
                  child: _LocationGate(
                    isLoading: _state == _VerifyState.locating,
                    errorMessage: _locationError,
                    onRetry: _requestLocation,
                    onOpenSettings: () async {
                      await Geolocator.openLocationSettings();
                      _requestLocation();
                    },
                  ),
                )
              else
                Expanded(child: _FrameArea(
                  orbitCtrl:    _orbitCtrl,
                  scanAnim:     _scanAnim,
                  pulseAnim:    _pulseAnim,
                  successScale: _successScale,
                  state:        _state,
                )),

              const SizedBox(height: 20),
              _StatusArea(state: _state),
              const SizedBox(height: 28),
              _CancelButton(onTap: () => context.go(AppRoutes.faHome)),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location gate — shown before face frame until GPS is confirmed
// ─────────────────────────────────────────────────────────────────────────────
class _LocationGate extends StatelessWidget {
  const _LocationGate({
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.onOpenSettings,
  });
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading) ...[
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    color: _gold,
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Fetching GPS Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Live location is required for attendance\nand admin heatmap tracking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.5,
                  ),
                ),
              ] else ...[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_off_rounded,
                    color: Color(0xFFEF4444),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Location Unavailable',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  errorMessage ?? 'Location permission is required.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onRetry,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Center(
                            child: Text(
                              'Retry',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: onOpenSettings,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: _gold.withValues(alpha: 0.3)),
                          ),
                          child: const Center(
                            child: Text(
                              'Open Settings',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _gold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.title});
  final VoidCallback onBack;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Powered by Kiba AI',
                style: TextStyle(
                  fontSize: 11,
                  color: _gold.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Lock icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _gold.withValues(alpha: 0.25)),
            ),
            child: Icon(Icons.lock_rounded, color: _gold.withValues(alpha: 0.9), size: 18),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Instruction text
// ─────────────────────────────────────────────────────────────────────────────
class _InstructionText extends StatelessWidget {
  const _InstructionText({required this.state});
  final _VerifyState state;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (state) {
      _VerifyState.locating       => ('Acquiring your location…', Colors.white60),
      _VerifyState.locationError  => ('Location Required', const Color(0xFFEF4444)),
      _VerifyState.aligning       => ('Position your face inside the frame', Colors.white60),
      _VerifyState.scanning       => ('Hold still — scanning biometrics...', _gold),
      _VerifyState.verified       => ('Identity Verified Successfully', _success),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Text(
        text,
        key: ValueKey(state),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Frame area — orbiting logos + face oval
// ─────────────────────────────────────────────────────────────────────────────
class _FrameArea extends StatelessWidget {
  const _FrameArea({
    required this.orbitCtrl,
    required this.scanAnim,
    required this.pulseAnim,
    required this.successScale,
    required this.state,
  });

  final AnimationController orbitCtrl;
  final Animation<double> scanAnim;
  final Animation<double> pulseAnim;
  final Animation<double> successScale;
  final _VerifyState state;

  // Base (unscaled) dimensions — scaled at runtime by LayoutBuilder
  static const _baseOvalW   = 272.0;
  static const _baseOvalH   = 348.0;
  static const _baseOrbitRx = 188.0;
  static const _baseOrbitRy = 192.0;
  static const _baseBoxW    = 440.0;
  static const _baseBoxH    = 460.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale   = (constraints.maxWidth / _baseBoxW).clamp(0.0, 1.0);
        final boxW    = _baseBoxW    * scale;
        final boxH    = _baseBoxH    * scale;
        final ovalW   = _baseOvalW   * scale;
        final ovalH   = _baseOvalH   * scale;
        final orbitRx = _baseOrbitRx * scale;
        final orbitRy = _baseOrbitRy * scale;

        return Center(
          child: SizedBox(
            width: boxW,
            height: boxH,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Orbiting logos (back layer — top half of orbit)
                ..._orbitLogos(
                    frontHalf: false,
                    orbitRx: orbitRx,
                    orbitRy: orbitRy,
                    scale: scale),

                // Face oval frame
                _FaceOval(
                  ovalW: ovalW,
                  ovalH: ovalH,
                  scanAnim: scanAnim,
                  pulseAnim: pulseAnim,
                  successScale: successScale,
                  state: state,
                ),

                // Orbiting logos (front layer — bottom half of orbit)
                ..._orbitLogos(
                    frontHalf: true,
                    orbitRx: orbitRx,
                    orbitRy: orbitRy,
                    scale: scale),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _orbitLogos({
    required bool frontHalf,
    required double orbitRx,
    required double orbitRy,
    required double scale,
  }) {
    return List.generate(_orbitColors.length, (i) {
      final baseAngle = (i * 2 * math.pi) / _orbitColors.length;
      final isOuter   = i.isEven;
      final rx    = isOuter ? orbitRx         : orbitRx * 0.82;
      final ry    = isOuter ? orbitRy         : orbitRy * 0.95;
      final speed = isOuter ? 1.0             : 1.55;
      final size  = (isOuter ? 38.0 : 30.0) * scale;

      return AnimatedBuilder(
        animation: orbitCtrl,
        builder: (context, child) {
          final angle  = baseAngle + orbitCtrl.value * 2 * math.pi * speed;
          final x      = math.cos(angle) * rx;
          final y      = math.sin(angle) * ry;

          // Depth split: y<0 = back (behind oval), y>0 = front (in front)
          final isFront = y > 0;
          if (isFront != frontHalf) return const SizedBox.shrink();

          final depthScale   = isFront ? 1.0 : 0.82;
          final depthOpacity = isFront ? 1.0 : 0.50;

          return Transform.translate(
            offset: Offset(x, y),
            child: Opacity(
              opacity: depthOpacity,
              child: Transform.scale(scale: depthScale, child: child),
            ),
          );
        },
        child: _KibaLogo(color: _orbitColors[i], size: size),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kiba orbit logo badge
// ─────────────────────────────────────────────────────────────────────────────
class _KibaLogo extends StatelessWidget {
  const _KibaLogo({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          'K',
          style: TextStyle(
            fontSize: size * 0.48,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Face oval frame
// ─────────────────────────────────────────────────────────────────────────────
class _FaceOval extends StatelessWidget {
  const _FaceOval({
    required this.ovalW,
    required this.ovalH,
    required this.scanAnim,
    required this.pulseAnim,
    required this.successScale,
    required this.state,
  });

  final double ovalW;
  final double ovalH;
  final Animation<double> scanAnim;
  final Animation<double> pulseAnim;
  final Animation<double> successScale;
  final _VerifyState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulseAnim, successScale]),
      builder: (context, child) {
        final isVerified  = state == _VerifyState.verified;
        final borderColor = isVerified
            ? Color.lerp(_navy, _success, successScale.value)!
            : Color.lerp(
                _navy.withValues(alpha: 0.6),
                _gold,
                pulseAnim.value,
              )!;
        final glowColor = isVerified
            ? _success.withValues(alpha: 0.35 * successScale.value)
            : _gold.withValues(alpha: 0.22 * pulseAnim.value);

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Outer glow
            Container(
              width: ovalW + 28,
              height: ovalH + 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular((ovalW + 28) / 2),
                boxShadow: [
                  BoxShadow(
                    color: glowColor,
                    blurRadius: 36,
                    spreadRadius: 12,
                  ),
                ],
              ),
            ),

            // Face oval
            Container(
              width: ovalW,
              height: ovalH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ovalW / 2),
                border: Border.all(color: borderColor, width: 2.5),
                gradient: RadialGradient(
                  colors: [
                    Colors.blueGrey.shade900.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Scan line
                  if (state != _VerifyState.verified)
                    AnimatedBuilder(
                      animation: scanAnim,
                      builder: (context, child) => Positioned(
                        top: scanAnim.value * (ovalH - 3),
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                _gold.withValues(alpha: 0.5),
                                _gold,
                                _gold.withValues(alpha: 0.5),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Success checkmark
                  if (state == _VerifyState.verified)
                    Center(
                      child: ScaleTransition(
                        scale: successScale,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _success.withValues(alpha: 0.15),
                            border: Border.all(color: _success, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: _success.withValues(alpha: 0.4),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: _success,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Corner brackets
            ..._corners(ovalW, ovalH),
          ],
        );
      },
    );
  }

  List<Widget> _corners(double w, double h) {
    const s = 24.0;
    const t = 3.0;

    // Stack size = (w+28) × (h+28); oval centered → 14px gap each side; -2 for overlap
    const edge = 12.0;
    return [
      Positioned(left: edge,  top: edge,    child: _Corner(size: s, thickness: t, corner: _CornerType.topLeft)),
      Positioned(right: edge, top: edge,    child: _Corner(size: s, thickness: t, corner: _CornerType.topRight)),
      Positioned(left: edge,  bottom: edge, child: _Corner(size: s, thickness: t, corner: _CornerType.bottomLeft)),
      Positioned(right: edge, bottom: edge, child: _Corner(size: s, thickness: t, corner: _CornerType.bottomRight)),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Corner bracket
// ─────────────────────────────────────────────────────────────────────────────
enum _CornerType { topLeft, topRight, bottomLeft, bottomRight }

class _Corner extends StatelessWidget {
  const _Corner({required this.size, required this.thickness, required this.corner});
  final double size;
  final double thickness;
  final _CornerType corner;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CornerPainter(thickness: thickness, corner: corner),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({required this.thickness, required this.corner});
  final double thickness;
  final _CornerType corner;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    switch (corner) {
      case _CornerType.topLeft:
        canvas.drawLine(Offset(0, h), Offset(0, 0), paint);
        canvas.drawLine(Offset(0, 0), Offset(w, 0), paint);
      case _CornerType.topRight:
        canvas.drawLine(Offset(w, h), Offset(w, 0), paint);
        canvas.drawLine(Offset(w, 0), Offset(0, 0), paint);
      case _CornerType.bottomLeft:
        canvas.drawLine(Offset(0, 0), Offset(0, h), paint);
        canvas.drawLine(Offset(0, h), Offset(w, h), paint);
      case _CornerType.bottomRight:
        canvas.drawLine(Offset(w, 0), Offset(w, h), paint);
        canvas.drawLine(Offset(w, h), Offset(0, h), paint);
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Status area
// ─────────────────────────────────────────────────────────────────────────────
class _StatusArea extends StatelessWidget {
  const _StatusArea({required this.state});
  final _VerifyState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (state) {
        _VerifyState.aligning       => const _PulsingDots(),
        _VerifyState.scanning       => const _ScanProgressBar(),
        _VerifyState.verified       => _VerifiedBadge(),
        _VerifyState.locating       => const SizedBox.shrink(),
        _VerifyState.locationError  => const SizedBox.shrink(),
      },
    );
  }
}

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final phase   = (i / 3.0);
            final val     = ((_ctrl.value - phase + 1.0) % 1.0);
            final opacity = (val < 0.5 ? val * 2 : (1 - val) * 2).clamp(0.15, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: opacity),
              ),
            );
          },
        );
      }),
    );
  }
}

class _ScanProgressBar extends StatefulWidget {
  const _ScanProgressBar();

  @override
  State<_ScanProgressBar> createState() => _ScanProgressBarState();
}

class _ScanProgressBarState extends State<_ScanProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 52),
      child: Column(
        children: [
          Text(
            'Analyzing facial features',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _anim,
            builder: (context, child) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _anim.value,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(_gold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _success.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: _success, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Face ID Matched',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _success,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cancel button
// ─────────────────────────────────────────────────────────────────────────────
class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: const Text(
          'Cancel Verification',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}
