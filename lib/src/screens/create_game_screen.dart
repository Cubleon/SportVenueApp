import 'package:flutter/material.dart';
import '../theme/app_icons.dart';

import '../labels.dart';

import '../../l10n/l10n.dart';

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/venue_picker.dart';
import '../widgets/venue_slot_picker.dart';
import 'games_screens.dart';

class CreateGameScreen extends StatefulWidget {
  const CreateGameScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends State<CreateGameScreen> {
  /// Measured, because the bar's buttons grow with the system font.
  double _barHeight = 150;

  void _onBarHeight(double height) {
    if (mounted && height != _barHeight) {
      setState(() => _barHeight = height);
    }
  }

  String? _sportId;
  Venue? _venue;
  late DateTime _date = DateTime(
    widget.controller.now.year,
    widget.controller.now.month,
    widget.controller.now.day,
  ).add(const Duration(days: 1));

  int _hour = 19;

  /// Set by the slot picker: whether the hour on screen is one the chosen
  /// club will actually take.
  bool _slotReady = false;
  int _duration = 120;
  int _capacity = 4;
  GameType _type = GameType.open;
  GenderFilter _gender = GenderFilter.any;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _sportId = _initialSportId();
    final venue = _selectedVenue;
    if (venue != null) {
      if (_capacity > venue.capacityMax) {
        _capacity = venue.capacityMax;
      }
      if (_capacity < venue.capacityMin) {
        _capacity = venue.capacityMin;
      }
    }
  }

  String? _initialSportId() {
    for (final selectedId in widget.controller.selectedSportIds) {
      for (final sport in widget.controller.sports) {
        if (sport.id == selectedId) {
          return selectedId;
        }
      }
    }
    for (final sport in widget.controller.sports) {
      return sport.id;
    }
    return null;
  }

  List<Venue> get _availableVenues {
    final sportId = _sportId;
    if (sportId == null) {
      return const [];
    }
    return widget.controller.venues
        .where((venue) => venue.sportIds.contains(sportId))
        .toList();
  }

  Venue? get _selectedVenue {
    final selectedId = _venue?.id;
    for (final venue in _availableVenues) {
      if (venue.id == selectedId) {
        return venue;
      }
    }
    for (final venue in _availableVenues) {
      return venue;
    }
    return null;
  }

  Future<void> _pickVenue(List<Venue> venues, Sport? sport) async {
    final picked = await pickVenue(
      context,
      venues: venues,
      selected: _selectedVenue,
      sportOf: (_) => sport,
    );
    if (picked != null) {
      _selectVenue(picked);
    }
  }

  Sport? get _selectedSport {
    final sportId = _sportId;
    for (final sport in widget.controller.sports) {
      if (sport.id == sportId) {
        return sport;
      }
    }
    return null;
  }

  int? get _pricePerPerson {
    final venue = _selectedVenue;
    if (venue == null) {
      return null;
    }
    return (BookingDraft(
      venue: venue,
      date: _date,
      durationMinutes: _duration,
      startHour: _hour,
      players: _capacity,
      mode: PaymentMode.split,
    ).sharePrice);
  }

  @override
  Widget build(BuildContext context) {
    final sport = _selectedSport;
    final selectedVenue = _selectedVenue;
    final availableVenues = _availableVenues;
    final pricePerPerson = _pricePerPerson;
    final minCapacity = selectedVenue?.capacityMin ?? 2;
    final maxCapacity = selectedVenue?.capacityMax ?? 2;
    // A game cannot be held at an hour the club has already let go, so the
    // button waits for the picker to say the chosen one is free.
    final canCreate =
        !_loading && sport != null && selectedVenue != null && _slotReady;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, _barHeight),
              children: [
                _CreateHeader(onBack: () => Navigator.of(context).pop()),
                _Block(
                  step: 1,
                  title: context.l10n.sportKind,
                  child: widget.controller.sports.isEmpty
                      ? Text(
                          context.l10n.sportsUnavailable,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.muted,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.controller.sports.map((sport) {
                            return SelectableChip(
                              label: sport.name.capitalized,
                              icon: sport.icon,
                              selected: _sportId == sport.id,
                              onTap: () => _selectSport(sport),
                            );
                          }).toList(),
                        ),
                ),
                _Block(
                  step: 2,
                  title: context.l10n.venueStep,
                  child: availableVenues.isEmpty
                      ? Text(
                          context.l10n.noVenuesForChosenSport,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.muted,
                          ),
                        )
                      // One line, whatever the catalogue grows to. The list
                      // and its search live in the sheet this opens.
                      : VenueRow(
                          key: const ValueKey('create-venue-field'),
                          venue: selectedVenue!,
                          sport: sport,
                          selected: false,
                          onTap: () => _pickVenue(availableVenues, sport),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (availableVenues.length > 1)
                                Text(
                                  context.l10n.moreVenues(
                                    availableVenues.length - 1,
                                  ),
                                  style: context.text.labelSmall?.copyWith(
                                    color: context.colors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              Icon(
                                AppIcons.chevronDown,
                                color: context.colors.dim,
                              ),
                            ],
                          ),
                        ),
                ),
                _Block(
                  step: 3,
                  title: context.l10n.dateStep,
                  child: DateStrip(
                    now: widget.controller.now,
                    selected: _date,
                    onSelect: (date) => setState(() => _date = date),
                  ),
                ),
                _Block(
                  step: 4,
                  title: context.l10n.startStep,
                  child: selectedVenue == null
                      ? Text(
                          context.l10n.pickVenueFirst,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.muted,
                          ),
                        )
                      : VenueSlotPicker(
                          controller: widget.controller,
                          venue: selectedVenue,
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
                _Block(
                  step: 5,
                  title: context.l10n.durationStep,
                  child: DurationPicker(
                    value: _duration,
                    onChanged: (value) => setState(() => _duration = value),
                  ),
                ),
                _Block(
                  step: 6,
                  title: context.l10n.placesStep,
                  child: Row(
                    children: [
                      IconButton.filled(
                        tooltip: context.l10n.removePlace,
                        key: const ValueKey('create-capacity-minus'),
                        onPressed:
                            selectedVenue != null && _capacity > minCapacity
                            ? withSelectionFeedback(
                                () => setState(() => _capacity--),
                              )
                            : null,
                        icon: const Icon(AppIcons.minus),
                      ),
                      Expanded(
                        child: Text(
                          context.l10n.placesCount(_capacity),
                          textAlign: TextAlign.center,
                          style: context.text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: context.l10n.addPlace,
                        key: const ValueKey('create-capacity-plus'),
                        onPressed:
                            selectedVenue != null && _capacity < maxCapacity
                            ? withSelectionFeedback(
                                () => setState(() => _capacity++),
                              )
                            : null,
                        icon: const Icon(AppIcons.plus),
                      ),
                    ],
                  ),
                ),
                _Block(
                  step: 7,
                  title: context.l10n.whoCanJoin,
                  // "Закрытая · только по ссылке" stood here, and there are
                  // no links: nothing in the app produces one, sends one or
                  // opens one, and nothing hides such a game from the public
                  // list either. It was an option that made a game harder to
                  // join and no harder to find. It comes back with the
                  // sharing it names.
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        activeThumbColor: context.colors.accent,
                        activeTrackColor: context.colors.accent.withValues(
                          alpha: 0.28,
                        ),
                        title: Text(
                          context.l10n.approveManually,
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          context.l10n.approveManuallyHint,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.muted,
                          ),
                        ),
                        value: _type == GameType.approval,
                        onChanged: (value) => setState(
                          () =>
                              _type = value ? GameType.approval : GameType.open,
                        ),
                      ),
                    ],
                  ),
                ),
                _Block(
                  step: 8,
                  title: context.l10n.participantFilter,
                  child: Row(
                    children: [
                      Expanded(
                        child: _GenderChip(
                          label: context.l10n.genderAny,
                          value: GenderFilter.any,
                          selected: _gender,
                          onTap: _setGender,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _GenderChip(
                          label: context.l10n.genderMen,
                          value: GenderFilter.men,
                          selected: _gender,
                          onTap: _setGender,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _GenderChip(
                          label: context.l10n.genderWomen,
                          value: GenderFilter.women,
                          selected: _gender,
                          onTap: _setGender,
                        ),
                      ),
                    ],
                  ),
                ),
                // The running total, set apart by a tinted fill rather than a
                // border, and given the same top gap as a numbered block so it
                // does not touch the filter chips above it.
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: AppCard(
                    color: context.colors.accentSoft,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.pricePerPerson,
                            style: context.text.bodyMedium?.copyWith(
                              color: context.colors.muted,
                            ),
                          ),
                        ),
                        Text(
                          pricePerPerson == null
                              ? context.l10n.emptyValue
                              : AppFormatters.money(pricePerPerson),
                          style: context.text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
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
                child: PrimaryButton(
                  key: const ValueKey('create-game-submit'),
                  label: context.l10n.createGame,
                  isLoading: _loading,
                  onPressed: canCreate ? _create : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setGender(GenderFilter value) {
    setState(() => _gender = value);
  }

  void _selectSport(Sport sport) {
    setState(() {
      _sportId = sport.id;
      _venue = null;
      final venue = _selectedVenue;
      if (venue != null) {
        if (_capacity > venue.capacityMax) {
          _capacity = venue.capacityMax;
        }
        if (_capacity < venue.capacityMin) {
          _capacity = venue.capacityMin;
        }
      }
    });
  }

  void _selectVenue(Venue venue) {
    setState(() {
      _venue = venue;
      if (_capacity > venue.capacityMax) {
        _capacity = venue.capacityMax;
      }
      if (_capacity < venue.capacityMin) {
        _capacity = venue.capacityMin;
      }
    });
  }

  Future<void> _create() async {
    final sportId = _sportId;
    final venue = _selectedVenue;
    if (sportId == null || venue == null) {
      showAppSnack(context, context.l10n.pickSportAndVenue);
      return;
    }

    setState(() => _loading = true);
    try {
      final game = await widget.controller.createGame(
        sportId: sportId,
        venue: venue,
        date: _date,
        startHour: _hour,
        durationMinutes: _duration,
        capacity: _capacity,
        type: _type,
        genderFilter: _gender,
      );
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      showAppSnack(context, context.l10n.gameCreated, tone: SnackTone.done);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              GameDetailScreen(controller: widget.controller, game: game),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      showAppSnack(context, errorText(context, error), tone: SnackTone.failed);
    }
  }
}

class _CreateHeader extends StatelessWidget {
  const _CreateHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filled(
          tooltip: context.l10n.back,
          onPressed: onBack,
          icon: const Icon(AppIcons.chevronLeft),
          style: IconButton.styleFrom(
            backgroundColor: context.colors.surface,
            foregroundColor: context.colors.ink,
          ),
        ),
        Expanded(
          child: Text(
            context.l10n.createGame,
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

class _Block extends StatelessWidget {
  const _Block({required this.step, required this.title, required this.child});

  final int step;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
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

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final GenderFilter value;
  final GenderFilter selected;
  final ValueChanged<GenderFilter> onTap;

  @override
  Widget build(BuildContext context) {
    return SelectableChip(
      label: label,
      selected: selected == value,
      onTap: () => onTap(value),
    );
  }
}
