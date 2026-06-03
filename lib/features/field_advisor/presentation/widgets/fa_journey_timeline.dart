import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kiba_app/features/field_advisor/data/visit_model.dart';
import 'package:kiba_app/features/field_advisor/domain/attendance_provider.dart';
import 'package:kiba_app/features/field_advisor/domain/visit_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _green     = Color(0xFF059669);
const _greenDark = Color(0xFF047857);
const _yellow    = Color(0xFFE8A020);
const _grey      = Color(0xFF9CA3AF);
const _greyLight = Color(0xFFE5E7EB);
const _textDark  = Color(0xFF111827);

// ── Field stop data ───────────────────────────────────────────────────────────
class _FieldStop {
  const _FieldStop({
    required this.label,
    required this.time,
    required this.t,
    required this.done,
  });
  final String label;
  final String time;
  final double t;   // fraction of total arc-length [0.0, 1.0]
  final bool   done;
}

// ── Geometry constants ────────────────────────────────────────────────────────
const _canvasH = 180.0;
const _amp     = 42.0;
const _perStop = 64.0;
const _hPad    = 20.0;

// ── Pure data helpers ─────────────────────────────────────────────────────────

/// Converts today's visits + attendance into the stop list the canvas needs.
List<_FieldStop> _stopsFromVisits(
    List<VisitModel> todayVisits, AttendanceState attendance) {
  final fmt = DateFormat('HH:mm');
  final raw = <_FieldStop>[];

  // Start — HQ departure
  raw.add(_FieldStop(
    label: 'Start',
    time:  attendance.checkInTime != null
        ? fmt.format(attendance.checkInTime!)
        : '--:--',
    t:    0.0,
    done: true, // always true once the timeline is visible (FA is checked in)
  ));

  // One stop per farm visit, sorted by check-in time
  for (final v in todayVisits) {
    final name  = v.farmerName;
    // Truncate long names so canvas labels don't collide
    final label = name.length > 9 ? '${name.substring(0, 8)}…' : name;
    raw.add(_FieldStop(
      label: label,
      time:  fmt.format(v.checkIn),
      t:    0.0, // placeholder; reassigned below
      done: v.status == VisitStatus.completed,
    ));
  }

  // End — HQ return
  raw.add(_FieldStop(
    label: 'HQ',
    time:  attendance.checkOutTime != null
        ? fmt.format(attendance.checkOutTime!)
        : '--:--',
    t:    1.0,
    done: attendance.isCheckedOut,
  ));

  // Assign evenly-spaced t values (same formula the mock used)
  final n = raw.length;
  return List.generate(n, (i) => _FieldStop(
    label: raw[i].label,
    time:  raw[i].time,
    t:     n < 2 ? 0.0 : i / (n - 1),
    done:  raw[i].done,
  ));
}

/// Where the bike should animate to, given the current stop states.
double _computeTargetT(
    List<_FieldStop> stops, AttendanceState attendance) {
  if (stops.isEmpty) return 0.0;

  // FA has checked out → bike is back at HQ
  if (attendance.isCheckedOut) return 1.0;

  // Find the last completed stop
  int lastDoneIdx = -1;
  for (int i = 0; i < stops.length; i++) {
    if (stops[i].done) lastDoneIdx = i;
  }

  if (lastDoneIdx < 0) return 0.0;
  if (lastDoneIdx == stops.length - 1) return stops.last.t;

  // Bike is 45% into the gap toward the next stop — clearly "en route"
  final lastT = stops[lastDoneIdx].t;
  final nextT = stops[lastDoneIdx + 1].t;
  return lastT + (nextT - lastT) * 0.45;
}

/// Reactive subtitle line shown beneath the section title.
String _buildSubtitle(
    List<VisitModel> today, AttendanceState attendance, bool isLoading) {
  if (isLoading && today.isEmpty) return 'Loading visits…';
  if (today.isEmpty)              return 'No farm visits logged yet';

  if (attendance.isCheckedOut) {
    final n = today.length;
    return 'Journey complete · $n farm${n == 1 ? '' : 's'} visited';
  }

  final active = today.where((v) => v.isActive).firstOrNull;
  if (active != null) {
    final name = active.farmerName.length > 18
        ? '${active.farmerName.substring(0, 17)}…'
        : active.farmerName;
    return 'Live · at $name';
  }

  final done  = today.where((v) => v.status == VisitStatus.completed).length;
  final total = today.length;
  return 'Live · $done of $total farms done';
}

// ── Main widget ───────────────────────────────────────────────────────────────
class FAJourneyTimeline extends ConsumerStatefulWidget {
  const FAJourneyTimeline({super.key});

  @override
  ConsumerState<FAJourneyTimeline> createState() => _FAJourneyTimelineState();
}

class _FAJourneyTimelineState extends ConsumerState<FAJourneyTimeline>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;
  final _scrollCtrl = ScrollController();

  // Sentinel -1.0 so the very first computed target always triggers animation.
  double _lastTargetT = -1.0;
  // Kept in sync when animation fires; used by _scrollToBike for width math.
  int    _stopsCount  = 2;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _scrollToBike();
    });
  }

  /// Schedules an animation to [newT] if it differs meaningfully from the
  /// last animated target. Safe to call from build — fires post-frame.
  void _maybeAnimate(double newT, int stopsCount) {
    if ((newT - _lastTargetT).abs() < 0.01) return;
    _lastTargetT = newT;
    _stopsCount  = stopsCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ctrl.animateTo(
        newT,
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _scrollToBike() {
    if (!_scrollCtrl.hasClients) return;
    final maxExt = _scrollCtrl.position.maxScrollExtent;
    if (maxExt <= 0) return;
    final totalW = _totalWidth(context.findRenderObject());
    final bikeX  = _ctrl.value * (totalW - _hPad * 2) + _hPad;
    final viewW  = _scrollCtrl.position.viewportDimension;
    final target = (bikeX - viewW * 0.30).clamp(0.0, maxExt);
    _scrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  double _totalWidth(RenderObject? ro) {
    final sw = (ro?.paintBounds.width ?? 320.0) - 40;
    return math.max(sw, (_stopsCount - 1) * _perStop + _hPad * 2);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(faVisitsProvider);
    final attendance  = ref.watch(attendanceProvider);

    // Filter to today's visits only, sorted chronologically
    final allVisits = visitsAsync.valueOrNull ?? [];
    final now       = DateTime.now();
    final today = allVisits
        .where((v) =>
            v.checkIn.year  == now.year  &&
            v.checkIn.month == now.month &&
            v.checkIn.day   == now.day)
        .toList()
      ..sort((a, b) => a.checkIn.compareTo(b.checkIn));

    final stops   = _stopsFromVisits(today, attendance);
    final targetT = _computeTargetT(stops, attendance);
    _maybeAnimate(targetT, stops.length);

    final visitCount = today.length;
    final doneCount  = today.where((v) => v.status == VisitStatus.completed).length;
    final badgeText  = visitCount == 0
        ? '0 farms'
        : '$doneCount of $visitCount farm${visitCount == 1 ? '' : 's'}';
    final subtitle = _buildSubtitle(today, attendance, visitsAsync.isLoading);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Today's Journey",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.route_rounded, color: _green, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: _grey),
          ),
          const SizedBox(height: 14),

          // ── Canvas / loading / empty ─────────────────────────────────────
          if (visitsAsync.isLoading && today.isEmpty)
            const _LoadingPlaceholder()
          else if (today.isEmpty)
            const _EmptyState()
          else
            LayoutBuilder(
              builder: (context, box) {
                final n      = stops.length;
                final totalW = math.max(
                  box.maxWidth,
                  (n - 1) * _perStop + _hPad * 2,
                );
                return _ScrollableTimeline(
                  stops:      stops,
                  bikeAnim:   _ctrl,
                  totalW:     totalW,
                  screenW:    box.maxWidth,
                  scrollCtrl: _scrollCtrl,
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── Loading placeholder ───────────────────────────────────────────────────────
class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: _canvasH,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: _green),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _canvasH,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pin_drop_outlined, color: _green, size: 22),
            ),
            const SizedBox(height: 10),
            const Text(
              'No farm visits yet',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Log your first visit using the Visits tab',
              style: TextStyle(fontSize: 11, color: _grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scrollable wrapper with fade edges ────────────────────────────────────────
class _ScrollableTimeline extends StatelessWidget {
  const _ScrollableTimeline({
    required this.stops,
    required this.bikeAnim,
    required this.totalW,
    required this.screenW,
    required this.scrollCtrl,
  });

  final List<_FieldStop>  stops;
  final Animation<double> bikeAnim;
  final double            totalW;
  final double            screenW;
  final ScrollController  scrollCtrl;

  @override
  Widget build(BuildContext context) {
    final isScrollable = totalW > screenW + 1;

    Widget timeline = SingleChildScrollView(
      controller: scrollCtrl,
      scrollDirection: Axis.horizontal,
      physics: isScrollable
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      child: AnimatedBuilder(
        animation: bikeAnim,
        builder: (context, child) => _TimelineCanvas(
          stops:  stops,
          bikeT:  bikeAnim.value,
          totalW: totalW,
        ),
      ),
    );

    if (isScrollable) {
      timeline = ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end:   Alignment.centerRight,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops:  [0.0, 0.82, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: timeline,
      );
    }

    return SizedBox(height: _canvasH, child: timeline);
  }
}

// ── Canvas: CustomPaint + bike overlay ───────────────────────────────────────
class _TimelineCanvas extends StatelessWidget {
  const _TimelineCanvas({
    required this.stops,
    required this.bikeT,
    required this.totalW,
  });

  final List<_FieldStop> stops;
  final double           bikeT;
  final double           totalW;

  static Offset _stopOffset(int i, int n, double w) {
    final cy = _canvasH * 0.5;
    final x  = (n < 2) ? w / 2 : _hPad + (i / (n - 1)) * (w - _hPad * 2);
    final y  = (i == 0 || i == n - 1)
        ? cy
        : (i.isOdd ? cy - _amp : cy + _amp);
    return Offset(x, y);
  }

  static Path _buildWave(int n, double w) {
    final p0 = _stopOffset(0, n, w);
    final path = Path()..moveTo(p0.dx, p0.dy);
    for (int i = 0; i < n - 1; i++) {
      final a  = _stopOffset(i,     n, w);
      final b  = _stopOffset(i + 1, n, w);
      final mx = (a.dx + b.dx) / 2;
      path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final n      = stops.length;
    final wave   = _buildWave(n, totalW);
    final metric = wave.computeMetrics().first;
    final total  = metric.length;

    final bikeDist   = (bikeT * total).clamp(2.0, total - 2.0);
    final bikePosTan = metric.getTangentForOffset(bikeDist);

    return SizedBox(
      width:  totalW,
      height: _canvasH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(totalW, _canvasH),
            painter: _PathPainter(
              stops:     stops,
              bikeT:     bikeT,
              metric:    metric,
              stopPosFn: (i) => _stopOffset(i, n, totalW),
            ),
          ),
          if (bikePosTan != null && bikeT > 0.01)
            Positioned(
              left: bikePosTan.position.dx - 18,
              top:  bikePosTan.position.dy - 26,
              child: Transform.rotate(
                angle:     bikePosTan.angle,
                alignment: Alignment.center,
                child:     const _BikeWidget(),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Path painter ─────────────────────────────────────────────────────────────
class _PathPainter extends CustomPainter {
  const _PathPainter({
    required this.stops,
    required this.bikeT,
    required this.metric,
    required this.stopPosFn,
  });

  final List<_FieldStop>   stops;
  final double             bikeT;
  final ui.PathMetric      metric;
  final Offset Function(int) stopPosFn;

  @override
  void paint(Canvas canvas, Size size) {
    final total    = metric.length;
    final bikeDist = bikeT * total;

    _drawDashed(
      canvas, metric, bikeDist, total,
      Paint()
        ..color      = _greyLight
        ..strokeWidth = 3.0
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round,
    );

    if (bikeDist > 1) {
      canvas.drawPath(
        metric.extractPath(0, bikeDist),
        Paint()
          ..shader = const LinearGradient(colors: [_greenDark, _green])
              .createShader(Rect.fromLTWH(0, 0, size.width, 1))
          ..strokeWidth = 4.0
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.round,
      );
    }

    for (int i = 0; i < stops.length; i++) {
      final pos  = stopPosFn(i);
      final done = stops[i].t <= bikeT + 0.005;
      _drawDot(canvas, pos, done);
      _drawLabel(canvas, pos, stops[i], done, size.height, size.width);
    }
  }

  void _drawDashed(
      Canvas canvas, ui.PathMetric m, double from, double to, Paint p) {
    const dash = 7.0;
    const gap  = 5.0;
    var pos = from;
    while (pos < to - 1) {
      canvas.drawPath(m.extractPath(pos, math.min(pos + dash, to)), p);
      pos += dash + gap;
    }
  }

  void _drawDot(Canvas canvas, Offset center, bool done) {
    canvas.drawCircle(
      center, 10.0,
      Paint()
        ..color = (done ? _green : _greyLight).withValues(alpha: 0.22)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center, 6.0,
      Paint()..color = done ? _green : _greyLight..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center, 2.8,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );
  }

  void _drawLabel(Canvas canvas, Offset pos, _FieldStop stop,
      bool done, double h, double w) {
    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(
          text: '${stop.label}\n',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: done ? _textDark : _grey,
            height: 1.4,
          ),
        ),
        TextSpan(
          text: stop.time,
          style: TextStyle(
            fontSize: 8.5,
            color: done ? _green : _grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 56);

    final cy      = h * 0.5;
    final isAbove = pos.dy <= cy;
    final dx = (pos.dx - tp.width / 2).clamp(0.0, w - tp.width);
    final dy = isAbove ? pos.dy - 13 - tp.height : pos.dy + 13;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.bikeT != bikeT;
}

// ── Bike & rider (canvas-drawn, no assets) ────────────────────────────────────
class _BikeWidget extends StatelessWidget {
  const _BikeWidget();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 36,
      height: 48,
      child: CustomPaint(painter: _BikePainter()),
    );
  }
}

class _BikePainter extends CustomPainter {
  const _BikePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final wy = size.height * 0.68;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 1, wy + 7), width: 30, height: 8),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.13)
        ..style = PaintingStyle.fill,
    );

    final wFill = Paint()..color = const Color(0xFF1F2937)..style = PaintingStyle.fill;
    final wRim  = Paint()
      ..color      = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke;
    for (final wCx in [cx - 11.0, cx + 11.0]) {
      canvas.drawCircle(Offset(wCx, wy), 6,   wFill);
      canvas.drawCircle(Offset(wCx, wy), 3.8, wRim);
      canvas.drawCircle(Offset(wCx, wy), 1.5,
          Paint()..color = Colors.white.withValues(alpha: 0.5)..style = PaintingStyle.fill);
    }

    final frame = Path()
      ..moveTo(cx - 11, wy)
      ..lineTo(cx - 2,  wy - 7)
      ..lineTo(cx + 8,  wy - 6)
      ..lineTo(cx + 11, wy)
      ..moveTo(cx - 2,  wy - 7)
      ..lineTo(cx + 4,  wy)
      ..lineTo(cx - 11, wy);
    canvas.drawPath(
      frame,
      Paint()
        ..color       = _greenDark
        ..strokeWidth = 2.5
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round
        ..strokeJoin  = StrokeJoin.round,
    );

    canvas.drawLine(
      Offset(cx + 8, wy - 6), Offset(cx + 10, wy - 10),
      Paint()
        ..color      = const Color(0xFF1F2937)
        ..strokeWidth = 2
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 4, wy - 8), width: 10, height: 3),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFF1F2937)..style = PaintingStyle.fill,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 5, wy - 17, 8, 9),
        const Radius.circular(3),
      ),
      Paint()..color = _green..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      Offset(cx - 1, wy - 22), 5.5,
      Paint()..color = _yellow..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, wy - 21), width: 7.5, height: 2.5),
        const Radius.circular(1.2),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.32)..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx - 2.5, wy - 24), 1.5,
      Paint()..color = Colors.white.withValues(alpha: 0.6)..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_BikePainter old) => false;
}
