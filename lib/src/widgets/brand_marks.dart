import 'package:flutter/material.dart';

/// The marks of the sign-in providers.
///
/// Drawn on canvas rather than pulled from an icon pack: these three are the
/// only brand marks the app needs, and each provider expects its own colours
/// — a monochrome Google G is not the Google G. Nothing here is fetched, so
/// the buttons look the same offline.

/// Google's four-colour G.
///
/// The geometry is the official mark's own, converted from its 48x48 artwork
/// and normalised to a unit square — hand-fitted arcs kept reading as an 'e'.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final s = size.shortestSide;
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    for (final (path, colour) in [
      (_yellow(s), _yellowFill),
      (_red(s), _redFill),
      (_green(s), _greenFill),
      (_blue(s), _blueFill),
    ]) {
      canvas.drawPath(path, Paint()..color = colour);
    }
  }

  static const _yellowFill = Color(0xFFFFC107);
  static const _redFill = Color(0xFFFF3D00);
  static const _greenFill = Color(0xFF4CAF50);
  static const _blueFill = Color(0xFF1976D2);

  static Path _yellow(double s) => Path()
    ..moveTo(0.90856 * s, 0.41840 * s)
    ..lineTo(0.87500 * s, 0.41840 * s)
    ..lineTo(0.87500 * s, 0.41667 * s)
    ..lineTo(0.50000 * s, 0.41667 * s)
    ..lineTo(0.50000 * s, 0.58333 * s)
    ..lineTo(0.73548 * s, 0.58333 * s)
    ..cubicTo(
      0.70112 * s,
      0.68035 * s,
      0.60881 * s,
      0.75000 * s,
      0.50000 * s,
      0.75000 * s,
    )
    ..cubicTo(
      0.36194 * s,
      0.75000 * s,
      0.25000 * s,
      0.63806 * s,
      0.25000 * s,
      0.50000 * s,
    )
    ..cubicTo(
      0.25000 * s,
      0.36194 * s,
      0.36194 * s,
      0.25000 * s,
      0.50000 * s,
      0.25000 * s,
    )
    ..cubicTo(
      0.56373 * s,
      0.25000 * s,
      0.62171 * s,
      0.27404 * s,
      0.66585 * s,
      0.31331 * s,
    )
    ..lineTo(0.78371 * s, 0.19546 * s)
    ..cubicTo(
      0.70929 * s,
      0.12610 * s,
      0.60975 * s,
      0.08333 * s,
      0.50000 * s,
      0.08333 * s,
    )
    ..cubicTo(
      0.26990 * s,
      0.08333 * s,
      0.08333 * s,
      0.26990 * s,
      0.08333 * s,
      0.50000 * s,
    )
    ..cubicTo(
      0.08333 * s,
      0.73010 * s,
      0.26990 * s,
      0.91667 * s,
      0.50000 * s,
      0.91667 * s,
    )
    ..cubicTo(
      0.73010 * s,
      0.91667 * s,
      0.91667 * s,
      0.73010 * s,
      0.91667 * s,
      0.50000 * s,
    )
    ..cubicTo(
      0.91667 * s,
      0.47206 * s,
      0.91379 * s,
      0.44479 * s,
      0.90856 * s,
      0.41840 * s,
    )
    ..close();

  static Path _red(double s) => Path()
    ..moveTo(0.13137 * s, 0.30606 * s)
    ..lineTo(0.26827 * s, 0.40646 * s)
    ..cubicTo(
      0.30531 * s,
      0.31475 * s,
      0.39502 * s,
      0.25000 * s,
      0.50000 * s,
      0.25000 * s,
    )
    ..cubicTo(
      0.56373 * s,
      0.25000 * s,
      0.62171 * s,
      0.27404 * s,
      0.66585 * s,
      0.31331 * s,
    )
    ..lineTo(0.78371 * s, 0.19546 * s)
    ..cubicTo(
      0.70929 * s,
      0.12610 * s,
      0.60975 * s,
      0.08333 * s,
      0.50000 * s,
      0.08333 * s,
    )
    ..cubicTo(
      0.33996 * s,
      0.08333 * s,
      0.20117 * s,
      0.17369 * s,
      0.13137 * s,
      0.30606 * s,
    )
    ..close();

  static Path _green(double s) => Path()
    ..moveTo(0.50000 * s, 0.91667 * s)
    ..cubicTo(
      0.60762 * s,
      0.91667 * s,
      0.70542 * s,
      0.87548 * s,
      0.77935 * s,
      0.80850 * s,
    )
    ..lineTo(0.65040 * s, 0.69937 * s)
    ..cubicTo(
      0.60856 * s,
      0.73106 * s,
      0.55656 * s,
      0.75000 * s,
      0.50000 * s,
      0.75000 * s,
    )
    ..cubicTo(
      0.39163 * s,
      0.75000 * s,
      0.29960 * s,
      0.68090 * s,
      0.26494 * s,
      0.58446 * s,
    )
    ..lineTo(0.12906 * s, 0.68915 * s)
    ..cubicTo(
      0.19802 * s,
      0.82408 * s,
      0.33806 * s,
      0.91667 * s,
      0.50000 * s,
      0.91667 * s,
    )
    ..close();

  static Path _blue(double s) => Path()
    ..moveTo(0.90856 * s, 0.41840 * s)
    ..lineTo(0.87500 * s, 0.41840 * s)
    ..lineTo(0.87500 * s, 0.41667 * s)
    ..lineTo(0.50000 * s, 0.41667 * s)
    ..lineTo(0.50000 * s, 0.58333 * s)
    ..lineTo(0.73548 * s, 0.58333 * s)
    ..cubicTo(
      0.71898 * s,
      0.62994 * s,
      0.68900 * s,
      0.67012 * s,
      0.65033 * s,
      0.69940 * s,
    )
    ..cubicTo(
      0.65035 * s,
      0.69937 * s,
      0.65037 * s,
      0.69937 * s,
      0.65040 * s,
      0.69935 * s,
    )
    ..lineTo(0.77935 * s, 0.80848 * s)
    ..cubicTo(
      0.77023 * s,
      0.81677 * s,
      0.91667 * s,
      0.70833 * s,
      0.91667 * s,
      0.50000 * s,
    )
    ..cubicTo(
      0.91667 * s,
      0.47206 * s,
      0.91379 * s,
      0.44479 * s,
      0.90856 * s,
      0.41840 * s,
    )
    ..close();

  @override
  bool shouldRepaint(covariant _GooglePainter oldDelegate) => false;
}

/// VK's mark: their blue tile with the wordmark on it.
class VkMark extends StatelessWidget {
  const VkMark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0077FF),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Text(
        'VK',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.46,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: 1,
        ),
      ),
    );
  }
}

/// Apple's mark, from the Material icon set, which carries the real glyph.
class AppleMark extends StatelessWidget {
  const AppleMark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.apple, size: size * 1.2, color: const Color(0xFF111111));
  }
}
