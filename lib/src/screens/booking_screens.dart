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
import '../widgets/pull_to_refresh.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/venue_picker.dart';
import '../widgets/venue_slot_picker.dart';

/// One screen for an hour at a club, whoever is going to play in it.
///
/// Booking and creating a game used to be two screens behind a sheet that
/// asked which one before anything else: the same club, day, length and hour
/// asked twice, in two orders, with two sets of buttons. Now the question is
/// a switch at the top — «Для своих» or «Нужны игроки» — and the steps below
/// are shared; a game adds who may play and whether the organiser lets each
/// player in by hand.
class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.controller,
    this.venue,
    this.date,
    this.findPlayers = false,
  });

  final AppController controller;

  /// The club, when the reader arrived from one. From the «+» there is none
  /// yet, and the first step asks.
  final Venue? venue;

  /// The day the screen opens on. The home screen sends the day its calendar
  /// is showing, so picking Friday there and tapping a club does not land you
  /// back on today.
  final DateTime? date;

  /// Opens on «Нужны игроки» rather than «Для своих».
  final bool findPlayers;

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

  late bool _findPlayers = widget.findPlayers;

  /// The day, if one has been chosen. A reader arriving from the home
  /// brings the day its calendar was showing; one arriving from the tab bar
  /// has not said yet, and the steps below wait for them.
  late DateTime? _date = widget.date;
  late Venue? _venue = widget.venue;

  /// An hour for a booking, two for a game — until the reader says
  /// otherwise, after which switching modes leaves their answer alone.
  late int _duration = _findPlayers ? 120 : 60;
  bool _durationTouched = false;

  /// The hour, once it is picked. It used to start at eight in the evening
  /// with the pay button already live above it, so the screen could be paid
  /// for an hour nobody had chosen.
  int? _hour;
  late int _players = _venue == null
      ? 4
      : 4.clamp(_venue!.capacityMin, _venue!.capacityMax);

  /// Set by the slot picker, which is the only thing that knows whether the
  /// hour on screen is one the club will take.
  bool _slotReady = false;

  /// The game's sport, when the club has more than one.
  String? _sportId;
  GameType _type = GameType.open;
  GenderFilter _gender = GenderFilter.any;
  bool _creating = false;

  bool get _venueChosen => _venue != null;
  bool get _dateChosen => _venueChosen && _date != null;
  bool get _timeChosen => _dateChosen && _hour != null && _slotReady;

  /// Only makes sense once a club, a day and an hour exist.
  BookingDraft get _draft => BookingDraft(
    venue: _venue!,
    date: _date!,
    durationMinutes: _duration,
    startHour: _hour!,
    players: _players,
    mode: PaymentMode.split,
  );

  /// The sport a game at [venue] is for: the one picked on the screen, else
  /// the reader's own if the club has it, else the club's first.
  String _gameSportId(Venue venue) {
    final picked = _sportId;
    if (picked != null && venue.sportIds.contains(picked)) {
      return picked;
    }
    for (final id in widget.controller.selectedSportIds) {
      if (venue.sportIds.contains(id)) {
        return id;
      }
    }
    return primarySportId(venue);
  }

  void _setMode(bool findPlayers) {
    if (findPlayers == _findPlayers) {
      return;
    }
    setState(() {
      _findPlayers = findPlayers;
      if (!_durationTouched && _hour == null) {
        _duration = findPlayers ? 120 : 60;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final venue = _venue;
    final l10n = context.l10n;
    var step = 0;
    final multiSport = venue != null && venue.sportIds.length > 1;
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
                    title: _findPlayers ? l10n.newGame : l10n.booking,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    child: _ModeSwitch(
                      findPlayers: _findPlayers,
                      onChanged: _setMode,
                    ),
                  ),
                ),
                if (venue != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: VenueHero(
                        venue: venue,
                        // The game's sport, so a padel game at a club that
                        // also has tennis does not show a tennis court.
                        sportId: _findPlayers ? _gameSportId(venue) : null,
                        height: context.scaled(120, max: 1.2),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _StepBlock(
                    step: ++step,
                    title: l10n.venueStep,
                    // The club arrives with the screen, but it is still a
                    // choice: comparing two clubs' free hours used to mean
                    // going back out and starting over.
                    child: venue == null
                        // Opened from the «+» with no clubs to offer: the
                        // server did not answer, or has none yet. A picker
                        // over an empty list said neither.
                        ? ListenableBuilder(
                            listenable: widget.controller,
                            builder: (context, _) {
                              final venues = widget.controller.venues;
                              if (venues.isNotEmpty) {
                                return _ChooseVenueRow(
                                  key: const ValueKey('create-venue-empty'),
                                  count: venues.length,
                                  onTap: _pickVenue,
                                );
                              }
                              if (widget.controller.loadFailed) {
                                return RetryNotice(
                                  key: const ValueKey('create-load-failed'),
                                  message: l10n.loadFailed,
                                  onRetry: () => refreshAndReport(
                                    context,
                                    widget.controller,
                                  ),
                                );
                              }
                              return Text(
                                l10n.noVenuesAvailable,
                                key: const ValueKey('create-no-venues'),
                                style: context.text.bodyMedium?.copyWith(
                                  color: context.colors.muted,
                                ),
                              );
                            },
                          )
                        : VenueRow(
                            key: const ValueKey('booking-venue-field'),
                            venue: venue,
                            sport: _sportById(
                              _findPlayers
                                  ? _gameSportId(venue)
                                  : primarySportId(venue),
                            ),
                            selected: false,
                            onTap: _pickVenue,
                            trailing: Icon(
                              AppIcons.chevronDown,
                              color: context.colors.muted,
                            ),
                          ),
                  ),
                ),
                // A game is for one sport; a club with several asks which.
                if (_findPlayers && multiSport)
                  SliverToBoxAdapter(
                    child: _StepBlock(
                      step: ++step,
                      title: l10n.sportKind,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in venue.sportIds)
                            SelectableChip(
                              label: _sportById(id)?.name.capitalized ?? id,
                              selected: _gameSportId(venue) == id,
                              onTap: () => setState(() => _sportId = id),
                            ),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: RevealStep(
                    visible: _venueChosen,
                    child: _StepBlock(
                      step: ++step,
                      title: l10n.dateStep,
                      child: DateStrip(
                        now: widget.controller.now,
                        selected: _date,
                        onSelect: (date) => setState(() {
                          _date = date;
                          // A different day has different free hours; the
                          // one that was picked on the old day is not a
                          // choice on this one.
                          _hour = null;
                          _slotReady = false;
                        }),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealStep(
                    visible: _dateChosen,
                    child: _StepBlock(
                      step: ++step,
                      title: l10n.durationStep,
                      child: DurationPicker(
                        value: _duration,
                        onChanged: (value) => setState(() {
                          _duration = value;
                          _durationTouched = true;
                        }),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealStep(
                    visible: _dateChosen,
                    child: _StepBlock(
                      step: ++step,
                      title: l10n.timeStep,
                      child: venue == null
                          ? const SizedBox.shrink()
                          : VenueSlotPicker(
                              key: ValueKey(
                                'slots-${venue.id}-${_date?.toIso8601String()}',
                              ),
                              controller: widget.controller,
                              venue: venue,
                              date: _date ?? widget.controller.now,
                              durationMinutes: _duration,
                              selectedHour: _hour,
                              onHourChanged: (hour) =>
                                  setState(() => _hour = hour),
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
                      step: ++step,
                      title: _findPlayers ? l10n.placesStep : l10n.playersStep,
                      child: Column(
                        children: [
                          _CounterRow(
                            value: _players,
                            min: venue?.capacityMin ?? 2,
                            max: venue?.capacityMax ?? 2,
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
                if (_findPlayers) ...[
                  SliverToBoxAdapter(
                    child: RevealStep(
                      visible: _timeChosen,
                      child: _StepBlock(
                        step: ++step,
                        title: l10n.participantFilter,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                for (final (index, option) in [
                                  (GenderFilter.any, l10n.genderAny),
                                  (GenderFilter.men, l10n.genderMen),
                                  (GenderFilter.women, l10n.genderWomen),
                                ].indexed) ...[
                                  if (index > 0) const SizedBox(width: 8),
                                  Expanded(
                                    child: SelectableChip(
                                      label: option.$2,
                                      selected: _gender == option.$1,
                                      onTap: () =>
                                          setState(() => _gender = option.$1),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // Three bare chips let anyone shut half the city
                            // out of a game with one tap and no thought. The
                            // line does not forbid it — women's and men's
                            // sessions are a real thing — it says what the
                            // option is for.
                            const SizedBox(height: 8),
                            Text(
                              l10n.participantFilterHint,
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.muted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: RevealStep(
                      visible: _timeChosen,
                      child: _StepBlock(
                        step: ++step,
                        title: l10n.whoCanJoin,
                        // One node for a screen reader: the switch, named by
                        // the words beside it.
                        child: AppCard(
                          child: MergeSemantics(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.approveManually,
                                        style: context.text.titleSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        l10n.approveManuallyHint,
                                        style: context.text.bodySmall?.copyWith(
                                          color: context.colors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Switch.adaptive(
                                  key: const ValueKey(
                                    'create-approve-manually',
                                  ),
                                  activeThumbColor: context.colors.accent,
                                  activeTrackColor: context.colors.accent
                                      .withValues(alpha: 0.28),
                                  value: _type == GameType.approval,
                                  onChanged: (value) => setState(
                                    () => _type = value
                                        ? GameType.approval
                                        : GameType.open,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: RevealStep(
                    visible: _timeChosen && !_findPlayers,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                      // What the money is for. The hour is chosen steps up
                      // the page, and the one part of the deal that changes
                      // should be in sight while paying.
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${AppFormatters.dateShort(_date!)} · '
                          '${_draft.timeRange} · ${venue!.name.capitalized}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_findPlayers)
                        PrimaryButton(
                          key: const ValueKey('create-game-submit'),
                          label: l10n.createGameShare(
                            AppFormatters.money(_draft.sharePrice),
                          ),
                          tone: ButtonTone.commit,
                          isLoading: _creating,
                          onPressed: _creating ? null : _createGame,
                        )
                      else ...[
                        PrimaryButton(
                          key: const ValueKey('pay-share'),
                          label: l10n.paySharePrice(
                            AppFormatters.money(_draft.sharePrice),
                          ),
                          tone: ButtonTone.commit,
                          onPressed: () => _goToConfirm(PaymentMode.split),
                        ),
                        const SizedBox(height: 10),
                        PrimaryButton(
                          key: const ValueKey('pay-full'),
                          label: l10n.payFullPrice(
                            AppFormatters.money(_draft.totalPrice),
                          ),
                          tone: ButtonTone.neutral,
                          onPressed: () => _goToConfirm(PaymentMode.full),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Sport? _sportById(String id) {
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
      sportOf: (venue) => _sportById(primarySportId(venue)),
    );
    if (picked == null || !mounted || picked.id == _venue?.id) {
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

  Future<void> _createGame() async {
    final venue = _venue!;
    setState(() => _creating = true);
    try {
      final game = await widget.controller.createGame(
        sportId: _gameSportId(venue),
        venue: venue,
        date: _date!,
        startHour: _hour!,
        durationMinutes: _duration,
        capacity: _players,
        type: _type,
        genderFilter: _gender,
      );
      if (!mounted) {
        return;
      }
      setState(() => _creating = false);
      showAppSnack(context, context.l10n.gameCreated, tone: SnackTone.done);
      // Replaced rather than stacked, and by address rather than by
      // object: the game now has a link its organiser can send to people.
      context.go(gameLocation(game));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _creating = false);
      showAppSnack(context, errorText(context, error), tone: SnackTone.failed);
    }
  }
}

/// «Для своих» or «Нужны игроки»: the one question that tells a booking from
/// a game, asked before the steps they share.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.findPlayers, required this.onChanged});

  final bool findPlayers;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget option({
      required Key key,
      required bool value,
      required String title,
      required String hint,
    }) {
      final selected = findPlayers == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: TapTarget(
            key: key,
            radius: 12,
            onTap: withSelectionFeedback(() => onChanged(value)),
            child: AnimatedContainer(
              duration: context.motion(const Duration(milliseconds: 160)),
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
              decoration: BoxDecoration(
                color: selected ? colors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: context.text.titleSmall?.copyWith(
                      color: selected ? colors.onAccent : colors.ink,
                    ),
                  ),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: context.text.labelSmall?.copyWith(
                      color: selected
                          ? colors.onAccent.withValues(alpha: 0.85)
                          : colors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          option(
            key: const ValueKey('mode-own'),
            value: false,
            title: context.l10n.modeOwn,
            hint: context.l10n.modeOwnHint,
          ),
          option(
            key: const ValueKey('mode-game'),
            value: true,
            title: context.l10n.modeGame,
            hint: context.l10n.modeGameHint,
          ),
        ],
      ),
    );
  }
}

/// The club step before it is answered: a row that looks like the row that
/// replaces it, so the step does not change shape when it is filled in.
class _ChooseVenueRow extends StatelessWidget {
  const _ChooseVenueRow({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: context.scaled(44),
              height: context.scaled(44),
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(AppIcons.search, color: colors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.chooseVenue,
                    style: context.text.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.venuesToChoose(count),
                    style: context.text.bodySmall?.copyWith(
                      color: colors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(AppIcons.chevronRight, color: colors.muted),
          ],
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
    // Cancelling is not pinned: as the big button at the foot it was the
    // loudest thing on the screen, and the screen is about collecting the
    // money. It sits at the end of the page as a quiet red link.
    final hasBar = canPay || canTake;
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
                if (booking.isActive) ...[
                  const SizedBox(height: 12),
                  PlanActions(
                    title: context.l10n.calendarBookingTitle(
                      booking.draft.venue.name.capitalized,
                    ),
                    start: booking.startsAt,
                    durationMinutes: booking.draft.durationMinutes,
                    venue: booking.draft.venue,
                  ),
                ],
                if (booking.shares.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SharesCard(booking: booking),
                ],
                const SizedBox(height: 12),
                const _CancellationTermsCard(),
                if (canCancel) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      key: const ValueKey('cancel-booking'),
                      onPressed: _loading ? null : _cancel,
                      style: TextButton.styleFrom(
                        foregroundColor: context.colors.danger,
                        minimumSize: const Size(44, 48),
                      ),
                      child: _loading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colors.danger,
                              ),
                            )
                          : Text(
                              context.l10n.cancelBooking,
                              style: context.text.labelLarge?.copyWith(
                                color: context.colors.danger,
                              ),
                            ),
                    ),
                  ),
                ],
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
                  style: context.text.titleSmall,
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
                    child: share.isOpen
                        // A free place: a plus, not an empty grey disc.
                        ? Icon(
                            AppIcons.plus,
                            size: context.scaled(16),
                            color: context.colors.muted,
                          )
                        : Text(
                            share.initial,
                            style: context.text.labelLarge?.copyWith(
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
                            ? FontWeight.w600
                            : FontWeight.w400,
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
                        : context.colors.muted,
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
          // Places taken and not paid for: someone said yes and has not
          // followed through. There is no push to nudge them yet, so this
          // hands over a reminder ready for the players' chat.
          if (_owing(booking) > 0) ...[
            const SizedBox(height: 10),
            PrimaryButton(
              key: const ValueKey('remind-to-pay'),
              label: context.l10n.remindToPay,
              tone: ButtonTone.neutral,
              icon: AppIcons.clock,
              onPressed: () => _copyReminder(context, booking),
            ),
          ],
        ],
      ),
    );
  }
}

int _owing(Booking booking) => booking.shares
    .where(
      (share) =>
          share.status == ShareStatus.unpaid ||
          share.status == ShareStatus.notFound,
    )
    .length;

Future<void> _copyReminder(BuildContext context, Booking booking) async {
  final l10n = context.l10n;
  final text = [
    l10n.payReminderText(
      AppFormatters.money(booking.draft.sharePrice),
      booking.draft.venue.name.capitalized,
      '${AppFormatters.dateShort(booking.draft.date)}, ${booking.draft.timeRange}',
    ),
    l10n.payReminderDeadline(AppFormatters.moment(booking.deadline)),
    if (canShareLinks) shareLink(Routes.booking(booking.id)),
  ].join(' ');
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    showAppSnack(context, l10n.payReminderCopied, tone: SnackTone.done);
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
        Text(title, style: context.text.titleSmall),
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
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Wraps on large text: «Продолжительность» at 160% is wider
              // than the phone.
              Flexible(child: Text(title, style: context.text.titleSmall)),
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
            style: context.text.titleLarge,
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
