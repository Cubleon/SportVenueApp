import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../labels.dart';

import '../../l10n/l10n.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import 'sport_surface.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72, this.showWordmark = false});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size.square(size),
      painter: _LogoPainter(
        fill: context.colors.surface,
        line: context.colors.accent,
      ),
    );

    if (!showWordmark) {
      return mark;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            style: context.text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
            children: [
              const TextSpan(text: 'sport'),
              TextSpan(
                text: 'venue',
                style: TextStyle(color: context.colors.accent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.fill, required this.line});

  /// A painter sees no context, so the theme's colours are handed to it.
  final Color fill;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;
    final points = List.generate(6, (index) {
      final angle = -math.pi / 2 + index * math.pi / 3;
      return Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
    });
    final path = Path()..addPolygon(points, true);
    final inner = Path()
      ..addPolygon(
        List.generate(6, (index) {
          final angle = -math.pi / 2 + index * math.pi / 3;
          final innerRadius = radius * 0.68;
          return Offset(
            center.dx + math.cos(angle) * innerRadius,
            center.dy + math.sin(angle) * innerRadius,
          );
        }),
        true,
      );

    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = line.withValues(alpha: 0.35),
    );
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = line.withValues(alpha: 0.16),
    );
    canvas.drawLine(
      Offset(size.width * 0.22, center.dy),
      Offset(size.width * 0.78, center.dy),
      Paint()
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = line,
    );
    canvas.drawCircle(
      center,
      size.width * 0.15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = line,
    );
    canvas.drawCircle(center, size.width * 0.04, Paint()..color = line);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.line != line;
}

/// Wraps a tap that changes a choice so the hand hears it.
///
/// Selection feedback is the quietest of the three — a tick rather than a
/// knock — and it is what a picker, a chip or a stepper is meant to make.
/// Navigation is deliberately left silent: a tab that buzzes every time
/// stops meaning anything.
VoidCallback? withSelectionFeedback(VoidCallback? onTap) {
  if (onTap == null) {
    return null;
  }
  return () {
    HapticFeedback.selectionClick();
    onTap();
  };
}

/// How much weight a button carries.
enum ButtonTone {
  /// Ordinary actions: continue, join, create.
  accent,

  /// The quieter of two choices, or a way out. A flat neutral fill.
  neutral,

  /// Spends money or takes a slot. Dark, and used sparingly — if two of
  /// these sit together, neither reads as final.
  commit,

  /// Destroys something: cancels a paid booking, signs out. Red, and only
  /// ever the confirming button of a question already asked.
  danger,
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.tone = ButtonTone.accent,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final ButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final neutral = tone == ButtonTone.neutral;
    final background = !enabled
        ? context.colors.surfaceRaised
        : switch (tone) {
            ButtonTone.accent => context.colors.accent,
            ButtonTone.neutral => context.colors.surface,
            ButtonTone.commit => context.colors.commit,
            ButtonTone.danger => context.colors.danger,
          };
    final foreground = !enabled
        ? context.colors.dim
        : switch (tone) {
            ButtonTone.accent => context.colors.onAccent,
            ButtonTone.neutral => context.colors.ink,
            // The commit fill is near-black on a light page and near-white
            // on a dark one, so its label cannot follow the accent's.
            ButtonTone.commit => context.colors.onCommit,
            ButtonTone.danger => context.colors.onDanger,
          };

    return SizedBox(
      width: double.infinity,
      height: context.scaled(neutral ? 50 : 56),
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          disabledBackgroundColor: background,
          foregroundColor: foreground,
          disabledForegroundColor: foreground,
          shape: AppTheme.pill,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isLoading
              ? SizedBox(
                  key: ValueKey('loader'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: context.colors.onAccent,
                  ),
                )
              : Row(
                  key: ValueKey(label),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 19),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        // A button says what it does; truncated to
                        // "Оплатить свою часть ·…" it no longer does. The
                        // box grows with the text, so a second line fits.
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.05,
                          height: 1.15,
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

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  /// Overrides the white fill, for a card that summarises rather than lists.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: color ?? context.colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: content,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.15,
              ),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class SportBadge extends StatelessWidget {
  const SportBadge({super.key, required this.sport, this.compact = false});

  final Sport sport;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 26 : 30,
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 11),
      decoration: BoxDecoration(
        color: context.colors.surfaceRaised,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Text(
              sport.icon,
              style: TextStyle(fontSize: compact ? 11 : 13),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            sport.name.toUpperCase(),
            style: context.text.labelSmall?.copyWith(
              color: context.colors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final bool selected;

  /// Omit it for a chip that only reports a state and cannot be changed by
  /// tapping — a preference is not something to lose by accident.
  final VoidCallback? onTap;
  final String? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Colour alone tells a sighted reader which chip is on; a screen
      // reader needs to be told.
      selected: selected,
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: withSelectionFeedback(onTap),
          borderRadius: BorderRadius.circular(99),
          // A chip with no handler takes no touches, so it cannot ripple or
          // look pressable.
          excludeFromSemantics: onTap == null,
          child: Container(
            height: context.scaled(44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: selected ? context.colors.accent : context.colors.surface,
              borderRadius: BorderRadius.circular(99),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    // An emoji is decoration here: read aloud it becomes
                    // "soccer ball" in the middle of the label.
                    ExcludeSemantics(
                      child: Text(icon!, style: const TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    maxLines: 1,
                    style: context.text.labelLarge?.copyWith(
                      color: selected
                          ? context.colors.onAccent
                          : context.colors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The venue's surface, as a picture.
///
/// Nothing is written on top of it: white text over pitch markings never
/// reads cleanly, so the name and address sit under the image in ink where
/// the card owns them.
class VenueHero extends StatelessWidget {
  const VenueHero({super.key, required this.venue, this.height = 116});

  final Venue venue;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: SportSurface(sportId: venue.sportIds.first),
    );
  }
}

class BookingSummaryRows extends StatelessWidget {
  const BookingSummaryRows({super.key, required this.draft});

  final BookingDraft draft;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SummaryRow(
          label: context.l10n.summaryDate,
          value: AppFormatters.dateFull(draft.date),
        ),
        SummaryRow(label: context.l10n.summaryTime, value: draft.timeRange),
        SummaryRow(
          label: context.l10n.summaryVenue,
          value: draft.venue.name.capitalized,
        ),
        SummaryRow(
          label: context.l10n.summaryPlayers,
          value: '${draft.players}',
        ),
        SummaryRow(
          label: context.l10n.summaryTotal,
          value: AppFormatters.money(draft.totalPrice),
          highlight: true,
        ),
        SummaryRow(
          label: context.l10n.summaryYourShare,
          value: AppFormatters.money(draft.sharePrice),
          accent: true,
        ),
      ],
    );
  }
}

class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: context.text.bodyMedium?.copyWith(
                color: accent ? context.colors.accent : context.colors.ink,
                fontWeight: highlight || accent
                    ? FontWeight.w700
                    : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a snack is reporting, which decides what the hand feels.
enum SnackTone {
  /// A notice with no outcome attached: a stub, a hint, nothing happened.
  plain,

  /// Something went through — a booking paid, a game created. Worth a knock.
  done,

  /// Something would not go through. A heavier one, so a failed payment
  /// never feels the same as a success the reader half-saw.
  failed,
}

void showAppSnack(
  BuildContext context,
  String message, {
  SnackTone tone = SnackTone.plain,
}) {
  switch (tone) {
    case SnackTone.plain:
      break;
    case SnackTone.done:
      HapticFeedback.mediumImpact();
    case SnackTone.failed:
      HapticFeedback.heavyImpact();
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      // The text colour is named here on purpose: Material's own snack style
      // is written for a dark plate, so on a light one it turns invisible.
      content: Text(
        message,
        style: context.text.bodyMedium?.copyWith(
          color: context.colors.onCommit,
          fontWeight: FontWeight.w500,
        ),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: context.colors.commit,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: const StadiumBorder(),
    ),
  );
}

class ScreenTitleBar extends StatelessWidget {
  const ScreenTitleBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;

  /// Before the title. Where a way back belongs: every other screen in the
  /// app puts it there, and a thumb reaches the left corner.
  final Widget? leading;

  /// After the title. For what the screen does, not for leaving it.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          ?leading,
          if (leading != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.25,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Holds the actions pinned to the bottom of a flow.
///
/// A bar positioned over a scroll view needs a ground of its own: without
/// one the content slides up through the buttons and both become
/// unreadable. The short fade above it keeps the join from reading as a
/// hard edge.
class PinnedActionBar extends StatelessWidget {
  const PinnedActionBar({super.key, required this.child, this.onHeight});

  final Widget child;

  /// Reports the bar's laid-out height, so the scrolling content behind it
  /// can reserve exactly that much and no guessed constant has to be kept
  /// in step with the buttons — which grow with the system font.
  final ValueChanged<double>? onHeight;

  @override
  Widget build(BuildContext context) {
    final bar = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                context.colors.bg.withValues(alpha: 0),
                context.colors.bg,
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          color: context.colors.bg,
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
          child: child,
        ),
      ],
    );
    return onHeight == null
        ? bar
        : _MeasureHeight(onHeight: onHeight!, child: bar);
  }
}

/// Reports its child's height after every layout.
///
/// A bar that floats over a scroll view has to tell that view how much room
/// to leave, and only layout knows: the buttons inside it are sized by the
/// reader's font setting.
class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureHeightBox(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _MeasureHeightBox renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _MeasureHeightBox extends RenderProxyBox {
  _MeasureHeightBox(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (_reported != height) {
      _reported = height;
      // The listener rebuilds the screen, which cannot happen during layout.
      SchedulerBinding.instance.addPostFrameCallback((_) => onHeight(height));
    }
  }
}

/// One booking as a row: the date as a block, the venue, and its status.
class BookingRow extends StatelessWidget {
  const BookingRow({super.key, required this.booking, this.onTap});

  final Booking booking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: ValueKey('booking-row-${booking.id}'),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: context.scaled(56),
            height: context.scaled(62),
            decoration: BoxDecoration(
              color: context.colors.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppFormatters.weekdayShort(booking.draft.date).toUpperCase(),
                  style: context.text.labelSmall?.copyWith(
                    color: context.colors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${booking.draft.date.day}',
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.draft.venue.name.capitalized,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.bookingRowSubtitle(
                    booking.draft.timeRange,
                    bookingStatusText(context, booking),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: context.colors.dim),
        ],
      ),
    );
  }
}

/// The round back button used at the top of a pushed screen.
class BackCircleButton extends StatelessWidget {
  const BackCircleButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: context.l10n.back,
      onPressed: onTap,
      icon: const Icon(Icons.chevron_left_rounded),
      style: IconButton.styleFrom(
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.ink,
      ),
    );
  }
}

/// What a screen shows when a list comes back empty.
///
/// Always says why it is empty and, when a filter caused it, offers the way
/// out — an empty screen with no explanation and no exit leaves the reader
/// guessing whether the app is broken.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.accentSoft,
            ),
            child: Icon(icon, color: context.colors.accent, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.muted,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            PrimaryButton(
              label: actionLabel!,
              tone: ButtonTone.neutral,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

/// Asks before something irreversible happens, and answers true if the
/// reader said yes.
///
/// A paid booking used to disappear on a single tap of a button sitting
/// under the thumb, with nothing between the tap and the refund rules. This
/// is that missing step: it names what is about to go, and puts the way out
/// under the thumb instead.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  ButtonTone tone = ButtonTone.danger,
}) async {
  final answer = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.ink.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                key: const ValueKey('confirm-yes'),
                label: confirmLabel,
                tone: tone,
                onPressed: () => Navigator.pop(sheetContext, true),
              ),
              const SizedBox(height: 10),
              // Second, and neutral: the reader arrived here by accident far
              // more often than on purpose.
              PrimaryButton(
                key: const ValueKey('confirm-no'),
                label: cancelLabel ?? context.l10n.cancel,
                tone: ButtonTone.neutral,
                onPressed: () => Navigator.pop(sheetContext, false),
              ),
            ],
          ),
        ),
      );
    },
  );
  return answer ?? false;
}

/// Two weeks of days as a scrolling strip, one of them chosen.
class DateStrip extends StatelessWidget {
  const DateStrip({
    super.key,
    required this.now,
    required this.selected,
    required this.onSelect,
    this.days = 14,
  });

  final DateTime now;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final int days;

  @override
  Widget build(BuildContext context) {
    final start = DateTime(now.year, now.month, now.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Two weeks can cross a month, and a bare "1" after a "31" is a
        // riddle. The month of the day you are on answers it.
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            AppFormatters.monthGenitive(selected),
            style: context.text.labelSmall?.copyWith(color: context.colors.dim),
          ),
        ),
        SizedBox(
          height: context.scaled(88, max: 1.45),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final date = start.add(Duration(days: index));
              return _DayCard(
                date: date,
                isSelected: DateUtils.isSameDay(date, selected),
                isToday: index == 0,
                onTap: withSelectionFeedback(() => onSelect(date)),
              );
            },
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemCount: days,
          ),
        ),
      ],
    );
  }
}

/// One day in [DateStrip]. The chosen one grows and fills: on a screen where
/// every later step depends on the date, the date should be the thing your eye
/// lands on first.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: context.scaled(isSelected ? 74 : 60, max: 1.3),
          decoration: BoxDecoration(
            color: isSelected ? colors.accent : colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? colors.accent : colors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppFormatters.weekdayShort(date),
                style: context.text.labelSmall?.copyWith(
                  color: isSelected
                      ? colors.onAccent.withValues(alpha: 0.85)
                      : colors.dim,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${date.day}',
                style:
                    (isSelected
                            ? context.text.headlineSmall
                            : context.text.titleLarge)
                        ?.copyWith(
                          color: isSelected ? colors.onAccent : colors.ink,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.1,
                        ),
              ),
              if (isToday) ...[
                const SizedBox(height: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? colors.onAccent : colors.accent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DurationPicker extends StatelessWidget {
  const DurationPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final values = {
      60: context.l10n.durationHour,
      90: context.l10n.durationHourAndHalf,
      120: context.l10n.durationTwoHours,
    };
    return Row(
      children: values.entries.map((entry) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: entry.key == 120 ? 0 : 8),
            child: SelectableChip(
              label: entry.value,
              selected: value == entry.key,
              onTap: () => onChanged(entry.key),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// One time in a [TimeGrid].
class TimeTile extends StatelessWidget {
  const TimeTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.available = true,
  });

  final String label;
  final bool selected;
  final bool available;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: available ? withSelectionFeedback(onTap) : null,
      child: Semantics(
        selected: selected,
        button: available,
        enabled: available,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: selected
                ? context.colors.accent
                : available
                ? Colors.transparent
                : context.colors.ink.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? context.colors.accent
                  : available
                  ? context.colors.ink.withValues(alpha: 0.12)
                  : context.colors.ink.withValues(alpha: 0.05),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: context.text.titleSmall?.copyWith(
                color: selected
                    ? context.colors.onAccent
                    : available
                    ? context.colors.ink
                    : context.colors.dim,
                decoration: available ? null : TextDecoration.lineThrough,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Times, three to a row, every one of them visible.
class TimeGrid extends StatelessWidget {
  const TimeGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      // A fixed aspect ratio would keep the tile the same height however
      // large the time inside it is set to print.
      mainAxisExtent: context.scaled(52),
      children: tiles,
    );
  }
}

/// One club as a row: the pitch it offers, where it is, what it costs.
///
/// The same row wherever a club has to be chosen from several, because
/// choosing between them means comparing them, and two different layouts
/// for the same comparison make it harder than it is.
class VenueRow extends StatelessWidget {
  const VenueRow({
    super.key,
    required this.venue,
    required this.sport,
    required this.selected,
    required this.onTap,
    this.color,
    this.trailing,
  });

  final Venue venue;

  /// Which of the club's sports to draw. Under a filter it is the filtered
  /// one — a club listed under hockey drawing a football pitch reads as the
  /// wrong club.
  final Sport? sport;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  /// Defaults to a chevron, for a row that opens something. A picker passes
  /// its own mark instead.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        color: color,
        borderColor: selected ? context.colors.accent : context.colors.border,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: context.scaled(56),
                height: context.scaled(56),
                child: SportSurface(sportId: sport?.id ?? 'football'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name.capitalized,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.venueAddressDistance(
                      venue.address,
                      venue.distanceKm.toStringAsFixed(1),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 15,
                        color: context.colors.ink,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        venue.rating.toStringAsFixed(1),
                        style: context.text.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.l10n.pricePerHour(
                          AppFormatters.money(venue.pricePerHour),
                        ),
                        style: context.text.labelMedium?.copyWith(
                          color: context.colors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded, color: context.colors.dim),
          ],
        ),
      ),
    );
  }
}
