import 'dart:math' as math;

import 'package:flutter/material.dart';

enum SportBallKind { soccer, basket, tennis }

/// Drawn, not photographed. The references float 3-D renders; a ball painted
/// from a couple of gradients and four arcs gets most of that lift without
/// shipping a megabyte of PNG per sport.
class SportBall extends StatelessWidget {
  const SportBall({
    super.key,
    required this.kind,
    required this.size,
    this.tilt = 0,
  });

  final SportBallKind kind;
  final double size;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x4D0B2A66),
              blurRadius: 24,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: CustomPaint(painter: _SportBallPainter(kind)),
      ),
    );
  }
}

class _SportBallPainter extends CustomPainter {
  const _SportBallPainter(this.kind);

  final SportBallKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final r = size.width / 2;
    final c = Offset(r, r);
    final rect = Rect.fromCircle(center: c, radius: r);

    final base = switch (kind) {
      SportBallKind.soccer => Colors.white,
      SportBallKind.basket => const Color(0xFFF2802A),
      SportBallKind.tennis => const Color(0xFFD9F24B),
    };
    canvas.drawCircle(c, r, Paint()..color = base);

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    switch (kind) {
      case SportBallKind.soccer:
        final dark = Paint()..color = const Color(0xFF15131C);
        for (final (dx, dy, k) in const [
          (0.0, -0.58, 0.22),
          (-0.56, 0.2, 0.19),
          (0.56, 0.22, 0.19),
          (0.0, 0.78, 0.18),
        ]) {
          canvas.drawCircle(c + Offset(dx * r, dy * r), k * r, dark);
        }
      case SportBallKind.basket:
        final line = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.075
          ..color = const Color(0xCC170A00);
        canvas.drawLine(Offset(0, r), Offset(size.width, r), line);
        canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 0.9, height: size.height * 1.5),
          line,
        );
        canvas.drawOval(
          Rect.fromCenter(center: c, width: size.width * 1.5, height: r * 0.9),
          line,
        );
      case SportBallKind.tennis:
        final seam = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.16
          ..color = Colors.white;
        canvas.drawArc(
          Rect.fromCenter(
            center: c + Offset(-r * 0.92, 0),
            width: r * 1.5,
            height: size.height * 1.05,
          ),
          -math.pi / 2.4,
          math.pi / 1.2,
          false,
          seam,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: c + Offset(r * 0.92, 0),
            width: r * 1.5,
            height: size.height * 1.05,
          ),
          math.pi / 1.7,
          math.pi / 1.2,
          false,
          seam,
        );
    }
    canvas.restore();

    // Light from the upper left, shade at the lower right: the two gradients
    // that turn a disc into a sphere.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 0.85,
          colors: [
            Colors.white.withValues(alpha: 0.7),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.45, 0.6),
          radius: 0.95,
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(
              alpha: kind == SportBallKind.soccer ? 0.2 : 0.32,
            ),
          ],
          stops: const [0.45, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SportBallPainter oldDelegate) => oldDelegate.kind != kind;
}
