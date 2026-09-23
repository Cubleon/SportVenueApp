import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
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

  /// The hours a game can start at. Every one of them is on screen, so
  /// there is no order to tap them in and no way to overshoot.
  static const _firstHour = 8;
  static const _lastHour = 23;

  int _hour = 19;
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
    final canCreate = !_loading && sport != null && selectedVenue != null;
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
                  title: 'Вид спорта',
                  child: widget.controller.sports.isEmpty
                      ? Text(
                          'Виды спорта пока недоступны',
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
                  title: 'Площадка',
                  child: availableVenues.isEmpty
                      ? Text(
                          'Для выбранного спорта площадок пока нет',
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.muted,
                          ),
                        )
                      : Column(
                          children: availableVenues
                              .map(
                                (venue) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: AppCard(
                                    onTap: withSelectionFeedback(
                                      () => _selectVenue(venue),
                                    ),
                                    borderColor: selectedVenue?.id == venue.id
                                        ? context.colors.accent
                                        : context.colors.border,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                venue.name.capitalized,
                                                style: context.text.titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${venue.address} · ${AppFormatters.money(venue.pricePerHour)}/час',
                                                style: context.text.bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          context.colors.muted,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (selectedVenue?.id == venue.id)
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: context.colors.accent,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                _Block(
                  step: 3,
                  title: 'Дата',
                  child: DateStrip(
                    now: widget.controller.now,
                    selected: _date,
                    onSelect: (date) => setState(() => _date = date),
                  ),
                ),
                _Block(
                  step: 4,
                  title: 'Начало',
                  child: TimeGrid(
                    tiles: [
                      for (var hour = _firstHour; hour <= _lastHour; hour++)
                        TimeTile(
                          label: '${hour.toString().padLeft(2, '0')}:00',
                          selected: hour == _hour,
                          onTap: () => setState(() => _hour = hour),
                        ),
                    ],
                  ),
                ),
                _Block(
                  step: 5,
                  title: 'Продолжительность',
                  child: DurationPicker(
                    value: _duration,
                    onChanged: (value) => setState(() => _duration = value),
                  ),
                ),
                _Block(
                  step: 6,
                  title: 'Количество мест',
                  child: Row(
                    children: [
                      IconButton.filled(
                        tooltip: 'Убрать место',
                        key: const ValueKey('create-capacity-minus'),
                        onPressed:
                            selectedVenue != null && _capacity > minCapacity
                            ? withSelectionFeedback(
                                () => setState(() => _capacity--),
                              )
                            : null,
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      Expanded(
                        child: Text(
                          '$_capacity места',
                          textAlign: TextAlign.center,
                          style: context.text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: 'Добавить место',
                        key: const ValueKey('create-capacity-plus'),
                        onPressed:
                            selectedVenue != null && _capacity < maxCapacity
                            ? withSelectionFeedback(
                                () => setState(() => _capacity++),
                              )
                            : null,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
                _Block(
                  step: 7,
                  title: 'Тип игры',
                  child: Column(
                    children: [
                      _OptionTile(
                        title: 'Открытая',
                        subtitle: 'Любой может вступить',
                        selected: _type == GameType.open,
                        onTap: () => setState(() => _type = GameType.open),
                      ),
                      const SizedBox(height: 8),
                      _OptionTile(
                        title: 'Закрытая',
                        subtitle: 'Только по ссылке',
                        selected: _type == GameType.closed,
                        onTap: () => setState(() => _type = GameType.closed),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        activeThumbColor: context.colors.accent,
                        activeTrackColor: context.colors.accent.withValues(
                          alpha: 0.28,
                        ),
                        title: Text(
                          'Одобрять вручную',
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'Вы будете подтверждать каждого игрока',
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
                  title: 'Фильтр участников',
                  child: Row(
                    children: [
                      Expanded(
                        child: _GenderChip(
                          label: 'Любой',
                          value: GenderFilter.any,
                          selected: _gender,
                          onTap: _setGender,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _GenderChip(
                          label: 'Мужчины',
                          value: GenderFilter.men,
                          selected: _gender,
                          onTap: _setGender,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _GenderChip(
                          label: 'Женщины',
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
                            'Стоимость с человека',
                            style: context.text.bodyMedium?.copyWith(
                              color: context.colors.muted,
                            ),
                          ),
                        ),
                        Text(
                          pricePerPerson == null
                              ? '—'
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
                  label: 'Создать игру',
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
      showAppSnack(context, 'Выберите вид спорта и площадку');
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
      showAppSnack(context, 'Игра создана', tone: SnackTone.done);
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
      showAppSnack(
        context,
        widget.controller.messageFor(error),
        tone: SnackTone.failed,
      );
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
          tooltip: 'Назад',
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left_rounded),
          style: IconButton.styleFrom(
            backgroundColor: context.colors.surface,
            foregroundColor: context.colors.ink,
          ),
        ),
        Expanded(
          child: Text(
            'Создать игру',
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

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: withSelectionFeedback(onTap),
      borderColor: selected ? context.colors.accent : context.colors.border,
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? context.colors.accent : context.colors.dim,
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
                Text(
                  subtitle,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.muted,
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
