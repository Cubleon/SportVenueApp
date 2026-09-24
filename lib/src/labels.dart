import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';
import 'data/api_client.dart';
import 'models/sport_venue_models.dart';
import 'data/app_controller.dart';

/// Values the app holds as codes, put into the reader's language.
///
/// The data layer classifies and the server labels; neither has any
/// business knowing which language it is being read in, so the sentences
/// live here, where the context does.

/// Puts whatever went wrong into words.
///
/// The classification lives in the controller, which has no business
/// knowing which language it is being read in; the sentence lives here,
/// where the context does.
String errorText(BuildContext context, Object error) =>
    errorTextFor(context.l10n, error);

/// The same words, for a caller that took its strings before awaiting and
/// no longer has a context it is allowed to touch.
String errorTextFor(L l10n, Object error) {
  return switch (AppController.kindOf(error)) {
    AppErrorKind.network => l10n.errorNetwork,
    AppErrorKind.invalidResponse => l10n.errorInvalidResponse,
    AppErrorKind.sessionExpired => l10n.errorSessionExpired,
    AppErrorKind.slotTaken => l10n.errorSlotTaken,
    AppErrorKind.gameFull => l10n.errorGameFull,
    AppErrorKind.cancelNotOrganizer => l10n.errorCancelNotOrganizer,
    AppErrorKind.badPhone => l10n.errorBadPhone,
    AppErrorKind.invalidCode => l10n.errorInvalidCode,
    AppErrorKind.challengeExpired => l10n.errorChallengeExpired,
    AppErrorKind.tooManyAttempts => l10n.errorTooManyAttempts,
    AppErrorKind.timeout => l10n.errorTimeout,
    AppErrorKind.serverSaidSo when error is ApiException => error.message,
    _ => l10n.errorUnknown,
  };
}

/// A booking's state, which the server sends as a code.
///
/// While the money is being collected the state is a count, not a word:
/// "оплатили 2 из 4" answers the question the reader actually has, which
/// "сбор долей" never did.
String bookingStatusText(BuildContext context, Booking booking) {
  if (booking.isCollectingShares && booking.shares.isNotEmpty) {
    return context.l10n.bookingStatusCollectingPaid(
      booking.paidShares,
      booking.shares.length,
    );
  }
  return switch (booking.statusCode) {
    'collecting_shares' => context.l10n.bookingStatusCollecting,
    'confirmed' => context.l10n.bookingStatusConfirmed,
    'cancelled' => context.l10n.bookingStatusCancelled,
    'expired' => context.l10n.bookingStatusExpired,
    // A state this build has not heard of: better the server's own word
    // than nothing at all.
    _ => booking.statusCode,
  };
}

/// How long until a game starts, said the way a person would.
///
/// A date tells you when; "через 2 ч 40 мин" tells you whether to put your
/// boots in the bag now. Past the end of tomorrow the countdown stops being
/// useful and the caller shows the date instead, so this returns null.
String? countdownText(BuildContext context, DateTime startsAt, DateTime now) {
  final left = startsAt.difference(now);
  if (left.isNegative) {
    return context.l10n.gameRunning;
  }
  if (left.inMinutes < 60) {
    return context.l10n.startsInMinutes(left.inMinutes);
  }
  if (left.inHours < 12) {
    return context.l10n.startsInHours(left.inHours, left.inMinutes % 60);
  }
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  if (DateUtils.isSameDay(startsAt, tomorrow)) {
    return context.l10n.startsTomorrow(
      '${startsAt.hour.toString().padLeft(2, '0')}:00',
    );
  }
  return null;
}
