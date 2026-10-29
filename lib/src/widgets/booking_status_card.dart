import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';

/// Where a booking stands, said at the top of the screens that show one:
/// the booking itself and the game that stands on it.
///
/// A status used to be one word inside the details card. It did not say
/// the thing a player needs: by when the money must be in, and what
/// happens to it if it is not.
class BookingStatusCard extends StatelessWidget {
  const BookingStatusCard({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final state = _BookingState.of(booking);
    final colors = context.colors;
    final tone = switch (state) {
      _BookingState.collecting || _BookingState.awaiting => colors.accent,
      _BookingState.confirmed => colors.success,
      _BookingState.expired || _BookingState.cancelled => colors.danger,
      _BookingState.unknown => colors.muted,
    };
    final icon = switch (state) {
      _BookingState.collecting => AppIcons.clock,
      _BookingState.awaiting => AppIcons.history,
      _BookingState.confirmed => AppIcons.checkCircle,
      _BookingState.expired || _BookingState.cancelled => AppIcons.x,
      _BookingState.unknown => AppIcons.clock,
    };
    final l10n = context.l10n;
    final title = switch (state) {
      _BookingState.collecting => l10n.bookingStateCollectingTitle,
      _BookingState.awaiting => l10n.payPendingTitle,
      _BookingState.confirmed => l10n.bookingStateConfirmedTitle,
      _BookingState.expired => l10n.bookingStateExpiredTitle,
      _BookingState.cancelled => l10n.bookingStateCancelledTitle,
      // A state this build has not heard of: the server's own word.
      _BookingState.unknown => booking.statusCode.capitalized,
    };
    final body = switch (state) {
      _BookingState.collecting => l10n.bookingStateCollectingBody(
        AppFormatters.moment(booking.deadline),
      ),
      _BookingState.awaiting => l10n.bookingStateAwaitingBody,
      _BookingState.confirmed => l10n.bookingStateConfirmedBody(
        '${AppFormatters.dateFull(booking.draft.date)}, '
        '${booking.draft.timeRange}',
      ),
      _BookingState.expired => l10n.bookingStateExpiredBody,
      _BookingState.cancelled || _BookingState.unknown => null,
    };
    final refund =
        state == _BookingState.expired || state == _BookingState.cancelled
        ? _refundLine(context)
        : null;
    final lines = [?body, ?refund];
    final counted =
        state == _BookingState.collecting && booking.shares.isNotEmpty;

    return Semantics(
      container: true,
      liveRegion: true,
      child: AppCard(
        key: ValueKey('booking-status-${booking.statusCode}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: context.scaled(44),
              height: context.scaled(44),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: tone),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (counted) ...[
                    const SizedBox(height: 2),
                    Text(
                      l10n
                          .bookingStatusCollectingPaid(
                            booking.paidShares,
                            booking.shares.length,
                          )
                          .capitalized,
                      style: context.text.bodyMedium?.copyWith(
                        color: tone,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: booking.paidShares / booking.shares.length,
                        minHeight: 6,
                        color: tone,
                        backgroundColor: colors.surfaceRaised,
                      ),
                    ),
                  ],
                  for (final line in lines) ...[
                    const SizedBox(height: 6),
                    Text(
                      line,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// What happens to the money once a booking is off. Said only when the
  /// shares are known: a booking sent without them may still have had money.
  String? _refundLine(BuildContext context) {
    final shares = booking.shares;
    if (shares.isEmpty) {
      return null;
    }
    final l10n = context.l10n;
    // A player reads about their own money: «оплат не было» is wrong for
    // someone who did not pay while the others did, and the other way round.
    final mine = booking.myShare;
    if (mine != null) {
      return switch (mine.status) {
        ShareStatus.refundDue ||
        ShareStatus.paid ||
        ShareStatus.pendingConfirmation => l10n.bookingStateRefundDue,
        ShareStatus.refunded => l10n.bookingStateRefunded,
        _ => l10n.bookingStateYouDidNotPay,
      };
    }
    if (shares.any((share) => share.status == ShareStatus.refundDue)) {
      return l10n.bookingStateRefundDue;
    }
    if (shares.any((share) => share.status == ShareStatus.refunded)) {
      return l10n.bookingStateRefunded;
    }
    if (shares.any((share) => share.status.holdsMoney)) {
      // The server has not marked the refund yet; the promise still holds.
      return l10n.bookingStateRefundDue;
    }
    return l10n.bookingStateNoMoney;
  }
}

enum _BookingState {
  collecting,
  awaiting,
  confirmed,
  expired,
  cancelled,
  unknown;

  static _BookingState of(Booking booking) => switch (booking.statusCode) {
    'collecting_shares' => collecting,
    'awaiting_confirmation' => awaiting,
    'confirmed' => confirmed,
    'expired' => expired,
    'cancelled' => cancelled,
    _ => unknown,
  };
}
