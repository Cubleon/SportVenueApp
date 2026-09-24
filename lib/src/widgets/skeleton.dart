import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A block standing in for something still on its way.
///
/// A spinner says "wait" and nothing else; a skeleton says what is coming and
/// how much of it, so the screen does not jump when the answer lands. The
/// shimmer is slow on purpose — fast movement on a surface that carries no
/// information reads as an error.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  /// A line of text at a given height, rounded like the type it replaces.
  const Skeleton.line({
    super.key,
    required this.width,
    this.height = 12,
    this.radius = 6,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              colors.surfaceRaised,
              colors.border,
              _pulse.value,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// A club in the list, before the club is known.
class VenueRowSkeleton extends StatelessWidget {
  const VenueRowSkeleton({super.key, this.divided = false});

  final bool divided;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: divided
            ? Border(top: BorderSide(color: context.colors.border))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(
            width: context.scaled(56, max: 1.2),
            height: context.scaled(56, max: 1.2),
            radius: 12,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Skeleton.line(width: 150, height: 14),
                const SizedBox(height: 8),
                const Skeleton.line(width: 110),
                const SizedBox(height: 10),
                Row(
                  children: const [
                    Skeleton.line(width: 62, height: 16, radius: 6),
                    SizedBox(width: 6),
                    Skeleton.line(width: 48, height: 16, radius: 6),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Skeleton.line(width: 56, height: 16),
              SizedBox(height: 8),
              Skeleton.line(width: 40),
            ],
          ),
        ],
      ),
    );
  }
}
