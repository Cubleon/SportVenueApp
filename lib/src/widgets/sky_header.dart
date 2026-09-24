import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'sport_ball.dart';

/// The top of a tab: the app's colour running under the status bar, the
/// screen's name at display size on it, and an object breaking out of it.
///
/// The wash ends in exactly the page colour, so there is no edge between the
/// loud top and the calm list below — the same join the home screen makes,
/// which is what keeps four tabs looking like one app.
class SkyHeader extends StatelessWidget {
  const SkyHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.ball,
    this.child,
  });

  final String title;
  final String? subtitle;

  /// What the screen does, not how to leave it.
  final Widget? trailing;

  /// The object that breaks out of the field. Each tab gets its own, so the
  /// screens are told apart before a word is read.
  final SportBallKind? ball;

  /// Anything that belongs on the colour rather than on the page — a search
  /// field, a row of pills.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final kind = ball;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.skyTop, colors.skyLow, colors.bg],
          stops: const [0, 0.62, 1],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (kind != null)
            // Low and to the right, where it crosses the field's edge onto the
            // page. Up top it would sit under whatever the screen puts in the
            // corner.
            Positioned(
              right: -30,
              bottom: -16,
              child: SportBall(
                kind: kind,
                size: context.scaled(84, max: 1.15),
                tilt: 0.18,
              ),
            ),
          // A short header would compress the wash into a bar with a visible
          // end. The floor gives the fade room to be a fade.
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: topInset + context.scaled(146, max: 1.3),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topInset + 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: context.text.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                                height: 1.05,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                subtitle!,
                                style: context.text.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 12),
                        trailing!,
                      ],
                    ],
                  ),
                  if (child != null) ...[
                    SizedBox(height: context.scaled(18, max: 1.3)),
                    child!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A round button for the colour: the theme's icon buttons are drawn for a
/// pale page and disappear on it.
class SkyIconButton extends StatelessWidget {
  const SkyIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;

  /// Spoken by a screen reader, which has no icon to look at.
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.white.withValues(alpha: 0.18),
          shape: CircleBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: context.scaled(44, max: 1.25),
              height: context.scaled(44, max: 1.25),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
