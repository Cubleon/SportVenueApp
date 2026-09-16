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
  String? _sportId;
  Venue? _venue;
  late DateTime _date = DateTime(
    widget.controller.now.year,
    widget.controller.now.month,
    widget.controller.now.day,
  ).add(const Duration(days: 1));
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 128),
              children: [
                _CreateHeader(onBack: () => Navigator.of(context).pop()),
                _Block(
                  step: 1,
                  title: 'Вид спорта',
                  child: widget.controller.sports.isEmpty
                      ? Text(
                          'Виды спорта пока недоступны',
                          style: context.text.bodyMedium?.copyWith(
                            color: AppColors.muted,
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
                            color: AppColors.muted,
                          ),
                        )
                      : Column(
                          children: availableVenues
                              .map(
                                (venue) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: AppCard(
                                    onTap: () => _selectVenue(venue),
                                    borderColor: selectedVenue?.id == venue.id
                                        ? AppColors.accent
                                        : AppColors.border,
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
                                                      color: AppColors.muted,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (selectedVenue?.id == venue.id)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.accent,
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
                  title: 'Дата и время',
                  child: Row(
                    children: [
                      Expanded(
                        child: _SmallSelector(
                          label: AppFormatters.dateShort(_date),
                          onTap: () => setState(
                            () => _date = _date.add(const Duration(days: 1)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SmallSelector(
                          label: '${_hour.toString().padLeft(2, '0')}:00',
                          onTap: () => setState(
                            () => _hour = _hour >= 22 ? 18 : _hour + 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SmallSelector(
                          label:
                              '${_duration ~/ 60}${_duration == 90 ? '.5' : ''} ч',
                          onTap: () => setState(
                            () => _duration = switch (_duration) {
                              60 => 90,
                              90 => 120,
                              _ => 60,
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _Block(
                  step: 4,
                  title: 'Количество мест',
                  child: Row(
                    children: [
                      IconButton.filled(
                        key: const ValueKey('create-capacity-minus'),
                        onPressed:
                            selectedVenue != null && _capacity > minCapacity
                            ? () => setState(() => _capacity--)
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
                        key: const ValueKey('create-capacity-plus'),
                        onPressed:
                            selectedVenue != null && _capacity < maxCapacity
                            ? () => setState(() => _capacity++)
                            : null,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
                _Block(
                  step: 5,
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
                        activeThumbColor: AppColors.accent,
                        activeTrackColor: AppColors.accent.withValues(
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
                            color: AppColors.muted,
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
                  step: 6,
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
                AppCard(
                  borderColor: AppColors.accent.withValues(alpha: 0.22),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Стоимость с человека',
                          style: context.text.bodyMedium?.copyWith(
                            color: AppColors.muted,
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
              ],
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 28,
              child: PrimaryButton(
                key: const ValueKey('create-game-submit'),
                label: 'Создать игру',
                isLoading: _loading,
                onPressed: canCreate ? _create : null,
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
      showAppSnack(context, 'Игра создана');
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
      showAppSnack(context, widget.controller.messageFor(error));
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
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left_rounded),
          style: IconButton.styleFrom(backgroundColor: AppColors.surface),
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
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$step',
                    style: context.text.labelSmall?.copyWith(
                      color: AppColors.ink,
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

class _SmallSelector extends StatelessWidget {
  const _SmallSelector({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
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
      onTap: onTap,
      borderColor: selected ? AppColors.accent : AppColors.border,
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? AppColors.accent : AppColors.dim,
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
                  style: context.text.bodySmall?.copyWith(color: AppColors.muted),
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
