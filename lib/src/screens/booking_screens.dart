import 'package:flutter/material.dart';

import '../labels.dart';

import '../../l10n/l10n.dart';

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
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

  late DateTime _date =
      widget.date ??
      DateTime(
        widget.controller.now.year,
        widget.controller.now.month,
        widget.controller.now.day,
      );
  late Venue _venue = widget.venue;
  int _duration = 60;
  int _hour = 20;
  int _players = 4;

  /// Set by the slot picker, which is the only thing that knows whether the
  /// hour on screen is one the club will take.
  bool _slotReady = false;

  BookingDraft get _draft => BookingDraft(
    venue: _venue,
    date: _date,
    durationMinutes: _duration,
    startHour: _hour,
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
                  child: _BookingHeader(
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
                        Icons.expand_more_rounded,
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
                      onSelect: (date) => setState(() => _date = date),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _StepBlock(
                    step: 3,
                    title: context.l10n.durationStep,
                    child: DurationPicker(
                      value: _duration,
                      onChanged: (value) => setState(() => _duration = value),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _StepBlock(
                    step: 4,
                    title: context.l10n.timeStep,
                    child: VenueSlotPicker(
                      controller: widget.controller,
                      venue: _venue,
                      date: _date,
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
                SliverToBoxAdapter(
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
                        AppCard(child: BookingSummaryRows(draft: _draft)),
                      ],
                    ),
                  ),
                ),
                // Room for the pinned bar, which floats over the content.
                SliverToBoxAdapter(child: SizedBox(height: _barHeight)),
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
    for (final sport in widget.controller.sports) {
      if (sport.id == venue.sportIds.first) {
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

  bool _accepted = true;
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
                _BookingNav(
                  title: context.l10n.confirmation,
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
                _BookingDetailsCard(draft: widget.draft),
                const SizedBox(height: 12),
                const _CancellationTermsCard(),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => setState(() => _accepted = !_accepted),
                  borderRadius: BorderRadius.circular(16),
                  child: AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _accepted,
                          activeColor: context.colors.accent,
                          onChanged: (value) =>
                              setState(() => _accepted = value ?? false),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              context.l10n.payConsent,
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.muted,
                                height: 1.42,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                    PrimaryButton(
                      key: const ValueKey('confirm-payment'),
                      label: context.l10n.goToPayment(
                        AppFormatters.money(_paymentAmount),
                      ),
                      tone: ButtonTone.commit,
                      isLoading: _loading,
                      onPressed: _accepted ? _pay : null,
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
      await widget.controller.addBooking(widget.draft);
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      showAppSnack(context, context.l10n.paymentDone, tone: SnackTone.done);
      Navigator.of(context).popUntil((route) => route.isFirst);
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

  @override
  Widget build(BuildContext context) {
    final canCancel = widget.controller.canCancelBooking(widget.booking);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                canCancel ? _barHeight : 24,
              ),
              children: [
                _BookingNav(
                  title: context.l10n.bookingDetails,
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 12),
                _BookingDetailsCard(
                  draft: widget.booking.draft,
                  status: bookingStatusText(context, widget.booking),
                ),
                if (widget.booking.shares.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SharesCard(booking: widget.booking),
                ],
                const SizedBox(height: 12),
                const _CancellationTermsCard(),
                if (!canCancel) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    child: Text(
                      context.l10n.onlyOrganizerCancels,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.muted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (canCancel)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: PinnedActionBar(
                  onHeight: _onBarHeight,
                  child: PrimaryButton(
                    key: const ValueKey('cancel-booking'),
                    label: context.l10n.cancelBooking,
                    tone: ButtonTone.neutral,
                    isLoading: _loading,
                    onPressed: _loading ? null : _cancel,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    final draft = widget.booking.draft;
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
      await widget.controller.cancelBooking(widget.booking);
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
  const _BookingDetailsCard({required this.draft, this.status});

  final BookingDraft draft;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.bookingDetailsCard,
            style: context.text.labelLarge?.copyWith(
              color: context.colors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          BookingSummaryRows(draft: draft),
          if (status != null) ...[
            const SizedBox(height: 12),
            Text(
              context.l10n.statusLine(status!),
              style: context.text.bodySmall?.copyWith(
                color: context.colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
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
                      share.name,
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
                    share.isPaid
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    size: 18,
                    color: share.isPaid
                        ? context.colors.success
                        : context.colors.dim,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    share.isPaid
                        ? context.l10n.sharePaid
                        : context.l10n.shareUnpaid,
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
        ],
      ),
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
            style: context.text.labelLarge?.copyWith(
              color: context.colors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _Bullet(text: context.l10n.cancellationTermAuto),
          _Bullet(text: context.l10n.cancellationTermRefund),
        ],
      ),
    );
  }
}

class _BookingHeader extends StatelessWidget {
  const _BookingHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        children: [
          IconButton.filled(
            tooltip: context.l10n.back,
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded),
            style: IconButton.styleFrom(
              backgroundColor: context.colors.surface,
              foregroundColor: context.colors.ink,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                // The club is named by the step below, which is also where
                // it can be changed.
                Text(
                  context.l10n.booking,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _BookingNav extends StatelessWidget {
  const _BookingNav({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filled(
          tooltip: context.l10n.back,
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left_rounded),
          style: IconButton.styleFrom(
            backgroundColor: context.colors.surface,
            foregroundColor: context.colors.ink,
          ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
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
                      color: context.colors.ink,
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
    return Row(
      children: [
        _CounterButton(
          key: const ValueKey('players-minus'),
          icon: Icons.remove_rounded,
          label: context.l10n.removePlayer,
          enabled: value > min,
          onTap: withSelectionFeedback(() => onChanged(value - 1))!,
        ),
        Expanded(
          child: Text(
            context.l10n.playersCount(value),
            textAlign: TextAlign.center,
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _CounterButton(
          key: const ValueKey('players-plus'),
          icon: Icons.add_rounded,
          label: context.l10n.addPlayer,
          enabled: value < max,
          onTap: withSelectionFeedback(() => onChanged(value + 1))!,
        ),
      ],
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;

  /// An icon on its own says nothing out loud.
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: label,
      onPressed: enabled ? onTap : null,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: enabled
            ? context.colors.accent
            : context.colors.surfaceRaised,
        disabledBackgroundColor: context.colors.surfaceRaised,
        foregroundColor: context.colors.onAccent,
        disabledForegroundColor: context.colors.dim,
      ),
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
