import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../theme/app_icons.dart';

import '../labels.dart';

import '../../l10n/l10n.dart';

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../router.dart';
import '../widgets/booking_status_card.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/venue_picker.dart';
import '../widgets/venue_slot_picker.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.controller,
    required this.venue,
    this.date,
  });

  final AppController controller;
  final Venue venue;

  /// The day the screen opens on. The home screen sends the day its calendar
  /// is showing, so picking Friday there and tapping a club does not land you
  /// back on today.
  final DateTime? date;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  /// Measured, because the bar's buttons grow with the system font.
  double _barHeight = 200;

  void _onBarHeight(double height) {
    if (mounted && height != _barHeight) {
      setState(() => _barHeight = height);
    }
  }

  /// The day, if one has been chosen. A reader arriving from the home
  /// brings the day its calendar was showing; one arriving from the tab bar
  /// has not said yet, and the steps below wait for them.
  late DateTime? _date = widget.date;
  late Venue _venue = widget.venue;
  int _duration = 60;

  /// The hour, once it is picked. It used to start at eight in the evening
  /// with the pay button already live above it, so the screen could be paid
  /// for an hour nobody had chosen.
  int? _hour;
  int _players = 4;

  /// Set by the slot picker, which is the only thing that knows whether the
  /// hour on screen is one the club will take.
  bool _slotReady = false;

  bool get _dateChosen => _date != null;
  bool get _timeChosen => _hour != null && _slotReady;

  /// Only makes sense once a day and an hour exist.
  BookingDraft get _draft => BookingDraft(
    venue: _venue,
    date: _date!,
    durationMinutes: _duration,
    startHour: _hour!,
    players: _players,
    mode: PaymentMode.split,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  // The club is named by the step below, which is also where
                  // it can be changed.
                  child: ScreenTitleBar(
                    title: context.l10n.booking,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: VenueHero(venue: _venue, height: 138),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _StepBlock(
                    step: 1,
                    title: context.l10n.venueStep,
                    // The club arrives with the screen, but it is still a
                    // choice: comparing two clubs' free hours used to mean
                    // going back out and starting over.
                    child: VenueRow(
                      key: const ValueKey('booking-venue-field'),
                      venue: _venue,
                      sport: _sportOf(_venue),
                      selected: false,
                      onTap: _pickVenue,
                      trailing: Icon(
                        AppIcons.chevronDown,
                        color: context.colors.dim,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _StepBlock(
                    step: 2,
                    title: context.l10n.dateStep,
                    child: DateStrip(
                      now: widget.controller.now,
                      selected: _date,
                      onSelect: (date) => setState(() {
                        _date = date;
                        // A different day has different free hours; the one
                        // that was picked on the old day is not a choice on
                        // this one.
                        _hour = null;
                        _slotReady = false;
                      }),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealStep(
                    visible: _dateChosen,
                    child: _StepBlock(
                      step: 3,
                      title: context.l10n.durationStep,
                      child: DurationPicker(
                        value: _duration,
                        onChanged: (value) => setState(() => _duration = value),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealStep(
                    visible: _dateChosen,
                    child: _StepBlock(
                      step: 4,
                      title: context.l10n.timeStep,
                      child: VenueSlotPicker(
                        key: ValueKey(
                          'slots-${_venue.id}-${_date?.toIso8601String()}',
                        ),
                        controller: widget.controller,
                        venue: _venue,
                        date: _date ?? widget.controller.now,
                        durationMinutes: _duration,
                        selectedHour: _hour,
                        onHourChanged: (hour) => setState(() => _hour = hour),
                        onReadyChanged: (ready) {
                          if (ready != _slotReady) {
                            setState(() => _slotReady = ready);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealStep(
                    visible: _timeChosen,
                    child: _StepBlock(
                      step: 5,
                      title: context.l10n.playersStep,
                      child: Column(
                        children: [
                          _CounterRow(
                            value: _players,
                            min: _venue.capacityMin,
                            max: _venue.capacityMax,
                            onChanged: (value) =>
                                setState(() => _players = value),
                          ),
                          const SizedBox(height: 14),
                          if (_timeChosen)
                            AppCard(child: BookingSummaryRows(draft: _draft)),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealStep(
                    visible: _timeChosen,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: _timeChosen
                          ? _PaymentExplainerCard(draft: _draft)
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealStep(
                    visible: _timeChosen,
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _CancellationTermsCard(),
                    ),
                  ),
                ),
                // Room for the pinned bar, which floats over the content.
                SliverToBoxAdapter(
                  child: SizedBox(height: _timeChosen ? _barHeight : 24),
                ),
              ],
            ),
            // No bar until there is an hour to pay for: the price of a
            // booking nobody has finished describing is not a price.
            if (_timeChosen)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: PinnedActionBar(
                  onHeight: _onBarHeight,
                  child: Column(
                    children: [
                      // What the money is for. The hour is chosen four steps
                      // up the page and the button used to carry only a price,
                      // so the one part of the deal that changes was the one
                      // part the reader could not see while paying.
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${AppFormatters.dateShort(_date!)} · '
                          '${_draft.timeRange} · ${_venue.name.capitalized}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      PrimaryButton(
                        key: const ValueKey('pay-share'),
                        label: context.l10n.paySharePrice(
                          AppFormatters.money(_draft.sharePrice),
                        ),
                        tone: ButtonTone.commit,
                        onPressed: _canContinue
                            ? () => _goToConfirm(PaymentMode.split)
                            : null,
                      ),
                      const SizedBox(height: 10),
                      PrimaryButton(
                        key: const ValueKey('pay-full'),
                        label: context.l10n.payFullPrice(
                          AppFormatters.money(_draft.totalPrice),
                        ),
                        tone: ButtonTone.neutral,
                        onPressed: _canContinue
                            ? () => _goToConfirm(PaymentMode.full)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool get _canContinue => _slotReady;

  /// The club's own first sport, which is what [VenueHero] above draws. Two
  /// pictures of the same club disagreeing reads as a mistake.
  Sport? _sportOf(Venue venue) {
    final id = primarySportId(venue);
    for (final sport in widget.controller.sports) {
      if (sport.id == id) {
        return sport;
      }
    }
    return null;
  }

  Future<void> _pickVenue() async {
    final picked = await pickVenue(
      context,
      venues: widget.controller.venues,
      selected: _venue,
      sportOf: _sportOf,
    );
    if (picked == null || !mounted || picked.id == _venue.id) {
      return;
    }
    setState(() {
      _venue = picked;
      // Clubs take different numbers of players; carrying a count the new
      // one will not accept would be rejected at payment.
      _players = _players.clamp(picked.capacityMin, picked.capacityMax);
    });
  }

  void _goToConfirm(PaymentMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(
          controller: widget.controller,
          draft: _draft.copyWith(mode: mode),
        ),
      ),
    );
  }
}

class BookingConfirmationScreen extends StatefulWidget {
  const BookingConfirmationScreen({
    super.key,
    required this.controller,
    required this.draft,
  });

  final AppController controller;
  final BookingDraft draft;

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  /// Measured, because the bar's buttons grow with the system font.
  double _barHeight = 136;

  void _onBarHeight(double height) {
    if (mounted && height != _barHeight) {
      setState(() => _barHeight = height);
    }
  }

  bool _loading = false;

  int get _paymentAmount {
    return widget.draft.mode == PaymentMode.split
        ? widget.draft.sharePrice
        : widget.draft.totalPrice;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, _barHeight),
              children: [
                ScreenTitleBar(
                  padding: EdgeInsets.zero,
                  title: context.l10n.confirmation,
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
                _BookingDetailsCard(draft: widget.draft),
                const SizedBox(height: 12),
                const _CancellationTermsCard(),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PinnedActionBar(
                onHeight: _onBarHeight,
                child: Column(
                  children: [
                    // The sentence says the press is the agreement, so a box
                    // beside it asked for the same consent twice — and asked
                    // for it pre-ticked, which is not consent at all.
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        context.l10n.payConsent,
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.muted,
                          height: 1.35,
                        ),
                      ),
                    ),
                    PrimaryButton(
                      key: const ValueKey('confirm-payment'),
                      label: context.l10n.goToPayment(
                        AppFormatters.money(_paymentAmount),
                      ),
                      tone: ButtonTone.commit,
                      isLoading: _loading,
                      onPressed: _loading ? null : _pay,
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      key: const ValueKey('close-booking-checkout'),
                      label: context.l10n.goBack,
                      tone: ButtonTone.neutral,
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pay() async {
    setState(() => _loading = true);
    try {
      final booking = await widget.controller.addBooking(widget.draft);
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      // Said in the hand as well as on the screen: the snack used to carry
      // this, and the success screen that replaced it should not be quieter.
      // Not awaited: the buzz is a side effect, and on a platform whose
      // channel never answers, awaiting it holds the screen on a payment
      // that has already gone through.
      unawaited(HapticFeedback.mediumImpact());
      // The moment gets a screen of its own, which says what is held until
      // when, and leads on to paying the reader's share.
      context.go(Routes.created(booking.id));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      showAppSnack(context, errorText(context, error), tone: SnackTone.failed);
    }
  }
}

class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({
    super.key,
    required this.controller,
    required this.booking,
  });

  final AppController controller;
  final Booking booking;

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  /// Measured, because the bar's buttons grow with the system font.
  double _barHeight = 112;

  void _onBarHeight(double height) {
    if (mounted && height != _barHeight) {
      setState(() => _barHeight = height);
    }
  }

  bool _loading = false;

  /// The booking as it stands now: paying, a confirmation or the deadline
  /// change it while the screen is open, and the copy it was opened with
  /// would go on showing the old shares.
  Booking get _booking =>
      widget.controller.bookingById(widget.booking.id) ?? widget.booking;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => _build(context, _booking),
    );
  }

  Widget _build(BuildContext context, Booking booking) {
    // A booking that is over has nothing left to cancel.
    final canCancel =
        booking.isActive && widget.controller.canCancelBooking(booking);
    final mine = booking.myShare;
    // The reader's own share is the one thing on this screen they can do
    // something about; it gets the button, and the cancel goes under it.
    final canPay =
        booking.isActive &&
        mine != null &&
        (mine.status == ShareStatus.unpaid ||
            mine.status == ShareStatus.notFound ||
            mine.status == ShareStatus.pendingConfirmation);
    // Someone who came by a friend's link and has no place yet: the one
    // thing to do here is to take one.
    final outsider = mine == null && !canCancel;
    final canTake =
        outsider && booking.isCollectingShares && booking.openShares > 0;
    final hasBar = canCancel || canPay || canTake;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                hasBar ? _barHeight : 24,
              ),
              children: [
                ScreenTitleBar(
                  padding: EdgeInsets.zero,
                  title: context.l10n.bookingDetails,
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
                BookingStatusCard(booking: booking),
                const SizedBox(height: 12),
                // The state is said once, by the card above.
                _BookingDetailsCard(draft: booking.draft),
                if (booking.shares.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SharesCard(booking: booking),
                ],
                const SizedBox(height: 12),
                const _CancellationTermsCard(),
                if (!canCancel && !canTake) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    child: Text(
                      mine != null
                          ? context.l10n.onlyOrganizerCancels
                          : booking.isCollectingShares
                          ? context.l10n.takeShareNoPlaces
                          : context.l10n.takeShareClosed,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.muted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (hasBar)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: PinnedActionBar(
                  onHeight: _onBarHeight,
                  child: Column(
                    children: [
                      if (canTake)
                        PrimaryButton(
                          key: const ValueKey('take-share'),
                          label: context.l10n.takeShareButton(
                            AppFormatters.money(_openShareAmount(booking)),
                          ),
                          tone: ButtonTone.commit,
                          isLoading: _taking,
                          onPressed: _taking ? null : _take,
                        ),
                      if (canPay)
                        PrimaryButton(
                          key: const ValueKey('pay-my-share'),
                          label: mine.status == ShareStatus.pendingConfirmation
                              ? context.l10n.payPendingTitle
                              : context.l10n.payMyShare(
                                  AppFormatters.money(
                                    mine.amount ?? booking.draft.sharePrice,
                                  ),
                                ),
                          tone: ButtonTone.commit,
                          onPressed: () => context.go(Routes.pay(booking.id)),
                        ),
                      if (canPay && canCancel) const SizedBox(height: 10),
                      if (canCancel)
                        PrimaryButton(
                          key: const ValueKey('cancel-booking'),
                          label: context.l10n.cancelBooking,
                          tone: ButtonTone.neutral,
                          isLoading: _loading,
                          onPressed: _loading ? null : _cancel,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _taking = false;

  int _openShareAmount(Booking booking) =>
      booking.shares
          .where((share) => share.isOpen)
          .map((share) => share.amount)
          .nonNulls
          .firstOrNull ??
      booking.draft.sharePrice;

  /// Takes a free place and goes straight to paying for it: the place is
  /// held only until the deadline, and paying is why the link was sent.
  Future<void> _take() async {
    setState(() => _taking = true);
    try {
      final booking = await widget.controller.takeShare(_booking);
      if (!mounted) {
        return;
      }
      setState(() => _taking = false);
      context.go(Routes.pay(booking.id));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _taking = false);
      showAppSnack(context, errorText(context, error), tone: SnackTone.failed);
    }
  }

  Future<void> _cancel() async {
    final draft = _booking.draft;
    final confirmed = await confirmAction(
      context,
      title: context.l10n.cancelBookingQuestion,
      message: context.l10n.cancelBookingMessage(
        draft.venue.name.capitalized,
        AppFormatters.dateFull(draft.date),
        draft.timeRange,
      ),
      confirmLabel: context.l10n.cancelBooking,
      cancelLabel: context.l10n.keepBooking,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.controller.cancelBooking(_booking);
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      showAppSnack(
        context,
        context.l10n.bookingCancelled,
        tone: SnackTone.done,
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      showAppSnack(context, errorText(context, error), tone: SnackTone.failed);
    }
  }
}

class _BookingDetailsCard extends StatelessWidget {
  const _BookingDetailsCard({required this.draft});

  final BookingDraft draft;

  @override
  Widget build(BuildContext context) {
    return AppCard(child: BookingSummaryRows(draft: draft));
  }
}

/// Who has paid their part and who has not.
///
/// A booking that is collecting shares raises exactly one question, and the
/// old label answered none of it: the organiser could not tell whom to
/// remind, and the others could not tell whether they were the ones holding
/// it up.
class _SharesCard extends StatelessWidget {
  const _SharesCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final unpaid = booking.shares.length - booking.paidShares;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.sharesTitle,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                unpaid == 0
                    ? context.l10n.sharesAllPaid
                    : context.l10n.sharesLeft(unpaid),
                style: context.text.bodySmall?.copyWith(
                  color: unpaid == 0
                      ? context.colors.success
                      : context.colors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final share in booking.shares)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: context.scaled(34),
                    height: context.scaled(34),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: share.isPaid
                          ? context.colors.accentSoft
                          : context.colors.surfaceRaised,
                    ),
                    child: Text(
                      share.initial,
                      style: context.text.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: share.isPaid
                            ? context.colors.accent
                            : context.colors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      share.isOpen ? context.l10n.shareOpenSeat : share.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: share.isCurrentUser
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // The mark carries the state too: paid and not paid must
                  // not differ by colour alone.
                  Icon(
                    share.isPaid ? AppIcons.checkCircle : AppIcons.clock,
                    size: 18,
                    color: share.isPaid
                        ? context.colors.success
                        : context.colors.dim,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    shareStatusText(context, share.status),
                    style: context.text.bodySmall?.copyWith(
                      color: share.isPaid
                          ? context.colors.success
                          : context.colors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          // The organiser's actual job, once the money is in: chasing the
          // other shares. The card said who had not paid and offered nothing
          // to do about it, and the booking dies two hours before kick-off
          // if they never do.
          if (unpaid > 0 && canShareLinks) ...[
            const SizedBox(height: 4),
            PrimaryButton(
              key: const ValueKey('invite-to-booking'),
              label: context.l10n.invitePlayers,
              tone: ButtonTone.neutral,
              icon: AppIcons.share,
              onPressed: () => copyLink(context, Routes.booking(booking.id)),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the two buttons below actually mean.
///
/// «Оплатить свою часть» asks for a quarter of the price and says nothing
/// about the other three quarters — who pays them, by when, and what
/// happens if nobody does. Until this card the answer lived on the next
/// screen, in the small print, after the decision had been made.
class _PaymentExplainerCard extends StatelessWidget {
  const _PaymentExplainerCard({required this.draft});

  final BookingDraft draft;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.howPaymentWorks,
            style: AppTheme.sectionLabel(context),
          ),
          const SizedBox(height: 12),
          _ExplainerRow(
            title: context.l10n.payShareTitle(
              AppFormatters.money(draft.sharePrice),
            ),
            body: context.l10n.payShareExplainer(
              draft.players - 1,
              AppFormatters.money(draft.totalPrice),
            ),
          ),
          const SizedBox(height: 12),
          _ExplainerRow(
            title: context.l10n.payFullTitle(
              AppFormatters.money(draft.totalPrice),
            ),
            body: context.l10n.payFullExplainer,
          ),
        ],
      ),
    );
  }
}

class _ExplainerRow extends StatelessWidget {
  const _ExplainerRow({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          body,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.muted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _CancellationTermsCard extends StatelessWidget {
  const _CancellationTermsCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.cancellationTerms,
            style: AppTheme.sectionLabel(context),
          ),
          const SizedBox(height: 12),
          _Bullet(text: context.l10n.cancellationTermAuto),
          _Bullet(text: context.l10n.cancellationTermRefund),
        ],
      ),
    );
  }
}

class _StepBlock extends StatelessWidget {
  const _StepBlock({
    required this.step,
    required this.title,
    required this.child,
  });

  final int step;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: context.scaled(22),
                height: context.scaled(22),
                decoration: BoxDecoration(
                  color: context.colors.accent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$step',
                    style: context.text.labelSmall?.copyWith(
                      // On the accent, not beside it: near-black on blue is
                      // 2.6:1, which is a number you have to hunt for.
                      color: context.colors.onAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // The pair sits together on the right. Split to the two edges of the
    // screen, changing four into six meant carrying a thumb three hundred
    // pixels across and back for every step.
    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.playersCount(value),
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        StepperButton(
          key: const ValueKey('players-minus'),
          icon: AppIcons.minus,
          label: context.l10n.removePlayer,
          enabled: value > min,
          onTap: withSelectionFeedback(() => onChanged(value - 1))!,
        ),
        const SizedBox(width: 10),
        StepperButton(
          key: const ValueKey('players-plus'),
          icon: AppIcons.plus,
          label: context.l10n.addPlayer,
          enabled: value < max,
          onTap: withSelectionFeedback(() => onChanged(value + 1))!,
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(
              color: context.colors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.muted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Holds the actions pinned to the bottom of a flow.
///
/// Without a ground of its own, content scrolls up through a floating button
/// and both become unreadable; the fade above it keeps the join from looking
/// like a hard edge.
