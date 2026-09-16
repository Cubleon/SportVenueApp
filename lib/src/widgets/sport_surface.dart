import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Scale drawings of real playing surfaces.
///
/// Every measurement below is the regulation one in metres. A single
/// metre-to-pixel transform maps them into the paint box, so a pitch keeps its
/// true proportions and its markings stay in the right place whether it is
/// painted on a small chip or a full-width card.
class SportSurface extends StatelessWidget {
  const SportSurface({super.key, required this.sportId});

  final String sportId;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SportSurfacePainter(sportId: sportId),
      size: Size.infinite,
    );
  }
}

class SportSurfacePainter extends CustomPainter {
  const SportSurfacePainter({required this.sportId});

  final String sportId;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final spec = _SurfaceSpec.of(sportId);
    final pitch = _fit(size, spec);
    final scale = pitch.width / spec.width;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = spec.surround,
    );

    final board = _Board(canvas: canvas, pitch: pitch, scale: scale);
    spec.paint(board);
  }

  /// Centres the pitch in the box, portrait, leaving run-off room around it.
  Rect _fit(Size size, _SurfaceSpec spec) {
    final margin = math.min(size.width, size.height) * 0.07;
    final availableWidth = size.width - margin * 2;
    final availableHeight = size.height - margin * 2;
    final ratio = spec.length / spec.width;

    var width = math.min(availableWidth, availableHeight / ratio);
    var height = width * ratio;
    if (width <= 0 || height <= 0) {
      width = availableWidth;
      height = availableHeight;
    }

    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: width,
      height: height,
    );
  }

  @override
  bool shouldRepaint(covariant SportSurfacePainter oldDelegate) =>
      oldDelegate.sportId != sportId;
}

/// Drawing helpers that speak metres instead of pixels.
///
/// The pitch is painted portrait: the sport's width runs left to right, its
/// length runs top to bottom, and the origin sits at the centre spot.
class _Board {
  _Board({required this.canvas, required this.pitch, required this.scale});

  final Canvas canvas;
  final Rect pitch;
  final double scale;

  /// Metres to pixels.
  double m(double metres) => metres * scale;

  /// A point in metres from the centre spot.
  Offset at(double x, double y) =>
      Offset(pitch.center.dx + m(x), pitch.center.dy + m(y));

  Rect rect(double x, double y, double width, double height) => Rect.fromLTWH(
    pitch.center.dx + m(x),
    pitch.center.dy + m(y),
    m(width),
    m(height),
  );

  Rect centred(double x, double y, double width, double height) =>
      Rect.fromCenter(
        center: at(x, y),
        width: m(width),
        height: m(height),
      );

  Paint line(Color color, {double width = 0.12}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.9, m(width))
    ..strokeCap = StrokeCap.square
    ..color = color;

  Paint fill(Color color) => Paint()..color = color;

  double get halfWidth => pitch.width / 2 / scale;
  double get halfLength => pitch.height / 2 / scale;

  void spot(double x, double y, Color color, {double radius = 0.16}) =>
      canvas.drawCircle(at(x, y), math.max(1.1, m(radius)), fill(color));

  /// Evenly spaced bands across the pitch — mown grass, court inlays, planks.
  void bands(Rect area, Color color, int count, {bool vertical = true}) {
    canvas.save();
    canvas.clipRect(area);
    final step = (vertical ? area.width : area.height) / count;
    for (var i = 0; i < count; i += 2) {
      canvas.drawRect(
        vertical
            ? Rect.fromLTWH(area.left + step * i, area.top, step, area.height)
            : Rect.fromLTWH(area.left, area.top + step * i, area.width, step),
        fill(color),
      );
    }
    canvas.restore();
  }

  void dashedLine(Offset from, Offset to, Paint paint, double dash) {
    final delta = to - from;
    final total = delta.distance;
    if (total <= 0) return;
    final step = math.max(1.5, m(dash));
    final unit = delta / total;
    for (var travelled = 0.0; travelled < total; travelled += step * 2) {
      final end = math.min(travelled + step, total);
      canvas.drawLine(from + unit * travelled, from + unit * end, paint);
    }
  }
}

/// One playing surface: its regulation size, its colours, its markings.
class _SurfaceSpec {
  const _SurfaceSpec({
    required this.width,
    required this.length,
    required this.surface,
    required this.surround,
    required this.line,
    required this.paint,
  });

  /// Short side, in metres.
  final double width;

  /// Long side, in metres.
  final double length;

  final Color surface;
  final Color surround;
  final Color line;
  final void Function(_Board board) paint;

  static _SurfaceSpec of(String sportId) {
    switch (sportId) {
      case 'football':
        return _football;
      case 'hockey':
        return _hockey;
      case 'basketball':
        return _basketball;
      case 'volleyball':
        return _volleyball;
      case 'tennis':
        return _tennis;
      case 'padel':
        return _padel;
      default:
        return _football;
    }
  }
}

// ---------------------------------------------------------------------------
// Football — FIFA pitch, 68 × 105 m.
// ---------------------------------------------------------------------------

final _SurfaceSpec _football = _SurfaceSpec(
  width: 68,
  length: 105,
  surface: const Color(0xFF1E7A3C),
  surround: const Color(0xFF14512A),
  line: Colors.white.withValues(alpha: 0.82),
  paint: (b) {
    b.canvas.drawRect(b.pitch, b.fill(const Color(0xFF1E7A3C)));
    // Mown stripes run the length of the pitch, as a groundsman cuts them.
    b.bands(b.pitch, Colors.white.withValues(alpha: 0.045), 12);
    // Low evening light across one corner.
    b.canvas.drawRect(
      b.pitch,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.16),
          ],
        ).createShader(b.pitch),
    );

    final line = b.line(Colors.white.withValues(alpha: 0.82));
    final halfW = b.halfWidth;
    final halfL = b.halfLength;

    b.canvas.drawRect(b.pitch.deflate(b.m(0.6)), line);
    b.canvas.drawLine(b.at(-halfW, 0), b.at(halfW, 0), line);
    b.canvas.drawCircle(b.at(0, 0), b.m(9.15), line);
    b.spot(0, 0, Colors.white.withValues(alpha: 0.9), radius: 0.28);

    for (final side in const [-1.0, 1.0]) {
      final goalLine = halfL * side - 0.6 * side;
      // Penalty area 40.32 × 16.5, goal area 18.32 × 5.5.
      b.canvas.drawRect(
        Rect.fromPoints(
          b.at(-20.16, goalLine),
          b.at(20.16, goalLine - 16.5 * side),
        ),
        line,
      );
      b.canvas.drawRect(
        Rect.fromPoints(
          b.at(-9.16, goalLine),
          b.at(9.16, goalLine - 5.5 * side),
        ),
        line,
      );

      final penaltySpot = goalLine - 11 * side;
      b.spot(0, penaltySpot, Colors.white.withValues(alpha: 0.9), radius: 0.28);

      // The penalty arc is the part of a 9.15 m circle outside the box.
      b.canvas.save();
      b.canvas.clipRect(
        Rect.fromPoints(
          b.at(-halfW, goalLine - 16.5 * side),
          b.at(halfW, 0),
        ),
      );
      b.canvas.drawCircle(b.at(0, penaltySpot), b.m(9.15), line);
      b.canvas.restore();

      // Goal frame, seen from above, sitting behind the goal line.
      b.canvas.drawRect(
        Rect.fromPoints(
          b.at(-3.66, goalLine),
          b.at(3.66, goalLine + 1.8 * side),
        ),
        b.line(Colors.white.withValues(alpha: 0.95), width: 0.22),
      );

      // Corner arcs are quarter circles turned into the pitch.
      for (final corner in const [-1.0, 1.0]) {
        final start = side < 0
            ? (corner < 0 ? 0.0 : math.pi / 2)
            : (corner > 0 ? math.pi : math.pi * 3 / 2);
        b.canvas.drawArc(
          Rect.fromCircle(
            center: b.at(halfW * corner, goalLine),
            radius: b.m(1),
          ),
          start,
          math.pi / 2,
          false,
          line,
        );
      }
    }
  },
);

// ---------------------------------------------------------------------------
// Ice hockey — IIHF rink, 30 × 60 m, 8.5 m corner radius.
// ---------------------------------------------------------------------------

final _SurfaceSpec _hockey = _SurfaceSpec(
  width: 30,
  length: 60,
  surface: const Color(0xFFE8F4FB),
  surround: const Color(0xFF1B2B3A),
  line: const Color(0xFF9FB4C4),
  paint: (b) {
    final rink = RRect.fromRectAndRadius(b.pitch, Radius.circular(b.m(8.5)));
    b.canvas.drawRRect(rink, b.fill(const Color(0xFFE8F4FB)));
    // Freshly flooded ice: bright, with a faint cool sheen rather than grey.
    b.canvas.drawRRect(
      rink,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.85),
            const Color(0xFFDCEEFA).withValues(alpha: 0.75),
            const Color(0xFFC6E2F5).withValues(alpha: 0.55),
          ],
        ).createShader(b.pitch),
    );

    b.canvas.save();
    b.canvas.clipRRect(rink);

    final red = const Color(0xFFD7263D).withValues(alpha: 0.85);
    final blue = const Color(0xFF1B6CC4).withValues(alpha: 0.85);
    final halfW = b.halfWidth;
    final halfL = b.halfLength;

    // Centre line, blue lines, goal lines.
    b.canvas.drawLine(
      b.at(-halfW, 0),
      b.at(halfW, 0),
      b.line(red, width: 0.4),
    );
    for (final side in const [-1.0, 1.0]) {
      b.canvas.drawLine(
        b.at(-halfW, 7.5 * side),
        b.at(halfW, 7.5 * side),
        b.line(blue, width: 0.4),
      );

      final goalLine = (halfL - 4) * side;
      b.canvas.drawLine(
        b.at(-halfW, goalLine),
        b.at(halfW, goalLine),
        b.line(red, width: 0.2),
      );

      // Goal crease: a 1.8 m semicircle in front of the net.
      b.canvas.drawArc(
        Rect.fromCircle(center: b.at(0, goalLine), radius: b.m(1.8)),
        side > 0 ? math.pi : 0,
        math.pi,
        false,
        b.line(red, width: 0.15),
      );
      b.canvas.drawRect(
        Rect.fromPoints(
          b.at(-0.92, goalLine),
          b.at(0.92, goalLine + 1.15 * side),
        ),
        b.line(red, width: 0.18),
      );

      // Four end-zone face-off circles, plus neutral-zone spots.
      for (final x in const [-7.0, 7.0]) {
        final y = goalLine - 6.1 * side;
        b.canvas.drawCircle(b.at(x, y), b.m(4.5), b.line(red, width: 0.12));
        b.spot(x, y, red, radius: 0.3);
      }
      b.spot(-7, 5 * side, red, radius: 0.3);
      b.spot(7, 5 * side, red, radius: 0.3);
    }

    b.canvas.drawCircle(b.at(0, 0), b.m(4.5), b.line(blue, width: 0.12));
    b.spot(0, 0, blue, radius: 0.3);

    b.canvas.restore();
    b.canvas.drawRRect(rink, b.line(const Color(0xFF5B7285), width: 0.35));
  },
);

// ---------------------------------------------------------------------------
// Basketball — FIBA court, 15 × 28 m.
// ---------------------------------------------------------------------------

final _SurfaceSpec _basketball = _SurfaceSpec(
  width: 15,
  length: 28,
  surface: const Color(0xFFB9763B),
  surround: const Color(0xFF5E3317),
  line: Colors.white.withValues(alpha: 0.85),
  paint: (b) {
    b.canvas.drawRect(b.pitch, b.fill(const Color(0xFFB9763B)));
    // Maple planks run the length of the floor.
    b.bands(b.pitch, Colors.black.withValues(alpha: 0.07), 22);
    b.canvas.drawRect(
      b.pitch,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.22),
          ],
        ).createShader(b.pitch),
    );

    final line = b.line(Colors.white.withValues(alpha: 0.85), width: 0.06);
    final halfW = b.halfWidth;
    final halfL = b.halfLength;

    b.canvas.drawRect(b.pitch.deflate(b.m(0.3)), line);
    b.canvas.drawLine(b.at(-halfW, 0), b.at(halfW, 0), line);
    b.canvas.drawCircle(b.at(0, 0), b.m(1.8), line);

    for (final side in const [-1.0, 1.0]) {
      final baseline = halfL * side - 0.3 * side;
      // Restricted area (the key), 4.9 wide and 5.79 deep.
      final freeThrow = baseline - 5.79 * side;
      b.canvas.drawRect(
        Rect.fromPoints(b.at(-2.45, baseline), b.at(2.45, freeThrow)),
        line,
      );
      b.canvas.drawCircle(b.at(0, freeThrow), b.m(1.8), line);

      // Three-point line: a 6.75 m arc off the basket with straight returns
      // 0.9 m in from each sideline.
      final basket = baseline - 1.575 * side;
      final corner = math.sqrt(math.max(0, 6.75 * 6.75 - 6.6 * 6.6));
      for (final x in const [-6.6, 6.6]) {
        b.canvas.drawLine(
          b.at(x, baseline),
          b.at(x, basket - corner * side),
          line,
        );
      }
      b.canvas.drawArc(
        Rect.fromCircle(center: b.at(0, basket), radius: b.m(6.75)),
        side > 0 ? math.pi + math.asin(corner / 6.75) : math.asin(corner / 6.75),
        math.pi - math.asin(corner / 6.75) * 2,
        false,
        line,
      );

      // Backboard and hoop.
      b.canvas.drawLine(
        b.at(-0.9, baseline - 1.2 * side),
        b.at(0.9, baseline - 1.2 * side),
        b.line(Colors.white.withValues(alpha: 0.95), width: 0.12),
      );
      b.canvas.drawCircle(
        b.at(0, basket),
        b.m(0.45),
        b.line(const Color(0xFFFF7043), width: 0.1),
      );
    }
  },
);

// ---------------------------------------------------------------------------
// Volleyball — FIVB court, 9 × 18 m, with the free zone around it.
// ---------------------------------------------------------------------------

final _SurfaceSpec _volleyball = _SurfaceSpec(
  width: 9,
  length: 18,
  surface: const Color(0xFFD99328),
  surround: const Color(0xFF17496B),
  line: Colors.white.withValues(alpha: 0.9),
  paint: (b) {
    b.canvas.drawRect(b.pitch, b.fill(const Color(0xFFD99328)));
    b.canvas.drawRect(
      b.pitch,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.18),
          ],
        ).createShader(b.pitch),
    );

    final line = b.line(Colors.white.withValues(alpha: 0.9), width: 0.05);
    final halfW = b.halfWidth;

    b.canvas.drawRect(b.pitch.deflate(b.m(0.025)), line);
    // Attack lines sit 3 m either side of the centre line.
    for (final side in const [-1.0, 1.0]) {
      b.canvas.drawLine(b.at(-halfW, 3 * side), b.at(halfW, 3 * side), line);
    }

    // The net, with its posts standing in the free zone.
    b.canvas.drawLine(
      b.at(-halfW, 0),
      b.at(halfW, 0),
      b.line(Colors.white.withValues(alpha: 0.5), width: 0.05),
    );
    final mesh = b.line(Colors.white.withValues(alpha: 0.55), width: 0.04);
    for (var x = -halfW; x <= halfW; x += 1.1) {
      b.canvas.drawLine(b.at(x, -0.3), b.at(x, 0.3), mesh);
    }
    b.canvas.drawLine(b.at(-halfW, -0.35), b.at(halfW, -0.35), mesh);
    b.canvas.drawLine(b.at(-halfW, 0.35), b.at(halfW, 0.35), mesh);
    for (final x in [-halfW - 0.8, halfW + 0.8]) {
      b.spot(x, 0, Colors.white.withValues(alpha: 0.8), radius: 0.18);
    }
  },
);

// ---------------------------------------------------------------------------
// Tennis — ITF court, 10.97 × 23.77 m (doubles).
// ---------------------------------------------------------------------------

final _SurfaceSpec _tennis = _SurfaceSpec(
  width: 10.97,
  length: 23.77,
  surface: const Color(0xFF2C6E9B),
  surround: const Color(0xFF15402A),
  line: Colors.white.withValues(alpha: 0.9),
  paint: (b) {
    b.canvas.drawRect(b.pitch, b.fill(const Color(0xFF2C6E9B)));
    b.canvas.drawRect(
      b.pitch,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.20),
          ],
        ).createShader(b.pitch),
    );

    final line = b.line(Colors.white.withValues(alpha: 0.9), width: 0.05);
    final halfW = b.halfWidth;
    final halfL = b.halfLength;

    b.canvas.drawRect(b.pitch.deflate(b.m(0.025)), line);
    // Singles sidelines, 1.37 m inside the doubles lines.
    for (final x in [-halfW + 1.37, halfW - 1.37]) {
      b.canvas.drawLine(b.at(x, -halfL), b.at(x, halfL), line);
    }
    // Service lines 6.4 m from the net, joined by the centre service line.
    for (final side in const [-1.0, 1.0]) {
      b.canvas.drawLine(
        b.at(-halfW + 1.37, 6.4 * side),
        b.at(halfW - 1.37, 6.4 * side),
        line,
      );
      // Centre mark on each baseline.
      b.canvas.drawLine(b.at(0, halfL * side), b.at(0, (halfL - 0.3) * side), line);
    }
    b.canvas.drawLine(b.at(0, -6.4), b.at(0, 6.4), line);

    // Net across the middle, posts 0.91 m outside the doubles lines.
    final mesh = b.line(Colors.white.withValues(alpha: 0.5), width: 0.04);
    for (var x = -halfW - 0.91; x <= halfW + 0.91; x += 0.55) {
      b.canvas.drawLine(b.at(x, -0.3), b.at(x, 0.3), mesh);
    }
    b.canvas.drawLine(
      b.at(-halfW - 0.91, -0.3),
      b.at(halfW + 0.91, -0.3),
      b.line(Colors.white.withValues(alpha: 0.75), width: 0.08),
    );
    b.canvas.drawLine(b.at(-halfW - 0.91, 0.3), b.at(halfW + 0.91, 0.3), mesh);
  },
);

// ---------------------------------------------------------------------------
// Padel — FIP court, 10 × 20 m, inside a glass and mesh enclosure.
// ---------------------------------------------------------------------------

final _SurfaceSpec _padel = _SurfaceSpec(
  width: 10,
  length: 20,
  surface: const Color(0xFF1C5C86),
  surround: const Color(0xFF101B2A),
  line: Colors.white.withValues(alpha: 0.88),
  paint: (b) {
    b.canvas.drawRect(b.pitch, b.fill(const Color(0xFF1C5C86)));
    b.canvas.drawRect(
      b.pitch,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.22),
          ],
        ).createShader(b.pitch),
    );

    final line = b.line(Colors.white.withValues(alpha: 0.88), width: 0.05);
    final halfW = b.halfWidth;
    final halfL = b.halfLength;

    // Service lines 6.95 m from each back wall; the centre line only runs
    // between the service line and the wall.
    for (final side in const [-1.0, 1.0]) {
      final service = (halfL - 6.95) * side;
      b.canvas.drawLine(b.at(-halfW, service), b.at(halfW, service), line);
      b.canvas.drawLine(b.at(0, service), b.at(0, halfL * side), line);
    }

    final mesh = b.line(Colors.white.withValues(alpha: 0.5), width: 0.04);
    for (var x = -halfW; x <= halfW; x += 0.5) {
      b.canvas.drawLine(b.at(x, -0.25), b.at(x, 0.25), mesh);
    }
    b.canvas.drawLine(
      b.at(-halfW, 0),
      b.at(halfW, 0),
      b.line(Colors.white.withValues(alpha: 0.7), width: 0.06),
    );

    // The enclosure: glass across the ends, mesh down the sides, posts at the
    // corners and at the service-line joints, as a padel cage is built.
    b.canvas.save();
    b.canvas.clipRect(b.pitch);

    final mesh2 = b.line(const Color(0xFFBBD9EC).withValues(alpha: 0.20), width: 0.04);
    for (var y = -halfL; y <= halfL; y += 0.9) {
      b.canvas.drawLine(b.at(-halfW, y), b.at(-halfW + 0.5, y), mesh2);
      b.canvas.drawLine(b.at(halfW - 0.5, y), b.at(halfW, y), mesh2);
    }
    for (final side in const [-1.0, 1.0]) {
      // Glass panels behind each baseline read as a brighter band.
      b.canvas.drawRect(
        Rect.fromPoints(b.at(-halfW, halfL * side), b.at(halfW, (halfL - 0.5) * side)),
        b.fill(const Color(0xFFDCEEF9).withValues(alpha: 0.16)),
      );
    }
    b.canvas.restore();

    b.canvas.drawRect(
      b.pitch,
      b.line(const Color(0xFFBBD9EC).withValues(alpha: 0.5), width: 0.14),
    );
    for (final side in const [-1.0, 1.0]) {
      for (final x in [-halfW, halfW]) {
        b.spot(x, halfL * side, const Color(0xFFDCEEF9).withValues(alpha: 0.7),
            radius: 0.22);
      }
    }
  },
);
