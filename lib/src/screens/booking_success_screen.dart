import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../router.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

/// The moment a booking is made, given a screen of its own.
///
/// It says what was booked and what happens next, honestly: the hour is
/// held, not yet paid for, until the deadline. The way on is paying the
/// reader's own share; for a split booking, calling the others in too.
class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({
    super.key,
    required this.controller,
    required this.bookingId,
  });

  final AppController controller;
  final String bookingId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final booking = controller.bookingById(bookingId);
        if (booking == null) {
          return const SizedBox.shrink();
        }
        final share = booking.myShare;
        final split = booking.draft.mode == PaymentMode.split;
        final owed = booking.othersUnpaid;
        final deadline = _moment(booking.deadline);
        final amount = share?.amount ?? booking.draft.sharePrice;
        final canPay =
            share != null &&
            (share.status == ShareStatus.unpaid ||
                share.status == ShareStatus.notFound);
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
                    children: [
                      const Center(child: _SuccessMark()),
                      const SizedBox(height: 20),
                      Text(
                        context.l10n.bookingCreated,
                        textAlign: TextAlign.center,
                        style: context.text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.successHeld(deadline),
                        key: const ValueKey('success-held'),
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        split && owed > 0
                            ? context.l10n.bookingCreatedShares(owed)
                            : context.l10n.successFullBody,
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),
                      AppCard(child: BookingSummaryRows(draft: booking.draft)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      if (canPay) ...[
                        PrimaryButton(
                          key: const ValueKey('success-pay'),
                          label: context.l10n.payMyShare(
                            AppFormatters.money(amount),
                          ),
                          tone: ButtonTone.commit,
                          onPressed: () => context.go(Routes.pay(booking.id)),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (split && owed > 0 && canShareLinks) ...[
                        PrimaryButton(
                          key: const ValueKey('success-invite'),
                          label: context.l10n.invitePlayers,
                          tone: ButtonTone.neutral,
                          icon: AppIcons.share,
                          onPressed: () =>
                              copyLink(context, Routes.booking(booking.id)),
                        ),
                        const SizedBox(height: 10),
                      ],
                      PrimaryButton(
                        key: const ValueKey('success-open-booking'),
                        label: context.l10n.openBooking,
                        tone: ButtonTone.neutral,
                        onPressed: () => context.go(Routes.booking(booking.id)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A day and an hour, the way the rest of the app writes them.
String _moment(DateTime value) {
  final hours = value.hour.toString().padLeft(2, '0');
  final minutes = value.minute.toString().padLeft(2, '0');
  return '${AppFormatters.dateShort(value)}, $hours:$minutes';
}

/// The tick, arriving with a small spring so the moment registers. With
/// reduced motion it is simply there.
class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: context.motion(const Duration(milliseconds: 520)),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      ),
      child: Container(
        key: const ValueKey('success-mark'),
        width: context.scaled(88),
        height: context.scaled(88),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.success.withValues(alpha: 0.14),
        ),
        child: Icon(AppIcons.check, size: 42, color: colors.success),
      ),
    );
  }
}
